import 'package:flutter/material.dart';
import 'package:ridey_app/design/ridey_theme.dart';
import 'package:ridey_app/features/live/live_snapshot.dart';
import 'package:ridey_app/features/rider/bike_detail_page.dart';
import 'package:ridey_app/features/staff/staff_checks.dart';
import 'package:ridey_app/features/staff/staff_session.dart';
import 'package:ridey_app/widgets/ridey_ui.dart';

/// 직원 상세 화면 아래: 현장에서 본 결과를 한 번에 남긴다. 남기면 들를 순서·내 주변 수에서 빠진다.
class StaffCheckPanel extends StatelessWidget {
  const StaffCheckPanel({super.key, required this.session, required this.bike});

  final StaffSession session;
  final String bike;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: session,
      builder: (context, _) {
        final theme = Theme.of(context);
        final c = context.ridey;
        final done = session.checkOf(bike);
        if (done != null) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                staffCheckText(done),
                textAlign: TextAlign.center,
                style: theme.textTheme.titleMedium?.copyWith(
                  color: done == StaffCheck.pickedUp ? c.signalText : c.muted,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '오늘 들를 순서와 내 주변 수에서 뺐어요.',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(color: c.muted),
              ),
              const SizedBox(height: 12),
              RideyButton.secondary(
                label: '되돌리기',
                onPressed: () => session.setCheck(bike, null),
              ),
            ],
          );
        }
        return Row(
          children: [
            Expanded(
              child: RideyButton.signal(
                label: '고장 — 가져감',
                onPressed: () => session.setCheck(bike, StaffCheck.pickedUp),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: RideyButton.secondary(
                label: '멀쩡함',
                onPressed: () => session.setCheck(bike, StaffCheck.fine),
              ),
            ),
          ],
        );
      },
    );
  }
}

String staffCheckText(StaffCheck check) => switch (check) {
  StaffCheck.pickedUp => '가져감',
  StaffCheck.fine => '멀쩡함',
};

/// 직원 모드에서 자전거 상세를 연다(현장 확인 단추 포함).
Future<void> openStaffBike(
  BuildContext context,
  StaffSession session,
  LiveBike bike,
) => Navigator.of(context).push(
  MaterialPageRoute<void>(
    builder: (_) => BikeDetailPage(
      bike: bike,
      updatedAt: session.updatedAt ?? DateTime.now(),
      feed: session.feed,
      staffPanel: StaffCheckPanel(session: session, bike: bike.bike),
    ),
  ),
);
