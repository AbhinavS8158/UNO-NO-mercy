import 'package:flutter_test/flutter_test.dart';
import 'package:uno_no_mercy/models/uno_card.dart';

void main() {
  group('UnoCard Tests', () {
    test('Number matching works correctly', () {
      const topCard = UnoCard(
        id: '1',
        color: CardColor.red,
        type: CardType.number,
        numberValue: 5,
      );

      const matchingColorCard = UnoCard(
        id: '2',
        color: CardColor.red,
        type: CardType.number,
        numberValue: 9,
      );

      const matchingNumberCard = UnoCard(
        id: '3',
        color: CardColor.blue,
        type: CardType.number,
        numberValue: 5,
      );

      const differentCard = UnoCard(
        id: '4',
        color: CardColor.yellow,
        type: CardType.number,
        numberValue: 2,
      );

      expect(matchingColorCard.canPlayOn(topCard), isTrue);
      expect(matchingNumberCard.canPlayOn(topCard), isTrue);
      expect(differentCard.canPlayOn(topCard), isFalse);
    });

    test('Wild card can be played on any card', () {
      const topCard = UnoCard(
        id: '1',
        color: CardColor.red,
        type: CardType.number,
        numberValue: 5,
      );

      const wildCard = UnoCard(
        id: 'w1',
        color: CardColor.wild,
        type: CardType.drawFour,
      );

      expect(wildCard.canPlayOn(topCard), isTrue);
    });

    test('No Mercy Stacking rule requires equal or higher draw card', () {
      const activeDrawCard = UnoCard(
        id: 'd1',
        color: CardColor.red,
        type: CardType.drawFour,
      );

      const drawTwo = UnoCard(
        id: 'd2',
        color: CardColor.red,
        type: CardType.drawTwo,
      );

      const drawSix = UnoCard(
        id: 'd3',
        color: CardColor.red,
        type: CardType.drawSix,
      );

      const drawTen = UnoCard(
        id: 'd4',
        color: CardColor.wild,
        type: CardType.drawTen,
      );

      // When there is an active stacking penalty (> 0):
      // Draw Two (+2) cannot stack on Draw Four (+4)
      expect(drawTwo.canPlayOn(activeDrawCard, pendingDrawCount: 4), isFalse);
      
      // Draw Six (+6) can stack on Draw Four (+4)
      expect(drawSix.canPlayOn(activeDrawCard, pendingDrawCount: 4), isTrue);
      
      // Draw Ten (+10) can stack on Draw Four (+4)
      expect(drawTen.canPlayOn(activeDrawCard, pendingDrawCount: 4), isTrue);
    });
  });
}
