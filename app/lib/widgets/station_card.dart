import 'package:flutter/material.dart';
import 'package:ridey_app/design/ridey_theme.dart';
import 'package:ridey_app/features/live/live_snapshot.dart';
import 'package:ridey_app/features/rider/directions.dart';
import 'package:ridey_app/features/rider/nearby_stations.dart';
import 'package:ridey_app/widgets/ridey_ui.dart';

/// 지도에서 대여소를 누르면 아래에서 올라오는 카드(지도 앱의 '핀 정보' 꼴):
/// 대여소 이름 · 구 · 거리 · 탈 만한 자전거 수, 그리고 그곳의 고장 의심 자전거 목록.
/// 자전거를 누르면 [onBike] (보통 상세 화면), [onRent] 가 있으면 공식 앱 대여 단추.
/// 시민 홈과 직원 구별 현황이 같은 카드를 쓴다.
Future<void> showStationCard(
  BuildContext context, {
  required String name,
  String? district,
  double? meters,
  int? choosable,
  required List<LiveBike> bikes,
  required void Function(LiveBike bike) onBike,
  Future<void> Function()? onRent,
  double? latitude,
  double? longitude,
}) {
  final sorted = [...bikes]
    ..sort((a, b) {
      if (a.isHighAlert != b.isHighAlert) return a.isHighAlert ? -1 : 1;
      return b.chain.compareTo(a.chain);
    });
  return showModalBottomSheet<void>(
    context: context,
    useRootNavigator: true,
    isScrollControlled: true,
    backgroundColor: Theme.of(context).scaffoldBackgroundColor,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (sheet) {
      final theme = Theme.of(sheet);
      final c = sheet.ridey;
      final facts = [
        if (district != null && district.trim().isNotEmpty) district.trim(),
        if (meters != null)
          '${distanceText(meters)} · 걸어서 약 ${walkMinutes(meters)}분',
        if (choosable != null) '탈 만한 자전거 약 $choosable대',
      ].join(' · ');
      return SafeArea(
        top: false,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(sheet).height * .7,
          ),
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 10, 20, 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 5,
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: c.line,
                      borderRadius: BorderRadius.circular(99),
                    ),
                  ),
                ),
                Text(
                  name.trim(),
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                if (facts.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    facts,
                    style: theme.textTheme.bodyMedium?.copyWith(color: c.muted),
                  ),
                ],
                const SizedBox(height: 16),
                if (sorted.isEmpty)
                  Text(
                    '지금 이 대여소에는 고장 의심 자전거가 없어요.',
                    style: theme.textTheme.bodyLarge?.copyWith(color: c.muted),
                  )
                else ...[
                  Text(
                    '고장 의심 ${sorted.length}대',
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: c.signalText,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 8),
                  RideyListCard(
                    children: [
                      for (final bike in sorted)
                        RideyRow(
                          leading: Container(
                            width: 14,
                            height: 14,
                            decoration: BoxDecoration(
                              color: bike.isHighAlert ? c.signal : c.signalSoft,
                              shape: BoxShape.circle,
                              border: bike.isHighAlert
                                  ? null
                                  : Border.all(color: c.signal, width: 2),
                            ),
                          ),
                          title: bike.bike,
                          subtitle: bike.isHighAlert ? '강한 경보' : '경보',
                          trailing: Text(
                            '연쇄 ${bike.chain}명',
                            style: sheet
                                .rideyNumbers(theme.textTheme.titleMedium)
                                ?.copyWith(
                                  fontSize: 14,
                                  color: bike.isHighAlert
                                      ? c.signalText
                                      : c.muted,
                                ),
                          ),
                          onTap: () {
                            Navigator.of(sheet).pop();
                            onBike(bike);
                          },
                        ),
                    ],
                  ),
                ],
                const SizedBox(height: 16),
                // 길찾기(지도 앱의 도보 길안내)와 대여하기를 나란히 — 둘 다 이 대여소로 가는 다음 행동.
                Row(
                  children: [
                    if (latitude != null && longitude != null)
                      Expanded(
                        child: RideyButton(
                          label: '길 찾기',
                          icon: Icons.directions_walk_rounded,
                          onPressed: () {
                            Navigator.of(sheet).pop();
                            openWalkingDirections(
                              latitude: latitude,
                              longitude: longitude,
                              name: name,
                            );
                          },
                        ),
                      ),
                    if (latitude != null && longitude != null && onRent != null)
                      const SizedBox(width: 8),
                    if (onRent != null)
                      Expanded(
                        child: RideyButton.secondary(
                          label: '대여하기',
                          onPressed: () {
                            Navigator.of(sheet).pop();
                            onRent();
                          },
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
      );
    },
  );
}
