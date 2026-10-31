import 'package:flutter/material.dart';
import 'package:ridey_app/design/ridey_theme.dart';
import 'package:ridey_app/features/live/live_snapshot.dart';
import 'package:ridey_app/features/rider/bike_detail_page.dart';
import 'package:ridey_app/features/staff/district_stats.dart';
import 'package:ridey_app/features/staff/staff_clock.dart';
import 'package:ridey_app/features/staff/staff_session.dart';
import 'package:ridey_app/widgets/ridey_tab_bar.dart';
import 'package:ridey_app/widgets/ridey_ui.dart';

class StaffListPage extends StatelessWidget {
  const StaffListPage({super.key, required this.session});

  final StaffSession session;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (session.loading && session.bikes.isEmpty) {
      return const Center(child: CircularProgressIndicator.adaptive());
    }

    final bikes = session.visibleBikes.toList(growable: false);
    final groups = <String, List<LiveBike>>{};
    for (final bike in bikes) {
      (groups[bike.station] ??= []).add(bike);
    }
    final stations = groups.entries.toList()
      ..sort((a, b) {
        final byExpected = (expectOf(b.value) ?? 0).compareTo(
          expectOf(a.value) ?? 0,
        );
        if (byExpected != 0) return byExpected;
        return b.value.length.compareTo(a.value.length);
      });

    return RefreshIndicator.adaptive(
      color: context.ridey.signal,
      onRefresh: session.reload,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 8, 16, rideyTabClearance),
        children: [
          Text('목록', style: theme.textTheme.displayLarge),
          const SizedBox(height: 14),
          SegmentedButton<ListSource>(
            segments: const [
              ButtonSegment(value: ListSource.live, label: Text('실시간')),
              ButtonSegment(value: ListSource.morning, label: Text('아침 목록')),
            ],
            selected: {session.source},
            onSelectionChanged: (next) => session.setSource(next.single),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            children: [
              for (final filter in AlertLevelFilter.values)
                ChoiceChip(
                  label: Text(switch (filter) {
                    AlertLevelFilter.all => '전체',
                    AlertLevelFilter.high => '강한 경보',
                    AlertLevelFilter.alert => '경보',
                  }),
                  selected: session.levelFilter == filter,
                  onSelected: (_) => session.setLevelFilter(filter),
                ),
            ],
          ),
          const SizedBox(height: 16),
          if (bikes.isEmpty)
            Text(
              '이 조건에 맞는 고장 의심 자전거가 없어요.',
              style: theme.textTheme.bodyLarge?.copyWith(
                color: context.ridey.muted,
              ),
            )
          else
            for (final group in stations) ...[
              Padding(
                padding: const EdgeInsets.fromLTRB(4, 10, 4, 8),
                child: Text(
                  session.stations[group.key]?.name ?? group.value.first.stationName,
                  style: theme.textTheme.titleMedium,
                ),
              ),
              RideyListCard(
                children: [
                  for (final bike in group.value)
                    RideyRow(
                      title: bike.bike,
                      subtitle: bike.isHighAlert ? '강한 경보' : '경보',
                      trailing: Text(
                        '${bike.chain}명',
                        style: context.rideyNumbers(theme.textTheme.titleMedium)
                            ?.copyWith(
                              color: bike.isHighAlert
                                  ? context.ridey.signalText
                                  : context.ridey.muted,
                            ),
                      ),
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => BikeDetailPage(
                              bike: bike,
                              updatedAt: DateTime.now(),
                            ),
                          ),
                        );
                      },
                    ),
                ],
              ),
            ],
        ],
      ),
    );
  }
}
