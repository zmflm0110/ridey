import 'package:ridey_app/features/live/live_snapshot.dart';

class StationTask {
  const StationTask({
    required this.stationId,
    required this.stationName,
    required this.bikes,
  });

  final String stationId;
  final String stationName;
  final List<LiveBike> bikes;

  int get highAlertCount => bikes.where((bike) => bike.isHighAlert).length;
  int get totalChain => bikes.fold(0, (total, bike) => total + bike.chain);
  double get priorityScore =>
      bikes.fold(0, (total, bike) => total + (bike.probability ?? bike.chain));
}

List<StationTask> buildStationTasks(List<LiveBike> bikes) {
  final grouped = <String, List<LiveBike>>{};
  for (final bike in bikes) {
    grouped.putIfAbsent(bike.station, () => []).add(bike);
  }

  final tasks = grouped.entries
      .map(
        (entry) => StationTask(
          stationId: entry.key,
          stationName: entry.value.first.stationName.isEmpty
              ? entry.key
              : entry.value.first.stationName,
          bikes: List.unmodifiable(entry.value),
        ),
      )
      .toList();
  tasks.sort((left, right) {
    final highAlert = right.highAlertCount.compareTo(left.highAlertCount);
    if (highAlert != 0) return highAlert;
    final score = right.priorityScore.compareTo(left.priorityScore);
    if (score != 0) return score;
    return right.totalChain.compareTo(left.totalChain);
  });
  return tasks;
}
