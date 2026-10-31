enum ListSource { live, morning }

({String date, int minutes}) seoulParts([DateTime? now]) {
  final utc = (now ?? DateTime.now()).toUtc();
  final seoul = utc.add(const Duration(hours: 9));
  final month = seoul.month.toString().padLeft(2, '0');
  final day = seoul.day.toString().padLeft(2, '0');
  return (
    date: '${seoul.year}-$month-$day',
    minutes: seoul.hour * 60 + seoul.minute,
  );
}

({ListSource source, String? day}) resolveWorklist({
  required List<String> days,
  ListSource? source,
  String? day,
  DateTime? now,
}) {
  final clock = seoulParts(now);
  final morningDefault = clock.minutes < 12 * 60 && days.contains(clock.date)
      ? clock.date
      : null;

  if (source == ListSource.live) {
    return (source: ListSource.live, day: null);
  }
  if (source == ListSource.morning) {
    if (day != null && days.contains(day)) {
      return (source: ListSource.morning, day: day);
    }
    return (
      source: ListSource.morning,
      day: morningDefault ?? (days.isEmpty ? null : days.first),
    );
  }
  if (morningDefault != null) {
    return (source: ListSource.morning, day: morningDefault);
  }
  return (source: ListSource.live, day: null);
}
