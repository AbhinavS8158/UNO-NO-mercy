import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/game_room.dart';
import '../models/uno_card.dart';
import '../models/deck_generator.dart';
import '../models/chat_message.dart';
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
    final roomCode = 'UNO${DateTime.now().millisecondsSinceEpoch.toString().substring(8)}';
    final roomRef = _firestore.collection('rooms').doc();

    final hostPlayer = PlayerSummary(
      id: uid,
      name: playerName,
      cardCount: 7,
      isHost: true,
    );

    final fullDeck = DeckGenerator.generateNoMercyDeck();
    final hostHand = fullDeck.sublist(0, 7);

    int topIndex = 7;
    while (topIndex < fullDeck.length && fullDeck[topIndex].isWild) {
      topIndex++;
    }
    final startingTopCard = fullDeck[topIndex];

    final remainingDeck = List<UnoCard>.from(fullDeck);
    remainingDeck.removeRange(0, 7);
    remainingDeck.remove(startingTopCard);

    final roomData = {
      'roomCode': roomCode,
      'status': 'waiting',
      'currentTurn': uid,
      'turnDirection': 1,
      'topCard': _cardToMap(startingTopCard),
      'activeColor': startingTopCard.color.name.toUpperCase(),
      'drawCountPending': 0,
      'players': [hostPlayer.toMap()],
      'gameRules': rules,
      'winnerId': null,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    };

    await roomRef.set(roomData);
    await roomRef.collection('private_hands').doc(uid).set({
      'cards': hostHand.map(_cardToMap).toList(),
    });
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
      final deckRef = roomDoc.reference.collection('deck').doc('draw_pile');
      final deckSnap = await deckRef.get();
      List<dynamic> rawDeck = (deckSnap.data()?['cards'] as List<dynamic>? ?? []);

      if (rawDeck.length < 7) {
        rawDeck = DeckGenerator.generateNoMercyDeck().map(_cardToMap).toList();
      }

      final playerHand = rawDeck.sublist(0, 7);
      final remainingDeck = rawDeck.sublist(7);

      await deckRef.set({'cards': remainingDeck});
      await roomDoc.reference.collection('private_hands').doc(uid).set({
        'cards': playerHand,
      });

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

      // 1. Retrieve player's hand
      final handRef = roomRef.collection('private_hands').doc(uid);
      final handSnap = await transaction.get(handRef);
      final cardsRaw = (handSnap.data()?['cards'] as List<dynamic>? ?? []);

      final cardIndex = cardsRaw.indexWhere((c) => c['id'] == cardId);
      if (cardIndex == -1) return;

      final playedCardMap = cardsRaw[cardIndex];
      final playedCard = _mapToCard(playedCardMap as Map<String, dynamic>);

      // 2. Discard All Rule:
      // Discards every card in hand that matches this card's color!
      if (playedCard.type == CardType.discardAll) {
        cardsRaw.removeWhere((c) => c['color'] == playedCardMap['color']);
      } else {
        cardsRaw.removeAt(cardIndex);
      }
      transaction.set(handRef, {'cards': cardsRaw});

      // 3. Stacking Penalty Calculation:
      int currentPending = (roomData['drawCountPending'] as int?) ?? 0;
      if (playedCard.isDrawPenalty) {
        currentPending += playedCard.penaltyCount;
      }

      // 4. Direction & Turn calculation
      int direction = (roomData['turnDirection'] as int?) ?? 1;
      if (playedCard.type == CardType.reverse || playedCard.type == CardType.wildReverseDrawFour) {
        direction = direction == 1 ? -1 : 1;
      }

      final rawPlayers = (roomData['players'] as List<dynamic>? ?? []);
      final activePlayers = rawPlayers.where((p) => p['isKnockedOut'] != true).toList();

      int curIdx = activePlayers.indexWhere((p) => p['id'] == uid);
      if (curIdx == -1) curIdx = 0;

      String nextTurnId = uid;
      if (playedCard.type == CardType.skipEveryone) {
        // Skip Everyone: skips ALL other players, current player plays again!
        nextTurnId = uid;
      } else {
        int steps = (playedCard.type == CardType.skip) ? 2 : 1;
        int nextIdx = (curIdx + direction * steps) % activePlayers.length;
        if (nextIdx < 0) nextIdx += activePlayers.length;
        nextTurnId = activePlayers[nextIdx]['id'];
      }

      // 5. 7's Swap Rule
      if (playedCard.type == CardType.pointSevenSwap && swapTargetPlayerId != null) {
        final targetHandRef = roomRef.collection('private_hands').doc(swapTargetPlayerId);
        final targetHandSnap = await transaction.get(targetHandRef);
        final targetCards = (targetHandSnap.data()?['cards'] as List<dynamic>? ?? []);

        // Swap Hands!
        transaction.set(handRef, {'cards': targetCards});
        transaction.set(targetHandRef, {'cards': cardsRaw});
      }

      // 6. 0's Pass Rule: Pass all hands in current direction of play
      if (playedCard.type == CardType.pointZeroPass && activePlayers.length >= 2) {
        final List<List<dynamic>> allHands = [];
        for (var p in activePlayers) {
          final pId = p['id'] as String;
          if (pId == uid) {
            allHands.add(cardsRaw);
          } else {
            final pRef = roomRef.collection('private_hands').doc(pId);
            final pSnap = await transaction.get(pRef);
            allHands.add(pSnap.data()?['cards'] as List<dynamic>? ?? []);
          }
        }

        // Shift hands by play direction
        for (int i = 0; i < activePlayers.length; i++) {
          final targetIdx = (i + direction) % activePlayers.length;
          final adjustedTargetIdx = targetIdx < 0 ? targetIdx + activePlayers.length : targetIdx;
          final receivingPlayerId = activePlayers[adjustedTargetIdx]['id'] as String;
          final receivingHandRef = roomRef.collection('private_hands').doc(receivingPlayerId);
          transaction.set(receivingHandRef, {'cards': allHands[i]});
        }
      }

      // Update player summary count & check winner (0 cards = Win!)
      String? winnerId;
      final updatedPlayers = rawPlayers.map((p) {
        if (p['id'] == uid) {
          final count = cardsRaw.length;
          if (count == 0) winnerId = uid;
          return {
            ...p as Map<String, dynamic>,
            'cardCount': count,
          };
        }
        return p;
      }).toList();

      transaction.update(roomRef, {
        'topCard': playedCardMap,
        'activeColor': chosenColor?.name.toUpperCase() ?? playedCardMap['color'],
        'drawCountPending': currentPending,
        'turnDirection': direction,
        'currentTurn': nextTurnId,
        'players': updatedPlayers,
        if (winnerId != null) 'winnerId': winnerId,
        if (winnerId != null) 'status': 'ended',
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
      final roomSnap = await transaction.get(roomRef);
      if (!roomSnap.exists) return;
      final roomData = roomSnap.data()!;

      // Stacking Rule: If penalty is accumulated (e.g. +4, +6, +10 = 20),
      // the targeted player MUST draw ALL accumulated cards!
      int pending = (roomData['drawCountPending'] as int?) ?? 0;
      int countToDraw = pending > 0 ? pending : 1;

      final deckSnap = await transaction.get(deckRef);
      List<dynamic> rawDeck = (deckSnap.data()?['cards'] as List<dynamic>? ?? []);

      while (rawDeck.length < countToDraw) {
        rawDeck.addAll(DeckGenerator.generateNoMercyDeck().map(_cardToMap));
      }

      final drawnCards = rawDeck.sublist(0, countToDraw);
      final remainingDeck = rawDeck.sublist(countToDraw);
      transaction.set(deckRef, {'cards': remainingDeck});

      final handSnap = await transaction.get(handRef);
      final cardsRaw = (handSnap.data()?['cards'] as List<dynamic>? ?? []);
      cardsRaw.addAll(drawnCards);

      // Mercy Rule: 25 cards or more = Knocked Out!
      bool isKnockedOut = cardsRaw.length >= 25;
      if (isKnockedOut) {
        transaction.set(handRef, {'cards': []}); // Eliminate cards
      } else {
        transaction.set(handRef, {'cards': cardsRaw});
      }

      // Next player's turn
      final rawPlayers = (roomData['players'] as List<dynamic>? ?? []);
      final activePlayers = rawPlayers.where((p) => p['isKnockedOut'] != true).toList();
      int curIdx = activePlayers.indexWhere((p) => p['id'] == uid);
      if (curIdx == -1) curIdx = 0;
      final direction = (roomData['turnDirection'] as int?) ?? 1;
      int nextIdx = (curIdx + direction) % activePlayers.length;
      if (nextIdx < 0) nextIdx += activePlayers.length;
      final nextTurnId = activePlayers[nextIdx]['id'];

      final updatedPlayers = rawPlayers.map((p) {
        if (p['id'] == uid) {
          return {
            ...p as Map<String, dynamic>,
            'cardCount': isKnockedOut ? 0 : cardsRaw.length,
            'isKnockedOut': isKnockedOut,
          };
        }
        return p;
      }).toList();

      // Check if only 1 player remains standing (Last Man Standing Win!)
      final remainingStanding = updatedPlayers.where((p) => p['isKnockedOut'] != true).toList();
      String? winnerId = remainingStanding.length == 1 ? remainingStanding.first['id'] : null;

      transaction.update(roomRef, {
        'players': updatedPlayers,
        'drawCountPending': 0, // Penalty consumed!
        'currentTurn': nextTurnId,
        if (winnerId != null) 'winnerId': winnerId,
        if (winnerId != null) 'status': 'ended',
        'updatedAt': FieldValue.serverTimestamp(),
      });
    });
  }

  @override
  Future<void> callUno({required String roomId, required String callerName}) async {
    await _firestore.collection('rooms').doc(roomId).update({
      'lastUnoCall': {
        'callerName': callerName,
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      },
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

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

  @override
  Future<void> sendChatMessage({
    required String roomId,
    required String senderName,
    required String text,
  }) async {
    final uid = await _ensureAuthenticated();
    await _firestore.collection('rooms').doc(roomId).collection('chat').add({
      'senderId': uid,
      'senderName': senderName,
      'text': text,
      'timestamp': FieldValue.serverTimestamp(),
    });
  }

  @override
  Stream<List<ChatMessage>> streamChatMessages(String roomId) {
    return _firestore
        .collection('rooms')
        .doc(roomId)
        .collection('chat')
        .orderBy('timestamp', descending: false)
        .snapshots()
        .map((snap) {
      return snap.docs.map((doc) {
        final data = doc.data();
        final ts = (data['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now();
        return ChatMessage(
          id: doc.id,
          senderId: data['senderId'] ?? '',
          senderName: data['senderName'] ?? 'Player',
          text: data['text'] ?? '',
          timestamp: ts,
        );
      }).toList();
    });
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
        case 'SKIPEVERYONE':
        case 'SKIP_EVERYONE': return CardType.skipEveryone;
        case 'DRAWTWO':
        case 'DRAW_2': return CardType.drawTwo;
        case 'DRAWFOUR':
        case 'DRAW_4': return CardType.drawFour;
        case 'DRAWSIX':
        case 'DRAW_6': return CardType.drawSix;
        case 'DRAWTEN':
        case 'DRAW_10': return CardType.drawTen;
        case 'WILDREVERSEDRAWFOUR':
        case 'WILD_REVERSE_DRAW_4': return CardType.wildReverseDrawFour;
        case 'COLORROULETTE':
        case 'COLOR_ROULETTE': return CardType.colorRoulette;
        case 'DISCARDALL':
        case 'DISCARD_ALL': return CardType.discardAll;
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
