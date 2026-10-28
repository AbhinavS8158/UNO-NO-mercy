enum CardColor { red, blue, green, yellow, wild }

enum CardType {
  number,
  skip,
  reverse,
  skipEveryone,
  drawTwo,
  drawFour,
  drawSix,
  drawTen,
  wildReverseDrawFour,
  roulette,
  colorRoulette,
  discardAll,
  pointSevenSwap,
  pointZeroPass,
}

class UnoCard {
  final String id;
  final CardColor color;
  final CardType type;
  final int? numberValue; // 0 to 9

  const UnoCard({
    required this.id,
    required this.color,
    required this.type,
    this.numberValue,
  });

  bool get isWild =>
      color == CardColor.wild ||
      type == CardType.drawSix ||
      type == CardType.drawTen ||
      type == CardType.wildReverseDrawFour ||
      type == CardType.colorRoulette ||
      type == CardType.roulette;

  bool get isDrawPenalty =>
      type == CardType.drawTwo ||
      type == CardType.drawFour ||
      type == CardType.drawSix ||
      type == CardType.drawTen ||
      type == CardType.wildReverseDrawFour;

  int get penaltyCount {
    switch (type) {
      case CardType.drawTwo:
        return 2;
      case CardType.drawFour:
      case CardType.wildReverseDrawFour:
        return 4;
      case CardType.drawSix:
        return 6;
      case CardType.drawTen:
        return 10;
      default:
        return 0;
    }
  }

  String get displayLabel {
    if (type == CardType.number) {
      return '${numberValue ?? 0}';
    }
    switch (type) {
      case CardType.skip:
        return '⊘';
      case CardType.reverse:
        return '⇄';
      case CardType.skipEveryone:
        return 'ALL ⊘';
      case CardType.drawTwo:
        return '+2';
      case CardType.drawFour:
        return '+4';
      case CardType.drawSix:
        return '+6';
      case CardType.drawTen:
        return '+10';
      case CardType.wildReverseDrawFour:
        return '⇄ +4';
      case CardType.colorRoulette:
      case CardType.roulette:
        return '🎰';
      case CardType.discardAll:
        return 'ALL';
      case CardType.pointSevenSwap:
        return '7 ⇄';
      case CardType.pointZeroPass:
        return '0 ↻';
      default:
        return '';
    }
  }

  String get actionName {
    switch (type) {
      case CardType.skip:
        return 'SKIP';
      case CardType.reverse:
        return 'REVERSE';
      case CardType.skipEveryone:
        return 'ALL SKIP';
      case CardType.drawTwo:
        return 'DRAW 2';
      case CardType.drawFour:
        return 'DRAW 4';
      case CardType.drawSix:
        return 'WILD +6';
      case CardType.drawTen:
        return 'WILD +10';
      case CardType.wildReverseDrawFour:
        return 'REV DRAW 4';
      case CardType.colorRoulette:
      case CardType.roulette:
        return 'ROULETTE';
      case CardType.discardAll:
        return 'DISCARD ALL';
      case CardType.pointSevenSwap:
        return '7 SWAP';
      case CardType.pointZeroPass:
        return '0 PASS';
      default:
        return '';
    }
  }

  bool canPlayOn(UnoCard topCard, {int pendingDrawCount = 0, CardColor? activeColor}) {
    // 1. Official Stacking Rule:
    // When a player receives a draw penalty (pendingDrawCount > 0), only equal or higher-value
    // draw cards can be stacked (+2 on +2; +4/+6/+10 on +4; +6/+10 on +6; +10 on +10).
    // Lower-value draw cards (+2 on +4; +2/+4 on +6; +2/+4/+6 on +10) and ALL non-draw cards CANNOT be played.
    if (pendingDrawCount > 0) {
      if (!isDrawPenalty) return false;
      return penaltyCount >= topCard.penaltyCount;
    }

    // Rule: Players CANNOT stack a lower-value draw card on top of a higher-value draw card,
    // even if color matches or after penalties have been drawn.
    // Top card +4: cannot stack +2.
    // Top card +6: cannot stack +4, +2.
    // Top card +10: cannot stack +6, +4, +2.
    if (isDrawPenalty && topCard.isDrawPenalty && penaltyCount < topCard.penaltyCount) {
      return false;
    }

    // 2. 0's Pass and 7's Swap can be played on ANY card regardless of color:
    if (type == CardType.pointZeroPass ||
        numberValue == 0 ||
        type == CardType.pointSevenSwap ||
        numberValue == 7) {
      return true;
    }

    // 3. Wilds:
    if (isWild) return true;

    // 4. Color matching: check direct top card color or active selected color
    final effectiveTopColor = (activeColor != null && activeColor != CardColor.wild)
        ? activeColor
        : topCard.color;
    if (color == effectiveTopColor || (topCard.isWild && activeColor != null && color == activeColor)) {
      return true;
    }

    // 5. Number:
    if (numberValue != null && topCard.numberValue != null && numberValue == topCard.numberValue) {
      return true;
    }

    // 6. Action:
    if (type == topCard.type && type != CardType.number) {
      return true;
    }

    return false;
  }
}
