import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:ridey_app/design/ridey_theme.dart';

/// 앱을 켤 때 한 번: 잉크 바탕에 신호 점이 위에서 떨어져 글자 바닥선에 튀며 앉고
/// (사이트 로고의 '떨어져 앉는 점'), 'RIDEY' 글자가 왼쪽부터 가림막 뒤에서 올라온 뒤
/// 점에서 고리가 한 번 퍼지고 화면이 걷힌다. 움직임 줄이기면 바로 끝난다.
class RideyIntro extends StatefulWidget {
  const RideyIntro({super.key, required this.onDone});

  final VoidCallback onDone;

  static const duration = Duration(milliseconds: 1900);

  @override
  State<RideyIntro> createState() => _RideyIntroState();
}

class _RideyIntroState extends State<RideyIntro>
    with SingleTickerProviderStateMixin {
  late final AnimationController _t = AnimationController(
    vsync: this,
    duration: RideyIntro.duration,
  );
  var _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    if (RideyMotion.reduced(context)) {
      WidgetsBinding.instance.addPostFrameCallback((_) => widget.onDone());
      return;
    }
    _t.forward().whenComplete(() {
      if (mounted) widget.onDone();
    });
  }

  @override
  void dispose() {
    _t.dispose();
    super.dispose();
  }

  /// 0..1 of [start, end] seconds within the whole run.
  double _phase(double start, double end) {
    final s = _t.value * RideyIntro.duration.inMilliseconds / 1000;
    return ((s - start) / (end - start)).clamp(0.0, 1.0);
  }

  @override
  Widget build(BuildContext context) {
    const size = 44.0;
    const letters = 'RIDEY';
    final style = const TextStyle(
      fontFamily: RideyTheme.numberFamily,
      fontWeight: FontWeight.w800,
      fontSize: size,
      height: 1,
      letterSpacing: -size * .02,
      color: RideyColors.heroText,
    );

    return Semantics(
      label: 'RIDEY',
      excludeSemantics: true,
      child: AnimatedBuilder(
        animation: _t,
        builder: (context, _) {
          final fade = 1 - Curves.easeIn.transform(_phase(1.5, 1.9));
          final drop = _phase(0.05, 0.75);
          final ring = _phase(1.05, 1.6);
          return IgnorePointer(
            ignoring: _t.value > .8,
            child: Opacity(
              opacity: fade,
              child: ColoredBox(
                color: RideyColors.hero,
                child: Center(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      for (var i = 0; i < letters.length; i++)
                        _Letter(
                          text: letters[i],
                          style: style,
                          t: RideyMotion.ease.transform(
                            _phase(0.55 + i * .07, 1.05 + i * .07),
                          ),
                        ),
                      Padding(
                        padding: const EdgeInsets.only(left: size * .06),
                        child: _Dot(size: size * .27, drop: drop, ring: ring),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

/// 한 글자: 바닥선 아래 가림막 뒤에서 올라온다.
class _Letter extends StatelessWidget {
  const _Letter({required this.text, required this.style, required this.t});

  final String text;
  final TextStyle style;
  final double t;

  @override
  Widget build(BuildContext context) {
    return ClipRect(
      child: FractionalTranslation(
        translation: Offset(0, 1 - t),
        child: Opacity(
          opacity: t,
          child: Text(text, style: style),
        ),
      ),
    );
  }
}

/// 떨어지는 점: 위에서 떨어져 바닥에 닿을 때 살짝 납작해졌다가 두 번 작게 튀고 앉는다.
class _Dot extends StatelessWidget {
  const _Dot({required this.size, required this.drop, required this.ring});

  final double size;
  final double drop;
  final double ring;

  @override
  Widget build(BuildContext context) {
    final y = -_height(drop) * 220;
    // 닿는 순간(0.45, 0.75, 0.92 근처) 납작하게
    final squash = _impact(drop);
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _RingPainter(ring),
        child: Transform.translate(
          offset: Offset(0, y),
          child: Transform(
            alignment: Alignment.bottomCenter,
            transform: Matrix4.diagonal3Values(
              1 + squash * .3,
              1 - squash * .3,
              1,
            ),
            child: const DecoratedBox(
              decoration: BoxDecoration(
                color: RideyColors.heroSignal,
                shape: BoxShape.circle,
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// 0 = 바닥선, 1 = 처음 높이. 떨어진 뒤 0.22, 0.06 높이로 두 번 튐.
  static double _height(double t) {
    if (t <= 0) return 1;
    if (t < .45) {
      final p = t / .45;
      return 1 - p * p;
    }
    if (t < .75) {
      final p = (t - .45) / .3;
      return .22 * (1 - math.pow(2 * p - 1, 2));
    }
    if (t < .92) {
      final p = (t - .75) / .17;
      return .06 * (1 - math.pow(2 * p - 1, 2));
    }
    return 0;
  }

  static double _impact(double t) {
    double bump(double at, double width, double depth) {
      final d = (t - at).abs();
      return d >= width ? 0 : depth * (1 - d / width);
    }

    return bump(.45, .06, 1) + bump(.75, .05, .5) + bump(.92, .04, .25);
  }
}

/// 점이 앉은 뒤 한 번 퍼지는 고리.
class _RingPainter extends CustomPainter {
  _RingPainter(this.t);

  final double t;

  @override
  void paint(Canvas canvas, Size size) {
    if (t <= 0 || t >= 1) return;
    final e = RideyMotion.ease.transform(t);
    canvas.drawCircle(
      size.center(Offset.zero),
      size.width / 2 + e * size.width * 2.2,
      Paint()
        ..color = RideyColors.heroSignal.withValues(alpha: (1 - t) * .7)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
  }

  @override
  bool shouldRepaint(_RingPainter old) => old.t != t;
}
