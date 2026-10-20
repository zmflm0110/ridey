import 'package:shared_preferences/shared_preferences.dart';

const savedStationsLimit = 5;

List<String> addSavedStation(List<String> stations, String stationId) {
  if (stations.contains(stationId)) return stations;
  return [...stations, stationId].takeLast(savedStationsLimit);
}

List<String> removeSavedStation(List<String> stations, String stationId) {
  return stations.where((id) => id != stationId).toList(growable: false);
}

extension on List<String> {
  List<String> takeLast(int count) {
    if (length <= count) return this;
    return sublist(length - count);
  }
}

class SavedStationsStore {
  static const _key = 'my_stations';

  Future<List<String>> load() async {
    final preferences = await SharedPreferences.getInstance();
    return (preferences.getStringList(_key) ?? const [])
        .take(savedStationsLimit)
        .toList(growable: false);
  }

  Future<List<String>> add(String stationId) async {
    final preferences = await SharedPreferences.getInstance();
    final next = addSavedStation(
      preferences.getStringList(_key) ?? const [],
      stationId,
    );
    await preferences.setStringList(_key, next);
    return next;
  }

  Future<List<String>> remove(String stationId) async {
    final preferences = await SharedPreferences.getInstance();
    final next = removeSavedStation(
      preferences.getStringList(_key) ?? const [],
      stationId,
    );
    await preferences.setStringList(_key, next);
    return next;
  }
}
