import 'package:flutter/material.dart';

abstract final class RideyColors {
  static const ink = Color(0xFF111317);
  static const paper = Color(0xFFF7F5F0);
  static const surface = Color(0xFFFFFFFF);
  static const line = Color(0xFFE2DFD7);
  static const body = Color(0xFF474B53);
  static const muted = Color(0xFF63676F);
  static const signal = Color(0xFFFF4F1F);
  static const signalText = Color(0xFFB82D07);
  static const signalSoft = Color(0xFFFFE4D9);
  static const calm = Color(0xFF2D5BFF);
  static const calmSoft = Color(0xFFE4EAFF);

  static const darkInk = Color(0xFFF3F1EC);
  static const darkPaper = Color(0xFF0D0F12);
  static const darkSurface = Color(0xFF16191E);
  static const darkLine = Color(0xFF262A31);
  static const darkBody = Color(0xFFB3B7BE);
  static const darkMuted = Color(0xFF8A8F98);
  static const darkSignal = Color(0xFFFF5C2E);
  static const darkSignalText = Color(0xFFFF7A52);
  static const darkSignalSoft = Color(0xFF3A1C12);
  static const darkCalm = Color(0xFF7C9BFF);
  static const darkCalmSoft = Color(0xFF17204A);
}

abstract final class RideyTheme {
  static ThemeData light() => _build(Brightness.light);

  static ThemeData dark() => _build(Brightness.dark);

  static ThemeData _build(Brightness brightness) {
    final isDark = brightness == Brightness.dark;
    final ink = isDark ? RideyColors.darkInk : RideyColors.ink;
    final paper = isDark ? RideyColors.darkPaper : RideyColors.paper;
    final surface = isDark ? RideyColors.darkSurface : RideyColors.surface;
    final line = isDark ? RideyColors.darkLine : RideyColors.line;
    final body = isDark ? RideyColors.darkBody : RideyColors.body;
    final muted = isDark ? RideyColors.darkMuted : RideyColors.muted;
    final signal = isDark ? RideyColors.darkSignal : RideyColors.signal;
    final signalSoft = isDark
        ? RideyColors.darkSignalSoft
        : RideyColors.signalSoft;
    final calm = isDark ? RideyColors.darkCalm : RideyColors.calm;
    final calmSoft = isDark ? RideyColors.darkCalmSoft : RideyColors.calmSoft;
    final textTheme = Typography.material2021().black.apply(
      bodyColor: body,
      displayColor: ink,
      decorationColor: ink,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      scaffoldBackgroundColor: paper,
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
      ),
      textTheme: textTheme.copyWith(
        displayLarge: textTheme.displayLarge?.copyWith(
          fontSize: 36,
          fontWeight: FontWeight.w800,
          height: 1.04,
          letterSpacing: -1.6,
        ),
        headlineLarge: textTheme.headlineLarge?.copyWith(
          fontSize: 28,
          fontWeight: FontWeight.w800,
          height: 1.12,
          letterSpacing: -.9,
        ),
        titleLarge: textTheme.titleLarge?.copyWith(
          fontSize: 22,
          fontWeight: FontWeight.w800,
          letterSpacing: -.6,
        ),
        titleMedium: textTheme.titleMedium?.copyWith(
          fontWeight: FontWeight.w800,
          letterSpacing: -.3,
        ),
        bodyLarge: textTheme.bodyLarge?.copyWith(height: 1.5),
        bodyMedium: textTheme.bodyMedium?.copyWith(height: 1.45),
        labelLarge: textTheme.labelLarge?.copyWith(
          fontWeight: FontWeight.w700,
          letterSpacing: -.2,
        ),
      ),
      dividerColor: line,
      appBarTheme: AppBarTheme(
        backgroundColor: paper,
        foregroundColor: ink,
        elevation: 0,
        centerTitle: false,
        surfaceTintColor: Colors.transparent,
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
          shape: const StadiumBorder(),
          textStyle: textTheme.labelLarge,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size.fromHeight(50),
          foregroundColor: ink,
          side: BorderSide(color: line),
          shape: const StadiumBorder(),
          textStyle: textTheme.labelLarge,
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: surface,
        selectedColor: signalSoft,
        side: BorderSide(color: line),
        shape: const StadiumBorder(),
        labelStyle: textTheme.labelLarge,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      ),
      extensions: <ThemeExtension<dynamic>>[
        RideySemanticColors(
          signal: signal,
          signalSoft: signalSoft,
          signalText: isDark
              ? RideyColors.darkSignalText
              : RideyColors.signalText,
          calm: calm,
          calmSoft: calmSoft,
          muted: muted,
          line: line,
        ),
      ],
    );
  }
}

class RideySemanticColors extends ThemeExtension<RideySemanticColors> {
  const RideySemanticColors({
    required this.signal,
    required this.signalSoft,
    required this.signalText,
    required this.calm,
    required this.calmSoft,
    required this.muted,
    required this.line,
  });

  final Color signal;
  final Color signalSoft;
  final Color signalText;
  final Color calm;
  final Color calmSoft;
  final Color muted;
  final Color line;

  @override
  RideySemanticColors copyWith({
    Color? signal,
    Color? signalSoft,
    Color? signalText,
    Color? calm,
    Color? calmSoft,
    Color? muted,
    Color? line,
  }) {
    return RideySemanticColors(
      signal: signal ?? this.signal,
      signalSoft: signalSoft ?? this.signalSoft,
      signalText: signalText ?? this.signalText,
      calm: calm ?? this.calm,
      calmSoft: calmSoft ?? this.calmSoft,
      muted: muted ?? this.muted,
      line: line ?? this.line,
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
      calmSoft: Color.lerp(calmSoft, other.calmSoft, t)!,
      muted: Color.lerp(muted, other.muted, t)!,
      line: Color.lerp(line, other.line, t)!,
    );
  }
}

extension RideyThemeContext on BuildContext {
  RideySemanticColors get ridey =>
      Theme.of(this).extension<RideySemanticColors>()!;

  /// Use this only for the one decision that defines a journey.
  TextStyle? get rideyHeroText => Theme.of(this).textTheme.displayLarge;

  /// Standard page titles deliberately stay smaller than hero decisions.
  TextStyle? get rideyPageTitle => Theme.of(this).textTheme.headlineLarge;
}
