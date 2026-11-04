import 'package:flutter/material.dart';
import 'package:ridey_app/design/ridey_theme.dart';
import 'package:ridey_app/features/rider/nearby_map.dart';
import 'package:ridey_app/features/staff/district_stats.dart';
import 'package:ridey_app/features/staff/staff_clock.dart';
import 'package:ridey_app/features/staff/staff_session.dart';
import 'package:ridey_app/features/staff/staff_source_line.dart';
import 'package:ridey_app/features/rider/bike_detail_page.dart';
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
        onStationTap: (id) => _openStation(context, id),
      ),
      children: [
        // 재배치 길에서 바로 쓰는 것: 지금 서 있는 곳 가까이에서 먼저 가져갈 자전거.
        _NearMe(session: session, onOpen: (id) => _openStation(context, id)),
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

  void _openStation(BuildContext context, String id) {
    final station = session.stations[id];
    showStationCard(
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
      onBike: (bike) => Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => BikeDetailPage(
            bike: bike,
            updatedAt: session.updatedAt ?? DateTime.now(),
            feed: session.feed,
          ),
        ),
      ),
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
        if (near.isEmpty)
          Text(
            '가까운 대여소에는 지금 고장 의심 자전거가 없어요.',
            style: theme.textTheme.bodyLarge?.copyWith(color: c.muted),
          )
        else
          RideyListCard(
            children: [
              for (final item in near.take(5))
                RideyRow(
                  title: item.station.name.trim(),
                  subtitle: [
                    '고장 의심 ${item.bikes.length}대',
                    if (item.bikes.any((b) => b.isHighAlert)) '강한 경보 있음',
                  ].join(' · '),
                  trailing: Text(
                    item.meters < 1000
                        ? '${item.meters.round()}m'
                        : '${(item.meters / 1000).toStringAsFixed(1)}km',
                    style: theme.textTheme.bodyMedium?.copyWith(color: c.muted),
                  ),
                  onTap: () => onOpen(item.station.id),
                ),
            ],
          ),
      ],
    );
  }
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
