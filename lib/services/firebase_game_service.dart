import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/game_room.dart';
import '../models/uno_card.dart';
import 'game_service.dart';

class FirebaseGameService implements IGameService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  String? _cachedUserId;

  Future<String> _ensureAuthenticated() async {
    if (_auth.currentUser != null) {
      _cachedUserId = _auth.currentUser!.uid;
      return _cachedUserId!;
    }
    // Sign in anonymously if not signed in
    final cred = await _auth.signInAnonymously();
    _cachedUserId = cred.user!.uid;
    return _cachedUserId!;
  }

  @override
  Future<Map<String, String>> createRoom({
    required String playerName,
    String rules = 'no_mercy',
  }) async {
    final uid = await _ensureAuthenticated();

    // 6-digit uppercase alphanumeric room code
    final roomCode = 'UNO${DateTime.now().millisecondsSinceEpoch.toString().substring(8)}';
    final roomRef = _firestore.collection('rooms').doc();

    final hostPlayer = PlayerSummary(
      id: uid,
      name: playerName,
      cardCount: 7,
      isHost: true,
    );

    // Initial default top card
    const initialTop = UnoCard(
      id: 'top_init',
      color: CardColor.red,
      type: CardType.number,
      numberValue: 7,
    );

    final roomData = {
      'roomCode': roomCode,
      'status': 'waiting',
      'currentTurn': uid,
      'turnDirection': 1,
      'topCard': {
        'id': initialTop.id,
        'color': 'RED',
        'type': 'NUMBER',
        'numberValue': 7,
      },
      'activeColor': 'RED',
      'drawCountPending': 0,
      'players': [hostPlayer.toMap()],
      'gameRules': rules,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    };

    await roomRef.set(roomData);

    // Create host's private hand
    final initialHand = [
      const UnoCard(id: 'c1', color: CardColor.red, type: CardType.number, numberValue: 7),
      const UnoCard(id: 'c2', color: CardColor.blue, type: CardType.number, numberValue: 7),
      const UnoCard(id: 'c3', color: CardColor.red, type: CardType.skip),
      const UnoCard(id: 'c4', color: CardColor.yellow, type: CardType.drawTwo),
      const UnoCard(id: 'c5', color: CardColor.wild, type: CardType.drawFour),
      const UnoCard(id: 'c6', color: CardColor.red, type: CardType.drawSix),
      const UnoCard(id: 'c7', color: CardColor.wild, type: CardType.drawTen),
    ];

    await roomRef.collection('private_hands').doc(uid).set({
      'cards': initialHand.map((c) => {
        'id': c.id,
        'color': c.color.name.toUpperCase(),
        'type': c.type.name.toUpperCase(),
        'numberValue': c.numberValue,
      }).toList(),
    });

    return {'roomId': roomRef.id, 'roomCode': roomCode};
  }

  @override
  Future<Map<String, String>> joinRoom({
    required String roomCode,
    required String playerName,
  }) async {
    final uid = await _ensureAuthenticated();
    final cleanCode = roomCode.toUpperCase().trim();

    // Query room by code across all devices!
    final query = await _firestore
        .collection('rooms')
        .where('roomCode', isEqualTo: cleanCode)
        .limit(1)
        .get();

    if (query.docs.isEmpty) {
      throw Exception('റൂം കോഡ് തെറ്റാണ് അല്ലെങ്കിൽ റൂം നിലവിലില്ല!');
    }

    final roomDoc = query.docs.first;
    final roomId = roomDoc.id;
    final data = roomDoc.data();

    final List<dynamic> playersRaw = data['players'] ?? [];
    final alreadyIn = playersRaw.any((p) => p['id'] == uid);

    if (!alreadyIn) {
      final newPlayer = PlayerSummary(
        id: uid,
        name: playerName,
        cardCount: 7,
      );

      await roomDoc.reference.update({
        'players': FieldValue.arrayUnion([newPlayer.toMap()]),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // Give new player their 7 private cards
      final initialHand = [
        const UnoCard(id: 'c1', color: CardColor.green, type: CardType.number, numberValue: 7),
        const UnoCard(id: 'c2', color: CardColor.yellow, type: CardType.number, numberValue: 7),
        const UnoCard(id: 'c3', color: CardColor.blue, type: CardType.skip),
        const UnoCard(id: 'c4', color: CardColor.red, type: CardType.drawTwo),
        const UnoCard(id: 'c5', color: CardColor.wild, type: CardType.drawFour),
        const UnoCard(id: 'c6', color: CardColor.blue, type: CardType.drawSix),
        const UnoCard(id: 'c7', color: CardColor.wild, type: CardType.drawTen),
      ];

      await roomDoc.reference.collection('private_hands').doc(uid).set({
        'cards': initialHand.map((c) => {
          'id': c.id,
          'color': c.color.name.toUpperCase(),
          'type': c.type.name.toUpperCase(),
          'numberValue': c.numberValue,
        }).toList(),
      });
    }

    return {'roomId': roomId, 'roomCode': cleanCode};
  }

  @override
  Future<void> startGame({required String roomId}) async {
    await _firestore.collection('rooms').doc(roomId).update({
      'status': 'in_progress',
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  @override
  Future<void> playCard({
    required String roomId,
    required String cardId,
    CardColor? chosenColor,
    String? swapTargetPlayerId,
  }) async {
    final uid = await _ensureAuthenticated();
    final roomRef = _firestore.collection('rooms').doc(roomId);

    await _firestore.runTransaction((transaction) async {
      final roomSnap = await transaction.get(roomRef);
      if (!roomSnap.exists) return;

      final handRef = roomRef.collection('private_hands').doc(uid);
      final handSnap = await transaction.get(handRef);
      final cardsRaw = (handSnap.data()?['cards'] as List<dynamic>? ?? []);

      final cardIndex = cardsRaw.indexWhere((c) => c['id'] == cardId);
      if (cardIndex == -1) return;

      final playedCardMap = cardsRaw.removeAt(cardIndex);
      transaction.set(handRef, {'cards': cardsRaw});

      // Update Top Card in room
      transaction.update(roomRef, {
        'topCard': playedCardMap,
        'activeColor': chosenColor?.name.toUpperCase() ?? playedCardMap['color'],
        'updatedAt': FieldValue.serverTimestamp(),
      });
    });
  }

  @override
  Future<void> drawCard({required String roomId}) async {
    final uid = await _ensureAuthenticated();
    final handRef = _firestore.collection('rooms').doc(roomId).collection('private_hands').doc(uid);

    final handSnap = await handRef.get();
    final cardsRaw = (handSnap.data()?['cards'] as List<dynamic>? ?? []);

    cardsRaw.add({
      'id': 'draw_${DateTime.now().millisecondsSinceEpoch}',
      'color': 'BLUE',
      'type': 'NUMBER',
      'numberValue': 5,
    });

    await handRef.set({'cards': cardsRaw});
  }

  @override
  Future<void> callUno({required String roomId}) async {}

  @override
  Stream<GameRoom> streamRoom(String roomId) {
    return _firestore.collection('rooms').doc(roomId).snapshots().map((snap) {
      if (!snap.exists) throw Exception('Room not found');
      return GameRoom.fromMap(snap.id, snap.data()!);
    });
  }

  @override
  Stream<List<UnoCard>> streamPrivateHand(String roomId, String myUserId) {
    return _firestore
        .collection('rooms')
        .doc(roomId)
        .collection('private_hands')
        .doc(myUserId)
        .snapshots()
        .map((snap) {
      if (!snap.exists) return [];
      final rawCards = snap.data()?['cards'] as List<dynamic>? ?? [];
      return rawCards.map((c) {
        CardColor parseCol(String? col) {
          switch (col) {
            case 'RED': return CardColor.red;
            case 'BLUE': return CardColor.blue;
            case 'GREEN': return CardColor.green;
            case 'YELLOW': return CardColor.yellow;
            default: return CardColor.wild;
          }
        }
        return UnoCard(
          id: c['id'] ?? '',
          color: parseCol(c['color']),
          type: CardType.number,
          numberValue: c['numberValue'],
        );
      }).toList();
    });
  }

  @override
  Future<String> getLiveKitVoiceToken(String roomId) async {
    return 'token_$roomId';
  }
}
