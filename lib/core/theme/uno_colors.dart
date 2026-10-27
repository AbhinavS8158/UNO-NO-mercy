import 'package:flutter/material.dart';

class UnoColors {
  UnoColors._();

  // Classic & No Mercy vibrant colors
  static const Color red = Color(0xFFF22424);
  static const Color blue = Color(0xFF1E88E5);
  static const Color green = Color(0xFF00C853);
  static const Color yellow = Color(0xFFFFD600);
  
  // No Mercy dark theme backgrounds
  static const Color background = Color(0xFF121216);
  static const Color surface = Color(0xFF1E1E26);
  static const Color surfaceElevated = Color(0xFF2A2A36);
  
  // Special action badge colors
  static const Color drawTenFlame = Color(0xFFFF3D00);
  static const Color discardAllPurple = Color(0xFF9C27B0);
  static const Color rouletteCyan = Color(0xFF00E5FF);

  // Card Borders and Highlights
  static const Color cardBorder = Colors.white;
  static const Color cardGlow = Color(0xFFFFF176);
  static const Color cardBack = Color(0xFF1A1A1E);

  // Multi-color gradient for Wild cards
  static const List<Color> wildGradient = [
    Color(0xFFF22424),
    Color(0xFF1E88E5),
    Color(0xFF00C853),
    Color(0xFFFFD600),
  ];
}
