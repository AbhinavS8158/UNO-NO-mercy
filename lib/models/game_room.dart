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
  final int remainingDeckCount;
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
    this.remainingDeckCount = 140,
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
      switch (colorStr?.toUpperCase()) {
        case 'RED': return CardColor.red;
        case 'BLUE': return CardColor.blue;
        case 'GREEN': return CardColor.green;
        case 'YELLOW': return CardColor.yellow;
        default: return CardColor.wild;
      }
    }

    // Parse CardType (Handles both DRAW_6 and DRAWSIX, SKIPEVERYONE and SKIP_EVERYONE, etc.)
    CardType parseType(String? typeStr) {
      final clean = typeStr?.toUpperCase().replaceAll('_', '') ?? '';
      switch (clean) {
        case 'SKIP': return CardType.skip;
        case 'REVERSE': return CardType.reverse;
        case 'DRAWTWO':
        case 'DRAW2': return CardType.drawTwo;
        case 'DRAWFOUR':
        case 'DRAW4': return CardType.drawFour;
        case 'DRAWSIX':
        case 'DRAW6': return CardType.drawSix;
        case 'DRAWTEN':
        case 'DRAW10': return CardType.drawTen;
        case 'WILDREVERSEDRAWFOUR':
        case 'WILDREVERSEDRAW4': return CardType.wildReverseDrawFour;
        case 'COLORROULETTE':
        case 'ROULETTE': return CardType.colorRoulette;
        case 'DISCARDALL': return CardType.discardAll;
        case 'SKIPEVERYONE': return CardType.skipEveryone;
        case 'POINTSEVENSWAP':
        case 'SEVENSWAP': return CardType.pointSevenSwap;
        case 'POINTZEROPASS':
        case 'ZEROPASS': return CardType.pointZeroPass;
        default: return CardType.number;
      }
    }

    final parsedActiveColor = parseColor(map['activeColor']);
    final topCardColor = parseColor(topCardMap['color']);
    final parsedType = parseType(topCardMap['type']);
    final isTopWild = topCardColor == CardColor.wild ||
        parsedType == CardType.drawSix ||
        parsedType == CardType.drawTen ||
        parsedType == CardType.wildReverseDrawFour ||
        parsedType == CardType.colorRoulette ||
        parsedType == CardType.roulette;

    final topCard = UnoCard(
      id: topCardMap['id'] ?? 'top',
      color: (isTopWild && parsedActiveColor != CardColor.wild)
          ? parsedActiveColor
          : topCardColor,
      type: parsedType,
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
      remainingDeckCount: (map['remainingDeckCount'] as int?) ?? 140,
      players: players,
      winnerId: map['winnerId'],
      lastUnoCall: map['lastUnoCall'] as Map<String, dynamic>?,
    );
  }
}
