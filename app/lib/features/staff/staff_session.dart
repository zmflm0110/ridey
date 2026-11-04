import 'package:flutter/foundation.dart';
import 'package:ridey_app/features/live/live_snapshot.dart';
import 'package:ridey_app/features/live/live_snapshot_repository.dart';
import 'package:ridey_app/features/location/device_location.dart';
import 'package:ridey_app/features/rider/nearby_stations.dart';
import 'package:ridey_app/features/ops/ops_list.dart';
import 'package:ridey_app/features/ops/ops_list_repository.dart';
import 'package:ridey_app/features/staff/district_stats.dart';
import 'package:ridey_app/features/staff/staff_clock.dart';
import 'package:ridey_app/features/staff/staff_districts.dart';
import 'package:ridey_app/features/stations/bike_station.dart';
import 'package:ridey_app/features/stations/station_repository.dart';

enum AlertLevelFilter { all, high, alert }

class StaffSession extends ChangeNotifier {
  StaffSession({
    required LiveSnapshotRepository liveRepository,
    required OpsListRepository opsRepository,
    required StationRepository stationRepository,
    this.districtsStore = const StaffDistrictsStore(),
    this.now,
    this.readLocation,
  }) : _liveRepository = liveRepository,
       _opsRepository = opsRepository,
       _stationRepository = stationRepository;

  final LiveSnapshotRepository _liveRepository;
  final OpsListRepository _opsRepository;
  final StationRepository _stationRepository;
  final StaffDistrictsStore districtsStore;
  final DateTime? now;

  /// 최근 아침 목록 채점(새 날부터) — '이 목록이 맞았나' 를 직원이 직접 본다. 못 받으면 빈 목록.
  List<OpsScore> scores = const [];

  /// 직원이 지금 서 있는 곳 — 재배치 길에서 '가까운 고장 의심' 을 먼저 보여 주려고 쓴다. 없으면 구별로만.
  final Future<DeviceLocation?> Function()? readLocation;
  DeviceLocation? location;

  /// 목록을 가까운 순으로(위치가 있을 때 기본) 또는 위험한 순으로.
  var sortByDistance = true;

  List<String>? assigned;
  String? focusedDistrict;
  ListSource? sourceOverride;
  AlertLevelFilter levelFilter = AlertLevelFilter.all;

  var loading = true;
  Object? error;
  List<LiveBike> bikes = const [];
  Map<String, BikeStation> stations = const {};
  ListSource source = ListSource.live;
  String? morningDay;
  List<String> morningDays = const [];

  /// 지금 보이는 목록이 만들어진 때와 대여 기록 상태 — 상세 화면의 '갱신' 표시에 쓴다.
  /// 아침 목록은 그날 07:00 에 만든 것, 실시간은 받은 자료(폰에 저장해 둔 사본이면 그 시각)의 것.
  DateTime? updatedAt;
  FeedHealth? feed;

  var _generation = 0;

  List<String> get catalogDistricts => districtNames(stations.values);

  Future<void> start() async {
    assigned = await districtsStore.read();
    await Future.wait([reload(), locate(), _loadScores()]);
  }

  Future<void> _loadScores() async {
    try {
      scores = await _opsRepository.scores();
      notifyListeners();
    } catch (_) {}
  }

  /// 위치를 다시 찾는다(못 찾으면 그대로 구별 보기).
  Future<void> locate() async {
    final read = readLocation;
    if (read == null) return;
    try {
      final found = await read();
      if (found == null) return;
      location = found;
      notifyListeners();
    } catch (_) {}
  }

  void setSortByDistance(bool value) {
    if (sortByDistance == value) return;
    sortByDistance = value;
    notifyListeners();
  }

  /// 대여소까지의 거리(m). 위치나 대여소 좌표가 없으면 null.
  double? metersTo(String stationId) {
    final here = location;
    final station = stations[stationId];
    if (here == null || station == null) return null;
    return metersBetween(
      here.latitude,
      here.longitude,
      station.latitude,
      station.longitude,
    );
  }

  /// 내 주변 [radius] 안의 고장 의심 대여소 — 가까운 순. 담당 구와 상관없이 지금 보이는 자료 전부에서.
  List<({BikeStation station, List<LiveBike> bikes, double meters})> nearby({
    double radius = 2000,
  }) {
    final grouped = <String, List<LiveBike>>{};
    for (final bike in bikes) {
      (grouped[bike.station] ??= []).add(bike);
    }
    final out =
        <({BikeStation station, List<LiveBike> bikes, double meters})>[];
    for (final entry in grouped.entries) {
      final meters = metersTo(entry.key);
      final station = stations[entry.key];
      if (meters == null || station == null || meters > radius) continue;
      out.add((station: station, bikes: entry.value, meters: meters));
    }
    out.sort((a, b) => a.meters.compareTo(b.meters));
    return out;
  }

  /// 오늘 들를 순서 — 내 위치에서 시작해 매번 가장 가까운 다음 대여소로(가까운 이웃 순서).
  /// 강한 경보가 있는 대여소는 거리를 0.6배로 쳐서 먼저 들른다. [leg] 는 앞 지점에서 이 대여소까지(m).
  List<({BikeStation station, List<LiveBike> bikes, double leg})> visitOrder({
    double radius = 2000,
    int limit = 5,
  }) {
    final here = location;
    if (here == null) return const [];
    final left = [...nearby(radius: radius)];
    final out = <({BikeStation station, List<LiveBike> bikes, double leg})>[];
    var lat = here.latitude, lon = here.longitude;
    while (left.isNotEmpty && out.length < limit) {
      double cost(
        ({BikeStation station, List<LiveBike> bikes, double meters}) e,
      ) {
        final d = metersBetween(
          lat,
          lon,
          e.station.latitude,
          e.station.longitude,
        );
        return e.bikes.any((b) => b.isHighAlert) ? d * .6 : d;
      }

      left.sort((a, b) => cost(a).compareTo(cost(b)));
      final next = left.removeAt(0);
      final leg = metersBetween(
        lat,
        lon,
        next.station.latitude,
        next.station.longitude,
      );
      out.add((station: next.station, bikes: next.bikes, leg: leg));
      lat = next.station.latitude;
      lon = next.station.longitude;
    }
    return out;
  }

  Future<void> saveDistricts(List<String> districts) async {
    await districtsStore.write(districts);
    assigned = districts;
    focusedDistrict = null;
    notifyListeners();
  }

  void focusDistrict(String district) {
    focusedDistrict = district;
    notifyListeners();
  }

  /// 구별 현황에서 한 구를 눌러 목록을 좁혔다가 다른 탭으로 가면 담당 구 전체로 돌아온다.
  void clearFocus() {
    if (focusedDistrict == null) return;
    focusedDistrict = null;
    notifyListeners();
  }

  void setLevelFilter(AlertLevelFilter filter) {
    if (levelFilter == filter) return;
    levelFilter = filter;
    notifyListeners();
  }

  Future<void> setSource(ListSource next) async {
    sourceOverride = next;
    await reload();
  }

  /// 받기가 끝난 뒤에만 출처·목록을 함께 바꾼다. 실패하면 전에 보던 출처와 목록이 그대로 맞게 남고,
  /// 빠르게 두 번 바꿔 늦게 온 옛 응답은 버린다(출처 표시와 목록이 어긋나지 않게).
  Future<void> reload() async {
    final generation = ++_generation;
    loading = true;
    error = null;
    notifyListeners();
    try {
      final catalog = await _stationRepository.fetch();
      final days = await _opsRepository.days();
      final choice = resolveWorklist(
        days: days,
        source: sourceOverride,
        now: now,
      );
      final List<LiveBike> nextBikes;
      final ListSource nextSource;
      final DateTime nextUpdatedAt;
      FeedHealth? nextFeed;
      if (choice.source == ListSource.morning && choice.day != null) {
        nextBikes = (await _opsRepository.fetch(choice.day!)).bikes;
        nextSource = ListSource.morning;
        nextUpdatedAt =
            DateTime.tryParse('${choice.day}T07:00:00+09:00') ?? DateTime.now();
      } else {
        final live = await _liveRepository.fetch();
        nextBikes = live.bikes;
        nextSource = ListSource.live;
        nextUpdatedAt = live.updatedAt;
        nextFeed = live.feed;
      }
      if (generation != _generation) return;
      stations = {for (final station in catalog) station.id: station};
      morningDays = days;
      source = nextSource;
      morningDay = nextSource == ListSource.morning ? choice.day : null;
      bikes = nextBikes;
      updatedAt = nextUpdatedAt;
      feed = nextFeed;
    } catch (caught) {
      if (generation != _generation) return;
      error = caught;
    } finally {
      if (generation == _generation) {
        loading = false;
        notifyListeners();
      }
    }
  }

  Iterable<LiveBike> get visibleBikes {
    final selected = focusedDistrict == null
        ? (assigned ?? const <String>[])
        : <String>[focusedDistrict!];
    return bikes.where((bike) {
      if (selected.isNotEmpty &&
          !selected.contains(districtOf(bike, stations))) {
        return false;
      }
      return switch (levelFilter) {
        AlertLevelFilter.all => true,
        AlertLevelFilter.high => bike.isHighAlert,
        AlertLevelFilter.alert => !bike.isHighAlert,
      };
    });
  }
}
