import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  // Light palette
  static const _lBg       = Color(0xFFF7F6F3);
  static const _lCard     = Color(0xFFEEECEA);
  static const _lCardHigh = Color(0xFFE5E3DF);
  static const _lBorder   = Color(0xFFD8D5D0);
  static const _lText     = Color(0xFF1A1917);
  static const _lMuted    = Color(0xFF6B6963);

  // Dark palette
  static const _dBg       = Color(0xFF141312);
  static const _dCard     = Color(0xFF1E1C1A);
  static const _dCardHigh = Color(0xFF272422);
  static const _dBorder   = Color(0xFF2E2B28);
  static const _dText     = Color(0xFFF0EDE8);
  static const _dMuted    = Color(0xFF9E9A94);

  // Semantic
  static const _green    = Color(0xFF2D6A4F);
  static const _greenBg  = Color(0xFFD8F3DC);
  static const _red      = Color(0xFFC1121F);
  static const _redBg    = Color(0xFFFFE5E5);
  static const _dGreen   = Color(0xFF52B788);
  static const _dGreenBg = Color(0xFF1B3A2D);
  static const _dRed     = Color(0xFFE63946);
  static const _dRedBg   = Color(0xFF2D1B1B);

  static TextTheme _textTheme(Color primary, Color secondary) {
    return TextTheme(
      displayLarge: GoogleFonts.dmSerifDisplay(
          fontSize: 32, color: primary, letterSpacing: -.5),
      displayMedium: GoogleFonts.dmSerifDisplay(
          fontSize: 26, color: primary, letterSpacing: -.3),
      displaySmall: GoogleFonts.dmSerifDisplay(
          fontSize: 22, color: primary, letterSpacing: -.3),
      titleLarge: GoogleFonts.dmSans(
          fontSize: 16, fontWeight: FontWeight.w500, color: primary),
      titleMedium: GoogleFonts.dmSans(
          fontSize: 14, fontWeight: FontWeight.w500, color: primary),
      titleSmall: GoogleFonts.dmSans(
          fontSize: 13, fontWeight: FontWeight.w500, color: primary),
      bodyLarge: GoogleFonts.dmSans(
          fontSize: 15, color: primary, height: 1.6),
      bodyMedium: GoogleFonts.dmSans(
          fontSize: 14, color: primary, height: 1.6),
      bodySmall: GoogleFonts.dmSans(
          fontSize: 13, color: secondary, height: 1.5),
      labelSmall: GoogleFonts.dmSans(
          fontSize: 11, color: secondary, letterSpacing: .05),
    );
  }

  static ThemeData light() {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      scaffoldBackgroundColor: _lBg,
      colorScheme: const ColorScheme.light(
        surface: _lBg,
        surfaceContainerLow: _lCard,
        surfaceContainerHigh: _lCardHigh,
        outline: _lBorder,
        onSurface: _lText,
        onSurfaceVariant: _lMuted,
        primary: _lText,
        onPrimary: _lBg,
        error: _red,
        onError: Colors.white,
      ),
      textTheme: _textTheme(_lText, _lMuted),
      dividerColor: _lBorder,
      extensions: const [
        AppColors(
          cardBg: _lCard,
          greenAccent: _green,
          greenBg: _greenBg,
          redAccent: _red,
          redBg: _redBg,
        ),
      ],
    );
  }

  static ThemeData dark() {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: _dBg,
      colorScheme: const ColorScheme.dark(
        surface: _dBg,
        surfaceContainerLow: _dCard,
        surfaceContainerHigh: _dCardHigh,
        outline: _dBorder,
        onSurface: _dText,
        onSurfaceVariant: _dMuted,
        primary: _dText,
        onPrimary: _dBg,
        error: _dRed,
        onError: Colors.white,
      ),
      textTheme: _textTheme(_dText, _dMuted),
      dividerColor: _dBorder,
      extensions: const [
        AppColors(
          cardBg: _dCard,
          greenAccent: _dGreen,
          greenBg: _dGreenBg,
          redAccent: _dRed,
          redBg: _dRedBg,
        ),
      ],
    );
  }
}

class AppColors extends ThemeExtension<AppColors> {
  final Color cardBg;
  final Color greenAccent;
  final Color greenBg;
  final Color redAccent;
  final Color redBg;

  const AppColors({
    required this.cardBg,
    required this.greenAccent,
    required this.greenBg,
    required this.redAccent,
    required this.redBg,
  });

  @override
  AppColors copyWith({
    Color? cardBg,
    Color? greenAccent,
    Color? greenBg,
    Color? redAccent,
    Color? redBg,
  }) =>
      AppColors(
        cardBg: cardBg ?? this.cardBg,
        greenAccent: greenAccent ?? this.greenAccent,
        greenBg: greenBg ?? this.greenBg,
        redAccent: redAccent ?? this.redAccent,
        redBg: redBg ?? this.redBg,
      );

  @override
  AppColors lerp(AppColors? other, double t) => this;
}