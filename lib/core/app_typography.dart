import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'app_colors.dart';

class AppTypography {
  static TextStyle display = GoogleFonts.inter(
    fontSize: 40,
    fontWeight: FontWeight.w900,
    height: 44 / 40,
    letterSpacing: -1.0,
    color: AppColors.sky900,
  );
  static TextStyle h1 = GoogleFonts.inter(
    fontSize: 32,
    fontWeight: FontWeight.w800,
    height: 38 / 32,
    letterSpacing: -0.5,
    color: AppColors.sky900,
  );
  static TextStyle h2 = GoogleFonts.inter(
    fontSize: 24,
    fontWeight: FontWeight.w700,
    height: 30 / 24,
    letterSpacing: -0.3,
    color: AppColors.sky900,
  );
  static TextStyle h3 = GoogleFonts.inter(
    fontSize: 20,
    fontWeight: FontWeight.w700,
    height: 26 / 20,
    letterSpacing: -0.2,
    color: AppColors.sky900,
  );
  static TextStyle bodyLg = GoogleFonts.inter(
    fontSize: 16,
    fontWeight: FontWeight.w500,
    height: 24 / 16,
    color: AppColors.sky900,
  );
  static TextStyle body = GoogleFonts.inter(
    fontSize: 14,
    fontWeight: FontWeight.w400,
    height: 20 / 14,
    color: AppColors.sky900,
  );
  static TextStyle caption = GoogleFonts.inter(
    fontSize: 12,
    fontWeight: FontWeight.w500,
    height: 16 / 12,
    letterSpacing: 0.2,
    color: AppColors.neutral600,
  );
  static TextStyle overline = GoogleFonts.inter(
    fontSize: 11,
    fontWeight: FontWeight.w700,
    height: 14 / 11,
    letterSpacing: 1.2,
    color: AppColors.neutral600,
  );

  static TextStyle numLg = GoogleFonts.jetBrainsMono(
    fontSize: 28,
    fontWeight: FontWeight.w700,
    height: 32 / 28,
    fontFeatures: const [FontFeature.tabularFigures()],
    color: AppColors.sky900,
  );
  static TextStyle numMd = GoogleFonts.jetBrainsMono(
    fontSize: 18,
    fontWeight: FontWeight.w600,
    height: 22 / 18,
    fontFeatures: const [FontFeature.tabularFigures()],
    color: AppColors.sky900,
  );
}
