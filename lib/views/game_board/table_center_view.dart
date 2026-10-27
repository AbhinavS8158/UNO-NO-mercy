import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/theme/uno_colors.dart';
import '../../models/uno_card.dart';
import '../widgets/uno_card_widget.dart';

class TableCenterView extends StatelessWidget {
  final UnoCard topCard;
  final CardColor activeColor;
  final int pendingDrawCount;
  final int remainingDeckCards;
  final bool isClockwise;
  final VoidCallback onDrawDeckTapped;

  const TableCenterView({
    super.key,
    required this.topCard,
    required this.activeColor,
    required this.pendingDrawCount,
    required this.remainingDeckCards,
    this.isClockwise = true,
    required this.onDrawDeckTapped,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Stacking / Penalty Indicator Alert
          if (pendingDrawCount > 0)
            Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [UnoColors.drawTenFlame, Colors.deepOrange],
                ),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: UnoColors.drawTenFlame.withOpacity(0.5),
                    blurRadius: 10,
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

          // Central Board (Draw pile + Discard pile + Direction Arrows)
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // 1. Draw Pile
              GestureDetector(
                onTap: onDrawDeckTapped,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    // Fake stack depth
                    Transform.translate(
                      offset: const Offset(4, 4),
                      child: Container(
                        width: 100,
                        height: 145,
                        decoration: BoxDecoration(
                          color: Colors.black45,
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                    ),
                    Transform.translate(
                      offset: const Offset(2, 2),
                      child: Container(
                        width: 100,
                        height: 145,
                        decoration: BoxDecoration(
                          color: Colors.white24,
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                    ),
                    // Main face down deck
                    UnoCardWidget(
                      card: const UnoCard(
                        id: 'deck_top',
                        color: CardColor.wild,
                        type: CardType.number,
                      ),
                      isFaceUp: false,
                      width: 100,
                      height: 145,
                    ),
                    // Deck count badge
                    Positioned(
                      bottom: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.75),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.white30),
                        ),
                        child: Text(
                          '$remainingDeckCards',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(width: 28),

              // 2. Discard Pile
              Stack(
                alignment: Alignment.center,
                children: [
                  // Underlying faded card for physical pile realism
                  Transform.rotate(
                    angle: 0.12,
                    child: Container(
                      width: 100,
                      height: 145,
                      decoration: BoxDecoration(
                        color: Colors.black38,
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                  ),
                  // Current Top Card
                  Transform.rotate(
                    angle: -0.05,
                    child: UnoCardWidget(
                      card: topCard,
                      width: 105,
                      height: 155,
                      isSelected: false,
                    ),
                  ),
                ],
              ),
            ],
          ),

          const SizedBox(height: 14),

          // Active Color / Direction Status
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            decoration: BoxDecoration(
              color: UnoColors.surfaceElevated,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: _getActiveColor(activeColor), width: 2),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 14,
                  height: 14,
                  decoration: BoxDecoration(
                    color: _getActiveColor(activeColor),
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  'CURRENT COLOR: ${_getColorName(activeColor)}',
                  style: GoogleFonts.rubik(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(width: 10),
                Icon(
                  isClockwise ? Icons.rotate_right : Icons.rotate_left,
                  color: Colors.white70,
                  size: 18,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Color _getActiveColor(CardColor color) {
    switch (color) {
      case CardColor.red:
        return UnoColors.red;
      case CardColor.blue:
        return UnoColors.blue;
      case CardColor.green:
        return UnoColors.green;
      case CardColor.yellow:
        return UnoColors.yellow;
      case CardColor.wild:
        return Colors.white;
    }
  }

  String _getColorName(CardColor color) {
    switch (color) {
      case CardColor.red:
        return 'RED';
      case CardColor.blue:
        return 'BLUE';
      case CardColor.green:
        return 'GREEN';
      case CardColor.yellow:
        return 'YELLOW';
      case CardColor.wild:
        return 'WILD';
    }
  }
}
