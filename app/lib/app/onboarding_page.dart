import 'package:flutter/material.dart';
import 'package:ridey_app/app/user_mode.dart';
import 'package:ridey_app/design/ridey_theme.dart';
import 'package:ridey_app/features/location/device_location.dart';
import 'package:ridey_app/widgets/ridey_tab_bar.dart';
import 'package:ridey_app/widgets/ridey_ui.dart';

/// First launch: who is this for, then (riders only) why the app asks for the
/// location before the system dialog appears. Skipping either step lands in
/// rider mode without a location; the home screen then offers saved stations.
class OnboardingPage extends StatefulWidget {
  const OnboardingPage({
    super.key,
    required this.onChosen,
    this.requestLocation,
  });

  final ValueChanged<UserMode> onChosen;

  /// Asks the system for the location (shows its dialog the first time).
  final Future<DeviceLocation?> Function()? requestLocation;

  @override
  State<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends State<OnboardingPage> {
  var _askLocation = false;
  var _busy = false;

  Future<void> _allowLocation() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await (widget.requestLocation ?? readDeviceLocation)();
    } finally {
      if (mounted) widget.onChosen(UserMode.rider);
    }
  }

  Widget _page(String key, List<Widget> children) {
    return ListView(
      key: ValueKey(key),
      padding: const EdgeInsets.fromLTRB(20, 24, 20, rideyTabClearance),
      children: [
        const RideyWordmark(size: 28),
        const SizedBox(height: 36),
        ...children,
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      body: SafeArea(
        child: AnimatedSwitcher(
          duration: RideyMotion.of(context, const Duration(milliseconds: 300)),
          child: _askLocation
              ? _page('location', [
                  Text(
                    '내 주변 고장 의심\n따릉이를 보여 드릴게요',
                    style: theme.textTheme.displayLarge,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    '위치는 2km 안의 고장 의심 자전거를 찾는 데만 써요. '
                    '이 폰 밖으로 보내지 않아요.',
                    style: theme.textTheme.bodyLarge?.copyWith(
                      color: context.ridey.body,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 28),
                  RideyButton(
                    label: '위치 허용하기',
                    busy: _busy,
                    onPressed: _allowLocation,
                  ),
                  const SizedBox(height: 10),
                  RideyButton.secondary(
                    label: '나중에, 대여소를 직접 고를게요',
                    onPressed: _busy
                        ? null
                        : () => widget.onChosen(UserMode.rider),
                  ),
                ])
              : _page('purpose', [
                  // 한국어는 글자 단위로 줄이 바뀌어 '이용 / 하실' 처럼 낱말이 쪼개진다 — 뜻 단위로 직접 끊는다.
                  Text(
                    'RIDEY 앱을\n어떤 목적으로\n이용하실 건가요?',
                    style: theme.textTheme.displayLarge,
                  ),
                  const SizedBox(height: 28),
                  RideyButton(
                    label: '따릉이를 이용하는 일반 시민이에요',
                    onPressed: () => setState(() => _askLocation = true),
                  ),
                  const SizedBox(height: 10),
                  RideyButton.secondary(
                    label: '따릉이를 수거하고 점검하는 관리 직원이에요',
                    onPressed: () => widget.onChosen(UserMode.staff),
                  ),
                  const SizedBox(height: 16),
                  Center(
                    child: TextButton(
                      onPressed: () => widget.onChosen(UserMode.rider),
                      child: const Text('나중에 할게요'),
                    ),
                  ),
                ]),
        ),
      ),
    );
  }
}
