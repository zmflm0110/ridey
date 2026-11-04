import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';

/// 폰이 앱을 여는 동안 보이는 'R.' (아이폰 LaunchScreen·안드로이드 시작 화면의 앱 아이콘)과
/// 똑같은 자리·크기. 첫 화면이 이 자리에서 이어받아 R 은 사라지고 점만 떨어져 서울로 퍼진다.
///
/// 크기는 아이폰 시작 화면 그대로: 1024px 아이콘의 가운데 640px 를 120pt 로 그린다
/// (안드로이드 시작 화면의 아이콘도 화면 가운데 거의 같은 크기 — 녹화로 확인).
abstract final class LaunchMark {
  static const _scale = 120 / 640;

  /// 화면 가운데에서 R 글자 상자(아이콘 px 256..636 × 326..697).
  static const rect = Rect.fromLTWH(
    (256 - 512) * _scale,
    (326 - 512) * _scale,
    380 * _scale,
    371 * _scale,
  );

  /// 화면 가운데에서 점의 가운데와 반지름(아이콘 px 중심 733.5, 630 · 반지름 65.5).
  static const dot = Offset((733.5 - 512) * _scale, (630 - 512) * _scale);
  static const dotRadius = 65.5 * _scale;

  /// 아이콘의 점 색(앱 안 신호색보다 아주 조금 진하다 — 떨어지면서 신호색으로 바뀐다).
  static const dotColor = Color(0xFFFF4F1F);

  static ui.Image? _r;

  /// main 에서 첫 화면 전에 한 번 읽는다 — 첫 프레임부터 R 이 있어야 시작 화면과 이어진다.
  static Future<void> load() async {
    try {
      final data = await rootBundle.load('assets/brand/launch_r.png');
      final codec = await ui.instantiateImageCodec(data.buffer.asUint8List());
      _r = (await codec.getNextFrame()).image;
    } catch (_) {}
  }

  /// R 글자(없으면 건너뜀)를 [opacity] 로, 화면 [size] 가운데 기준으로 그린다.
  static void paintR(Canvas canvas, Size size, double opacity) {
    final image = _r;
    if (image == null || opacity <= 0) return;
    final c = size.center(Offset.zero);
    canvas.drawImageRect(
      image,
      Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble()),
      rect.shift(c),
      Paint()
        ..filterQuality = FilterQuality.medium
        ..color = Color.fromRGBO(255, 255, 255, opacity.clamp(0.0, 1.0)),
    );
  }

  static void paintDot(Canvas canvas, Size size) => canvas.drawCircle(
    size.center(Offset.zero) + dot,
    dotRadius,
    Paint()..color = dotColor,
  );
}

/// 모드를 읽는 아주 짧은 사이에도 시작 화면의 'R.' 을 그대로 둔다.
class LaunchMarkPainter extends CustomPainter {
  const LaunchMarkPainter();

  @override
  void paint(Canvas canvas, Size size) {
    LaunchMark.paintR(canvas, size, 1);
    LaunchMark.paintDot(canvas, size);
  }

  @override
  bool shouldRepaint(LaunchMarkPainter oldDelegate) => false;
}
