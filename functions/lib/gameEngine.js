"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.determineWinner = exports.checkMercyElimination = exports.MERCY_LIMIT = exports.getNextPlayerId = exports.isCardPlayable = exports.getPenaltyCount = void 0;
function getPenaltyCount(card) {
    switch (card.type) {
        case 'DRAW_2':
            return 2;
        case 'DRAW_4':
            return 4;
        case 'DRAW_6':
            return 6;
        case 'DRAW_10':
            return 10;
        default:
            return 0;
    }
}
exports.getPenaltyCount = getPenaltyCount;
function isCardPlayable(card, topCard, activeColor, pendingDrawCount) {
    // If there is an active stacked penalty, player MUST play an equal or higher draw penalty!
    if (pendingDrawCount > 0) {
        const playedPenalty = getPenaltyCount(card);
        const topPenalty = getPenaltyCount(topCard);
        return playedPenalty > 0 && playedPenalty >= topPenalty;
    }
    // Wild cards can always be played
    if (card.color === 'WILD') {
        return true;
    }
    // Matches the current active color
    if (card.color === activeColor) {
        return true;
    }
    // Matches number value
    if (card.type === 'NUMBER' &&
        topCard.type === 'NUMBER' &&
        card.numberValue !== undefined &&
        card.numberValue === topCard.numberValue) {
        return true;
    }
    // Matches special action symbol
    if (card.type === topCard.type && card.type !== 'NUMBER') {
        return true;
    }
    return false;
}
exports.isCardPlayable = isCardPlayable;
function getNextPlayerId(players, currentTurnId, direction, steps = 1) {
    const activePlayers = players.filter((p) => !p.isKnockedOut);
    if (activePlayers.length === 0)
        return currentTurnId;
    let currentIndex = activePlayers.findIndex((p) => p.id === currentTurnId);
    if (currentIndex === -1)
        currentIndex = 0;
    const total = activePlayers.length;
    // Compute circular index with direction
    let nextIndex = (currentIndex + direction * steps) % total;
    if (nextIndex < 0)
        nextIndex += total;
    return activePlayers[nextIndex].id;
}
exports.getNextPlayerId = getNextPlayerId;
exports.MERCY_LIMIT = 25;
function checkMercyElimination(cardCount) {
    return cardCount >= exports.MERCY_LIMIT;
}
exports.checkMercyElimination = checkMercyElimination;
function determineWinner(players) {
    const activePlayers = players.filter((p) => !p.isKnockedOut);
    // If only 1 player remains standing (Mercy Last Man Standing)
    if (activePlayers.length === 1) {
        return activePlayers[0].id;
    }
    // If any player has 0 cards
    const zeroCardsPlayer = activePlayers.find((p) => p.cardCount === 0);
    if (zeroCardsPlayer) {
        return zeroCardsPlayer.id;
    }
    return null;
}
exports.determineWinner = determineWinner;
//# sourceMappingURL=gameEngine.js.map