import 'dart:math';
import 'uno_card.dart';

class DeckGenerator {
  static List<UnoCard> generateNoMercyDeck() {
    final List<UnoCard> deck = [];
    int counter = 0;

    final colors = [CardColor.red, CardColor.blue, CardColor.green, CardColor.yellow];

    for (final color in colors) {
      // 0's Pass (two per color)
      deck.add(UnoCard(id: 'c_${counter++}', color: color, type: CardType.pointZeroPass, numberValue: 0));
      deck.add(UnoCard(id: 'c_${counter++}', color: color, type: CardType.pointZeroPass, numberValue: 0));

      // 1 to 9 (two per color, 7 is 7's Swap)
      for (int num = 1; num <= 9; num++) {
        if (num == 7) {
          deck.add(UnoCard(id: 'c_${counter++}', color: color, type: CardType.pointSevenSwap, numberValue: 7));
          deck.add(UnoCard(id: 'c_${counter++}', color: color, type: CardType.pointSevenSwap, numberValue: 7));
        } else {
          deck.add(UnoCard(id: 'c_${counter++}', color: color, type: CardType.number, numberValue: num));
          deck.add(UnoCard(id: 'c_${counter++}', color: color, type: CardType.number, numberValue: num));
        }
      }

      // Standard Action & Penalty Cards per color
      for (int i = 0; i < 2; i++) {
        deck.add(UnoCard(id: 'c_${counter++}', color: color, type: CardType.skip));
        deck.add(UnoCard(id: 'c_${counter++}', color: color, type: CardType.reverse));
        deck.add(UnoCard(id: 'c_${counter++}', color: color, type: CardType.skipEveryone));
        deck.add(UnoCard(id: 'c_${counter++}', color: color, type: CardType.drawTwo));
        deck.add(UnoCard(id: 'c_${counter++}', color: color, type: CardType.drawFour));
        deck.add(UnoCard(id: 'c_${counter++}', color: color, type: CardType.drawSix));
        deck.add(UnoCard(id: 'c_${counter++}', color: color, type: CardType.discardAll));
      }
    }

    // Wild Specials: Wild Draw 10, Wild Reverse Draw 4, Wild Color Roulette
    for (int i = 0; i < 4; i++) {
      deck.add(UnoCard(id: 'c_${counter++}', color: CardColor.wild, type: CardType.drawTen));
      deck.add(UnoCard(id: 'c_${counter++}', color: CardColor.wild, type: CardType.wildReverseDrawFour));
      deck.add(UnoCard(id: 'c_${counter++}', color: CardColor.wild, type: CardType.colorRoulette));
    }

    // Shuffle using Fisher-Yates
    final random = Random();
    for (int i = deck.length - 1; i > 0; i--) {
      final j = random.nextInt(i + 1);
      final temp = deck[i];
      deck[i] = deck[j];
      deck[j] = temp;
    }

    return deck;
  }
}
