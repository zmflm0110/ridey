import 'package:flutter/material.dart';
import 'package:ridey_app/app/mode_switch.dart';
import 'package:ridey_app/app/user_mode.dart';
import 'package:ridey_app/design/ridey_theme.dart';
import 'package:ridey_app/features/staff/staff_district_picker.dart';
import 'package:ridey_app/features/staff/staff_session.dart';
import 'package:ridey_app/widgets/ridey_tab_bar.dart';
import 'package:ridey_app/widgets/ridey_ui.dart';

class StaffMorePage extends StatelessWidget {
  const StaffMorePage({
    super.key,
    required this.session,
    required this.themeMode,
    required this.onThemeModeChanged,
    required this.onSwitchToRider,
  });

  final StaffSession session;
  final ThemeMode themeMode;
  final ValueChanged<ThemeMode> onThemeModeChanged;
  final VoidCallback onSwitchToRider;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = switch (themeMode) {
      ThemeMode.dark => true,
      ThemeMode.light => false,
      ThemeMode.system => theme.brightness == Brightness.dark,
    };
    final assigned = session.assigned ?? const <String>[];

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, rideyTabClearance),
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Text('더보기', style: theme.textTheme.displayLarge),
        ),
        const SizedBox(height: 18),
        Padding(
          padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
          child: Text(
            '설정',
            style: theme.textTheme.labelLarge?.copyWith(
              color: context.ridey.muted,
              fontSize: 13,
            ),
          ),
        ),
        RideyListCard(
          children: [
            RideyRow(
              leading: const RideyIco(icon: Icons.swap_horiz_rounded),
              title: '이용 목적 바꾸기',
              subtitle: '시민 모드로 전환해요',
              trailing: Icon(
                Icons.chevron_right_rounded,
                color: context.ridey.muted,
              ),
              onTap: () async {
                final confirmed = await confirmModeSwitch(
                  context,
                  next: UserMode.rider,
                );
                if (confirmed) onSwitchToRider();
              },
            ),
            RideyRow(
              leading: const RideyIco(icon: Icons.map_outlined),
              title: '담당 구',
              subtitle: assigned.isEmpty ? '서울 전체' : assigned.join(', '),
              trailing: Icon(
                Icons.chevron_right_rounded,
                color: context.ridey.muted,
              ),
              onTap: () async {
                final next = await Navigator.of(context).push<List<String>>(
                  MaterialPageRoute(
                    builder: (_) => StaffDistrictPickerPage(
                      districts: session.catalogDistricts,
                      selected: assigned,
                      allowSkip: true,
                    ),
                  ),
                );
                if (next == null) return;
                await session.saveDistricts(next);
              },
            ),
            RideyRow(
              leading: RideyIco(
                icon: isDark
                    ? Icons.dark_mode_outlined
                    : Icons.light_mode_outlined,
              ),
              title: '화면 모드',
              subtitle: isDark ? '어두운 화면 사용 중' : '밝은 화면 사용 중',
              trailing: Switch(
                value: isDark,
                onChanged: (value) {
                  onThemeModeChanged(value ? ThemeMode.dark : ThemeMode.light);
                },
              ),
            ),
          ],
        ),
        const SizedBox(height: 28),
        Text(
          '자료: 서울 열린데이터광장 따릉이 대여이력·대여소 정보. '
          '경보 규칙: 서로 다른 사람이 3분·300m 안 반납을 2번 이상 이어서 함. '
          '직원 모드는 구별 고장 의심 목록만 읽습니다.',
          textAlign: TextAlign.center,
          style: theme.textTheme.bodyMedium?.copyWith(
            fontSize: 12,
            color: context.ridey.muted,
          ),
        ),
      ],
    );
  }
}
