import 'dart:async';
import '../models/game_room.dart';
import '../models/uno_card.dart';
import '../models/chat_message.dart';

abstract class IGameService {
  String get currentUid;
  Future<Map<String, String>> createRoom({required String playerName, String rules = 'no_mercy'});
  Future<Map<String, String>> joinRoom({required String roomCode, required String playerName});
  Future<void> startGame({required String roomId});
  Future<void> playCard({
    required String roomId,
    required String cardId,
    CardColor? chosenColor,
    String? swapTargetPlayerId,
  });
  Future<void> drawCard({required String roomId});
  Future<void> callUno({required String roomId, required String callerName});
  Stream<GameRoom> streamRoom(String roomId);
  Stream<List<UnoCard>> streamPrivateHand(String roomId, String myUserId);
  Future<String> getLiveKitVoiceToken(String roomId);
  Future<void> sendChatMessage({
    required String roomId,
    required String senderName,
    required String text,
  });
  Stream<List<ChatMessage>> streamChatMessages(String roomId);

  Future<void> sendVoiceSignal({
    required String roomId,
    required String targetId,
    required String senderId,
    required String type,
    required String data,
  });

  Stream<List<Map<String, dynamic>>> streamVoiceSignals({
    required String roomId,
    required String myPlayerId,
  });

  Future<void> deleteVoiceSignal({
    required String roomId,
    required String signalId,
  });
}

/// Robust Local Simulation & Fallback Service
/// Works out-of-the-box for offline testing & rapid multiplayer verification
class LocalGameService implements IGameService {
  final Map<String, GameRoom> _rooms = {};
  final Map<String, Map<String, List<UnoCard>>> _hands = {};
  
  final _roomController = StreamController<GameRoom>.broadcast();
  final _handController = StreamController<List<UnoCard>>.broadcast();

  String currentUserId = 'player_host_1';

  @override
  String get currentUid => currentUserId;

  @override
  Future<Map<String, String>> createRoom({required String playerName, String rules = 'no_mercy'}) async {
    final roomCode = 'UNO${DateTime.now().millisecondsSinceEpoch.toString().substring(8)}';
    final roomId = 'room_$roomCode';

    final host = PlayerSummary(
      id: currentUserId,
      name: playerName,
      cardCount: 7,
      isHost: true,
    );

    final room = GameRoom(
      id: roomId,
      roomCode: roomCode,
      status: 'waiting',
      currentTurn: currentUserId,
      turnDirection: 1,
      topCard: const UnoCard(id: 't1', color: CardColor.red, type: CardType.number, numberValue: 7),
      activeColor: CardColor.red,
      drawCountPending: 0,
      players: [host],
    );

    _rooms[roomId] = room;
    _hands[roomId] = {
      currentUserId: [
        const UnoCard(id: 'c1', color: CardColor.red, type: CardType.number, numberValue: 7),
        const UnoCard(id: 'c2', color: CardColor.blue, type: CardType.number, numberValue: 7),
        const UnoCard(id: 'c3', color: CardColor.red, type: CardType.drawSix),
        const UnoCard(id: 'c4', color: CardColor.wild, type: CardType.drawTen),
        const UnoCard(id: 'c5', color: CardColor.green, type: CardType.discardAll),
        const UnoCard(id: 'c6', color: CardColor.yellow, type: CardType.skipEveryone),
        const UnoCard(id: 'c7', color: CardColor.yellow, type: CardType.pointSevenSwap),
      ],
    };

    return {'roomId': roomId, 'roomCode': roomCode};
  }

  @override
  Future<Map<String, String>> joinRoom({required String roomCode, required String playerName}) async {
    final roomEntry = _rooms.entries.firstWhere(
      (e) => e.value.roomCode == roomCode.toUpperCase().trim(),
      orElse: () => throw Exception('റൂം കോഡ് തെറ്റാണ്!'),
    );

    final roomId = roomEntry.key;
    final currentRoom = roomEntry.value;

    final newPlayer = PlayerSummary(
      id: 'player_${DateTime.now().millisecondsSinceEpoch}',
      name: playerName,
      cardCount: 7,
    );

    final updatedPlayers = [...currentRoom.players, newPlayer];
    final updatedRoom = GameRoom(
      id: roomId,
      roomCode: currentRoom.roomCode,
      status: currentRoom.status,
      currentTurn: currentRoom.currentTurn,
      turnDirection: currentRoom.turnDirection,
      topCard: currentRoom.topCard,
      activeColor: currentRoom.activeColor,
      drawCountPending: currentRoom.drawCountPending,
      players: updatedPlayers,
    );

    _rooms[roomId] = updatedRoom;
    _roomController.add(updatedRoom);

    return {'roomId': roomId, 'roomCode': roomCode};
  }

  @override
  Future<void> startGame({required String roomId}) async {
    final room = _rooms[roomId];
    if (room == null) return;

    final updatedRoom = GameRoom(
      id: roomId,
      roomCode: room.roomCode,
      status: 'in_progress',
      currentTurn: room.players.first.id,
      turnDirection: room.turnDirection,
      topCard: room.topCard,
      activeColor: room.activeColor,
      drawCountPending: 0,
      players: room.players,
    );

    _rooms[roomId] = updatedRoom;
    _roomController.add(updatedRoom);
  }

  @override
  Future<void> playCard({
    required String roomId,
    required String cardId,
    CardColor? chosenColor,
    String? swapTargetPlayerId,
  }) async {
    final room = _rooms[roomId];
    if (room == null) return;

    final hand = _hands[roomId]?[currentUserId] ?? [];
    final cardIndex = hand.findIndex((c) => c.id == cardId);
    if (cardIndex == -1) return;

    final card = hand[cardIndex];
    hand.removeAt(cardIndex);

    final activePlayers = room.players;
    int curIdx = activePlayers.indexWhere((p) => p.id == currentUserId);
    if (curIdx == -1) curIdx = 0;
    String nextTurnId = currentUserId;
    if (card.type == CardType.skipEveryone) {
      nextTurnId = currentUserId; // Skip Everyone: play continuously!
    } else if (activePlayers.length > 1) {
      int nextIdx = (curIdx + 1) % activePlayers.length;
      nextTurnId = activePlayers[nextIdx].id;
    }

    final updatedRoom = GameRoom(
      id: roomId,
      roomCode: room.roomCode,
      status: room.status,
      currentTurn: nextTurnId,
      turnDirection: room.turnDirection,
      topCard: card,
      activeColor: chosenColor ?? (card.isWild ? CardColor.blue : card.color),
      drawCountPending: card.isDrawPenalty ? room.drawCountPending + card.penaltyCount : 0,
      players: room.players,
    );

    _rooms[roomId] = updatedRoom;
    _roomController.add(updatedRoom);
    _handController.add(hand);
  }

  @override
  Future<void> drawCard({required String roomId}) async {
    final hand = _hands[roomId]?[currentUserId] ?? [];
    final room = _rooms[roomId];
    final countToDraw = (room?.drawCountPending != null && room!.drawCountPending > 0)
        ? room.drawCountPending
        : 1;

    for (int i = 0; i < countToDraw; i++) {
      hand.add(UnoCard(
        id: 'drawn_${DateTime.now().microsecondsSinceEpoch}_$i',
        color: CardColor.values[i % 4],
        type: CardType.number,
        numberValue: (i + 1) % 10,
      ));
    }
    _handController.add(List.from(hand));

    if (room != null) {
      final updatedRoom = GameRoom(
        id: roomId,
        roomCode: room.roomCode,
        status: room.status,
        currentTurn: room.currentTurn,
        turnDirection: room.turnDirection,
        topCard: room.topCard,
        activeColor: room.activeColor,
        drawCountPending: 0, // penalty consumed
        players: room.players
            .map((p) => p.id == currentUserId
                ? PlayerSummary(
                    id: p.id,
                    name: p.name,
                    cardCount: hand.length,
                    isHost: p.isHost,
                  )
                : p)
            .toList(),
        lastUnoCall: room.lastUnoCall,
      );
      _rooms[roomId] = updatedRoom;
      _roomController.add(updatedRoom);
    }
  }

  @override
  Future<void> callUno({required String roomId, required String callerName}) async {
    final room = _rooms[roomId];
    if (room == null) return;
    final updatedRoom = GameRoom(
      id: roomId,
      roomCode: room.roomCode,
      status: room.status,
      currentTurn: room.currentTurn,
      turnDirection: room.turnDirection,
      topCard: room.topCard,
      activeColor: room.activeColor,
      drawCountPending: room.drawCountPending,
      players: room.players,
      lastUnoCall: {
        'callerName': callerName,
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      },
    );
    _rooms[roomId] = updatedRoom;
    _roomController.add(updatedRoom);
  }

  @override
  Stream<GameRoom> streamRoom(String roomId) {
    return _roomController.stream;
  }

  @override
  Stream<List<UnoCard>> streamPrivateHand(String roomId, String myUserId) {
    return _handController.stream;
  }

  @override
  Future<String> getLiveKitVoiceToken(String roomId) async {
    return 'mock_livekit_token_$roomId';
  }

  final _chatController = StreamController<List<ChatMessage>>.broadcast();
  final List<ChatMessage> _mockChatList = [];

  @override
  Future<void> sendChatMessage({
    required String roomId,
    required String senderName,
    required String text,
  }) async {
    final msg = ChatMessage(
      id: 'chat_${DateTime.now().millisecondsSinceEpoch}',
      senderId: currentUserId,
      senderName: senderName,
      text: text,
      timestamp: DateTime.now(),
    );
    _mockChatList.add(msg);
    _chatController.add(List.from(_mockChatList));
  }

  @override
  Stream<List<ChatMessage>> streamChatMessages(String roomId) {
    return _chatController.stream;
  }

  @override
  Future<void> sendVoiceSignal({
    required String roomId,
    required String targetId,
    required String senderId,
    required String type,
    required String data,
  }) async {}

  @override
  Stream<List<Map<String, dynamic>>> streamVoiceSignals({
    required String roomId,
    required String myPlayerId,
  }) {
    return const Stream.empty();
  }

  @override
  Future<void> deleteVoiceSignal({
    required String roomId,
    required String signalId,
  }) async {}
}

extension ListExt<T> on List<T> {
  int findIndex(bool Function(T element) test) {
    for (int i = 0; i < length; i++) {
      if (test(this[i])) return i;
    }
    return -1;
  }
}
