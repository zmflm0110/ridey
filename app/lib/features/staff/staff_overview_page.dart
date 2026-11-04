import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'package:ridey_app/design/ridey_theme.dart';
import 'package:ridey_app/features/ops/ops_list.dart';
import 'package:ridey_app/features/rider/nearby_map.dart';
import 'package:ridey_app/features/rider/nearby_stations.dart';
import 'package:ridey_app/features/staff/district_stats.dart';
import 'package:ridey_app/features/staff/pickup_plan.dart';
import 'package:ridey_app/features/staff/road_route.dart';
import 'package:ridey_app/features/staff/staff_bike.dart';
import 'package:ridey_app/features/staff/staff_clock.dart';
import 'package:ridey_app/features/staff/staff_navigation_page.dart';
import 'package:ridey_app/features/staff/staff_session.dart';
import 'package:ridey_app/features/staff/staff_source_line.dart';
import 'package:ridey_app/widgets/ridey_map_sheet.dart';
import 'package:ridey_app/widgets/ridey_tab_bar.dart';
import 'package:ridey_app/widgets/ridey_ui.dart';
import 'package:ridey_app/widgets/station_card.dart';

/// 직원 첫 화면: 지도(서울 전체 고장 의심 + 추천 경로) 위에 시트.
/// 시트: 오늘 추천 경로(재배치 + 고장 의심 수거를 한 번에, 또는 고장 의심만) → 길안내 시작,
/// 어제 아침 목록 성적, 구별 현황(누르면 그 구의 대여소별 목록).
class StaffOverviewPage extends StatefulWidget {
  const StaffOverviewPage({
    super.key,
    required this.session,
    required this.onOpenDistrict,
  });

  final StaffSession session;
  final ValueChanged<String> onOpenDistrict;

  @override
  State<StaffOverviewPage> createState() => _StaffOverviewPageState();
}

class _StaffOverviewPageState extends State<StaffOverviewPage> {
  StaffSession get session => widget.session;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (session.loading && session.bikes.isEmpty) {
      return const Center(child: CircularProgressIndicator.adaptive());
    }
    if (session.error != null && session.bikes.isEmpty) {
      return _StaffFailure(onRetry: session.reload);
    }

    final rows = districtRows(session.bikesWithReports, session.stations);
    final total = session.bikes.length;
    final high = session.bikes.where((bike) => bike.isHighAlert).length;
    final plan = session.plan;
    final road = session.roadForPlan;
    final here = session.location;
    // 경로가 생기면 도로 길을 한 번 받아 둔다(지도에 실제 길로 그리고 길안내에 씀).
    if (here != null && !plan.isEmpty && road == null && !session.routing) {
      WidgetsBinding.instance.addPostFrameCallback((_) => session.loadRoad());
    }
    final stopNumbers = {
      for (var i = 0; i < plan.stops.length; i++)
        plan.stops[i].station.id: i + 1,
    };
    final fit = here != null && !plan.isEmpty
        ? [
            LatLng(here.latitude, here.longitude),
            for (final s in plan.stops)
              LatLng(s.station.latitude, s.station.longitude),
          ]
        : _districtPoints();

    return RideyMapSheet(
      onRefresh: session.reload,
      map: NearbyMap(
        fullBleed: true,
        stations: _mapStations(plan),
        location: here,
        stopNumbers: stopNumbers,
        routePoints:
            road?.points ??
            (fit.length >= 2 && here != null && !plan.isEmpty ? fit : const []),
        fitPoints: fit.isEmpty ? null : fit,
        // 담당 구·경로 방식·출처를 바꾸면 지도를 다시 맞춘다(구를 바꿔도 지도가 그대로이던 문제).
        viewKey: [
          (session.assigned ?? const []).join(','),
          session.suspectsOnly,
          session.source,
          plan.stops.map((s) => s.station.id).join(','),
        ].join('|'),
        onStationTap: (id) => _openStation(context, id),
      ),
      children: [
        _RouteCard(
          session: session,
          plan: plan,
          road: road,
          onStart: () => _startNavigation(context),
          onOpen: (id) => _openStation(context, id),
        ),
        if (session.scores.isNotEmpty) ...[
          const SizedBox(height: 18),
          _ListScore(scores: session.scores),
        ],
        const SizedBox(height: 22),
        Text('구별 현황', style: theme.textTheme.displayLarge),
        const SizedBox(height: 8),
        Text(
          '지금 고장 의심 $total대 · 그중 강한 경보 $high대'
          '${session.reports.isEmpty ? '' : ' · 시민 신고 ${session.reports.length}대'}',
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
                  onTap: () => widget.onOpenDistrict(row.district),
                ),
            ],
          ),
      ],
    );
  }

  /// 담당 구가 있으면 그 구의 고장 의심 대여소가 다 보이게.
  List<LatLng> _districtPoints() {
    final chosen = session.assigned ?? const <String>[];
    if (chosen.isEmpty) return const [];
    return [
      for (final bike in session.bikesWithReports)
        if (session.stations[bike.station] case final s?
            when chosen.contains(s.district))
          LatLng(s.latitude, s.longitude),
    ];
  }

  /// 지도: 서울 전체 고장 의심 대여소 + 경로에 든 재배치 대여소.
  List<NearbyMapStation> _mapStations(PickupPlan plan) {
    final pins = <String, NearbyMapStation>{};
    for (final bike in session.bikesWithReports) {
      final s = session.stations[bike.station];
      if (s == null) continue;
      final current = pins[s.id];
      pins[s.id] = NearbyMapStation(
        id: s.id,
        latitude: s.latitude,
        longitude: s.longitude,
        isHighAlert: bike.isHighAlert || (current?.isHighAlert ?? false),
        alertCount: (current?.alertCount ?? 0) + 1,
        parkedBikes: session.occupancy[s.id]?.bikes,
      );
    }
    for (final stop in plan.stops) {
      pins.putIfAbsent(
        stop.station.id,
        () => NearbyMapStation(
          id: stop.station.id,
          latitude: stop.station.latitude,
          longitude: stop.station.longitude,
          parkedBikes: stop.station.bikes,
        ),
      );
    }
    return pins.values.toList(growable: false);
  }

  Future<void> _startNavigation(BuildContext context) async {
    final here = session.location;
    if (here == null || session.plan.isEmpty) return;
    await session.loadRoad();
    if (!context.mounted) return;
    await Navigator.of(context, rootNavigator: true).push(
      MaterialPageRoute<void>(
        builder: (_) => StaffNavigationPage(
          plan: session.plan,
          road: session.roadForPlan,
          start: here,
          positions: session.positions?.call(),
        ),
      ),
    );
  }

  Future<void> _openStation(BuildContext context, String id) {
    final station = session.stations[id];
    final occ = session.occupancy[id];
    return showStationCard(
      context,
      name: station?.name ?? '대여소 $id',
      district: [
        ?station?.district,
        if (occ != null) '거치 ${occ.bikes}대 / 거치대 ${occ.racks}',
      ].join(' · '),
      meters: session.metersTo(id),
      latitude: station?.latitude,
      longitude: station?.longitude,
      bikes: [
        for (final bike in session.bikesWithReports)
          if (bike.station == id) bike,
      ],
      note: (bike) {
        final n = session.reportsFor(bike.bike);
        return n > 0 ? '시민 신고 $n건' : null;
      },
      onBike: (bike) => openStaffBike(context, session, bike),
    );
  }
}

/// 오늘 추천 경로: 재배치(넘친 곳에서 싣고 빈 곳에 내려놓기)와 고장 의심 수거를 한 번에 도는 순서.
class _RouteCard extends StatelessWidget {
  const _RouteCard({
    required this.session,
    required this.plan,
    required this.road,
    required this.onStart,
    required this.onOpen,
  });

  final StaffSession session;
  final PickupPlan plan;
  final RoadRoute? road;
  final VoidCallback onStart;
  final ValueChanged<String> onOpen;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final c = context.ridey;
    final modes = Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        RideySelectBadge(
          label: '재배치 + 고장 의심',
          selected: !session.suspectsOnly,
          onSelected: (_) => session.setSuspectsOnly(false),
        ),
        RideySelectBadge(
          label: '고장 의심만',
          selected: session.suspectsOnly,
          onSelected: (_) => session.setSuspectsOnly(true),
        ),
      ],
    );
    if (session.location == null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('오늘 추천 경로', style: theme.textTheme.displayLarge),
          const SizedBox(height: 8),
          Text(
            '위치를 켜면 지금 있는 곳에서 출발해, 넘친 대여소에서 싣고 빈 대여소에 내려놓으면서 '
            '고장 의심 자전거도 함께 거두는 순서를 짜 드려요.',
            style: theme.textTheme.bodyLarge?.copyWith(color: c.muted),
          ),
          const SizedBox(height: 12),
          RideyButton.secondary(
            label: '내 위치 찾기',
            icon: Icons.my_location_rounded,
            onPressed: session.locate,
          ),
        ],
      );
    }
    final summary = [
      '${plan.stops.length}곳',
      if (road != null)
        '도로 ${navDistance(road!.distance)} · 차로 약 ${(road!.duration / 60).ceil()}분'
      else
        '직선 ${distanceText(plan.totalMeters)}',
    ].join(' · ');
    final work = [
      if (plan.suspects > 0) '고장 의심 ${plan.suspects}대 수거',
      if (plan.pickedUp > 0) '넘친 자전거 ${plan.pickedUp}대 싣기',
      if (plan.droppedOff > 0) '빈 곳에 ${plan.droppedOff}대 내려놓기',
    ].join(' · ');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('오늘 추천 경로', style: theme.textTheme.displayLarge),
        const SizedBox(height: 10),
        modes,
        const SizedBox(height: 12),
        if (plan.isEmpty)
          Text(
            session.suspectsOnly
                ? '담당 구역에 지금 고장 의심 자전거가 없어요.'
                : '담당 구역에 지금 거둘 고장 의심도, 넘치거나 빈 대여소도 없어요.',
            style: theme.textTheme.bodyLarge?.copyWith(color: c.muted),
          )
        else ...[
          Text(
            summary,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          if (work.isNotEmpty) ...[
            const SizedBox(height: 2),
            Text(
              work,
              style: theme.textTheme.bodyMedium?.copyWith(color: c.muted),
            ),
          ],
          const SizedBox(height: 10),
          RideyListCard(
            children: [
              for (var i = 0; i < plan.stops.length; i++)
                RideyRow(
                  leading: _StopNumber(
                    number: i + 1,
                    suspects: plan.stops[i].suspects.isNotEmpty,
                  ),
                  title: plan.stops[i].station.name,
                  subtitle: plan.stops[i].task,
                  trailing: Text(
                    i == 0
                        ? distanceText(plan.stops[i].leg)
                        : '+${distanceText(plan.stops[i].leg)}',
                    style: theme.textTheme.bodyMedium?.copyWith(color: c.muted),
                  ),
                  onTap: () => onOpen(plan.stops[i].station.id),
                ),
            ],
          ),
          const SizedBox(height: 12),
          RideyButton(
            label: '길안내 시작',
            icon: Icons.navigation_rounded,
            busy: session.routing,
            onPressed: onStart,
          ),
          const SizedBox(height: 6),
          Text(
            session.suspectsOnly
                ? '고장 의심 대여소만, 가장 짧게 도는 순서예요(가까운 순서를 잡고 구간을 바꿔 보며 줄임).'
                : '차 한 대(${plan.capacity}대 실음) 기준. 넘친 곳(거치대의 1.2배 넘음)에서 싣고 빈 곳(25% 아래)에 내려놓으면서, '
                      '고장 의심은 정비센터로 가져가도록 거둬요.',
            style: theme.textTheme.bodySmall?.copyWith(color: c.muted),
          ),
        ],
      ],
    );
  }
}

class _StopNumber extends StatelessWidget {
  const _StopNumber({required this.number, required this.suspects});

  final int number;
  final bool suspects;

  @override
  Widget build(BuildContext context) {
    final c = context.ridey;
    return Container(
      width: 26,
      height: 26,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: suspects ? c.signal : c.calm,
        shape: BoxShape.circle,
      ),
      child: Text(
        '$number',
        style: context
            .rideyNumbers(const TextStyle())
            ?.copyWith(
              fontSize: 13,
              height: 1,
              color: suspects ? RideyColors.ink : Colors.white,
            ),
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
