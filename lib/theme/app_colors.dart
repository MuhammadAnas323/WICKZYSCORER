// lib/theme/app_colors.dart
// Cricket-inspired color palette for WICKZYSCORER.
// Defines light and dark variants for every semantic color.

import 'package:flutter/material.dart';

/// Central color constants for WICKZYSCORER.
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

  // ── Vibrant Theme Colors (Requested by User) ─────────────────────────────
  static const Color vibrantBlue = Color(0xFF2196F3);
  static const Color vibrantCyan = Color(0xFF00BCD4);
  static const Color vibrantYellow = Color(0xFFFFEB3B);
  static const Color vibrantRed = Color(0xFFF44336);
  static const Color vibrantGreen = Color(0xFF4CAF50);
  static const Color vibrantPurple = Color(0xFF9C27B0);
  static const Color vibrantOrange = Color(0xFFFF9800);

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

  // ── Auto-assigned card gradients ─────────────────────────────────────────
  // Every match / tournament card picks one of these by id so new items are
  // automatically colored (stable across rebuilds, no manual setup needed).
  // Vivid Material colors so each card stands out instead of looking plain.
  static const List<LinearGradient> cardGradients = [
    LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFF448AFF), Color(0xFF7C4DFF)]), // blue → violet
    LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFFFF4081), Color(0xFFFF6E40)]), // pink → orange
    LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFF00E5FF), Color(0xFF00B0FF)]), // cyan → blue
    LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFF69F0AE), Color(0xFF00C853)]), // mint → green
    LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFFFFC400), Color(0xFFFF6D00)]), // amber → orange
    LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFFD500F9), Color(0xFFF50057)]), // purple → pink
    LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFFFF1744), Color(0xFF651FFF)]), // red → indigo
    LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFF40C4FF), Color(0xFF304FFE)]), // light blue → indigo
    LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFF1DE9B6), Color(0xFF0091EA)]), // teal → azure
    LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFFC6FF00), Color(0xFF00E676)]), // lime → green
  ];

  /// Deterministically picks a card gradient for [seed] (e.g. a match or
  /// tournament id), so a newly created match / tournament is colored
  /// automatically and keeps the same color across rebuilds.
  static LinearGradient cardGradientFor(String seed) =>
      cardGradients[(seed.hashCode & 0x7fffffff) % cardGradients.length];

  // ── Tournament card gradients ────────────────────────────────────────────
  // Deliberately a DIFFERENT palette from the match `cardGradients` so
  // tournament cards stay visually distinct from match cards. Deeper, richer
  // "trophy" tones (gold, emerald, crimson, royal navy...) instead of the
  // vivid neon match hues.
  static const List<LinearGradient> tournamentGradients = [
    LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFFFBC02D), Color(0xFFF57F17)]), // gold → amber
    LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFF00C853), Color(0xFF009688)]), // emerald → teal
    LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFFE53935), Color(0xFF8E24AA)]), // crimson → magenta
    LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFF1E88E5), Color(0xFF0D47A1)]), // royal blue → navy
    LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFF00897B), Color(0xFF00695C)]), // teal → dark teal
    LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFF5E35B1), Color(0xFF311B92)]), // deep purple
    LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFFD84315), Color(0xFFBF360C)]), // deep orange → rust
    LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFF546E7A), Color(0xFF263238)]), // slate → charcoal
  ];

  /// Deterministically picks a tournament gradient for [seed] (a tournament
  /// id). Kept separate from [cardGradientFor] so tournaments never share a
  /// corner color with match cards.
  static LinearGradient tournamentGradientFor(String seed) =>
      tournamentGradients[
          (seed.hashCode & 0x7fffffff) % tournamentGradients.length];

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
