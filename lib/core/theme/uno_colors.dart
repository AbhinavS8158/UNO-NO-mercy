import 'package:flutter/material.dart';

class UnoColors {
  UnoColors._();

  // Official Show 'em No Mercy physical print colors
  static const Color red = Color(0xFFE51D24);
  static const Color blue = Color(0xFF0D68B3);
  static const Color green = Color(0xFF2E8540);
  static const Color yellow = Color(0xFFFDB800);
  static const Color cardBlack = Color(0xFF0D0D0E);
  
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
