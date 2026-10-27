"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.shuffleDeck = exports.generateNoMercyDeck = void 0;
function generateNoMercyDeck() {
    const deck = [];
    let counter = 0;
    const colors = ['RED', 'BLUE', 'GREEN', 'YELLOW'];
    // 1. Color cards (0-9, Skip, Reverse, Draw 2, Draw 4, Draw 6, Discard All, Skip Everyone, 7 Swap, 0 Pass)
    for (const color of colors) {
        // 0 is usually 0 Pass Hand in No Mercy
        deck.push({ id: `c_${counter++}`, color, type: 'POINT_ZERO_PASS', numberValue: 0 });
        deck.push({ id: `c_${counter++}`, color, type: 'POINT_ZERO_PASS', numberValue: 0 });
        // Numbers 1 to 9 (two of each)
        for (let num = 1; num <= 9; num++) {
            if (num === 7) {
                // 7 is Hand Swap in No Mercy
                deck.push({ id: `c_${counter++}`, color, type: 'POINT_SEVEN_SWAP', numberValue: 7 });
                deck.push({ id: `c_${counter++}`, color, type: 'POINT_SEVEN_SWAP', numberValue: 7 });
            }
            else {
                deck.push({ id: `c_${counter++}`, color, type: 'NUMBER', numberValue: num });
                deck.push({ id: `c_${counter++}`, color, type: 'NUMBER', numberValue: num });
            }
        }
        // Standard Action cards (two of each per color)
        for (let i = 0; i < 2; i++) {
            deck.push({ id: `c_${counter++}`, color, type: 'SKIP' });
            deck.push({ id: `c_${counter++}`, color, type: 'REVERSE' });
            deck.push({ id: `c_${counter++}`, color, type: 'DRAW_2' });
            deck.push({ id: `c_${counter++}`, color, type: 'DRAW_4' });
            deck.push({ id: `c_${counter++}`, color, type: 'DISCARD_ALL' });
            deck.push({ id: `c_${counter++}`, color, type: 'SKIP_EVERYONE' });
        }
    }
    // 2. Wild Cards & No Mercy Super Penalty Cards
    for (let i = 0; i < 4; i++) {
        deck.push({ id: `c_${counter++}`, color: 'WILD', type: 'DRAW_4' });
        deck.push({ id: `c_${counter++}`, color: 'WILD', type: 'DRAW_6' });
        deck.push({ id: `c_${counter++}`, color: 'WILD', type: 'DRAW_10' }); // Signature +10 card!
        deck.push({ id: `c_${counter++}`, color: 'WILD', type: 'ROULETTE' });
    }
    return shuffleDeck(deck);
}
exports.generateNoMercyDeck = generateNoMercyDeck;
function shuffleDeck(cards) {
    const shuffled = [...cards];
    for (let i = shuffled.length - 1; i > 0; i--) {
        const j = Math.floor(Math.random() * (i + 1));
        [shuffled[i], shuffled[j]] = [shuffled[j], shuffled[i]];
    }
    return shuffled;
}
exports.shuffleDeck = shuffleDeck;
//# sourceMappingURL=deck.js.map