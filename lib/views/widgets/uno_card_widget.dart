import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/theme/uno_colors.dart';
import '../../models/uno_card.dart';

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
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: isSelected
                  ? UnoColors.cardGlow.withOpacity(0.8)
                  : Colors.black.withOpacity(0.35),
              blurRadius: isSelected ? 16 : 8,
              spreadRadius: isSelected ? 3 : 1,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border.all(
                color: isSelected ? UnoColors.cardGlow : Colors.white,
                width: 3.5,
              ),
              borderRadius: BorderRadius.circular(14),
            ),
            child: isFaceUp ? _buildCardFront() : _buildCardBack(),
          ),
        ),
      ),
    );
  }

  Widget _buildCardBack() {
    return Container(
      decoration: const BoxDecoration(
        color: UnoColors.cardBack,
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Inner oval
          Transform.rotate(
            angle: -0.4,
            child: Container(
              width: width * 0.9,
              height: height * 0.5,
              decoration: BoxDecoration(
                color: UnoColors.red,
                borderRadius: BorderRadius.all(
                  Radius.elliptical(width * 0.9, height * 0.5),
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
          // UNO Text
          Transform.rotate(
            angle: -0.4,
            child: Text(
              'UNO',
              style: GoogleFonts.blackOpsOne(
                fontSize: width * 0.28,
                fontWeight: FontWeight.w900,
                color: UnoColors.yellow,
                shadows: [
                  const Shadow(
                    color: Colors.black,
                    offset: Offset(3, 3),
                    blurRadius: 4,
                  ),
                ],
              ),
            ),
          ),
          // No Mercy subtle text
          Positioned(
            bottom: 6,
            child: Text(
              'NO MERCY',
              style: GoogleFonts.bebasNeue(
                color: Colors.redAccent,
                fontSize: 12,
                letterSpacing: 2.0,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCardFront() {
    final cardColor = _getCardBackgroundColor();

    return Container(
      decoration: BoxDecoration(
        gradient: card.isWild
            ? const SweepGradient(
                colors: UnoColors.wildGradient,
              )
            : null,
        color: card.isWild ? null : cardColor,
      ),
      child: Stack(
        children: [
          // Center Oval
          Center(
            child: Transform.rotate(
              angle: -0.45,
              child: Container(
                width: width * 0.82,
                height: height * 0.52,
                decoration: BoxDecoration(
                  color: card.isWild
                      ? Colors.black.withOpacity(0.85)
                      : Colors.white.withOpacity(0.18),
                  borderRadius: BorderRadius.all(
                    Radius.elliptical(width * 0.82, height * 0.52),
                  ),
                  border: Border.all(
                    color: Colors.white.withOpacity(0.4),
                    width: 2,
                  ),
                ),
              ),
            ),
          ),

          // Main Center Content (Number or Symbol)
          Center(
            child: _buildCenterSymbol(),
          ),

          // Top Left Label
          Positioned(
            top: 6,
            left: 8,
            child: _buildCornerLabel(),
          ),

          // Bottom Right Label (Flipped 180 degrees)
          Positioned(
            bottom: 6,
            right: 8,
            child: Transform.rotate(
              angle: math.pi,
              child: _buildCornerLabel(),
            ),
          ),

          // Special No Mercy badge on bottom center
          if (card.actionName.isNotEmpty)
            Positioned(
              bottom: 4,
              left: 0,
              right: 0,
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.65),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    card.actionName,
                    style: GoogleFonts.rubik(
                      color: Colors.white,
                      fontSize: 8,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildCornerLabel() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          card.displayLabel,
          style: GoogleFonts.montserrat(
            fontSize: width * 0.17,
            fontWeight: FontWeight.w900,
            color: Colors.white,
            shadows: [
              Shadow(
                color: Colors.black.withOpacity(0.7),
                offset: const Offset(1, 1),
                blurRadius: 2,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildCenterSymbol() {
    if (card.type == CardType.number) {
      return Text(
        '${card.numberValue ?? 0}',
        style: GoogleFonts.blackOpsOne(
          fontSize: width * 0.52,
          color: Colors.white,
          shadows: [
            Shadow(
              color: Colors.black.withOpacity(0.55),
              offset: const Offset(3, 3),
              blurRadius: 4,
            ),
          ],
        ),
      );
    }

    // Special icons
    switch (card.type) {
      case CardType.skip:
        return Icon(
          Icons.block,
          size: width * 0.45,
          color: Colors.white,
        );
      case CardType.reverse:
        return Icon(
          Icons.sync,
          size: width * 0.48,
          color: Colors.white,
        );
      case CardType.drawTwo:
      case CardType.drawFour:
      case CardType.drawSix:
      case CardType.drawTen:
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              card.displayLabel,
              style: GoogleFonts.blackOpsOne(
                fontSize: width * 0.38,
                color: Colors.white,
                shadows: [
                  Shadow(
                    color: Colors.black.withOpacity(0.6),
                    offset: const Offset(3, 3),
                    blurRadius: 5,
                  ),
                ],
              ),
            ),
            if (card.type == CardType.drawTen)
              const Icon(
                Icons.local_fire_department,
                color: UnoColors.drawTenFlame,
                size: 26,
              ),
          ],
        );
      case CardType.discardAll:
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.delete_sweep, size: width * 0.35, color: Colors.white),
            Text(
              'DISCARD',
              style: GoogleFonts.rubik(
                fontSize: 10,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ],
        );
      case CardType.skipEveryone:
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.do_not_disturb_on, size: width * 0.35, color: Colors.white),
            Text(
              'ALL SKIP',
              style: GoogleFonts.rubik(
                fontSize: 10,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ],
        );
      case CardType.wildReverseDrawFour:
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.sync, color: Colors.white, size: 28),
            Text(
              '+4',
              style: GoogleFonts.blackOpsOne(
                fontSize: width * 0.35,
                color: Colors.white,
              ),
            ),
          ],
        );
      case CardType.colorRoulette:
      case CardType.roulette:
        return Icon(
          Icons.casino,
          size: width * 0.45,
          color: Colors.white,
        );
      case CardType.pointSevenSwap:
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('7', style: GoogleFonts.blackOpsOne(fontSize: width * 0.35, color: Colors.white)),
            const Icon(Icons.swap_horiz, size: 24, color: Colors.white),
          ],
        );
      case CardType.pointZeroPass:
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('0', style: GoogleFonts.blackOpsOne(fontSize: width * 0.35, color: Colors.white)),
            const Icon(Icons.rotate_right, size: 24, color: Colors.white),
          ],
        );
      default:
        return Text(
          card.displayLabel,
          style: GoogleFonts.blackOpsOne(fontSize: width * 0.4, color: Colors.white),
        );
    }
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
        return Colors.black;
    }
  }
}
