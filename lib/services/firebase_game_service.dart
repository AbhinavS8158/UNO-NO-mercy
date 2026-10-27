import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/game_room.dart';
import '../models/uno_card.dart';
import '../models/deck_generator.dart';
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
    final cred = await _auth.signInAnonymously();
    _cachedUserId = cred.user!.uid;
    return _cachedUserId!;
  }

  String get currentUid => _auth.currentUser?.uid ?? _cachedUserId ?? 'player_me';

  @override
  Future<Map<String, String>> createRoom({
    required String playerName,
    String rules = 'no_mercy',
  }) async {
    final uid = await _ensureAuthenticated();

    // 6-digit room code
    final roomCode = 'UNO${DateTime.now().millisecondsSinceEpoch.toString().substring(8)}';
    final roomRef = _firestore.collection('rooms').doc();

    final hostPlayer = PlayerSummary(
      id: uid,
      name: playerName,
      cardCount: 7,
      isHost: true,
    );

    // 1. Generate full 168-card No Mercy shuffled deck
    final fullDeck = DeckGenerator.generateNoMercyDeck();

    // 2. Deal first 7 unique cards to Host
    final hostHand = fullDeck.sublist(0, 7);

    // 3. Pick first non-wild card as starting top card
    int topIndex = 7;
    while (topIndex < fullDeck.length && fullDeck[topIndex].isWild) {
      topIndex++;
    }
    final startingTopCard = fullDeck[topIndex];

    // 4. Remaining cards go to the shared draw pile
    final remainingDeck = List<UnoCard>.from(fullDeck);
    remainingDeck.removeRange(0, 7);
    remainingDeck.remove(startingTopCard);

    final roomData = {
      'roomCode': roomCode,
      'status': 'waiting',
      'currentTurn': uid,
      'turnDirection': 1,
      'topCard': {
        'id': startingTopCard.id,
        'color': startingTopCard.color.name.toUpperCase(),
        'type': startingTopCard.type.name.toUpperCase(),
        'numberValue': startingTopCard.numberValue,
      },
      'activeColor': startingTopCard.color.name.toUpperCase(),
      'drawCountPending': 0,
      'players': [hostPlayer.toMap()],
      'gameRules': rules,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    };

    await roomRef.set(roomData);

    // Save Host's Private Hand
    await roomRef.collection('private_hands').doc(uid).set({
      'cards': hostHand.map(_cardToMap).toList(),
    });

    // Save remaining draw deck
    await roomRef.collection('deck').doc('draw_pile').set({
      'cards': remainingDeck.map(_cardToMap).toList(),
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
      // 1. Fetch remaining cards from shared draw deck
      final deckRef = roomDoc.reference.collection('deck').doc('draw_pile');
      final deckSnap = await deckRef.get();
      List<dynamic> rawDeck = (deckSnap.data()?['cards'] as List<dynamic>? ?? []);

      if (rawDeck.length < 7) {
        // Fallback reshuffle if deck low
        rawDeck = DeckGenerator.generateNoMercyDeck().map(_cardToMap).toList();
      }

      // Deal 7 completely distinct cards to the joining player!
      final playerHand = rawDeck.sublist(0, 7);
      final remainingDeck = rawDeck.sublist(7);

      // Save remaining deck back
      await deckRef.set({'cards': remainingDeck});

      // Save new player's private hand
      await roomDoc.reference.collection('private_hands').doc(uid).set({
        'cards': playerHand,
      });

      // Update room players list
      final newPlayer = PlayerSummary(
        id: uid,
        name: playerName,
        cardCount: 7,
      );

      await roomDoc.reference.update({
        'players': FieldValue.arrayUnion([newPlayer.toMap()]),
        'updatedAt': FieldValue.serverTimestamp(),
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
      final roomData = roomSnap.data()!;

      final handRef = roomRef.collection('private_hands').doc(uid);
      final handSnap = await transaction.get(handRef);
      final cardsRaw = (handSnap.data()?['cards'] as List<dynamic>? ?? []);

      final cardIndex = cardsRaw.indexWhere((c) => c['id'] == cardId);
      if (cardIndex == -1) return;

      final playedCardMap = cardsRaw.removeAt(cardIndex);
      transaction.set(handRef, {'cards': cardsRaw});

      // Update player summary card count
      final players = (roomData['players'] as List<dynamic>? ?? []).map((p) {
        if (p['id'] == uid) {
          return {
            ...p as Map<String, dynamic>,
            'cardCount': cardsRaw.length,
          };
        }
        return p;
      }).toList();

      // Pass turn to next player
      final activePlayers = players.where((p) => p['isKnockedOut'] != true).toList();
      final currentTurn = roomData['currentTurn'] ?? uid;
      int curIdx = activePlayers.indexWhere((p) => p['id'] == currentTurn);
      if (curIdx == -1) curIdx = 0;
      final direction = (roomData['turnDirection'] as int?) ?? 1;
      final nextIdx = (curIdx + direction) % activePlayers.length;
      final nextTurnId = activePlayers[nextIdx >= 0 ? nextIdx : activePlayers.length - 1]['id'];

      transaction.update(roomRef, {
        'topCard': playedCardMap,
        'activeColor': chosenColor?.name.toUpperCase() ?? playedCardMap['color'],
        'players': players,
        'currentTurn': nextTurnId,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    });
  }

  @override
  Future<void> drawCard({required String roomId}) async {
    final uid = await _ensureAuthenticated();
    final roomRef = _firestore.collection('rooms').doc(roomId);
    final handRef = roomRef.collection('private_hands').doc(uid);
    final deckRef = roomRef.collection('deck').doc('draw_pile');

    await _firestore.runTransaction((transaction) async {
      final deckSnap = await transaction.get(deckRef);
      List<dynamic> rawDeck = (deckSnap.data()?['cards'] as List<dynamic>? ?? []);

      if (rawDeck.isEmpty) {
        rawDeck = DeckGenerator.generateNoMercyDeck().map(_cardToMap).toList();
      }

      final drawnCard = rawDeck.removeAt(0);
      transaction.set(deckRef, {'cards': rawDeck});

      final handSnap = await transaction.get(handRef);
      final cardsRaw = (handSnap.data()?['cards'] as List<dynamic>? ?? []);
      cardsRaw.add(drawnCard);
      transaction.set(handRef, {'cards': cardsRaw});

      // Update card count
      final roomSnap = await transaction.get(roomRef);
      final roomData = roomSnap.data()!;
      final players = (roomData['players'] as List<dynamic>? ?? []).map((p) {
        if (p['id'] == uid) {
          return {
            ...p as Map<String, dynamic>,
            'cardCount': cardsRaw.length,
          };
        }
        return p;
      }).toList();

      transaction.update(roomRef, {
        'players': players,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    });
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
      return rawCards.map((c) => _mapToCard(c as Map<String, dynamic>)).toList();
    });
  }

  @override
  Future<String> getLiveKitVoiceToken(String roomId) async {
    return 'token_$roomId';
  }

  Map<String, dynamic> _cardToMap(UnoCard c) {
    return {
      'id': c.id,
      'color': c.color.name.toUpperCase(),
      'type': c.type.name.toUpperCase(),
      'numberValue': c.numberValue,
    };
  }

  UnoCard _mapToCard(Map<String, dynamic> map) {
    CardColor parseCol(String? col) {
      switch (col) {
        case 'RED': return CardColor.red;
        case 'BLUE': return CardColor.blue;
        case 'GREEN': return CardColor.green;
        case 'YELLOW': return CardColor.yellow;
        default: return CardColor.wild;
      }
    }

    CardType parseType(String? typeStr) {
      switch (typeStr) {
        case 'SKIP': return CardType.skip;
        case 'REVERSE': return CardType.reverse;
        case 'DRAWTWO':
        case 'DRAW_2': return CardType.drawTwo;
        case 'DRAWFOUR':
        case 'DRAW_4': return CardType.drawFour;
        case 'DRAWSIX':
        case 'DRAW_6': return CardType.drawSix;
        case 'DRAWTEN':
        case 'DRAW_10': return CardType.drawTen;
        case 'DISCARDALL':
        case 'DISCARD_ALL': return CardType.discardAll;
        case 'SKIPEVERYONE':
        case 'SKIP_EVERYONE': return CardType.skipEveryone;
        case 'ROULETTE': return CardType.roulette;
        case 'POINTSEVENSWAP':
        case 'POINT_SEVEN_SWAP': return CardType.pointSevenSwap;
        case 'POINTZEROPASS':
        case 'POINT_ZERO_PASS': return CardType.pointZeroPass;
        default: return CardType.number;
      }
    }

    return UnoCard(
      id: map['id'] ?? '',
      color: parseCol(map['color']),
      type: parseType(map['type']),
      numberValue: map['numberValue'],
    );
  }
}
