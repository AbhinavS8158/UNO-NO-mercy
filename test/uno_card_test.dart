import 'package:flutter_test/flutter_test.dart';
import 'package:uno_no_mercy/models/uno_card.dart';

void main() {
  group('Official UNO Show em No Mercy Rules Tests', () {
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

    test('Wild cards can be played on any card', () {
      const topCard = UnoCard(
        id: '1',
        color: CardColor.red,
        type: CardType.number,
        numberValue: 5,
      );

      const wildTen = UnoCard(
        id: 'w1',
        color: CardColor.wild,
        type: CardType.drawTen,
      );

      const wildRevFour = UnoCard(
        id: 'w2',
        color: CardColor.wild,
        type: CardType.wildReverseDrawFour,
      );

      expect(wildTen.canPlayOn(topCard), isTrue);
      expect(wildRevFour.canPlayOn(topCard), isTrue);
    });

    test('Official Stacking Rule: can only stack equal or higher penalty value', () {
      const activeDrawFour = UnoCard(
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

      // +2 cannot stack on +4
      expect(drawTwo.canPlayOn(activeDrawFour, pendingDrawCount: 4), isFalse);

      // +6 can stack on +4
      expect(drawSix.canPlayOn(activeDrawFour, pendingDrawCount: 4), isTrue);

      // +10 can stack on +4 or +6
      expect(drawTen.canPlayOn(activeDrawFour, pendingDrawCount: 4), isTrue);
    });
  });
}
