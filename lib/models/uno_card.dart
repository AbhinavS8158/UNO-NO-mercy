enum CardColor { red, blue, green, yellow, wild }

enum CardType {
  number,
  skip,
  reverse,
  drawTwo,
  drawFour,
  // UNO Show 'em No Mercy Specials
  drawSix,
  drawTen,
  discardAll,
  skipEveryone,
  roulette,
  pointSevenSwap, // No Mercy 7 rule: swap hands with a player
  pointZeroPass,  // No Mercy 0 rule: pass hands in current direction
}

class UnoCard {
  final String id;
  final CardColor color;
  final CardType type;
  final int? numberValue; // 0 to 9 if type == number

  const UnoCard({
    required this.id,
    required this.color,
    required this.type,
    this.numberValue,
  });

  bool get isWild => color == CardColor.wild;

  bool get isDrawPenalty =>
      type == CardType.drawTwo ||
      type == CardType.drawFour ||
      type == CardType.drawSix ||
      type == CardType.drawTen;

  int get penaltyCount {
    switch (type) {
      case CardType.drawTwo:
        return 2;
      case CardType.drawFour:
        return 4;
      case CardType.drawSix:
        return 6;
      case CardType.drawTen:
        return 10;
      default:
        return 0;
    }
  }

  /// Label displayed on card corners & center
  String get displayLabel {
    if (type == CardType.number) {
      return '${numberValue ?? 0}';
    }
    switch (type) {
      case CardType.skip:
        return '⊘';
      case CardType.reverse:
        return '⇄';
      case CardType.drawTwo:
        return '+2';
      case CardType.drawFour:
        return '+4';
      case CardType.drawSix:
        return '+6';
      case CardType.drawTen:
        return '+10';
      case CardType.discardAll:
        return 'ALL';
      case CardType.skipEveryone:
        return 'ALL ⊘';
      case CardType.roulette:
        return '🎰';
      case CardType.pointSevenSwap:
        return '7 ⇄';
      case CardType.pointZeroPass:
        return '0 ↻';
      default:
        return '';
    }
  }

  /// Subtitle or descriptor
  String get actionName {
    switch (type) {
      case CardType.skip:
        return 'SKIP';
      case CardType.reverse:
        return 'REVERSE';
      case CardType.drawTwo:
        return 'DRAW 2';
      case CardType.drawFour:
        return 'WILD +4';
      case CardType.drawSix:
        return 'DRAW 6';
      case CardType.drawTen:
        return 'DRAW 10';
      case CardType.discardAll:
        return 'DISCARD ALL';
      case CardType.skipEveryone:
        return 'SKIP EVERYONE';
      case CardType.roulette:
        return 'ROULETTE';
      case CardType.pointSevenSwap:
        return 'SWAP HAND';
      case CardType.pointZeroPass:
        return 'PASS HAND';
      default:
        return '';
    }
  }

  /// Check if this card matches the top card under normal & stacking rules
  bool canPlayOn(UnoCard topCard, {int pendingDrawCount = 0}) {
    // If there is an active stacking penalty, must play a matching or higher draw card!
    if (pendingDrawCount > 0) {
      return isDrawPenalty && penaltyCount >= topCard.penaltyCount;
    }

    // Wild cards can always be played
    if (isWild) return true;

    // Matching color
    if (color == topCard.color) return true;

    // Matching number
    if (type == CardType.number && topCard.type == CardType.number) {
      return numberValue == topCard.numberValue;
    }

    // Matching action symbol
    if (type == topCard.type && type != CardType.number) {
      return true;
    }

    return false;
  }
}
