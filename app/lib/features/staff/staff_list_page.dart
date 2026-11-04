import 'package:flutter/material.dart';
import 'package:ridey_app/design/ridey_theme.dart';
import 'package:ridey_app/features/live/live_snapshot.dart';
import 'package:ridey_app/features/rider/nearby_stations.dart';
import 'package:ridey_app/features/staff/staff_bike.dart';
import 'package:ridey_app/features/staff/district_stats.dart';
import 'package:ridey_app/features/staff/staff_session.dart';
import 'package:ridey_app/features/staff/staff_source_line.dart';
import 'package:ridey_app/widgets/ridey_tab_bar.dart';
import 'package:ridey_app/widgets/ridey_ui.dart';

class StaffListPage extends StatelessWidget {
  const StaffListPage({super.key, required this.session, this.title});

  final StaffSession session;

  /// 구별 현황에서 한 구를 눌러 열었을 때 그 구 이름(뒤로 단추와 함께).
  final String? title;

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
    final byDistance = session.location != null && session.sortByDistance;
    final stations = groups.entries.toList()
      ..sort((a, b) {
        if (byDistance) {
          final da = session.metersTo(a.key) ?? double.infinity;
          final db = session.metersTo(b.key) ?? double.infinity;
          if (da != db) return da.compareTo(db);
        }
        final byExpected = (expectOf(b.value) ?? 0).compareTo(
          expectOf(a.value) ?? 0,
        );
        if (byExpected != 0) return byExpected;
        return b.value.length.compareTo(a.value.length);
      });

    final list = RefreshIndicator.adaptive(
      color: context.ridey.signal,
      onRefresh: session.reload,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.fromLTRB(
          16,
          8,
          16,
          title == null ? rideyTabClearance : 32,
        ),
        children: [
          if (title == null)
            Text('목록', style: theme.textTheme.displayLarge)
          else
            Row(
              children: [
                IconButton(
                  tooltip: '뒤로',
                  onPressed: () => Navigator.of(context).maybePop(),
                  padding: EdgeInsets.zero,
                  visualDensity: VisualDensity.compact,
                  constraints: const BoxConstraints(
                    minWidth: 32,
                    minHeight: 32,
                  ),
                  icon: const Icon(Icons.chevron_left_rounded, size: 30),
                ),
                const SizedBox(width: 2),
                Text(title!, style: theme.textTheme.displayLarge),
              ],
            ),
          const SizedBox(height: 14),
          // 실시간/아침 목록은 구별 현황에서 고른다. 여기서는 지금 무엇을 보는지만.
          StaffSourceLine(session: session),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final filter in AlertLevelFilter.values)
                RideySelectBadge(
                  label: switch (filter) {
                    AlertLevelFilter.all => '전체',
                    AlertLevelFilter.high => '강한 경보',
                    AlertLevelFilter.alert => '경보',
                  },
                  selected: session.levelFilter == filter,
                  onSelected: (_) => session.setLevelFilter(filter),
                ),
            ],
          ),
          // 위치가 있으면 재배치 길 순서(가까운 순)가 기본, 위험한 순으로도 볼 수 있다.
          if (session.location != null) ...[
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                RideySelectBadge(
                  label: '가까운 순',
                  selected: session.sortByDistance,
                  onSelected: (_) => session.setSortByDistance(true),
                ),
                RideySelectBadge(
                  label: '위험한 순',
                  selected: !session.sortByDistance,
                  onSelected: (_) => session.setSortByDistance(false),
                ),
              ],
            ),
          ],
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
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        session.stations[group.key]?.name ??
                            group.value.first.stationName,
                        style: theme.textTheme.titleMedium,
                      ),
                    ),
                    if (session.metersTo(group.key) case final m?)
                      Text(
                        distanceText(m),
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: context.ridey.muted,
                        ),
                      ),
                  ],
                ),
              ),
              RideyListCard(
                children: [
                  for (final bike in group.value)
                    RideyRow(
                      title: bike.bike,
                      // 마지막 헛대여가 최근일수록 아직 그 자리에 있을 가능성이 크다.
                      subtitle: [
                        if (bike.chain == 0)
                          '시민 신고'
                        else
                          bike.isHighAlert ? '강한 경보' : '경보',
                        if (session.reportsFor(bike.bike) > 0)
                          '시민 신고 ${session.reportsFor(bike.bike)}건',
                        if (bike.lastDud.isNotEmpty) '마지막 헛대여 ${bike.lastDud}',
                      ].join(' · '),
                      trailing: Text(
                        bike.chain > 0 ? '연쇄 ${bike.chain}명' : '신고',
                        style: context
                            .rideyNumbers(theme.textTheme.titleMedium)
                            ?.copyWith(
                              color: bike.isHighAlert
                                  ? context.ridey.signalText
                                  : context.ridey.muted,
                            ),
                      ),
                      onTap: () => openStaffBike(context, session, bike),
                    ),
                ],
              ),
            ],
        ],
      ),
    );
    if (title == null) return list;
    return Scaffold(body: SafeArea(bottom: false, child: list));
  }
}
