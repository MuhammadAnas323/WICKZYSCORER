// lib/theme/app_colors.dart
// Cricket-inspired color palette for SPORTYAPP.
// Defines light and dark variants for every semantic color.

import 'package:flutter/material.dart';

/// Central color constants for SPORTYAPP.
class AppColors {
  AppColors._();

  // ── Brand / Cricket palette ─────────────────────────────────────────────
  static const Color pitchGreen = Color(0xFF1A7A3E);
  static const Color pitchGreenLight = Color(0xFF2ECC71);
  static const Color pitchGreenDark = Color(0xFF0D5C2E);

  static const Color willowBrown = Color(0xFF8B5E3C);
  static const Color willowBrownLight = Color(0xFFBF8A5E);

  static const Color ballRed = Color(0xFFD32F2F);
  static const Color ballRedLight = Color(0xFFEF5350);
  static const Color ballSeam = Color(0xFFC62828);

  static const Color floodlightGold = Color(0xFFFFB300);
  static const Color floodlightGoldLight = Color(0xFFFFD54F);

  // ── Neutral / Charcoal ──────────────────────────────────────────────────
  static const Color charcoal900 = Color(0xFF121212);
  static const Color charcoal800 = Color(0xFF1E1E1E);
  static const Color charcoal700 = Color(0xFF2A2A2A);
  static const Color charcoal600 = Color(0xFF3A3A3A);
  static const Color charcoal400 = Color(0xFF6B6B6B);
  static const Color charcoal200 = Color(0xFFB0B0B0);
  static const Color charcoal100 = Color(0xFFE0E0E0);
  static const Color charcoal50 = Color(0xFFF5F5F5);

  // ── Live indicator ──────────────────────────────────────────────────────
  static const Color liveRed = Color(0xFFE53935);
  static const Color liveRedDark = Color(0xFFC62828);

  // ── Status colors ───────────────────────────────────────────────────────
  static const Color success = Color(0xFF43A047);
  static const Color warning = Color(0xFFFFA726);
  static const Color error = Color(0xFFEF5350);
  static const Color info = Color(0xFF42A5F5);

  // ── Gradient presets ────────────────────────────────────────────────────
  static const Gradient splashGradientDark = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Color(0xFF0D2818), Color(0xFF121212)],
  );

  static const Gradient splashGradientLight = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Color(0xFF1A7A3E), Color(0xFF2C3E50)],
  );

  static const Gradient heroCardGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF1A7A3E), Color(0xFF0D5C2E)],
  );

  static const Gradient liveCardGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF1B2838), Color(0xFF0D1B2A)],
  );

  static const Gradient goldGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFFFB300), Color(0xFFFF8F00)],
  );

  // ── Light theme surfaces ─────────────────────────────────────────────────
  static const Color lightBackground = Color(0xFFF4F6F8);
  static const Color lightSurface = Color(0xFFFFFFFF);
  static const Color lightSurfaceVariant = Color(0xFFEEF2F5);

  // ── Dark theme surfaces ──────────────────────────────────────────────────
  static const Color darkBackground = Color(0xFF0F0F0F);
  static const Color darkSurface = Color(0xFF1A1A1A);
  static const Color darkSurfaceVariant = Color(0xFF242424);

  // ── Glass card overlay ───────────────────────────────────────────────────
  static const Color glassFill = Color(0x1AFFFFFF);
  static const Color glassBorder = Color(0x33FFFFFF);

  // ── Shimmer ──────────────────────────────────────────────────────────────
  static const Color shimmerBase = Color(0xFF2A2A2A);
  static const Color shimmerHighlight = Color(0xFF3A3A3A);
  static const Color shimmerBaseLight = Color(0xFFE0E0E0);
  static const Color shimmerHighlightLight = Color(0xFFF5F5F5);
}
