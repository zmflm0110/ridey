import 'package:flutter/material.dart';
import 'package:ridey_app/design/ridey_theme.dart';
import 'package:ridey_app/features/staff/staff_clock.dart';
import 'package:ridey_app/features/staff/staff_session.dart';
import 'package:ridey_app/widgets/ridey_status.dart';

/// 지금 보는 목록이 무엇이고 언제 것인지 한 줄로. 받기에 실패했거나 자료가 늦으면
/// 신호 글자로 알린다(직원이 이미 고쳐졌을 자전거로 가지 않게).
class StaffSourceLine extends StatelessWidget {
  const StaffSourceLine({super.key, required this.session});

  final StaffSession session;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final c = context.ridey;
    final updatedAt = session.updatedAt;
    final source = session.source == ListSource.morning
        ? '아침 목록 ${session.morningDay ?? ''} 07:00'.trim()
        : '실시간';
    final focus = session.focusedDistrict;

    String? warning;
    if (session.error != null) {
      warning = '새 목록을 받지 못했어요. 아래로 당겨 다시 받아 주세요.';
    } else if (session.source == ListSource.live && updatedAt != null) {
      final late =
          session.feed?.isHealthy == false ||
          DateTime.now().difference(updatedAt) > const Duration(minutes: 15);
      if (late) warning = '자료가 늦어요 · ${rideyAgo(updatedAt)} 갱신';
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          [
            '$source 기준',
            if (session.source == ListSource.live && updatedAt != null)
              '${rideyAgo(updatedAt)} 갱신',
            if (focus != null) '$focus만',
          ].join(' · '),
          style: theme.textTheme.bodyMedium?.copyWith(color: c.muted),
        ),
        if (warning != null) ...[
          const SizedBox(height: 4),
          Text(
            warning,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: c.signalText,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ],
    );
  }
}
