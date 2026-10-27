import 'uno_card.dart';

class PlayerSummary {
  final String id;
  final String name;
  final int cardCount;
  final bool isKnockedOut;
  final bool isHost;
  final bool calledUno;

  const PlayerSummary({
    required this.id,
    required this.name,
    required this.cardCount,
    this.isKnockedOut = false,
    this.isHost = false,
    this.calledUno = false,
  });

  factory PlayerSummary.fromMap(Map<String, dynamic> map) {
    return PlayerSummary(
      id: map['id'] ?? '',
      name: map['name'] ?? 'Player',
      cardCount: map['cardCount'] ?? 0,
      isKnockedOut: map['isKnockedOut'] ?? false,
      isHost: map['isHost'] ?? false,
      calledUno: map['calledUno'] ?? false,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'cardCount': cardCount,
      'isKnockedOut': isKnockedOut,
      'isHost': isHost,
      'calledUno': calledUno,
    };
  }
}

class GameRoom {
  final String id;
  final String roomCode;
  final String status; // 'waiting', 'in_progress', 'ended'
  final String currentTurn;
  final int turnDirection; // 1 or -1
  final UnoCard topCard;
  final CardColor activeColor;
  final int drawCountPending;
  final List<PlayerSummary> players;
  final String? winnerId;
  final Map<String, dynamic>? lastUnoCall;

  const GameRoom({
    required this.id,
    required this.roomCode,
    required this.status,
    required this.currentTurn,
    required this.turnDirection,
    required this.topCard,
    required this.activeColor,
    required this.drawCountPending,
    required this.players,
    this.winnerId,
    this.lastUnoCall,
  });

  bool get isWaiting => status == 'waiting';
  bool get isInProgress => status == 'in_progress';
  bool get isEnded => status == 'ended';

  factory GameRoom.fromMap(String id, Map<String, dynamic> map) {
    final topCardMap = map['topCard'] as Map<String, dynamic>? ?? {};
    
    // Parse CardColor
    CardColor parseColor(String? colorStr) {
      switch (colorStr) {
        case 'RED': return CardColor.red;
        case 'BLUE': return CardColor.blue;
        case 'GREEN': return CardColor.green;
        case 'YELLOW': return CardColor.yellow;
        default: return CardColor.wild;
      }
    }

    // Parse CardType
    CardType parseType(String? typeStr) {
      switch (typeStr) {
        case 'SKIP': return CardType.skip;
        case 'REVERSE': return CardType.reverse;
        case 'DRAW_2': return CardType.drawTwo;
        case 'DRAW_4': return CardType.drawFour;
        case 'DRAW_6': return CardType.drawSix;
        case 'DRAW_10': return CardType.drawTen;
        case 'DISCARD_ALL': return CardType.discardAll;
        case 'SKIP_EVERYONE': return CardType.skipEveryone;
        case 'ROULETTE': return CardType.roulette;
        case 'POINT_SEVEN_SWAP': return CardType.pointSevenSwap;
        case 'POINT_ZERO_PASS': return CardType.pointZeroPass;
        default: return CardType.number;
      }
    }

    final topCard = UnoCard(
      id: topCardMap['id'] ?? 'top',
      color: parseColor(topCardMap['color']),
      type: parseType(topCardMap['type']),
      numberValue: topCardMap['numberValue'],
    );

    final rawPlayers = (map['players'] as List<dynamic>? ?? []);
    final players = rawPlayers
        .map((p) => PlayerSummary.fromMap(p as Map<String, dynamic>))
        .toList();

    return GameRoom(
      id: id,
      roomCode: map['roomCode'] ?? '',
      status: map['status'] ?? 'waiting',
      currentTurn: map['currentTurn'] ?? '',
      turnDirection: map['turnDirection'] ?? 1,
      topCard: topCard,
      activeColor: parseColor(map['activeColor']),
      drawCountPending: map['drawCountPending'] ?? 0,
      players: players,
      winnerId: map['winnerId'],
      lastUnoCall: map['lastUnoCall'] as Map<String, dynamic>?,
    );
  }
}
