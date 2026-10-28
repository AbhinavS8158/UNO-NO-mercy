import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/theme/uno_colors.dart';
import '../../models/uno_card.dart';

/// Authentic UNO Show 'em No Mercy Card Widget
/// Accurately reproduces physical card styling:
/// - Outer solid black border with distressed vintage scratches
/// - Saturated primary colors (Red, Yellow, Green, Blue)
/// - Signature tilted black-outlined center oval (White oval on Wilds)
/// - High-contrast white typography with heavy black outline & 3D drop shadow
/// - 7's Swap with double arrow `<->` and 0's Pass with circular arrow `🔄`
/// - Faithful Wild card illustrations: Wild Reverse Draw 4, Draw 6, Draw 10, Color Roulette
class UnoCardWidget extends StatelessWidget {
  final UnoCard card;
  final double width;
  final double height;
  final bool isFaceUp;
  final bool isSelected;
  final bool isPlayable;
  final VoidCallback? onTap;

  const UnoCardWidget({
    super.key,
    required this.card,
    this.width = 110,
    this.height = 160,
    this.isFaceUp = true,
    this.isSelected = false,
    this.isPlayable = true,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final borderRadius = BorderRadius.circular(width * 0.11);

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOutCubic,
        transform: Matrix4.identity()
          ..translate(0.0, isSelected ? -20.0 : 0.0),
        width: width,
        height: height,
        decoration: BoxDecoration(
          borderRadius: borderRadius,
          boxShadow: [
            BoxShadow(
              color: isSelected
                  ? UnoColors.cardGlow.withOpacity(0.9)
                  : Colors.black.withOpacity(0.55),
              blurRadius: isSelected ? 18 : 8,
              spreadRadius: isSelected ? 3 : 1,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: borderRadius,
          child: Container(
            decoration: BoxDecoration(
              color: UnoColors.cardBlack,
              border: Border.all(
                color: isSelected ? UnoColors.cardGlow : Colors.black,
                width: isSelected ? 3.0 : 1.5,
              ),
              borderRadius: borderRadius,
            ),
            child: isFaceUp ? _buildCardFront() : _buildCardBack(),
          ),
        ),
      ),
    );
  }

  // ==========================================
  // CARD BACK (Authentic Show 'em No Mercy)
  // ==========================================
  Widget _buildCardBack() {
    return Container(
      color: UnoColors.cardBlack,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Background distressed scratches
          Positioned.fill(
            child: CustomPaint(
              painter: CardGrungePainter(),
            ),
          ),
          // Center Red Tilted Oval
          Transform.rotate(
            angle: -0.49,
            child: Container(
              width: width * 0.84,
              height: height * 0.52,
              decoration: BoxDecoration(
                color: UnoColors.red,
                borderRadius: BorderRadius.all(
                  Radius.elliptical(width * 0.84, height * 0.52),
                ),
                border: Border.all(
                  color: Colors.black,
                  width: math.max(2.5, width * 0.03),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.4),
                    blurRadius: 4,
                  ),
                ],
              ),
            ),
          ),
          // Yellow "UNO" with thick black stroke and shadow
          Transform.rotate(
            angle: -0.49,
            child: _buildOutlinedText(
              'UNO',
              width * 0.36,
              fillColor: UnoColors.yellow,
              strokeWidth: width * 0.045,
            ),
          ),
          // No Mercy subtitle banner
          Positioned(
            bottom: height * 0.08,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.85),
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: Colors.white24, width: 0.8),
              ),
              child: Text(
                'NO MERCY',
                style: GoogleFonts.bebasNeue(
                  color: UnoColors.red,
                  fontSize: width * 0.11,
                  letterSpacing: 2.2,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ==========================================
  // CARD FRONT (Physical Match to Uploaded Photos)
  // ==========================================
  Widget _buildCardFront() {
    final isWildCard = card.isWild;
    final cardColor = _getCardBackgroundColor();
    final innerMargin = width * 0.055;

    return Container(
      color: UnoColors.cardBlack, // Distinctive black outer frame
      padding: EdgeInsets.all(innerMargin),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(width * 0.07),
        child: Container(
          decoration: BoxDecoration(
            color: isWildCard ? UnoColors.cardBlack : cardColor,
          ),
          child: Stack(
            children: [
              // 1. Signature Tilted Center Oval
              Center(
                child: Transform.rotate(
                  angle: -0.49, // Exact ~28 degree tilt of official cards
                  child: Container(
                    width: width * 0.78,
                    height: height * 0.50,
                    decoration: BoxDecoration(
                      color: isWildCard ? Colors.white : cardColor,
                      borderRadius: BorderRadius.all(
                        Radius.elliptical(width * 0.78, height * 0.50),
                      ),
                      border: Border.all(
                        color: Colors.black,
                        width: math.max(2.5, width * 0.032),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.25),
                          blurRadius: 4,
                          offset: const Offset(1, 2),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              // 2. Realistic subtle scratch & scuff grunge texture
              Positioned.fill(
                child: CustomPaint(
                  painter: CardGrungePainter(),
                ),
              ),

              // 3. Center Main Graphic / Number / Illustration
              Center(
                child: _buildCenterContent(),
              ),

              // 4. Top-Left Corner Index
              Positioned(
                top: height * 0.035,
                left: width * 0.045,
                child: _buildCornerIndex(isTopLeft: true),
              ),

              // 5. Bottom-Right Corner Index (Rotated 180 degrees)
              Positioned(
                bottom: height * 0.035,
                right: width * 0.045,
                child: Transform.rotate(
                  angle: math.pi,
                  child: _buildCornerIndex(isTopLeft: false),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ==========================================
  // CORNER INDICES (Top-Left & Bottom-Right)
  // ==========================================
  Widget _buildCornerIndex({required bool isTopLeft}) {
    final numSize = width * 0.19;
    final strokeW = width * 0.024;

    // 7's SWAP Corner: "7" with horizontal double arrow `<->` underneath
    if (card.type == CardType.pointSevenSwap || card.numberValue == 7) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildOutlinedText('7', numSize, strokeWidth: strokeW),
          SizedBox(height: width * 0.01),
          _buildSwapArrowIcon(width * 0.16),
        ],
      );
    }

    // 0's PASS Corner: "0" with circular pass arrow `🔄` underneath
    if (card.type == CardType.pointZeroPass || card.numberValue == 0) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildOutlinedText('0', numSize, strokeWidth: strokeW),
          SizedBox(height: width * 0.01),
          _buildPassArrowIcon(width * 0.12),
        ],
      );
    }

    // Wild Reverse Draw 4 Corner: "+4" with reverse arrows
    if (card.type == CardType.wildReverseDrawFour) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildOutlinedText('+4', numSize * 0.88, strokeWidth: strokeW),
          SizedBox(height: width * 0.01),
          _buildReverseArrowsIcon(width * 0.13),
        ],
      );
    }

    // Wild Draw 6 Corner: "+6"
    if (card.type == CardType.drawSix) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildOutlinedText('+6', numSize * 0.92, strokeWidth: strokeW),
        ],
      );
    }

    // Wild Draw 10 Corner: "+10"
    if (card.type == CardType.drawTen) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildOutlinedText('+10', numSize * 0.82, strokeWidth: strokeW),
        ],
      );
    }

    // Wild Color Roulette Corner: Sad face mini card
    if (card.type == CardType.colorRoulette || card.type == CardType.roulette) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildMiniSadFaceCard(width * 0.14),
        ],
      );
    }

    // Standard Draw 2 / Draw 4
    if (card.type == CardType.drawTwo || card.type == CardType.drawFour) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildOutlinedText(card.displayLabel, numSize * 0.88, strokeWidth: strokeW),
        ],
      );
    }

    // Skip Corner
    if (card.type == CardType.skip) {
      return _buildSkipIcon(width * 0.16);
    }

    // Skip Everyone Corner
    if (card.type == CardType.skipEveryone) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildSkipIcon(width * 0.12),
          _buildSkipIcon(width * 0.12),
        ],
      );
    }

    // Reverse Corner
    if (card.type == CardType.reverse) {
      return _buildReverseArrowsIcon(width * 0.16);
    }

    // Discard All Corner
    if (card.type == CardType.discardAll) {
      return _buildMiniDiscardFan(width * 0.16);
    }

    // Standard Number (1 - 9)
    final val = card.numberValue ?? 1;
    final isSixOrNine = (val == 6 || val == 9);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _buildOutlinedText('$val', numSize, strokeWidth: strokeW),
        if (isSixOrNine)
          Container(
            margin: const EdgeInsets.only(top: 1),
            width: width * 0.09,
            height: 2,
            color: Colors.white,
          ),
      ],
    );
  }

  // ==========================================
  // CENTER CONTENT (Symbol / Illustration)
  // ==========================================
  Widget _buildCenterContent() {
    final bigNumSize = width * 0.58;
    final bigStroke = width * 0.052;

    // 7's SWAP Center: Huge, bold "7" exactly like Image 1 top row
    if (card.type == CardType.pointSevenSwap || card.numberValue == 7) {
      return _buildOutlinedText(
        '7',
        bigNumSize,
        strokeWidth: bigStroke,
      );
    }

    // 0's PASS Center: Tall, bold "0" exactly like Image 1 bottom row
    if (card.type == CardType.pointZeroPass || card.numberValue == 0) {
      return _buildOutlinedText(
        '0',
        bigNumSize * 1.05,
        strokeWidth: bigStroke,
      );
    }

    // Wild Reverse Draw 4 (Image 2 Top-Left)
    if (card.type == CardType.wildReverseDrawFour) {
      return _buildWildReverseDrawFourGraphic();
    }

    // Wild Draw 6 (Image 2 Top-Right)
    if (card.type == CardType.drawSix && card.isWild) {
      return _buildWildDrawGraphic(count: 6);
    }

    // Wild Draw 10 (Image 2 Bottom-Left)
    if (card.type == CardType.drawTen) {
      return _buildWildDrawGraphic(count: 10);
    }

    // Wild Color Roulette (Image 2 Bottom-Right)
    if (card.type == CardType.colorRoulette || card.type == CardType.roulette) {
      return _buildWildRouletteGraphic();
    }

    // Colored Draw 2, Draw 4, Draw 6
    if (card.isDrawPenalty) {
      return _buildOutlinedText(
        '+${card.penaltyCount}',
        bigNumSize * 0.75,
        strokeWidth: bigStroke,
      );
    }

    // Skip
    if (card.type == CardType.skip) {
      return _buildSkipIcon(width * 0.46, strokeWidth: width * 0.05);
    }

    // Skip Everyone
    if (card.type == CardType.skipEveryone) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildSkipIcon(width * 0.28, strokeWidth: width * 0.035),
          Transform.translate(
            offset: Offset(-width * 0.08, 0),
            child: _buildSkipIcon(width * 0.28, strokeWidth: width * 0.035),
          ),
        ],
      );
    }

    // Reverse
    if (card.type == CardType.reverse) {
      return _buildReverseArrowsIcon(width * 0.44, isBig: true);
    }

    // Discard All
    if (card.type == CardType.discardAll) {
      return _buildDiscardAllGraphic();
    }

    // Standard Number (1 - 9)
    final val = card.numberValue ?? 1;
    final isSixOrNine = (val == 6 || val == 9);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _buildOutlinedText('$val', bigNumSize, strokeWidth: bigStroke),
        if (isSixOrNine)
          Container(
            margin: const EdgeInsets.only(top: 2),
            width: width * 0.24,
            height: width * 0.035,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(2),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.5),
                  offset: const Offset(1, 1),
                ),
              ],
            ),
          ),
      ],
    );
  }

  // ==========================================
  // GRAPHIC BUILDERS (Authentic Match to Image 2)
  // ==========================================

  /// Wild Reverse Draw 4 (Image 2 Top-Left):
  /// 4 overlapping colored cards with thick white reverse arrows in the center
  Widget _buildWildReverseDrawFourGraphic() {
    final cardW = width * 0.22;
    final cardH = width * 0.32;

    return SizedBox(
      width: width * 0.62,
      height: width * 0.62,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Yellow Card (Top-Right)
          Positioned(
            top: 2,
            right: width * 0.08,
            child: _buildMiniColoredCard(UnoColors.yellow, cardW, cardH, 0.1),
          ),
          // Blue Card (Top-Left)
          Positioned(
            top: 8,
            left: width * 0.08,
            child: _buildMiniColoredCard(UnoColors.blue, cardW, cardH, -0.15),
          ),
          // Red Card (Bottom-Right)
          Positioned(
            bottom: 4,
            right: width * 0.12,
            child: _buildMiniColoredCard(UnoColors.red, cardW, cardH, 0.05),
          ),
          // Green Card (Bottom-Left)
          Positioned(
            bottom: 2,
            left: width * 0.05,
            child: _buildMiniColoredCard(UnoColors.green, cardW, cardH, -0.08),
          ),
          // Two thick reverse arrows in the center
          Center(
            child: _buildReverseArrowsIcon(width * 0.34, isBig: true),
          ),
        ],
      ),
    );
  }

  /// Wild Draw 6 & Wild Draw 10 (Image 2 Top-Right & Bottom-Left):
  /// Stack of colorful overlapping cards
  Widget _buildWildDrawGraphic({required int count}) {
    final colors = [
      UnoColors.red,
      UnoColors.blue,
      UnoColors.green,
      UnoColors.yellow,
      UnoColors.red,
      UnoColors.blue,
      UnoColors.green,
      UnoColors.yellow,
      UnoColors.red,
      UnoColors.yellow,
    ];

    final displayCount = math.min(count, colors.length);
    final cardW = width * 0.18;
    final cardH = width * 0.26;

    return SizedBox(
      width: width * 0.62,
      height: width * 0.62,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Overlapping cascade of mini cards
          for (int i = 0; i < displayCount; i++)
            Transform.translate(
              offset: Offset(
                (i - displayCount / 2.0) * (width * 0.04),
                ((i % 3) - 1.0) * (width * 0.05),
              ),
              child: Transform.rotate(
                angle: (i - displayCount / 2.0) * 0.12,
                child: _buildMiniColoredCard(colors[i], cardW, cardH, 0.0),
              ),
            ),
          // Center Badge with +6 or +10
          Center(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.85),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: Colors.white, width: 1.5),
              ),
              child: _buildOutlinedText(
                '+$count',
                width * 0.28,
                strokeWidth: width * 0.03,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Wild Color Roulette (Image 2 Bottom-Right):
  /// 4 colorful cards with sad/frowning expressions 🙁
  Widget _buildWildRouletteGraphic() {
    final cardW = width * 0.20;
    final cardH = width * 0.28;

    return SizedBox(
      width: width * 0.62,
      height: width * 0.62,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Positioned(
            top: width * 0.04,
            left: width * 0.18,
            child: _buildMiniSadCard(UnoColors.yellow, cardW, cardH, -0.1),
          ),
          Positioned(
            top: width * 0.12,
            right: width * 0.08,
            child: _buildMiniSadCard(UnoColors.blue, cardW, cardH, 0.15),
          ),
          Positioned(
            bottom: width * 0.10,
            left: width * 0.08,
            child: _buildMiniSadCard(UnoColors.red, cardW, cardH, -0.05),
          ),
          Positioned(
            bottom: width * 0.04,
            right: width * 0.16,
            child: _buildMiniSadCard(UnoColors.green, cardW, cardH, 0.08),
          ),
        ],
      ),
    );
  }

  /// Discard All: 4 fanned cards in discard motion
  Widget _buildDiscardAllGraphic() {
    final cardW = width * 0.20;
    final cardH = width * 0.28;

    return SizedBox(
      width: width * 0.62,
      height: width * 0.62,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Transform.translate(
            offset: Offset(-width * 0.14, width * 0.05),
            child: Transform.rotate(
              angle: -0.3,
              child: _buildMiniColoredCard(UnoColors.yellow, cardW, cardH, 0),
            ),
          ),
          Transform.translate(
            offset: Offset(-width * 0.05, 0),
            child: Transform.rotate(
              angle: -0.1,
              child: _buildMiniColoredCard(UnoColors.red, cardW, cardH, 0),
            ),
          ),
          Transform.translate(
            offset: Offset(width * 0.05, -width * 0.04),
            child: Transform.rotate(
              angle: 0.15,
              child: _buildMiniColoredCard(UnoColors.blue, cardW, cardH, 0),
            ),
          ),
          Transform.translate(
            offset: Offset(width * 0.14, width * 0.02),
            child: Transform.rotate(
              angle: 0.35,
              child: _buildMiniColoredCard(UnoColors.green, cardW, cardH, 0),
            ),
          ),
        ],
      ),
    );
  }

  // ==========================================
  // MINI GRAPHIC HELPERS
  // ==========================================

  Widget _buildMiniColoredCard(Color color, double w, double h, double angle) {
    return Transform.rotate(
      angle: angle,
      child: Container(
        width: w,
        height: h,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(3),
          border: Border.all(color: Colors.black, width: 1.5),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.4),
              blurRadius: 3,
              offset: const Offset(1, 1),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMiniSadCard(Color color, double w, double h, double angle) {
    return Transform.rotate(
      angle: angle,
      child: Container(
        width: w,
        height: h,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: Colors.black, width: 1.5),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.4),
              blurRadius: 3,
              offset: const Offset(1, 1),
            ),
          ],
        ),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Eyes
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(width: 2.5, height: 2.5, color: Colors.black),
                  const SizedBox(width: 3),
                  Container(width: 2.5, height: 2.5, color: Colors.black),
                ],
              ),
              const SizedBox(height: 2),
              // Frown Mouth
              CustomPaint(
                size: const Size(8, 4),
                painter: FrownMouthPainter(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMiniSadFaceCard(double size) {
    return Container(
      width: size,
      height: size * 1.3,
      decoration: BoxDecoration(
        color: UnoColors.yellow,
        borderRadius: BorderRadius.circular(2),
        border: Border.all(color: Colors.black, width: 1.0),
      ),
      child: const Center(
        child: Icon(Icons.sentiment_dissatisfied, size: 9, color: Colors.black),
      ),
    );
  }

  Widget _buildMiniDiscardFan(double size) {
    return Icon(Icons.layers, size: size, color: Colors.white);
  }

  /// 7's Swap Horizontal Double-Arrow `<->`
  Widget _buildSwapArrowIcon(double size) {
    return SizedBox(
      width: size,
      height: size * 0.45,
      child: CustomPaint(
        painter: SwapArrowPainter(),
      ),
    );
  }

  /// 0's Pass Circular Arrow `🔄`
  Widget _buildPassArrowIcon(double size) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: PassCircleArrowPainter(),
      ),
    );
  }

  /// Reverse Opposing Curved Arrows
  Widget _buildReverseArrowsIcon(double size, {bool isBig = false}) {
    return SizedBox(
      width: size,
      height: size * 0.9,
      child: CustomPaint(
        painter: ReverseArrowsPainter(isBig: isBig),
      ),
    );
  }

  /// Skip `⊘` Symbol
  Widget _buildSkipIcon(double size, {double strokeWidth = 2.0}) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: SkipIconPainter(strokeWidth: strokeWidth),
      ),
    );
  }

  // ==========================================
  // TYPOGRAPHY HELPER (Solid White + Heavy Black Stroke + Shadow)
  // ==========================================
  Widget _buildOutlinedText(
    String text,
    double fontSize, {
    Color fillColor = Colors.white,
    double strokeWidth = 4.0,
  }) {
    return Stack(
      alignment: Alignment.center,
      children: [
        // Drop Shadow
        Text(
          text,
          style: TextStyle(
            fontFamily: GoogleFonts.rubik().fontFamily,
            fontSize: fontSize,
            fontWeight: FontWeight.w900,
            color: Colors.transparent,
            shadows: [
              Shadow(
                color: Colors.black.withOpacity(0.85),
                offset: Offset(strokeWidth * 0.35, strokeWidth * 0.45),
                blurRadius: 2.0,
              ),
            ],
          ),
        ),
        // Heavy Black Outline (Stroke)
        Text(
          text,
          style: TextStyle(
            fontFamily: GoogleFonts.rubik().fontFamily,
            fontSize: fontSize,
            fontWeight: FontWeight.w900,
            foreground: Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = strokeWidth
              ..strokeJoin = StrokeJoin.round
              ..strokeCap = StrokeCap.round
              ..color = Colors.black,
          ),
        ),
        // Solid Crisp Fill
        Text(
          text,
          style: TextStyle(
            fontFamily: GoogleFonts.rubik().fontFamily,
            fontSize: fontSize,
            fontWeight: FontWeight.w900,
            color: fillColor,
          ),
        ),
      ],
    );
  }

  Color _getCardBackgroundColor() {
    switch (card.color) {
      case CardColor.red:
        return UnoColors.red;
      case CardColor.blue:
        return UnoColors.blue;
      case CardColor.green:
        return UnoColors.green;
      case CardColor.yellow:
        return UnoColors.yellow;
      case CardColor.wild:
        return UnoColors.cardBlack;
    }
  }
}

// ============================================================================
// CUSTOM PAINTERS (Distress Scratches, Swap Arrow, Pass Arrow, Reverse, Skip)
// ============================================================================

/// Authentic battle-worn scratches & scuffs on card surface
class CardGrungePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withOpacity(0.12)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.8
      ..strokeCap = StrokeCap.round;

    // A few deterministic vintage scuffs matching the physical photo
    canvas.drawLine(
      Offset(size.width * 0.12, size.height * 0.08),
      Offset(size.width * 0.18, size.height * 0.14),
      paint,
    );
    canvas.drawLine(
      Offset(size.width * 0.82, size.height * 0.12),
      Offset(size.width * 0.76, size.height * 0.18),
      paint,
    );
    canvas.drawLine(
      Offset(size.width * 0.15, size.height * 0.84),
      Offset(size.width * 0.22, size.height * 0.89),
      paint,
    );
    canvas.drawLine(
      Offset(size.width * 0.80, size.height * 0.80),
      Offset(size.width * 0.86, size.height * 0.85),
      paint,
    );

    // Fine edge scuffs
    final dotPaint = Paint()
      ..color = Colors.white.withOpacity(0.09)
      ..style = PaintingStyle.fill;

    canvas.drawCircle(Offset(size.width * 0.25, size.height * 0.20), 0.8, dotPaint);
    canvas.drawCircle(Offset(size.width * 0.72, size.height * 0.65), 1.0, dotPaint);
    canvas.drawCircle(Offset(size.width * 0.35, size.height * 0.78), 0.7, dotPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// 7's Swap Horizontal Double-Ended Arrow `<->`
class SwapArrowPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final strokePaint = Paint()
      ..color = Colors.black
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.2
      ..strokeCap = StrokeCap.round;

    final fillPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2
      ..strokeCap = StrokeCap.round;

    void draw(Paint p) {
      final y = size.height * 0.5;
      // Main horizontal bar
      canvas.drawLine(Offset(2, y), Offset(size.width - 2, y), p);
      // Left arrow head `<`
      canvas.drawLine(Offset(size.width * 0.28, y - size.height * 0.38), Offset(2, y), p);
      canvas.drawLine(Offset(size.width * 0.28, y + size.height * 0.38), Offset(2, y), p);
      // Right arrow head `>`
      canvas.drawLine(Offset(size.width - size.width * 0.28, y - size.height * 0.38), Offset(size.width - 2, y), p);
      canvas.drawLine(Offset(size.width - size.width * 0.28, y + size.height * 0.38), Offset(size.width - 2, y), p);
    }

    draw(strokePaint);
    draw(fillPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// 0's Pass Circular Arrow `🔄`
class PassCircleArrowPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final strokePaint = Paint()
      ..color = Colors.black
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.2
      ..strokeCap = StrokeCap.round;

    final fillPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2
      ..strokeCap = StrokeCap.round;

    void draw(Paint p) {
      final rect = Rect.fromLTWH(2, 2, size.width - 4, size.height - 4);
      // 280 degree arc
      canvas.drawArc(rect, -math.pi * 0.7, math.pi * 1.5, false, p);
      // Arrow head at arc end
      final arrowTip = Offset(size.width * 0.85, size.height * 0.2);
      canvas.drawLine(arrowTip, Offset(arrowTip.dx - 4, arrowTip.dy - 3), p);
      canvas.drawLine(arrowTip, Offset(arrowTip.dx + 1, arrowTip.dy - 4), p);
    }

    draw(strokePaint);
    draw(fillPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Reverse Two Thick Curved Opposing Arrows
class ReverseArrowsPainter extends CustomPainter {
  final bool isBig;
  ReverseArrowsPainter({this.isBig = false});

  @override
  void paint(Canvas canvas, Size size) {
    final strokeW = isBig ? 4.0 : 2.4;
    final strokePaint = Paint()
      ..color = Colors.black
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeW + 2.0
      ..strokeCap = StrokeCap.round;

    final fillPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeW
      ..strokeCap = StrokeCap.round;

    void drawArrow(Paint p, bool topArrow) {
      final path = Path();
      if (topArrow) {
        // Top right-to-left curved arrow
        path.moveTo(size.width * 0.85, size.height * 0.40);
        path.quadraticBezierTo(
          size.width * 0.5,
          size.height * 0.05,
          size.width * 0.15,
          size.height * 0.35,
        );
        canvas.drawPath(path, p);
        // Arrow head on left
        final headPath = Path()
          ..moveTo(size.width * 0.30, size.height * 0.15)
          ..lineTo(size.width * 0.12, size.height * 0.35)
          ..lineTo(size.width * 0.30, size.height * 0.45);
        canvas.drawPath(headPath, p);
      } else {
        // Bottom left-to-right curved arrow
        path.moveTo(size.width * 0.15, size.height * 0.60);
        path.quadraticBezierTo(
          size.width * 0.5,
          size.height * 0.95,
          size.width * 0.85,
          size.height * 0.65,
        );
        canvas.drawPath(path, p);
        // Arrow head on right
        final headPath = Path()
          ..moveTo(size.width * 0.70, size.height * 0.85)
          ..lineTo(size.width * 0.88, size.height * 0.65)
          ..lineTo(size.width * 0.70, size.height * 0.55);
        canvas.drawPath(headPath, p);
      }
    }

    drawArrow(strokePaint, true);
    drawArrow(strokePaint, false);
    drawArrow(fillPaint, true);
    drawArrow(fillPaint, false);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Skip `⊘` (Circle with 45-degree diagonal slash)
class SkipIconPainter extends CustomPainter {
  final double strokeWidth;
  SkipIconPainter({this.strokeWidth = 2.0});

  @override
  void paint(Canvas canvas, Size size) {
    final strokePaint = Paint()
      ..color = Colors.black
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth + 2.0;

    final fillPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth;

    void draw(Paint p) {
      final center = Offset(size.width / 2, size.height / 2);
      final radius = size.width * 0.42;
      canvas.drawCircle(center, radius, p);
      // 45 degree slash
      final offset = radius * 0.7071;
      canvas.drawLine(
        Offset(center.dx - offset, center.dy + offset),
        Offset(center.dx + offset, center.dy - offset),
        p,
      );
    }

    draw(strokePaint);
    draw(fillPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Frown Mouth for Wild Roulette Cards
class FrownMouthPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.black
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2
      ..strokeCap = StrokeCap.round;

    final path = Path()
      ..moveTo(0, size.height)
      ..quadraticBezierTo(size.width / 2, 0, size.width, size.height);
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
