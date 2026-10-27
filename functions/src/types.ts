export type CardColor = 'RED' | 'BLUE' | 'GREEN' | 'YELLOW' | 'WILD';

export type CardType =
  | 'NUMBER'
  | 'SKIP'
  | 'REVERSE'
  | 'DRAW_2'
  | 'DRAW_4'
  | 'DRAW_6'
  | 'DRAW_10'
  | 'DISCARD_ALL'
  | 'SKIP_EVERYONE'
  | 'ROULETTE'
  | 'POINT_SEVEN_SWAP'
  | 'POINT_ZERO_PASS';

export interface ServerCard {
  id: string;
  color: CardColor;
  type: CardType;
  numberValue?: number;
}

export interface PlayerSummary {
  id: string;
  name: string;
  cardCount: number;
  isKnockedOut: boolean;
  isHost: boolean;
  calledUno: boolean;
}

export interface RoomDoc {
  id: string;
  roomCode: string;
  status: 'waiting' | 'in_progress' | 'ended';
  currentTurn: string;
  turnDirection: 1 | -1; // 1 = clockwise, -1 = counter-clockwise
  topCard: ServerCard;
  activeColor: CardColor;
  drawCountPending: number;
  players: PlayerSummary[];
  gameRules: 'no_mercy' | 'classic';
  winnerId?: string | null;
  createdAt: number;
  updatedAt: number;
}
