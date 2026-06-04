import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Core-360 Design Tokens and Premium Styling Rules.
class AppTheme {
  AppTheme._();

  // Premium Pitch Obsidian & Cyber Color Palette
  static const Color darkBackground = Color(0xFF08080C);
  static const Color darkSurface = Color(0xFF12121A);
  static const Color cyberCyan = Color(0xFF00F5FF);
  static const Color electricBlue = Color(0xFF007AFF);
  static const Color amethystPurple = Color(0xFFBD00FF);
  static const Color warningAmber = Color(0xFFFFD600);
  static const Color cardBorderColor = Color(0xFF2A2A3C);
  static const Color glassFillColor = Color(0x0AFFFFFF);

  /// Sleek Linear Gradient from Cyan to Electric Blue for primary CTAs
  static const LinearGradient primaryGradient = LinearGradient(
    colors: [cyberCyan, electricBlue],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  /// Amethyst to Purple secondary gradient
  static const LinearGradient secondaryGradient = LinearGradient(
    colors: [amethystPurple, Color(0xFF8E24AA)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  /// Dark theme configuration with Google Fonts Outfit typography
  static ThemeData get darkTheme {
    final baseTheme = ThemeData.dark(useMaterial3: true);
    
    return baseTheme.copyWith(
      scaffoldBackgroundColor: darkBackground,
      primaryColor: cyberCyan,
      colorScheme: const ColorScheme.dark(
        primary: cyberCyan,
        secondary: amethystPurple,
        surface: darkSurface,
        // background is deprecated in Material 3; use scaffoldBackgroundColor at the
        // ThemeData level (already set above) and surfaceContainerLowest for dialogs.
        surfaceContainerLowest: darkBackground,
        error: Colors.redAccent,
        onPrimary: Colors.black,
        onSecondary: Colors.white,
      ),
      textTheme: GoogleFonts.outfitTextTheme(baseTheme.textTheme).copyWith(
        displayMedium: GoogleFonts.outfit(
          color: Colors.white,
          fontWeight: FontWeight.bold,
          letterSpacing: -0.5,
        ),
        titleLarge: GoogleFonts.outfit(
          color: Colors.white,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.2,
        ),
        bodyLarge: GoogleFonts.outfit(
          color: Colors.white.withValues(alpha: 0.9),
          fontWeight: FontWeight.normal,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: glassFillColor,
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: cardBorderColor, width: 1.2),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: cyberCyan, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: Colors.redAccent, width: 1.2),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: Colors.redAccent, width: 1.5),
        ),
        labelStyle: GoogleFonts.outfit(color: Colors.white70, fontSize: 14),
        hintStyle: GoogleFonts.outfit(color: Colors.white30, fontSize: 14),
        floatingLabelStyle: GoogleFonts.outfit(color: cyberCyan),
      ),
      cardTheme: CardThemeData(
        color: darkSurface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: cardBorderColor, width: 1.2),
        ),
      ),
    );
  }
}
