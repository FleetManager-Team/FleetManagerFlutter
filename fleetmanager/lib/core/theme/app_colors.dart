import 'package:flutter/material.dart';

class AppColors {
  // Primary Brand Colors
  static const Color primary = Color(0xFF1E3A8A); // Dark Blue
  static const Color primaryLight = Color(0xFF3B82F6); // Light Blue
  static const Color primaryDark = Color(0xFF1E40AF); // Darker Blue

  // Secondary Colors
  static const Color secondary = Color(0xFFF59E0B); // Amber/Orange
  static const Color secondaryLight = Color(0xFFFBBF24); // Light Amber
  static const Color secondaryDark = Color(0xFFF8A604); // Dark Amber

  // Status Colors
  static const Color success = Color(0xFF10B981); // Green
  static const Color warning = Color(0xFFF59E0B); // Amber
  static const Color error = Color(0xFFEF4444); // Red
  static const Color info = Color(0xFF3B82F6); // Blue

  // Neutral Colors
  static const Color white = Color(0xFFFFFFFF);
  static const Color black = Color(0xFF000000);
  static const Color grey50 = Color(0xFFF9FAFB);
  static const Color grey100 = Color(0xFFF3F4F6);
  static const Color grey200 = Color(0xFFE5E7EB);
  static const Color grey300 = Color(0xFFD1D5DB);
  static const Color grey400 = Color(0xFF9CA3AF);
  static const Color grey500 = Color(0xFF6B7280);
  static const Color grey600 = Color(0xFF4B5563);
  static const Color grey700 = Color(0xFF374151);
  static const Color grey800 = Color(0xFF1F2937);
  static const Color grey900 = Color(0xFF111827);

  // Background Colors
  static const Color background = grey50;
  static const Color surface = white;
  static const Color surfaceVariant = grey100;

  // Text Colors
  static const Color textPrimary = black;
  static const Color textSecondary = grey700;
  static const Color textTertiary = grey600;
  static const Color textHint = grey500;
  static const Color textOnPrimary = white;
  static const Color textOnSecondary = white;

  // Borders & Dividers
  static const Color border = grey300;
  static const Color divider = grey200;

  // Shadows
  static Color shadowColor = black..withValues(alpha: 0.1);

  // Semantic Colors (mapping to primary/secondary)
  static const Color positive = success;
  static const Color negative = error;
  static const Color neutral = grey500;
  static const Color attention = warning;

  // Transparency variants for overlays
  static Color overlayDark = black..withValues(alpha: 0.05);
  static Color overlayDarker = black..withValues(alpha: 0.1);
  static Color overlayDarkest = black..withValues(alpha: 0.2);

  // Gradient colors
  static const List<Color> primaryGradient = [primary, primaryLight];
  static const List<Color> secondaryGradient = [secondary, secondaryLight];
}
