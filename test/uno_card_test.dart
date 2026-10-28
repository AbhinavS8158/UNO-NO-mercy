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

    test('Discard All can be played on matching color card', () {
      const redTopCard = UnoCard(id: 'r1', color: CardColor.red, type: CardType.number, numberValue: 3);
      const blueTopCard = UnoCard(id: 'b1', color: CardColor.blue, type: CardType.number, numberValue: 3);
      const redDiscardAll = UnoCard(id: 'da1', color: CardColor.red, type: CardType.discardAll);

      expect(redDiscardAll.canPlayOn(redTopCard), isTrue);
      expect(redDiscardAll.canPlayOn(blueTopCard), isFalse);
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
        color: CardColor.wild,
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

    test('0 Pass and 7 Swap can be played on any color card', () {
      const redTopCard = UnoCard(
        id: 'r1',
        color: CardColor.red,
        type: CardType.number,
        numberValue: 3,
      );

      const blueZeroPass = UnoCard(
        id: 'z1',
        color: CardColor.blue,
        type: CardType.pointZeroPass,
        numberValue: 0,
      );

      const yellowSevenSwap = UnoCard(
        id: 's1',
        color: CardColor.yellow,
        type: CardType.pointSevenSwap,
        numberValue: 7,
      );

      // Blue 0 can be played on Red 3
      expect(blueZeroPass.canPlayOn(redTopCard), isTrue);

      // Yellow 7 can be played on Red 3
      expect(yellowSevenSwap.canPlayOn(redTopCard), isTrue);
    });

    test('Strict UNO Mercy Card Stacking Rules Table', () {
      const topDrawFour = UnoCard(id: 'd4', color: CardColor.red, type: CardType.drawFour);
      const topDrawSix = UnoCard(id: 'd6', color: CardColor.wild, type: CardType.drawSix);
      const topDrawTen = UnoCard(id: 'd10', color: CardColor.wild, type: CardType.drawTen);

      const drawTwo = UnoCard(id: 'p2', color: CardColor.red, type: CardType.drawTwo);
      const drawFour = UnoCard(id: 'p4', color: CardColor.red, type: CardType.drawFour);
      const drawSix = UnoCard(id: 'p6', color: CardColor.wild, type: CardType.drawSix);
      const drawTen = UnoCard(id: 'p10', color: CardColor.wild, type: CardType.drawTen);

      // Verify Wild status
      expect(drawSix.isWild, isTrue);
      expect(drawTen.isWild, isTrue);

      // 1. +4 on top: cannot stack +2. Can stack +4, +6, +10.
      expect(drawTwo.canPlayOn(topDrawFour, pendingDrawCount: 4), isFalse);
      expect(drawFour.canPlayOn(topDrawFour, pendingDrawCount: 4), isTrue);
      expect(drawSix.canPlayOn(topDrawFour, pendingDrawCount: 4), isTrue);
      expect(drawTen.canPlayOn(topDrawFour, pendingDrawCount: 4), isTrue);

      // 2. +6 on top: cannot stack +4 or +2. Can stack +6, +10.
      expect(drawTwo.canPlayOn(topDrawSix, pendingDrawCount: 6), isFalse);
      expect(drawFour.canPlayOn(topDrawSix, pendingDrawCount: 6), isFalse);
      expect(drawSix.canPlayOn(topDrawSix, pendingDrawCount: 6), isTrue);
      expect(drawTen.canPlayOn(topDrawSix, pendingDrawCount: 6), isTrue);

      // 3. +10 on top: cannot stack +6, +4, or +2. Can stack +10.
      expect(drawTwo.canPlayOn(topDrawTen, pendingDrawCount: 10), isFalse);
      expect(drawFour.canPlayOn(topDrawTen, pendingDrawCount: 10), isFalse);
      expect(drawSix.canPlayOn(topDrawTen, pendingDrawCount: 10), isFalse);
      expect(drawTen.canPlayOn(topDrawTen, pendingDrawCount: 10), isTrue);

      // Even if pendingDrawCount is 0, lower-value draw cards cannot stack on higher-value draw cards
      expect(drawTwo.canPlayOn(topDrawFour, pendingDrawCount: 0), isFalse);
      expect(drawTwo.canPlayOn(topDrawSix, pendingDrawCount: 0), isFalse);
      expect(drawFour.canPlayOn(topDrawSix, pendingDrawCount: 0), isFalse);
      expect(drawTwo.canPlayOn(topDrawTen, pendingDrawCount: 0), isFalse);
      expect(drawFour.canPlayOn(topDrawTen, pendingDrawCount: 0), isFalse);
      expect(drawSix.canPlayOn(topDrawTen, pendingDrawCount: 0), isFalse);
    });
  });
}
