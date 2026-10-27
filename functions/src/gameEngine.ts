import { CardColor, PlayerSummary, ServerCard } from './types';

export function getPenaltyCount(card: ServerCard): number {
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

export function isCardPlayable(
  card: ServerCard,
  topCard: ServerCard,
  activeColor: CardColor,
  pendingDrawCount: number
): boolean {
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
  if (
    card.type === 'NUMBER' &&
    topCard.type === 'NUMBER' &&
    card.numberValue !== undefined &&
    card.numberValue === topCard.numberValue
  ) {
    return true;
  }

  // Matches special action symbol
  if (card.type === topCard.type && card.type !== 'NUMBER') {
    return true;
  }

  return false;
}

export function getNextPlayerId(
  players: PlayerSummary[],
  currentTurnId: string,
  direction: 1 | -1,
  steps: number = 1
): string {
  const activePlayers = players.filter((p) => !p.isKnockedOut);
  if (activePlayers.length === 0) return currentTurnId;

  let currentIndex = activePlayers.findIndex((p) => p.id === currentTurnId);
  if (currentIndex === -1) currentIndex = 0;

  const total = activePlayers.length;
  // Compute circular index with direction
  let nextIndex = (currentIndex + direction * steps) % total;
  if (nextIndex < 0) nextIndex += total;

  return activePlayers[nextIndex].id;
}

export const MERCY_LIMIT = 25;

export function checkMercyElimination(cardCount: number): boolean {
  return cardCount >= MERCY_LIMIT;
}

export function determineWinner(players: PlayerSummary[]): string | null {
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
