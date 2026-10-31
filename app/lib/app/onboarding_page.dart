import 'package:flutter/material.dart';
import 'package:ridey_app/app/user_mode.dart';
import 'package:ridey_app/widgets/ridey_tab_bar.dart';
import 'package:ridey_app/widgets/ridey_ui.dart';

class OnboardingPage extends StatelessWidget {
  const OnboardingPage({super.key, required this.onChosen});

  final ValueChanged<UserMode> onChosen;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 24, 20, rideyTabClearance),
          children: [
            const RideyWordmark(size: 28),
            const SizedBox(height: 36),
            Text(
              'RIDEY 앱을 어떤 목적으로 이용하실 건가요?',
              style: theme.textTheme.displayLarge,
            ),
            const SizedBox(height: 28),
            RideyButton(
              label: '따릉이를 이용하는 일반 시민이에요',
              onPressed: () => onChosen(UserMode.rider),
            ),
            const SizedBox(height: 10),
            RideyButton.secondary(
              label: '따릉이를 수거하고 점검하는 관리 직원이에요',
              onPressed: () => onChosen(UserMode.staff),
            ),
            const SizedBox(height: 16),
            Center(
              child: TextButton(
                onPressed: () => onChosen(UserMode.rider),
                child: const Text('나중에 할게요'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
