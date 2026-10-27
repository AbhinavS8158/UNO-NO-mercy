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
        return 'SKIP EVERYONE';
      case CardType.drawTwo:
        return 'DRAW 2';
      case CardType.drawFour:
        return 'DRAW 4';
      case CardType.drawSix:
        return 'DRAW 6';
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

  bool canPlayOn(UnoCard topCard, {int pendingDrawCount = 0}) {
    // 1. Official Stacking:
    if (pendingDrawCount > 0) {
      return isDrawPenalty && penaltyCount >= topCard.penaltyCount;
    }

    // 2. Wilds:
    if (isWild) return true;

    // 3. Color:
    if (color == topCard.color) return true;

    // 4. Number:
    if (type == CardType.number && topCard.type == CardType.number) {
      return numberValue == topCard.numberValue;
    }

    // 5. Action:
    if (type == topCard.type && type != CardType.number) {
      return true;
    }

    return false;
  }
}
