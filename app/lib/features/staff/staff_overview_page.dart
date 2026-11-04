import 'package:flutter/material.dart';
import 'package:ridey_app/design/ridey_theme.dart';
import 'package:ridey_app/features/rider/nearby_map.dart';
import 'package:ridey_app/features/staff/district_stats.dart';
import 'package:ridey_app/features/staff/staff_clock.dart';
import 'package:ridey_app/features/staff/staff_session.dart';
import 'package:ridey_app/features/staff/staff_source_line.dart';
import 'package:ridey_app/features/ops/ops_list.dart';
import 'package:ridey_app/features/rider/nearby_stations.dart';
import 'package:ridey_app/features/staff/staff_bike.dart';
import 'package:ridey_app/widgets/ridey_map_sheet.dart';
import 'package:ridey_app/widgets/station_card.dart';
import 'package:ridey_app/widgets/ridey_tab_bar.dart';
import 'package:ridey_app/widgets/ridey_ui.dart';

class StaffOverviewPage extends StatelessWidget {
  const StaffOverviewPage({
    super.key,
    required this.session,
    required this.onOpenDistrict,
  });

  final StaffSession session;
  final ValueChanged<String> onOpenDistrict;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (session.loading && session.bikes.isEmpty) {
      return const Center(child: CircularProgressIndicator.adaptive());
    }
    if (session.error != null && session.bikes.isEmpty) {
      return _StaffFailure(onRetry: session.reload);
    }

    final rows = districtRows(session.bikes, session.stations);
    final total = session.bikes.length;
    final high = session.bikes.where((bike) => bike.isHighAlert).length;

    // 시민 홈과 같은 꼴: 지도가 화면을 채우고 요약·전환·구 목록은 아래 시트에.
    return RideyMapSheet(
      onRefresh: session.reload,
      map: NearbyMap(
        fullBleed: true,
        stations: _alertStations(session),
        location: session.location,
        radiusMeters: session.location == null ? null : 2000,
        route: [for (final stop in session.visitOrder()) stop.station.id],
        onStationTap: (id) => _openStation(context, id),
      ),
      children: [
        // 재배치 길에서 바로 쓰는 것: 지금 서 있는 곳 가까이에서 먼저 가져갈 자전거.
        _NearMe(session: session, onOpen: (id) => _openStation(context, id)),
        if (session.scores.isNotEmpty) ...[
          const SizedBox(height: 18),
          _ListScore(scores: session.scores),
        ],
        const SizedBox(height: 22),
        Text('구별 현황', style: theme.textTheme.displayLarge),
        const SizedBox(height: 8),
        Text(
          '지금 고장 의심 $total대 · 그중 강한 경보 $high대',
          style: theme.textTheme.bodyLarge?.copyWith(
            color: context.ridey.muted,
          ),
        ),
        const SizedBox(height: 14),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            RideySelectBadge(
              label: '실시간',
              selected: session.source == ListSource.live,
              onSelected: (_) => session.setSource(ListSource.live),
            ),
            RideySelectBadge(
              label: '아침 목록',
              selected: session.source == ListSource.morning,
              onSelected: (_) => session.setSource(ListSource.morning),
            ),
          ],
        ),
        const SizedBox(height: 10),
        StaffSourceLine(session: session),
        const SizedBox(height: 18),
        if (rows.isEmpty)
          Text(
            '지금 목록에 고장 의심 자전거가 없어요.',
            style: theme.textTheme.bodyLarge?.copyWith(
              color: context.ridey.muted,
            ),
          )
        else
          RideyListCard(
            children: [
              for (final row in rows)
                RideyRow(
                  title: row.district,
                  subtitle: [
                    '강한 경보 ${row.highAlerts}대',
                    if (row.expected != null)
                      '다음에도 헛대여 예상 ${formatExpected(row.expected)}대',
                  ].join(' · '),
                  trailing: Text(
                    '${row.bikes}대',
                    style: context.rideyNumbers(theme.textTheme.titleMedium),
                  ),
                  onTap: () => onOpenDistrict(row.district),
                ),
            ],
          ),
      ],
    );
  }

  Future<void> _openStation(BuildContext context, String id) {
    final station = session.stations[id];
    return showStationCard(
      context,
      name: station?.name ?? '대여소 $id',
      district: station?.district,
      meters: session.metersTo(id),
      latitude: station?.latitude,
      longitude: station?.longitude,
      bikes: [
        for (final bike in session.bikes)
          if (bike.station == id) bike,
      ],
      onBike: (bike) => openStaffBike(context, session, bike),
    );
  }
}

/// '지금 내 주변 2km' — 가까운 고장 의심 대여소 다섯 곳. 위치가 없으면 켜는 단추만.
class _NearMe extends StatelessWidget {
  const _NearMe({required this.session, required this.onOpen});

  final StaffSession session;
  final ValueChanged<String> onOpen;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final c = context.ridey;
    if (session.location == null) {
      return Row(
        children: [
          Expanded(
            child: Text(
              '위치를 켜면 지금 서 있는 곳 가까이의 고장 의심부터 보여 줘요.',
              style: theme.textTheme.bodyMedium?.copyWith(color: c.muted),
            ),
          ),
          TextButton(onPressed: session.locate, child: const Text('내 위치 찾기')),
        ],
      );
    }
    final near = session.nearby();
    final count = near.fold<int>(0, (n, e) => n + e.bikes.length);
    final stops = session.visitOrder();
    final walk = stops.fold<double>(0, (m, e) => m + e.leg);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text.rich(
          TextSpan(
            style: theme.textTheme.headlineLarge?.copyWith(fontSize: 24),
            children: [
              const TextSpan(text: '지금 내 주변 2km에\n고장 의심 '),
              TextSpan(
                text: '$count대',
                style: TextStyle(color: c.signal),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        if (stops.isEmpty)
          Text(
            '가까운 대여소에는 지금 고장 의심 자전거가 없어요.',
            style: theme.textTheme.bodyLarge?.copyWith(color: c.muted),
          )
        else ...[
          // 재배치 차로 한 바퀴 도는 순서: 매번 가장 가까운 다음 곳(강한 경보는 먼저).
          Text(
            '들를 순서 · ${stops.length}곳 · 이어서 ${distanceText(walk)}',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          RideyListCard(
            children: [
              for (var i = 0; i < stops.length; i++)
                RideyRow(
                  leading: _StopNumber(number: i + 1),
                  title: stops[i].station.name.trim(),
                  subtitle: [
                    '고장 의심 ${stops[i].bikes.length}대',
                    if (stops[i].bikes.any((b) => b.isHighAlert)) '강한 경보 있음',
                  ].join(' · '),
                  trailing: Text(
                    i == 0
                        ? distanceText(stops[i].leg)
                        : '+${distanceText(stops[i].leg)}',
                    style: theme.textTheme.bodyMedium?.copyWith(color: c.muted),
                  ),
                  onTap: () => onOpen(stops[i].station.id),
                ),
            ],
          ),
        ],
      ],
    );
  }
}

class _StopNumber extends StatelessWidget {
  const _StopNumber({required this.number});

  final int number;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 26,
      height: 26,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: context.ridey.calm,
        shape: BoxShape.circle,
      ),
      child: Text(
        '$number',
        style: context
            .rideyNumbers(const TextStyle())
            ?.copyWith(fontSize: 13, height: 1, color: Colors.white),
      ),
    );
  }
}

/// 이 목록이 맞았나 — DB 가 매일 06:10 에 어제 아침 목록을 스스로 채점한 결과(ops_scores).
/// 직원이 '왜 이 목록대로 가야 하나' 를 숫자로 본다. 비교 기준: 아무 자전거나 다음 사람이 바로 반납할 확률 약 2.5%.
class _ListScore extends StatelessWidget {
  const _ListScore({required this.scores});

  final List<OpsScore> scores;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final c = context.ridey;
    final last = scores.firstWhere(
      (s) => s.hitRate != null,
      orElse: () => scores.first,
    );
    final rate = last.hitRate;
    final week = pooledHitRate(scores);
    String pct(double v) => '${(v * 100).round()}%';
    return RideyCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${_md(last.day)} 아침 목록 성적',
            style: theme.textTheme.labelLarge?.copyWith(color: c.muted),
          ),
          const SizedBox(height: 6),
          if (rate == null)
            Text('목록 자전거를 아직 아무도 타지 않았어요.', style: theme.textTheme.bodyLarge)
          else
            Text.rich(
              TextSpan(
                style: theme.textTheme.bodyLarge?.copyWith(height: 1.5),
                children: [
                  TextSpan(text: '다음 사람이 탄 ${last.rode}대 중 '),
                  TextSpan(
                    text: '${last.firstDud}대(${pct(rate)})',
                    style: TextStyle(
                      color: c.signalText,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const TextSpan(text: '가 또 바로 반납됐어요.'),
                ],
              ),
            ),
          const SizedBox(height: 4),
          Text(
            [
              '아무 자전거면 약 2.5%',
              if (week != null && scores.length > 1)
                '최근 ${scores.length}일 합치면 ${pct(week)}',
            ].join(' · '),
            style: theme.textTheme.bodyMedium?.copyWith(color: c.muted),
          ),
        ],
      ),
    );
  }
}

String _md(String day) {
  final parts = day.split('-');
  if (parts.length != 3) return day;
  return '${int.tryParse(parts[1]) ?? parts[1]}/${int.tryParse(parts[2]) ?? parts[2]}';
}

List<NearbyMapStation> _alertStations(StaffSession session) {
  final pins = <String, NearbyMapStation>{};
  for (final bike in session.bikes) {
    final catalog = session.stations[bike.station];
    if (catalog == null) continue;
    final current = pins[catalog.id];
    pins[catalog.id] = NearbyMapStation(
      id: catalog.id,
      latitude: catalog.latitude,
      longitude: catalog.longitude,
      isHighAlert: bike.isHighAlert || (current?.isHighAlert ?? false),
      alertCount: (current?.alertCount ?? 0) + 1,
    );
  }
  return pins.values.toList(growable: false);
}

class _StaffFailure extends StatelessWidget {
  const _StaffFailure({required this.onRetry});

  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, rideyTabClearance),
      children: [
        RideyCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '목록을 불러오지 못했어요.',
                style: Theme.of(context).textTheme.headlineLarge,
              ),
              const SizedBox(height: 18),
              RideyButton.secondary(label: '다시 시도', onPressed: () => onRetry()),
            ],
          ),
        ),
      ],
    );
  }
}
