import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Same values as the web demo (web/style.css) and docs/brand.md.
abstract final class RideyColors {
  static const ink = Color(0xFF111317);
  static const paper = Color(0xFFF7F5F0);
  static const surface = Color(0xFFFFFFFF);
  static const fill = Color(0xFFEFECE5);
  static const line = Color(0xFFE2DFD7);
  static const body = Color(0xFF474B53);
  static const muted = Color(0xFF63676F);
  static const signal = Color(0xFFFF4F1F);
  static const signalText = Color(0xFFB82D07);
  static const signalSoft = Color(0xFFFFE4D9);
  static const calm = Color(0xFF2D5BFF);
  static const calmText = Color(0xFF2149D6);
  static const calmSoft = Color(0xFFE4EAFF);

  static const darkInk = Color(0xFFF3F1EC);
  static const darkPaper = Color(0xFF0D0F12);
  static const darkSurface = Color(0xFF16191E);
  static const darkFill = Color(0xFF1E2228);
  static const darkLine = Color(0xFF262A31);
  static const darkBody = Color(0xFFB3B7BE);
  static const darkMuted = Color(0xFF8A8F98);
  static const darkSignal = Color(0xFFFF5C2E);
  static const darkSignalText = Color(0xFFFF7A52);
  static const darkSignalSoft = Color(0xFF3A1C12);
  static const darkCalm = Color(0xFF7C9BFF);
  static const darkCalmSoft = Color(0xFF17204A);

  /// The home hero stays ink in both modes, like the web `.hero`.
  static const hero = Color(0xFF111317);
  static const darkHero = Color(0xFF181B21);
  static const heroText = Color(0xFFF7F5F0);
  static const heroMuted = Color(0xFFB3B7BE);
  static const heroSignal = Color(0xFFFF5C2E);
}

/// Motion from docs/brand.md: leave fast and settle softly; only dots, bars
/// and cards spring. Everything collapses to zero under reduced motion.
abstract final class RideyMotion {
  /// `cubic-bezier(.16, 1, .3, 1)` — the web `--ease`.
  static const ease = Cubic(0.16, 1, 0.3, 1);

  /// The web `--spring`: overshoots about 15% near 30% and settles by the end.
  static const spring = _RideySpring();

  static const press = Duration(milliseconds: 140);
  static const enter = Duration(milliseconds: 550);
  static const slide = Duration(milliseconds: 550);

  static bool reduced(BuildContext context) =>
      MediaQuery.maybeDisableAnimationsOf(context) ?? false;

  static Duration of(BuildContext context, Duration duration) =>
      reduced(context) ? Duration.zero : duration;
}

class _RideySpring extends Curve {
  const _RideySpring();

  @override
  double transformInternal(double t) =>
      1 - math.exp(-6 * t) * math.cos(10 * t);
}

abstract final class RideyTheme {
  static const numberFamily = 'RideyNumbers';

  static ThemeData light() => _build(Brightness.light);

  static ThemeData dark() => _build(Brightness.dark);

  static ThemeData _build(Brightness brightness) {
    final isDark = brightness == Brightness.dark;
    final ink = isDark ? RideyColors.darkInk : RideyColors.ink;
    final paper = isDark ? RideyColors.darkPaper : RideyColors.paper;
    final surface = isDark ? RideyColors.darkSurface : RideyColors.surface;
    final fill = isDark ? RideyColors.darkFill : RideyColors.fill;
    final line = isDark ? RideyColors.darkLine : RideyColors.line;
    final body = isDark ? RideyColors.darkBody : RideyColors.body;
    final muted = isDark ? RideyColors.darkMuted : RideyColors.muted;
    final signal = isDark ? RideyColors.darkSignal : RideyColors.signal;
    final signalText = isDark
        ? RideyColors.darkSignalText
        : RideyColors.signalText;
    final signalSoft = isDark
        ? RideyColors.darkSignalSoft
        : RideyColors.signalSoft;
    final calm = isDark ? RideyColors.darkCalm : RideyColors.calm;
    final calmText = isDark ? RideyColors.darkCalm : RideyColors.calmText;
    final calmSoft = isDark ? RideyColors.darkCalmSoft : RideyColors.calmSoft;
    final base = Typography.material2021().black.apply(
      bodyColor: body,
      displayColor: ink,
      decorationColor: ink,
    );
    // Headings follow the web: heavy, tight (-0.045em … -0.02em), short lines.
    final textTheme = base.copyWith(
      displayLarge: base.displayLarge?.copyWith(
        fontSize: 28,
        fontWeight: FontWeight.w800,
        height: 1.25,
        letterSpacing: -1.26,
        color: ink,
      ),
      headlineLarge: base.headlineLarge?.copyWith(
        fontSize: 26,
        fontWeight: FontWeight.w800,
        height: 1.28,
        letterSpacing: -1.17,
        color: ink,
      ),
      titleLarge: base.titleLarge?.copyWith(
        fontSize: 19,
        fontWeight: FontWeight.w800,
        letterSpacing: -0.66,
        color: ink,
      ),
      titleMedium: base.titleMedium?.copyWith(
        fontSize: 16,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.32,
        color: ink,
      ),
      titleSmall: base.titleSmall?.copyWith(
        fontSize: 15,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.3,
        color: ink,
      ),
      bodyLarge: base.bodyLarge?.copyWith(fontSize: 16, height: 1.55),
      bodyMedium: base.bodyMedium?.copyWith(fontSize: 14.5, height: 1.5),
      labelLarge: base.labelLarge?.copyWith(
        fontSize: 16,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.16,
      ),
      labelMedium: base.labelMedium?.copyWith(
        fontSize: 13,
        fontWeight: FontWeight.w700,
      ),
      labelSmall: base.labelSmall?.copyWith(
        fontSize: 11,
        fontWeight: FontWeight.w700,
        letterSpacing: 0,
      ),
    );
    const pill = StadiumBorder();
    // No ripples: the web presses by shrinking (RideyPressable), not splashing.
    final quietOverlay = WidgetStateProperty.resolveWith<Color?>(
      (states) => states.contains(WidgetState.pressed)
          ? ink.withValues(alpha: .06)
          : null,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      scaffoldBackgroundColor: paper,
      splashFactory: NoSplash.splashFactory,
      highlightColor: Colors.transparent,
      colorScheme: ColorScheme(
        brightness: brightness,
        primary: ink,
        onPrimary: paper,
        secondary: calm,
        onSecondary: Colors.white,
        error: signal,
        onError: RideyColors.ink,
        surface: surface,
        onSurface: ink,
        surfaceContainerHighest: fill,
        outline: line,
        outlineVariant: line,
      ),
      textTheme: textTheme,
      dividerColor: line,
      dividerTheme: DividerThemeData(color: line, thickness: 1, space: 1),
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: RideyPageTransitionsBuilder(),
          TargetPlatform.iOS: RideyPageTransitionsBuilder(),
        },
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: paper,
        foregroundColor: ink,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        surfaceTintColor: Colors.transparent,
        titleTextStyle: textTheme.titleMedium,
      ),
      cardTheme: CardThemeData(
        color: surface,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: BorderSide(color: line),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size.fromHeight(54),
          backgroundColor: ink,
          foregroundColor: paper,
          shape: pill,
          textStyle: textTheme.labelLarge?.copyWith(fontSize: 17),
          elevation: 0,
        ).copyWith(overlayColor: quietOverlay),
      ),
      // The web's secondary button: a fill-colored pill without a border.
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size.fromHeight(52),
          backgroundColor: fill,
          foregroundColor: ink,
          side: BorderSide.none,
          shape: pill,
          textStyle: textTheme.labelLarge,
        ).copyWith(overlayColor: quietOverlay),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: ink,
          shape: pill,
          textStyle: textTheme.labelLarge?.copyWith(fontSize: 15),
        ).copyWith(overlayColor: quietOverlay),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(foregroundColor: muted)
            .copyWith(overlayColor: quietOverlay),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: fill,
        hintStyle: textTheme.bodyLarge?.copyWith(color: muted),
        contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: Colors.transparent, width: 1.5),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: Colors.transparent, width: 1.5),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: ink, width: 1.5),
        ),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected) ? paper : muted,
        ),
        trackColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected) ? ink : fill,
        ),
        trackOutlineColor: WidgetStateProperty.all(Colors.transparent),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: signal,
        linearTrackColor: fill,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        titleTextStyle: textTheme.titleLarge,
        contentTextStyle: textTheme.bodyLarge,
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: ink,
        contentTextStyle: textTheme.bodyLarge?.copyWith(
          color: paper,
          fontWeight: FontWeight.w600,
        ),
        shape: pill,
      ),
      chipTheme: ChipThemeData(
        backgroundColor: surface,
        selectedColor: ink,
        side: BorderSide(color: line),
        shape: pill,
        labelStyle: textTheme.labelLarge,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      ),
      extensions: <ThemeExtension<dynamic>>[
        RideySemanticColors(
          signal: signal,
          signalSoft: signalSoft,
          signalText: signalText,
          calm: calm,
          calmText: calmText,
          calmSoft: calmSoft,
          muted: muted,
          body: body,
          line: line,
          fill: fill,
          hero: isDark ? RideyColors.darkHero : RideyColors.hero,
          heroLine: isDark ? RideyColors.darkLine : Colors.transparent,
        ),
      ],
    );
  }
}

/// Pages rise 12px and fade in on the brand ease, like the web `.tab.on`.
class RideyPageTransitionsBuilder extends PageTransitionsBuilder {
  const RideyPageTransitionsBuilder();

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    if (RideyMotion.reduced(context)) return child;
    final enter = CurvedAnimation(
      parent: animation,
      curve: RideyMotion.ease,
      reverseCurve: Curves.easeInCubic,
    );
    return FadeTransition(
      opacity: enter,
      child: SlideTransition(
        position: Tween(
          begin: const Offset(0, 0.03),
          end: Offset.zero,
        ).animate(enter),
        child: child,
      ),
    );
  }
}

class RideySemanticColors extends ThemeExtension<RideySemanticColors> {
  const RideySemanticColors({
    required this.signal,
    required this.signalSoft,
    required this.signalText,
    required this.calm,
    required this.calmText,
    required this.calmSoft,
    required this.muted,
    required this.body,
    required this.line,
    required this.fill,
    required this.hero,
    required this.heroLine,
  });

  final Color signal;
  final Color signalSoft;
  final Color signalText;
  final Color calm;
  final Color calmText;
  final Color calmSoft;
  final Color muted;
  final Color body;
  final Color line;
  final Color fill;
  final Color hero;
  final Color heroLine;

  @override
  RideySemanticColors copyWith({
    Color? signal,
    Color? signalSoft,
    Color? signalText,
    Color? calm,
    Color? calmText,
    Color? calmSoft,
    Color? muted,
    Color? body,
    Color? line,
    Color? fill,
    Color? hero,
    Color? heroLine,
  }) {
    return RideySemanticColors(
      signal: signal ?? this.signal,
      signalSoft: signalSoft ?? this.signalSoft,
      signalText: signalText ?? this.signalText,
      calm: calm ?? this.calm,
      calmText: calmText ?? this.calmText,
      calmSoft: calmSoft ?? this.calmSoft,
      muted: muted ?? this.muted,
      body: body ?? this.body,
      line: line ?? this.line,
      fill: fill ?? this.fill,
      hero: hero ?? this.hero,
      heroLine: heroLine ?? this.heroLine,
    );
  }

  @override
  RideySemanticColors lerp(RideySemanticColors? other, double t) {
    if (other is! RideySemanticColors) return this;
    return RideySemanticColors(
      signal: Color.lerp(signal, other.signal, t)!,
      signalSoft: Color.lerp(signalSoft, other.signalSoft, t)!,
      signalText: Color.lerp(signalText, other.signalText, t)!,
      calm: Color.lerp(calm, other.calm, t)!,
      calmText: Color.lerp(calmText, other.calmText, t)!,
      calmSoft: Color.lerp(calmSoft, other.calmSoft, t)!,
      muted: Color.lerp(muted, other.muted, t)!,
      body: Color.lerp(body, other.body, t)!,
      line: Color.lerp(line, other.line, t)!,
      fill: Color.lerp(fill, other.fill, t)!,
      hero: Color.lerp(hero, other.hero, t)!,
      heroLine: Color.lerp(heroLine, other.heroLine, t)!,
    );
  }
}

extension RideyThemeContext on BuildContext {
  RideySemanticColors get ridey =>
      Theme.of(this).extension<RideySemanticColors>()!;

  /// The one big sentence of a screen (web `.headline`).
  TextStyle? get rideyHeroText => Theme.of(this).textTheme.displayLarge;

  /// Standard page titles share the headline size, like the web.
  TextStyle? get rideyPageTitle => Theme.of(this).textTheme.displayLarge;

  /// Counts and bike numbers use the brand's wide Unbounded figures with
  /// equal-width digits, so a value refreshed every five minutes never jitters.
  TextStyle? rideyNumbers(TextStyle? base) => base?.copyWith(
    fontFamily: RideyTheme.numberFamily,
    fontWeight: FontWeight.w800,
    letterSpacing: 0,
    fontFeatures: const [FontFeature.tabularFigures()],
  );
}
