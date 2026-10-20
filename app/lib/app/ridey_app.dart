import 'package:flutter/material.dart';
import 'package:ridey_app/design/ridey_theme.dart';
import 'package:ridey_app/features/rider/rider_home_page.dart';
import 'package:ridey_app/features/live/live_snapshot_repository.dart';
import 'package:ridey_app/widgets/liquid_navigation.dart';

class RideyApp extends StatefulWidget {
  const RideyApp({super.key, this.liveRepository});

  final LiveSnapshotRepository? liveRepository;

  @override
  State<RideyApp> createState() => _RideyAppState();
}

class _RideyAppState extends State<RideyApp> {
  ThemeMode _themeMode = ThemeMode.system;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'RIDEY',
      debugShowCheckedModeBanner: false,
      theme: RideyTheme.light(),
      darkTheme: RideyTheme.dark(),
      themeMode: _themeMode,
      home: RideyShell(
        liveRepository: widget.liveRepository,
        themeMode: _themeMode,
        onThemeModeChanged: (mode) => setState(() => _themeMode = mode),
      ),
    );
  }
}

class RideyShell extends StatefulWidget {
  const RideyShell({
    super.key,
    required this.liveRepository,
    required this.themeMode,
    required this.onThemeModeChanged,
  });

  final LiveSnapshotRepository? liveRepository;
  final ThemeMode themeMode;
  final ValueChanged<ThemeMode> onThemeModeChanged;

  @override
  State<RideyShell> createState() => _RideyShellState();
}

class _RideyShellState extends State<RideyShell> {
  var _index = 0;

  @override
  Widget build(BuildContext context) {
    final reducedMotion = MediaQuery.disableAnimationsOf(context);
    final pages = <Widget>[
      RiderHomePage(key: ValueKey('ride'), repository: widget.liveRepository),
      const _FoundationPage(
        key: ValueKey('work'),
        eyebrow: '업무',
        title: '오늘 먼저\n볼 곳.',
        description: '현장 확인·정비 우선순위·조사 흐름을 같은 작업 공간으로 묶어요.',
        icon: Icons.assignment_outlined,
      ),
      _MorePage(
        key: const ValueKey('more'),
        themeMode: widget.themeMode,
        onThemeModeChanged: widget.onThemeModeChanged,
      ),
    ];

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            const _AppHeader(),
            Expanded(
              child: AnimatedSwitcher(
                duration: reducedMotion
                    ? Duration.zero
                    : const Duration(milliseconds: 260),
                switchInCurve: Curves.easeOutCubic,
                switchOutCurve: Curves.easeInCubic,
                child: pages[_index],
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: LiquidNavigation(
        index: _index,
        onChanged: (index) => setState(() => _index = index),
      ),
    );
  }
}

class _AppHeader extends StatelessWidget {
  const _AppHeader();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 14, 24, 10),
      child: Row(
        children: [
          const _Wordmark(),
          const Spacer(),
          Text(
            '타기 전 확인',
            style: theme.textTheme.labelMedium?.copyWith(
              color: context.ridey.muted,
            ),
          ),
        ],
      ),
    );
  }
}

class _FoundationPage extends StatelessWidget {
  const _FoundationPage({
    super.key,
    required this.eyebrow,
    required this.title,
    required this.description,
    required this.icon,
  });

  final String eyebrow;
  final String title;
  final String description;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 34, 24, 130),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            eyebrow,
            style: theme.textTheme.labelLarge?.copyWith(
              color: context.ridey.signalText,
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
          const SizedBox(height: 44),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: theme.colorScheme.surface,
              border: Border.all(color: context.ridey.line),
              borderRadius: BorderRadius.circular(28),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: context.ridey.signalSoft,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, color: context.ridey.signalText),
                ),
                const SizedBox(height: 22),
                Text('공통 화면 기반을 만들고 있어요.', style: theme.textTheme.titleLarge),
                const SizedBox(height: 8),
                Text(
                  '이 단계에서는 iOS와 Android가 같은 디자인 규칙과 내비게이션을 사용하도록 먼저 정리합니다.',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: context.ridey.muted,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MorePage extends StatelessWidget {
  const _MorePage({
    super.key,
    required this.themeMode,
    required this.onThemeModeChanged,
  });

  final ThemeMode themeMode;
  final ValueChanged<ThemeMode> onThemeModeChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 34, 24, 130),
      children: [
        Text('더보기', style: theme.textTheme.displayLarge),
        const SizedBox(height: 12),
        Text(
          '시연, 내 기록, 설정은 실제 기능이 연결되는 순서에 맞춰 추가해요.',
          style: theme.textTheme.bodyLarge?.copyWith(
            color: context.ridey.muted,
          ),
        ),
        const SizedBox(height: 36),
        Card(
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 20,
              vertical: 8,
            ),
            leading: Icon(
              isDark ? Icons.dark_mode_outlined : Icons.light_mode_outlined,
            ),
            title: const Text('화면 모드'),
            subtitle: Text(isDark ? '어두운 화면 사용 중' : '밝은 화면 사용 중'),
            trailing: Switch(
              value: isDark,
              onChanged: (value) {
                onThemeModeChanged(value ? ThemeMode.dark : ThemeMode.light);
              },
            ),
          ),
        ),
      ],
    );
  }
}

class _Wordmark extends StatelessWidget {
  const _Wordmark();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return ExcludeSemantics(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(
            'RIDEY',
            style: theme.textTheme.titleLarge?.copyWith(
              color: theme.colorScheme.onSurface,
              fontWeight: FontWeight.w900,
              letterSpacing: -1.3,
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(left: 2, bottom: 4),
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: context.ridey.signal,
                shape: BoxShape.circle,
              ),
              child: const SizedBox(width: 7, height: 7),
            ),
          ),
        ],
      ),
    );
  }
}
