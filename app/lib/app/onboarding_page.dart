import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:ridey_app/app/seoul_hero.dart';
import 'package:ridey_app/app/user_mode.dart';
import 'package:ridey_app/design/ridey_theme.dart';
import 'package:ridey_app/features/live/live_snapshot.dart';
import 'package:ridey_app/features/location/device_location.dart';
import 'package:ridey_app/features/stations/bike_station.dart';
import 'package:ridey_app/widgets/ridey_ui.dart';

/// First launch, one continuous screen: the Seoul map story fills the screen
/// (see [SeoulHero]) and a panel rises from the bottom with the question. For
/// riders the panel then explains the location before the system asks — the
/// map stays behind it. Skipping lands in rider mode without a location.
class OnboardingPage extends StatefulWidget {
  const OnboardingPage({
    super.key,
    required this.onChosen,
    this.lastMode,
    this.requestLocation,
    this.stations,
    this.snapshot,
  });

  final ValueChanged<UserMode> onChosen;

  /// 지난번에 고른 모드(켤 때마다 묻기 때문). 있으면 위치 안내는 이미 본 것이라 건너뛴다.
  final UserMode? lastMode;

  /// Asks the system for the location (shows its dialog the first time).
  final Future<DeviceLocation?> Function()? requestLocation;

  /// Seoul stations and the live snapshot for the map.
  final Future<List<BikeStation>>? stations;
  final Future<LiveSnapshot?>? snapshot;

  @override
  State<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends State<OnboardingPage> {
  var _askLocation = false;
  var _busy = false;
  late final Future<List<BikeStation>> _stations =
      widget.stations ?? Future.value(const <BikeStation>[]);
  late final Future<LiveSnapshot?> _snapshot =
      widget.snapshot ?? Future.value(null);

  Future<void> _allowLocation() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await (widget.requestLocation ?? readDeviceLocation)();
    } finally {
      if (mounted) widget.onChosen(UserMode.rider);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: RideyColors.hero,
        body: SeoulHero(
          stations: _stations,
          snapshot: _snapshot,
          overlay: (context, story, lit, count) {
            // 패널은 점이 퍼지기 시작하면 올라온다. 손은 처음부터 닿는다(애니메이션을 기다리게 하지 않음).
            final rise = Curves.easeOutCubic.transform(
              ((story - .3) / .35).clamp(0.0, 1.0),
            );
            final logo = ((story - .55) / .3).clamp(0.0, 1.0);
            return Stack(
              children: [
                Positioned(
                  left: 20,
                  top: MediaQuery.paddingOf(context).top + 18,
                  child: Opacity(
                    opacity: logo,
                    child: const RideyWordmark(
                      size: 24,
                      color: RideyColors.heroText,
                    ),
                  ),
                ),
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: Transform.translate(
                    offset: Offset(0, (1 - rise) * 40),
                    child: Opacity(
                      opacity: rise,
                      child: _Panel(
                        lit: lit,
                        count: count,
                        child: Theme(
                          // 잉크 바탕 위 단추: 주 단추는 종이색, 보조는 어두운 면 — 어두운 화면 규칙 그대로.
                          data: RideyTheme.dark(),
                          child: AnimatedSwitcher(
                            duration: RideyMotion.of(
                              context,
                              const Duration(milliseconds: 280),
                            ),
                            child: _askLocation
                                ? _location(context)
                                : _purpose(context),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _purpose(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      key: const ValueKey('purpose'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // 한국어는 글자 단위로 줄이 바뀌어 '이용 / 하실' 처럼 낱말이 쪼개진다 — 뜻 단위로 직접 끊는다.
        Text(
          'RIDEY 앱을 어떤 목적으로\n이용하실 건가요?',
          style: theme.textTheme.headlineLarge?.copyWith(
            fontSize: 24,
            color: RideyColors.heroText,
          ),
        ),
        const SizedBox(height: 18),
        RideyButton(
          label: '따릉이를 이용하는 일반 시민이에요',
          onPressed: () => widget.lastMode == null
              ? setState(() => _askLocation = true)
              : widget.onChosen(UserMode.rider),
        ),
        const SizedBox(height: 10),
        RideyButton.secondary(
          label: '따릉이를 수거하고 점검하는 관리 직원이에요',
          onPressed: () => widget.onChosen(UserMode.staff),
        ),
        const SizedBox(height: 6),
        if (widget.lastMode == null)
          Center(
            child: TextButton(
              onPressed: () => widget.onChosen(UserMode.rider),
              style: TextButton.styleFrom(
                foregroundColor: RideyColors.heroMuted,
              ),
              child: const Text('나중에 할게요'),
            ),
          )
        else
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Text(
              widget.lastMode == UserMode.staff
                  ? '지난번엔 관리 직원으로 썼어요'
                  : '지난번엔 일반 시민으로 썼어요',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: RideyColors.heroMuted,
              ),
            ),
          ),
      ],
    );
  }

  Widget _location(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      key: const ValueKey('location'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          '내 주변 고장 의심\n따릉이를 보여 드릴게요',
          style: theme.textTheme.headlineLarge?.copyWith(
            fontSize: 24,
            color: RideyColors.heroText,
          ),
        ),
        const SizedBox(height: 10),
        Text(
          '위치는 지도를 내 근처에서 시작하고 가까운 순으로 줄 세우는 데만 써요. '
          '이 폰 밖으로 보내지 않아요.',
          style: theme.textTheme.bodyLarge?.copyWith(
            color: RideyColors.heroMuted,
            height: 1.5,
          ),
        ),
        const SizedBox(height: 18),
        RideyButton(label: '위치 허용하기', busy: _busy, onPressed: _allowLocation),
        const SizedBox(height: 10),
        RideyButton.secondary(
          label: '나중에, 대여소를 직접 고를게요',
          onPressed: _busy ? null : () => widget.onChosen(UserMode.rider),
        ),
        const SizedBox(height: 8),
      ],
    );
  }
}

/// Bottom panel: an ink fade so text reads over the map, the live count (or
/// the tagline without live data), then the step's question and buttons.
class _Panel extends StatelessWidget {
  const _Panel({required this.lit, required this.count, required this.child});

  final double lit;
  final int? count;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final shown = count;
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0x00111317), Color(0xF2111317), RideyColors.hero],
          stops: [0, .18, 1],
        ),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 40, 20, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 숫자 줄의 자리를 처음부터 잡아 둔다 — 실시간 자료가 늦게 와도 질문과 단추가 밀려 올라가지 않게.
              SizedBox(
                height: 48,
                child: Align(
                  alignment: Alignment.bottomLeft,
                  child: _countLine(context, theme, shown),
                ),
              ),
              const SizedBox(height: 22),
              child,
            ],
          ),
        ),
      ),
    );
  }

  Widget _countLine(BuildContext context, ThemeData theme, int? shown) {
    return shown != null && shown > 0
        ? Opacity(
            opacity: lit.clamp(0.0, 1.0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '${(shown * Curves.easeOut.transform(lit)).round()}',
                  style: context
                      .rideyNumbers(theme.textTheme.displayLarge)
                      ?.copyWith(
                        color: RideyColors.heroSignal,
                        fontSize: 44,
                        height: 1,
                      ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    '지금 서울의 고장 의심 따릉이\n서울시 공개 대여 기록 · 5분마다',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: RideyColors.heroMuted,
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            ),
          )
        : Text(
            '타기 전에, 고장 난 따릉이를 먼저',
            style: theme.textTheme.titleMedium?.copyWith(
              color: RideyColors.heroMuted,
              fontWeight: FontWeight.w700,
            ),
          );
  }
}
