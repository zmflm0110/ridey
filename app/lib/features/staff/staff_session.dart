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

  void setLevelFilter(AlertLevelFilter filter) {
    if (levelFilter == filter) return;
    levelFilter = filter;
    notifyListeners();
  }

  Future<void> setSource(ListSource next) async {
    sourceOverride = next;
    await reload();
  }

  Future<void> reload() async {
    loading = true;
    error = null;
    notifyListeners();
    try {
      final catalog = await _stationRepository.fetch();
      stations = {for (final station in catalog) station.id: station};
      morningDays = await _opsRepository.days();
      final choice = resolveWorklist(
        days: morningDays,
        source: sourceOverride,
        now: now,
      );
      source = choice.source;
      morningDay = choice.day;
      if (source == ListSource.morning && morningDay != null) {
        bikes = (await _opsRepository.fetch(morningDay!)).bikes;
      } else {
        source = ListSource.live;
        bikes = (await _liveRepository.fetch()).bikes;
      }
    } catch (caught) {
      error = caught;
    } finally {
      loading = false;
      notifyListeners();
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
