import 'package:flutter/foundation.dart';
import 'package:ridey_app/features/live/live_snapshot.dart';
import 'package:ridey_app/features/live/live_snapshot_repository.dart';
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
  }) : _liveRepository = liveRepository,
       _opsRepository = opsRepository,
       _stationRepository = stationRepository;

  final LiveSnapshotRepository _liveRepository;
  final OpsListRepository _opsRepository;
  final StationRepository _stationRepository;
  final StaffDistrictsStore districtsStore;
  final DateTime? now;

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
    await reload();
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
      if (selected.isNotEmpty && !selected.contains(districtOf(bike, stations))) {
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
