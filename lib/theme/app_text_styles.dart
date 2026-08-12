// lib/theme/app_text_styles.dart
// Centralized text styles using Poppins + Inter via google_fonts.

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Typography scale for WICKZYSCORER.
/// Headings use Poppins (bold, sporty feel).
/// Body / captions use Inter (clean, readable).
class AppTextStyles {
  AppTextStyles._();

  // ── Poppins headings ───────────────────────────────────────────────────

  static TextStyle displayLarge(Color color) => GoogleFonts.poppins(
        fontSize: 34,
        fontWeight: FontWeight.w800,
        color: color,
        letterSpacing: -0.5,
      );

  static TextStyle displayMedium(Color color) => GoogleFonts.poppins(
        fontSize: 28,
        fontWeight: FontWeight.w700,
        color: color,
        letterSpacing: -0.3,
      );

  static TextStyle headlineLarge(Color color) => GoogleFonts.poppins(
        fontSize: 24,
        fontWeight: FontWeight.w700,
        color: color,
      );

  static TextStyle headlineMedium(Color color) => GoogleFonts.poppins(
        fontSize: 20,
        fontWeight: FontWeight.w600,
        color: color,
      );

  static TextStyle headlineSmall(Color color) => GoogleFonts.poppins(
        fontSize: 18,
        fontWeight: FontWeight.w600,
        color: color,
      );

  static TextStyle titleLarge(Color color) => GoogleFonts.poppins(
        fontSize: 16,
        fontWeight: FontWeight.w600,
        color: color,
      );

  static TextStyle titleMedium(Color color) => GoogleFonts.poppins(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        color: color,
      );

  static TextStyle titleSmall(Color color) => GoogleFonts.poppins(
        fontSize: 12,
        fontWeight: FontWeight.w600,
        color: color,
        letterSpacing: 0.4,
      );

  // ── Inter body / labels ────────────────────────────────────────────────

  static TextStyle bodyLarge(Color color) => GoogleFonts.inter(
        fontSize: 16,
        fontWeight: FontWeight.w400,
        color: color,
      );

  static TextStyle bodyMedium(Color color) => GoogleFonts.inter(
        fontSize: 14,
        fontWeight: FontWeight.w400,
        color: color,
      );

  static TextStyle bodySmall(Color color) => GoogleFonts.inter(
        fontSize: 12,
        fontWeight: FontWeight.w400,
        color: color,
      );

  static TextStyle labelLarge(Color color) => GoogleFonts.inter(
        fontSize: 14,
        fontWeight: FontWeight.w500,
        color: color,
        letterSpacing: 0.1,
      );

  static TextStyle labelMedium(Color color) => GoogleFonts.inter(
        fontSize: 12,
        fontWeight: FontWeight.w500,
        color: color,
        letterSpacing: 0.5,
      );

  static TextStyle labelSmall(Color color) => GoogleFonts.inter(
        fontSize: 10,
        fontWeight: FontWeight.w600,
        color: color,
        letterSpacing: 0.8,
      );

  // ── Score display (extra large) ────────────────────────────────────────
  static TextStyle score(Color color) => GoogleFonts.poppins(
        fontSize: 36,
        fontWeight: FontWeight.w800,
        color: color,
        letterSpacing: -1,
      );

  static TextStyle scoreMedium(Color color) => GoogleFonts.poppins(
        fontSize: 24,
        fontWeight: FontWeight.w700,
        color: color,
      );

  static TextStyle scoreSmall(Color color) => GoogleFonts.poppins(
        fontSize: 18,
        fontWeight: FontWeight.w600,
        color: color,
      );

  // ── Live badge text ────────────────────────────────────────────────────
  static TextStyle liveBadge(Color color) => GoogleFonts.inter(
        fontSize: 10,
        fontWeight: FontWeight.w800,
        color: color,
        letterSpacing: 1.5,
      );

  // ── Timer / overs ──────────────────────────────────────────────────────
  static TextStyle timer(Color color) => GoogleFonts.poppins(
        fontSize: 22,
        fontWeight: FontWeight.w700,
        color: color,
        letterSpacing: 2,
        fontFeatures: [const FontFeature.tabularFigures()],
      );
}
