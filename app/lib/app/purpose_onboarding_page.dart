import 'package:flutter/material.dart';
import 'package:ridey_app/app/app_purpose.dart';
import 'package:ridey_app/design/ridey_theme.dart';

class PurposeOnboardingPage extends StatefulWidget {
  const PurposeOnboardingPage({super.key, required this.onSelected});

  final ValueChanged<AppPurpose> onSelected;

  @override
  State<PurposeOnboardingPage> createState() => _PurposeOnboardingPageState();
}

class _PurposeOnboardingPageState extends State<PurposeOnboardingPage> {
  final _controller = PageController();
  var _page = 0;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isRider = _page == 0;

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const _OnboardingWordmark(),
              const SizedBox(height: 42),
              Expanded(
                flex: 5,
                child: PageView(
                  controller: _controller,
                  onPageChanged: (page) => setState(() => _page = page),
                  children: const [
                    _PurposeIntroduction(
                      eyebrow: '이용하기',
                      title: '타기 전,\n한 번 확인하세요.',
                      description: '바로 반납된 기록이 이어지면, 타기 전에 먼저 알려 드려요.',
                      icon: Icons.directions_bike_outlined,
                      detail: '자전거 번호·QR·번호판으로 빠르게 확인할 수 있어요.',
                    ),
                    _PurposeIntroduction(
                      eyebrow: '업무',
                      title: '현장에서 발견하면,\n3초 만에 남기세요.',
                      description: '확인 결과가 다음 정비 우선순위에 바로 반영돼요.',
                      icon: Icons.assignment_turned_in_outlined,
                      detail: '확인할 곳과 조사할 곳을 한 흐름에서 처리할 수 있어요.',
                    ),
                  ],
                ),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(
                  2,
                  (index) => AnimatedContainer(
                    duration: MediaQuery.disableAnimationsOf(context)
                        ? Duration.zero
                        : const Duration(milliseconds: 180),
                    width: index == _page ? 20 : 6,
                    height: 6,
                    margin: const EdgeInsets.symmetric(horizontal: 3),
                    decoration: BoxDecoration(
                      color: index == _page
                          ? theme.colorScheme.onSurface
                          : context.ridey.line,
                      borderRadius: BorderRadius.circular(99),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 28),
              FilledButton(
                onPressed: () {
                  widget.onSelected(
                    isRider ? AppPurpose.rider : AppPurpose.worker,
                  );
                },
                child: Text(isRider ? '자전거 확인하기' : '업무 화면 보기'),
              ),
              const SizedBox(height: 10),
              OutlinedButton(
                onPressed: () {
                  widget.onSelected(
                    isRider ? AppPurpose.worker : AppPurpose.rider,
                  );
                },
                child: Text(isRider ? '업무 화면 보기' : '이용자 화면 보기'),
              ),
              const SizedBox(height: 12),
              Text(
                '언제든 상단의 목적 전환에서 바꿀 수 있어요.',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: context.ridey.muted,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PurposeIntroduction extends StatelessWidget {
  const _PurposeIntroduction({
    required this.eyebrow,
    required this.title,
    required this.description,
    required this.icon,
    required this.detail,
  });

  final String eyebrow;
  final String title;
  final String description;
  final IconData icon;
  final String detail;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Semantics(
      container: true,
      label: '$eyebrow 안내',
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 68,
              height: 68,
              decoration: BoxDecoration(
                color: context.ridey.calmSoft,
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: context.ridey.calm, size: 32),
            ),
            const SizedBox(height: 34),
            Text(
              eyebrow,
              style: theme.textTheme.labelLarge?.copyWith(
                color: context.ridey.calm,
              ),
            ),
            const SizedBox(height: 10),
            Text(title, style: theme.textTheme.displayLarge),
            const SizedBox(height: 18),
            Text(
              description,
              style: theme.textTheme.bodyLarge?.copyWith(
                color: context.ridey.muted,
              ),
            ),
            const SizedBox(height: 28),
            Text(detail, style: theme.textTheme.bodyMedium),
          ],
        ),
      ),
    );
  }
}

class _OnboardingWordmark extends StatelessWidget {
  const _OnboardingWordmark();

  @override
  Widget build(BuildContext context) {
    return Text(
      'RIDEY.',
      style: Theme.of(context).textTheme.titleLarge?.copyWith(
        fontWeight: FontWeight.w900,
        letterSpacing: -1.1,
      ),
    );
  }
}
