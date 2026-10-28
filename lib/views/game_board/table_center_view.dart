import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/theme/uno_colors.dart';
import '../../models/uno_card.dart';
import '../widgets/uno_card_widget.dart';

/// Ultra-Rich Table Center View matching the Open-Mercy / No Mercy UI
/// - Cyan tactical HUD brackets framing the Draw Pile
/// - Hazard-striped tactical Draw Deck with "TAP TO DRAW" prompt
/// - Discard Pile enveloped in active color's ambient neon aura glow
/// - Sleek center HUD capsule bar: Direction, Color Orb, Penalty Counter, 25-Card Knockout Progress
class TableCenterView extends StatelessWidget {
  final UnoCard topCard;
  final CardColor activeColor;
  final int pendingDrawCount;
  final int remainingDeckCards;
  final bool isClockwise;
  final int playerCardCount;
  final VoidCallback onDrawDeckTapped;

  const TableCenterView({
    super.key,
    required this.topCard,
    required this.activeColor,
    required this.pendingDrawCount,
    required this.remainingDeckCards,
    this.isClockwise = true,
    this.playerCardCount = 7,
    required this.onDrawDeckTapped,
  });

  @override
  Widget build(BuildContext context) {
    final glowColor = _getActiveGlowColor(activeColor);

    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 1. Stacked Penalty Banner (if penalties are actively accumulating)
          if (pendingDrawCount > 0)
            Container(
              margin: const EdgeInsets.only(bottom: 14),
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 6),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFFFF1744), Color(0xFFFF5252)],
                ),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.redAccent.withOpacity(0.6),
                    blurRadius: 16,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.warning_amber_rounded, color: Colors.white, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    '+$pendingDrawCount STACKED PENALTY!',
                    style: GoogleFonts.bebasNeue(
                      color: Colors.white,
                      fontSize: 18,
                      letterSpacing: 1.2,
                    ),
                  ),
                ],
              ),
            ),

          // 2. Central Table Cards: Draw Deck (HUD bracketed) + Discard Top Card (Neon Glow)
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // ==========================================
              // DRAW PILE (Framed with Cyan HUD brackets)
              // ==========================================
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: onDrawDeckTapped,
                child: MouseRegion(
                  cursor: SystemMouseCursors.click,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // HUD Brackets wrapping the deck
                      CustomPaint(
                        painter: HudBracketsPainter(
                          color: const Color(0xFF00E5FF),
                          bracketLength: 16,
                          strokeWidth: 2.2,
                        ),
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              // Depth stack layers
                              Transform.translate(
                                offset: const Offset(4, 4),
                                child: Container(
                                  width: 96,
                                  height: 142,
                                  decoration: BoxDecoration(
                                    color: Colors.black.withOpacity(0.6),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                              ),
                              Transform.translate(
                                offset: const Offset(2, 2),
                                child: Container(
                                  width: 96,
                                  height: 142,
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF1B1B22),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                              ),
                              // Tactical Hazard Deck Card
                              _buildTacticalDrawCard(),

                              // Remaining card count badge (e.g. 153)
                              Positioned(
                                bottom: 6,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: Colors.black.withOpacity(0.85),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(color: Colors.white24, width: 1.0),
                                  ),
                                  child: Text(
                                    '$remainingDeckCards',
                                    style: GoogleFonts.rubik(
                                      color: Colors.white,
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 6),
                      // "TAP TO DRAW" Cyan Glowing Text
                      Text(
                        pendingDrawCount > 0 ? '+$pendingDrawCount PENALTY' : 'TAP TO DRAW',
                        style: GoogleFonts.rubik(
                          color: pendingDrawCount > 0 ? Colors.redAccent : const Color(0xFF00E5FF),
                          fontSize: 11,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1.4,
                          shadows: [
                            Shadow(
                              color: (pendingDrawCount > 0 ? Colors.redAccent : const Color(0xFF00E5FF)).withOpacity(0.8),
                              blurRadius: 8,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(width: 32),

              // ==========================================
              // DISCARD PILE (Surrounded by Active Color Aura Glow)
              // ==========================================
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: glowColor.withOpacity(0.55),
                          blurRadius: 28,
                          spreadRadius: 3,
                        ),
                      ],
                    ),
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        // Depth pile card underneath
                        Transform.rotate(
                          angle: 0.12,
                          child: Container(
                            width: 100,
                            height: 148,
                            decoration: BoxDecoration(
                              color: Colors.black.withOpacity(0.4),
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                        // Current Top Card (Authentic No Mercy Design)
                        Transform.rotate(
                          angle: -0.04,
                          child: UnoCardWidget(
                            card: topCard,
                            width: 102,
                            height: 152,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 6),
                  // Active Color Name subtitle
                  Text(
                    activeColor.name.toUpperCase(),
                    style: GoogleFonts.rubik(
                      color: glowColor,
                      fontSize: 11,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.8,
                      shadows: [
                        Shadow(color: glowColor.withOpacity(0.8), blurRadius: 8),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),

          const SizedBox(height: 24),

          // 3. Center HUD Capsule Bar (Direction, Orb, Penalty, 25-Card Progress)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFF141318),
              borderRadius: BorderRadius.circular(30),
              border: Border.all(color: Colors.white12, width: 1.2),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.5),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Direction: 🔄 CCW / CW
                Row(
                  children: [
                    Icon(
                      isClockwise ? Icons.rotate_right_rounded : Icons.rotate_left_rounded,
                      size: 17,
                      color: Colors.white70,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      isClockwise ? 'CW' : 'CCW',
                      style: GoogleFonts.rubik(
                        color: Colors.white70,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),

                const SizedBox(width: 14),
                Container(width: 1, height: 16, color: Colors.white12),
                const SizedBox(width: 14),

                // Active Color Orb (Glowing)
                Container(
                  width: 13,
                  height: 13,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: glowColor,
                    boxShadow: [
                      BoxShadow(
                        color: glowColor.withOpacity(0.9),
                        blurRadius: 8,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                ),

                const SizedBox(width: 14),
                Container(width: 1, height: 16, color: Colors.white12),
                const SizedBox(width: 14),

                // Pending Draw Penalty (+ 0 or + 4)
                Text(
                  '+ $pendingDrawCount',
                  style: GoogleFonts.rubik(
                    color: pendingDrawCount > 0 ? Colors.redAccent : Colors.white60,
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                  ),
                ),

                const SizedBox(width: 14),
                Container(width: 1, height: 16, color: Colors.white12),
                const SizedBox(width: 14),

                // Mercy Rule Progress Bar (e.g. 7/25)
                Row(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: SizedBox(
                        width: 44,
                        height: 6,
                        child: LinearProgressIndicator(
                          value: (playerCardCount / 25.0).clamp(0.0, 1.0),
                          backgroundColor: Colors.white12,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            playerCardCount >= 20
                                ? Colors.redAccent
                                : (playerCardCount >= 12 ? Colors.amber : Colors.greenAccent),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '$playerCardCount/25',
                      style: GoogleFonts.rubik(
                        color: playerCardCount >= 20 ? Colors.redAccent : Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Tactical Hazard Deck Card with yellow/black stripes and circular logo
  Widget _buildTacticalDrawCard() {
    return Container(
      width: 96,
      height: 142,
      decoration: BoxDecoration(
        color: const Color(0xFF16161B),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white24, width: 1.2),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(11),
        child: Stack(
          alignment: Alignment.center,
          children: [
            // Top Hazard Stripes
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              height: 12,
              child: CustomPaint(painter: HazardStripesPainter()),
            ),
            // Bottom Hazard Stripes
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              height: 12,
              child: CustomPaint(painter: HazardStripesPainter()),
            ),
            // Center Circular Emblem
            Container(
              width: 54,
              height: 54,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.black,
                border: Border.all(color: Colors.redAccent.withOpacity(0.8), width: 2),
                boxShadow: [
                  BoxShadow(
                    color: Colors.redAccent.withOpacity(0.3),
                    blurRadius: 8,
                  ),
                ],
              ),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'OPEN',
                      style: GoogleFonts.bebasNeue(
                        color: Colors.white,
                        fontSize: 10,
                        letterSpacing: 1.2,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      'MERCY',
                      style: GoogleFonts.bebasNeue(
                        color: Colors.redAccent,
                        fontSize: 11,
                        letterSpacing: 1.2,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color _getActiveGlowColor(CardColor color) {
    switch (color) {
      case CardColor.red:
        return const Color(0xFFFF1744);
      case CardColor.blue:
        return const Color(0xFF00B0FF);
      case CardColor.green:
        return const Color(0xFF00E676);
      case CardColor.yellow:
        return const Color(0xFFFFEA00);
      case CardColor.wild:
        return const Color(0xFFE040FB);
    }
  }
}

// ============================================================================
// PAINTERS (HUD Brackets & Hazard Warning Stripes)
// ============================================================================

/// Futuristic HUD Corner Brackets (`┌ ┐ └ ┘`)
class HudBracketsPainter extends CustomPainter {
  final Color color;
  final double bracketLength;
  final double strokeWidth;

  HudBracketsPainter({
    required this.color,
    required this.bracketLength,
    required this.strokeWidth,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.square;

    // Top-Left ┌
    canvas.drawLine(const Offset(0, 0), Offset(bracketLength, 0), paint);
    canvas.drawLine(const Offset(0, 0), Offset(0, bracketLength), paint);

    // Top-Right ┐
    canvas.drawLine(Offset(size.width, 0), Offset(size.width - bracketLength, 0), paint);
    canvas.drawLine(Offset(size.width, 0), Offset(size.width, bracketLength), paint);

    // Bottom-Left └
    canvas.drawLine(Offset(0, size.height), Offset(bracketLength, size.height), paint);
    canvas.drawLine(Offset(0, size.height), Offset(0, size.height - bracketLength), paint);

    // Bottom-Right ┘
    canvas.drawLine(Offset(size.width, size.height), Offset(size.width - bracketLength, size.height), paint);
    canvas.drawLine(Offset(size.width, size.height), Offset(size.width, size.height - bracketLength), paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Hazard Warning Stripes (Diagonal yellow & black stripes)
class HazardStripesPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final yellowPaint = Paint()..color = const Color(0xFFFFD600);
    final blackPaint = Paint()..color = const Color(0xFF1E1E1E);

    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), blackPaint);

    final stripeW = 8.0;
    for (double x = -size.height; x < size.width + size.height; x += stripeW * 2) {
      final path = Path()
        ..moveTo(x, size.height)
        ..lineTo(x + stripeW, size.height)
        ..lineTo(x + stripeW + size.height, 0)
        ..lineTo(x + size.height, 0)
        ..close();
      canvas.drawPath(path, yellowPaint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
