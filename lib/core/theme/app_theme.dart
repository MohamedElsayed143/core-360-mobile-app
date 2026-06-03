import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  AppTheme._();

  // ─── GLOBAL BACKGROUND ───────────────────────────────────────────
  static const Color darkBackground = Color(0xFF030712);

  // ─── CARD CONTAINERS ──────────────────────────────────────────────
  static const Color darkSurface = Color(0xFF0b1329);

  // ─── ACCENT COLOR TOKENS ──────────────────────────────────────────
  static const Color cyberCyan = Color(0xFF00b4d8);
  static const Color electricBlue = Color(0xFF0ea5e9);
  static const Color matrixGreen = Color(0xFF22c55e);
  static const Color crimsonRed = Color(0xFFef4444);
  static const Color safetyAmber = Color(0xFFf59e0b);

  // ─── TYPOGRAPHY COLORS ────────────────────────────────────────────
  static const Color textWhite = Color(0xFFffffff);
  static const Color textSub = Color(0xFFcbd5e1);
  static const Color textMuted = Color(0xFF475569);

  // ─── BORDERS & GLASS ──────────────────────────────────────────────
  static const Color cardBorderColor = Color(0xFF1e293b);
  static const Color glassFillColor = Color(0x0AFFFFFF);

  // ─── LEGACY (kept for compatibility) ──────────────────────────────
  static const Color warningAmber = safetyAmber;
  static const Color amethystPurple = Color(0xFF8b5cf6);

  // ─── GRADIENTS ────────────────────────────────────────────────────
  static const LinearGradient primaryGradient = LinearGradient(
    colors: [cyberCyan, electricBlue],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient secondaryGradient = LinearGradient(
    colors: [amethystPurple, Color(0xFF6d28d9)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient accentGradient = LinearGradient(
    colors: [cyberCyan, matrixGreen],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  // ─── TEXT STYLES ──────────────────────────────────────────────────
  static TextStyle heroTitle({Color color = textWhite}) => GoogleFonts.outfit(
    fontSize: 28, fontWeight: FontWeight.w800, color: color, letterSpacing: -0.5,
  );

  static TextStyle sectionTitle({Color color = textWhite}) => GoogleFonts.outfit(
    fontSize: 16, fontWeight: FontWeight.w700, color: color, letterSpacing: 0.5,
  );

  static TextStyle metricNumber({Color color = cyberCyan}) => GoogleFonts.jetBrainsMono(
    fontSize: 20, fontWeight: FontWeight.w700, color: color,
  );

  static TextStyle metricUnit({Color color = textMuted}) => GoogleFonts.outfit(
    fontSize: 11, fontWeight: FontWeight.w500, color: color,
  );

  static TextStyle bodyText({Color color = textSub}) => GoogleFonts.outfit(
    fontSize: 13, fontWeight: FontWeight.w400, color: color, height: 1.4,
  );

  static TextStyle labelSmall({Color color = textMuted}) => GoogleFonts.outfit(
    fontSize: 11, fontWeight: FontWeight.w600, color: color, letterSpacing: 0.5,
  );

  static TextStyle monoValue({Color color = textWhite}) => GoogleFonts.jetBrainsMono(
    fontSize: 13, fontWeight: FontWeight.w600, color: color,
  );

  // ─── THEME DATA ───────────────────────────────────────────────────
  static ThemeData get darkTheme {
    final baseTheme = ThemeData.dark(useMaterial3: true);

    return baseTheme.copyWith(
      scaffoldBackgroundColor: darkBackground,
      primaryColor: cyberCyan,
      colorScheme: const ColorScheme.dark(
        primary: cyberCyan,
        secondary: matrixGreen,
        surface: darkSurface,
        surfaceContainerLowest: darkBackground,
        error: crimsonRed,
        onPrimary: Colors.black,
        onSecondary: Colors.white,
      ),
      textTheme: GoogleFonts.outfitTextTheme(baseTheme.textTheme).copyWith(
        displayMedium: GoogleFonts.outfit(
          color: textWhite, fontWeight: FontWeight.bold, letterSpacing: -0.5,
        ),
        titleLarge: GoogleFonts.outfit(
          color: textWhite, fontWeight: FontWeight.w600, letterSpacing: 0.2,
        ),
        bodyLarge: GoogleFonts.outfit(
          color: textSub, fontWeight: FontWeight.normal,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: darkSurface,
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: cardBorderColor, width: 1.0),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: cyberCyan, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: crimsonRed, width: 1.0),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: crimsonRed, width: 1.5),
        ),
        labelStyle: GoogleFonts.outfit(color: textSub, fontSize: 14),
        hintStyle: GoogleFonts.outfit(color: textMuted, fontSize: 14),
        floatingLabelStyle: GoogleFonts.outfit(color: cyberCyan),
      ),
      cardTheme: CardThemeData(
        color: darkSurface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: cardBorderColor, width: 1.0),
        ),
      ),
    );
  }
}
