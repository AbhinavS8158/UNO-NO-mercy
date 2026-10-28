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

  static String? _staticCachedUserId;

  Future<String> _ensureAuthenticated() async {
    if (_auth.currentUser != null) {
      _staticCachedUserId = _auth.currentUser!.uid;
      return _staticCachedUserId!;
    }
    final cred = await _auth.signInAnonymously();
    _staticCachedUserId = cred.user!.uid;
    return _staticCachedUserId!;
  }

  @override
  String get currentUid => _auth.currentUser?.uid ?? _staticCachedUserId ?? 'player_me';

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
      'remainingDeckCount': remainingDeck.length,
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
        'remainingDeckCount': remainingDeck.length,
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
    String? discardAllTopCardId,
  }) async {
    final uid = await _ensureAuthenticated();
    final roomRef = _firestore.collection('rooms').doc(roomId);

    await _firestore.runTransaction((transaction) async {
      final roomSnap = await transaction.get(roomRef);
      if (!roomSnap.exists) return;
      final roomData = roomSnap.data()!;

      // STRICT TURN ENFORCEMENT: Only currentTurn player can play!
      final currentTurn = roomData['currentTurn'] as String?;
      if (currentTurn != null && currentTurn.isNotEmpty && currentTurn != uid) {
        throw Exception('ഇപ്പോൾ നിങ്ങളുടെ ടേൺ അല്ല!');
      }

      // 1. Retrieve player's hand
      final handRef = roomRef.collection('private_hands').doc(uid);
      final handSnap = await transaction.get(handRef);
      final cardsRaw = (handSnap.data()?['cards'] as List<dynamic>? ?? []);

      final cardIndex = cardsRaw.indexWhere((c) => c['id'] == cardId);
      if (cardIndex == -1) {
        throw Exception('ഈ കാർഡ് നിങ്ങളുടെ കയ്യിൽ ഇല്ല!');
      }

      final playedCardMap = cardsRaw[cardIndex];
      final playedCard = _mapToCard(playedCardMap as Map<String, dynamic>);

      // Validate play legality against current server room state (Stacking & Color rules)
      int currentPending = (roomData['drawCountPending'] as int?) ?? 0;
      final serverTopCard = _mapToCard(roomData['topCard'] as Map<String, dynamic>? ?? {});
      final serverActiveColor = _parseColor(roomData['activeColor'] as String?);
      if (!playedCard.canPlayOn(serverTopCard, pendingDrawCount: currentPending, activeColor: serverActiveColor)) {
        throw Exception('നിയമപ്രകാരം ഈ കാർഡ് ഇപ്പോൾ വെക്കാൻ കഴിയില്ല!');
      }

      // 2. Discard All Rule:
      // Discards every card in hand that matches this card's color!
      // The player chooses which card is placed on top of the discard pile.
      Map<String, dynamic> topCardToPlace = playedCardMap;
      if (playedCard.type == CardType.discardAll) {
        if (discardAllTopCardId != null) {
          final matchIndex = cardsRaw.indexWhere((c) => c['id'] == discardAllTopCardId);
          if (matchIndex != -1) {
            topCardToPlace = Map<String, dynamic>.from(cardsRaw[matchIndex] as Map<String, dynamic>);
          }
        }
        cardsRaw.removeWhere((c) => c['color'] == playedCardMap['color']);
      } else {
        cardsRaw.removeAt(cardIndex);
      }

      // 3. Stacking Penalty Calculation:
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
      } else if (activePlayers.isNotEmpty) {
        int steps = (playedCard.type == CardType.skip) ? 2 : 1;
        int nextIdx = (curIdx + direction * steps) % activePlayers.length;
        if (nextIdx < 0) nextIdx += activePlayers.length;
        nextTurnId = activePlayers[nextIdx]['id'];
      }

      // 5. 7's Swap & 0's Pass Target Preparation (ALL READS FIRST)
      String? actualSwapTarget = swapTargetPlayerId;
      if (playedCard.type == CardType.pointSevenSwap && (actualSwapTarget == null || actualSwapTarget.isEmpty) && activePlayers.length >= 2) {
        int nextIdx = (curIdx + direction) % activePlayers.length;
        if (nextIdx < 0) nextIdx += activePlayers.length;
        actualSwapTarget = activePlayers[nextIdx]['id'];
      }

      final targetHandRef = (playedCard.type == CardType.pointSevenSwap && actualSwapTarget != null)
          ? roomRef.collection('private_hands').doc(actualSwapTarget)
          : null;
      final targetHandSnap = targetHandRef != null ? await transaction.get(targetHandRef) : null;
      final targetCards = (targetHandSnap?.data()?['cards'] as List<dynamic>? ?? []);

      final List<List<dynamic>> allHands = [];
      if (playedCard.type == CardType.pointZeroPass && activePlayers.length >= 2) {
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
      }

      // 6. WRITES BEGIN HERE
      final Map<String, int> playerHandCounts = {};
      for (var p in rawPlayers) {
        playerHandCounts[p['id']] = (p['cardCount'] as int?) ?? 7;
      }

      if (playedCard.type == CardType.pointSevenSwap && actualSwapTarget != null && targetHandRef != null) {
        // Swap Hands!
        transaction.set(handRef, {'cards': targetCards});
        transaction.set(targetHandRef, {'cards': cardsRaw});
        playerHandCounts[uid] = targetCards.length;
        playerHandCounts[actualSwapTarget] = cardsRaw.length;
      } else if (playedCard.type == CardType.pointZeroPass && activePlayers.length >= 2) {
        // Shift hands by play direction:
        for (int i = 0; i < activePlayers.length; i++) {
          final targetIdx = (i + direction) % activePlayers.length;
          final adjustedTargetIdx = targetIdx < 0 ? targetIdx + activePlayers.length : targetIdx;
          final receivingPlayerId = activePlayers[adjustedTargetIdx]['id'] as String;
          final receivingHandRef = roomRef.collection('private_hands').doc(receivingPlayerId);
          transaction.set(receivingHandRef, {'cards': allHands[i]});
          playerHandCounts[receivingPlayerId] = allHands[i].length;
        }
      } else {
        // Normal card played
        transaction.set(handRef, {'cards': cardsRaw});
        playerHandCounts[uid] = cardsRaw.length;
      }

      // Update player summary count & check winner (0 cards = Win!) / Mercy rule (25 cards)
      String? winnerId;
      final updatedPlayers = rawPlayers.map((p) {
        final pId = p['id'] as String;
        final count = playerHandCounts[pId] ?? (p['cardCount'] as int? ?? 7);
        final isKnockedOut = (p['isKnockedOut'] == true) || (count >= 25);
        if (count == 0 && winnerId == null) {
          winnerId = pId;
        }
        return {
          ...p as Map<String, dynamic>,
          'cardCount': count,
          'isKnockedOut': isKnockedOut,
        };
      }).toList();

      transaction.update(roomRef, {
        'topCard': topCardToPlace,
        'activeColor': chosenColor?.name.toUpperCase() ?? topCardToPlace['color'],
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
      // 1. ALL READS MUST OCCUR FIRST
      final roomSnap = await transaction.get(roomRef);
      if (!roomSnap.exists) return;
      final roomData = roomSnap.data()!;

      // STRICT TURN ENFORCEMENT: Only currentTurn player can draw!
      final currentTurn = roomData['currentTurn'] as String?;
      if (currentTurn != null && currentTurn.isNotEmpty && currentTurn != uid) {
        return; // Reject draw if not player's turn
      }

      final deckSnap = await transaction.get(deckRef);
      final handSnap = await transaction.get(handRef);

      // 2. IN-MEMORY COMPUTATION (NO WRITES YET)
      int pending = (roomData['drawCountPending'] as int?) ?? 0;
      int countToDraw = pending > 0 ? pending : 1;

      List<dynamic> rawDeck = List<dynamic>.from(deckSnap.data()?['cards'] as List<dynamic>? ?? []);
      while (rawDeck.length < countToDraw) {
        rawDeck.addAll(DeckGenerator.generateNoMercyDeck().map(_cardToMap));
      }

      final drawnCards = rawDeck.sublist(0, countToDraw);
      final remainingDeck = rawDeck.sublist(countToDraw);

      final cardsRaw = List<dynamic>.from(handSnap.data()?['cards'] as List<dynamic>? ?? []);
      cardsRaw.addAll(drawnCards);

      // Mercy Rule: 25 cards or more = Knocked Out!
      bool isKnockedOut = cardsRaw.length >= 25;

      // Next player's turn
      final rawPlayers = (roomData['players'] as List<dynamic>? ?? []);
      final activePlayers = rawPlayers.where((p) => p['isKnockedOut'] != true).toList();
      String nextTurnId = uid;
      if (activePlayers.isNotEmpty) {
        int curIdx = activePlayers.indexWhere((p) => p['id'] == uid);
        if (curIdx == -1) curIdx = 0;
        final direction = (roomData['turnDirection'] as int?) ?? 1;
        int nextIdx = (curIdx + direction) % activePlayers.length;
        if (nextIdx < 0) nextIdx += activePlayers.length;
        nextTurnId = activePlayers[nextIdx]['id'];
      }

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

      // If penalty draw (e.g. +4, +6, +10), turn passes automatically.
      // If normal 1-card draw, player retains turn to play the card or pass!
      final turnAfterDraw = (countToDraw > 1) ? nextTurnId : uid;

      // 3. ALL WRITES OCCUR AFTER ALL READS
      transaction.set(deckRef, {'cards': remainingDeck});
      transaction.set(handRef, {'cards': isKnockedOut ? [] : cardsRaw});
      transaction.update(roomRef, {
        'players': updatedPlayers,
        'drawCountPending': 0, // Penalty consumed!
        'currentTurn': turnAfterDraw,
        'remainingDeckCount': remainingDeck.length,
        if (winnerId != null) 'winnerId': winnerId,
        if (winnerId != null) 'status': 'ended',
        'updatedAt': FieldValue.serverTimestamp(),
      });
    });
  }

  @override
  Future<void> passTurn({required String roomId}) async {
    final uid = await _ensureAuthenticated();
    final roomRef = _firestore.collection('rooms').doc(roomId);

    await _firestore.runTransaction((transaction) async {
      final roomSnap = await transaction.get(roomRef);
      if (!roomSnap.exists) return;
      final roomData = roomSnap.data()!;

      final currentTurn = roomData['currentTurn'] as String?;
      if (currentTurn != null && currentTurn.isNotEmpty && currentTurn != uid) {
        return; // Only active player can pass
      }

      final rawPlayers = (roomData['players'] as List<dynamic>? ?? []);
      final activePlayers = rawPlayers.where((p) => p['isKnockedOut'] != true).toList();
      String nextTurnId = uid;
      if (activePlayers.isNotEmpty) {
        int curIdx = activePlayers.indexWhere((p) => p['id'] == uid);
        if (curIdx == -1) curIdx = 0;
        final direction = (roomData['turnDirection'] as int?) ?? 1;
        int nextIdx = (curIdx + direction) % activePlayers.length;
        if (nextIdx < 0) nextIdx += activePlayers.length;
        nextTurnId = activePlayers[nextIdx]['id'];
      }

      transaction.update(roomRef, {
        'currentTurn': nextTurnId,
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

  static CardColor _parseColor(String? col) {
    switch (col?.toUpperCase()) {
      case 'RED': return CardColor.red;
      case 'BLUE': return CardColor.blue;
      case 'GREEN': return CardColor.green;
      case 'YELLOW': return CardColor.yellow;
      default: return CardColor.wild;
    }
  }

  static CardType _parseCardType(String? typeStr) {
    final clean = typeStr?.toUpperCase().replaceAll('_', '') ?? '';
    switch (clean) {
      case 'SKIP': return CardType.skip;
      case 'REVERSE': return CardType.reverse;
      case 'SKIPEVERYONE': return CardType.skipEveryone;
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
      case 'POINTSEVENSWAP':
      case 'SEVENSWAP': return CardType.pointSevenSwap;
      case 'POINTZEROPASS':
      case 'ZEROPASS': return CardType.pointZeroPass;
      default: return CardType.number;
    }
  }

  UnoCard _mapToCard(Map<String, dynamic> map) {
    return UnoCard(
      id: map['id'] ?? '',
      color: _parseColor(map['color']),
      type: _parseCardType(map['type']),
      numberValue: map['numberValue'],
    );
  }

  @override
  Future<void> sendVoiceSignal({
    required String roomId,
    required String targetId,
    required String senderId,
    required String type,
    required String data,
  }) async {
    await _firestore
        .collection('rooms')
        .doc(roomId)
        .collection('voice_signals')
        .add({
      'from': senderId,
      'to': targetId,
      'type': type,
      'data': data,
      'timestamp': FieldValue.serverTimestamp(),
    });
  }

  @override
  Stream<List<Map<String, dynamic>>> streamVoiceSignals({
    required String roomId,
    required String myPlayerId,
  }) {
    return _firestore
        .collection('rooms')
        .doc(roomId)
        .collection('voice_signals')
        .where('to', isEqualTo: myPlayerId)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) {
        final d = doc.data();
        return {
          'id': doc.id,
          'from': d['from']?.toString() ?? '',
          'to': d['to']?.toString() ?? '',
          'type': d['type']?.toString() ?? '',
          'data': d['data']?.toString() ?? '',
        };
      }).toList();
    });
  }

  @override
  Future<void> deleteVoiceSignal({
    required String roomId,
    required String signalId,
  }) async {
    try {
      await _firestore
          .collection('rooms')
          .doc(roomId)
          .collection('voice_signals')
          .doc(signalId)
          .delete();
    } catch (_) {}
  }
}
