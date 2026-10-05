// lib/theme/app_theme.dart
// Material 3 ThemeData for light and dark modes with 5px radius and bluish borders.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'app_colors.dart';

/// Builds light and dark ThemeData for WICKZYSCORER.
class AppTheme {
  AppTheme._();

  static ThemeData light() {
    final base = ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: const ColorScheme.light(
        primary: AppColors.pitchGreen,
        onPrimary: Colors.white,
        primaryContainer: Color(0xFFE3F2FD),
        onPrimaryContainer: AppColors.pitchGreenDark,
        secondary: AppColors.vibrantBlue,
        onSecondary: Colors.white,
        tertiary: AppColors.floodlightGold,
        onTertiary: Colors.black,
        error: AppColors.vibrantRed,
        surface: AppColors.lightSurface,
        surfaceContainerHighest: AppColors.lightSurfaceVariant,
        onSurface: AppColors.charcoal900,
        onSurfaceVariant: AppColors.charcoal600,
        outline: AppColors.pitchGreen,
      ),
    );
    return base.copyWith(
      scaffoldBackgroundColor: AppColors.lightBackground,
      appBarTheme: AppBarTheme(
        backgroundColor: AppColors.lightSurface,
        foregroundColor: AppColors.charcoal900,
        elevation: 0,
        scrolledUnderElevation: 1,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(5),
          side: const BorderSide(color: AppColors.pitchGreen, width: 1.2),
        ),
        systemOverlayStyle: SystemUiOverlayStyle.dark,
        titleTextStyle: GoogleFonts.poppins(
          fontSize: 18,
          fontWeight: FontWeight.w700,
          color: AppColors.charcoal900,
        ),
      ),
      cardTheme: CardThemeData(
        elevation: AppColors.lightBackground == const Color(0xFFF4F6F8) ? 0 : 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(5),
          side: BorderSide(color: AppColors.pitchGreen.withValues(alpha: 0.3), width: 1.2),
        ),
        color: AppColors.lightSurface,
        margin: EdgeInsets.zero,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.pitchGreen,
          foregroundColor: Colors.white,
          elevation: 2,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(5),
            side: const BorderSide(color: AppColors.pitchGreenLight, width: 1.2),
          ),
          textStyle: GoogleFonts.poppins(
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.pitchGreen,
          side: const BorderSide(color: AppColors.pitchGreen, width: 1.5),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(5),
          ),
          textStyle: GoogleFonts.poppins(
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.lightSurfaceVariant,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(5),
          borderSide: const BorderSide(color: AppColors.pitchGreen, width: 1.2),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(5),
          borderSide: BorderSide(color: AppColors.pitchGreen.withValues(alpha: 0.4), width: 1.2),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(5),
          borderSide: const BorderSide(color: AppColors.pitchGreen, width: 1.5),
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: AppColors.lightSurfaceVariant,
        selectedColor: AppColors.pitchGreenLight,
        labelStyle: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w500),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(5),
          side: BorderSide(color: AppColors.pitchGreen.withValues(alpha: 0.5), width: 1.2),
        ),
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: AppColors.lightSurface,
        selectedItemColor: AppColors.pitchGreen,
        unselectedItemColor: AppColors.charcoal400,
        elevation: 8,
        type: BottomNavigationBarType.fixed,
      ),
      tabBarTheme: TabBarThemeData(
        labelColor: AppColors.pitchGreen,
        unselectedLabelColor: AppColors.charcoal400,
        indicator: BoxDecoration(
          borderRadius: BorderRadius.circular(5),
          color: AppColors.pitchGreen.withValues(alpha: 0.2),
          border: Border.all(color: AppColors.pitchGreen, width: 1.2),
        ),
        indicatorColor: Colors.transparent,
        labelStyle: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w600),
        unselectedLabelStyle:
            GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w500),
        dividerColor: Colors.transparent,
      ),
      dividerTheme: const DividerThemeData(
        color: AppColors.charcoal100,
        thickness: 1,
        space: 1,
      ),
      textTheme: GoogleFonts.interTextTheme(base.textTheme),
    );
  }

  static ThemeData dark() {
    final base = ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: const ColorScheme.dark(
        primary: AppColors.pitchGreenLight,
        onPrimary: Colors.white,
        primaryContainer: AppColors.pitchGreenDark,
        onPrimaryContainer: Color(0xFFD0E1FD),
        secondary: AppColors.vibrantBlue,
        onSecondary: Colors.white,
        tertiary: AppColors.floodlightGold,
        onTertiary: Colors.black,
        error: AppColors.ballRedLight,
        surface: AppColors.darkSurface,
        surfaceContainerHighest: AppColors.darkSurfaceVariant,
        onSurface: Colors.white,
        onSurfaceVariant: AppColors.charcoal200,
        outline: AppColors.pitchGreenLight,
      ),
    );
    return base.copyWith(
      scaffoldBackgroundColor: AppColors.darkBackground,
      appBarTheme: AppBarTheme(
        backgroundColor: AppColors.darkSurface,
        foregroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 1,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(5),
          side: const BorderSide(color: AppColors.pitchGreenLight, width: 1.2),
        ),
        systemOverlayStyle: SystemUiOverlayStyle.light,
        titleTextStyle: GoogleFonts.poppins(
          fontSize: 18,
          fontWeight: FontWeight.w700,
          color: Colors.white,
        ),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(5),
          side: BorderSide(color: AppColors.pitchGreenLight.withValues(alpha: 0.3), width: 1.2),
        ),
        color: AppColors.darkSurface,
        margin: EdgeInsets.zero,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.pitchGreen,
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(5),
            side: const BorderSide(color: AppColors.pitchGreenLight, width: 1.2),
          ),
          textStyle: GoogleFonts.poppins(
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.pitchGreenLight,
          side:
              const BorderSide(color: AppColors.pitchGreenLight, width: 1.5),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(5),
          ),
          textStyle: GoogleFonts.poppins(
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.darkSurfaceVariant,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(5),
          borderSide: const BorderSide(color: AppColors.pitchGreenLight, width: 1.2),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(5),
          borderSide: BorderSide(color: AppColors.pitchGreenLight.withValues(alpha: 0.4), width: 1.2),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(5),
          borderSide: const BorderSide(color: AppColors.pitchGreenLight, width: 1.5),
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: AppColors.darkSurfaceVariant,
        selectedColor: AppColors.pitchGreenLight,
        labelStyle: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w500),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(5),
          side: BorderSide(color: AppColors.pitchGreenLight.withValues(alpha: 0.5), width: 1.2),
        ),
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: AppColors.darkSurface,
        selectedItemColor: AppColors.pitchGreenLight,
        unselectedItemColor: AppColors.charcoal400,
        elevation: 8,
        type: BottomNavigationBarType.fixed,
      ),
      tabBarTheme: TabBarThemeData(
        labelColor: AppColors.pitchGreenLight,
        unselectedLabelColor: AppColors.charcoal400,
        indicator: BoxDecoration(
          borderRadius: BorderRadius.circular(5),
          color: AppColors.pitchGreenLight.withValues(alpha: 0.2),
          border: Border.all(color: AppColors.pitchGreenLight, width: 1.2),
        ),
        indicatorColor: Colors.transparent,
        labelStyle:
            GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w600),
        unselectedLabelStyle:
            GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w500),
        dividerColor: Colors.transparent,
      ),
      dividerTheme: const DividerThemeData(
        color: AppColors.charcoal700,
        thickness: 1,
        space: 1,
      ),
      textTheme: GoogleFonts.interTextTheme(base.textTheme).apply(
        bodyColor: Colors.white,
        displayColor: Colors.white,
      ),
    );
  }
}
