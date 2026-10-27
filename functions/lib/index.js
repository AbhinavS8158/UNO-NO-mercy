"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.getVoiceToken = exports.callUno = exports.drawCard = exports.playCard = exports.startGame = exports.joinRoom = exports.createRoom = void 0;
const functions = require("firebase-functions");
const admin = require("firebase-admin");
const livekit_server_sdk_1 = require("livekit-server-sdk");
const deck_1 = require("./deck");
const gameEngine_1 = require("./gameEngine");
admin.initializeApp();
const db = admin.firestore();
// 1. CREATE ROOM
exports.createRoom = functions.https.onCall(async (data, context) => {
    if (!context.auth) {
        throw new functions.https.HttpsError('unauthenticated', 'ലോഗിൻ ചെയ്യണം.');
    }
    const userId = context.auth.uid;
    const playerName = data.playerName || 'Player';
    const gameRules = data.gameRules || 'no_mercy';
    // 6-character clean room code
    const roomCode = Math.random().toString(36).substring(2, 8).toUpperCase();
    const roomRef = db.collection('rooms').doc();
    const hostPlayer = {
        id: userId,
        name: playerName,
        cardCount: 0,
        isKnockedOut: false,
        isHost: true,
        calledUno: false,
    };
    const initialRoom = {
        id: roomRef.id,
        roomCode,
        status: 'waiting',
        currentTurn: userId,
        turnDirection: 1,
        drawCountPending: 0,
        players: [hostPlayer],
        gameRules,
        winnerId: null,
        createdAt: Date.now(),
        updatedAt: Date.now(),
    };
    await roomRef.set(initialRoom);
    return { roomId: roomRef.id, roomCode };
});
// 2. JOIN ROOM
exports.joinRoom = functions.https.onCall(async (data, context) => {
    if (!context.auth) {
        throw new functions.https.HttpsError('unauthenticated', 'ലോഗിൻ ചെയ്യണം.');
    }
    const userId = context.auth.uid;
    const playerName = data.playerName || 'Player';
    const roomCode = (data.roomCode || '').toUpperCase().trim();
    const querySnap = await db.collection('rooms').where('roomCode', '==', roomCode).limit(1).get();
    if (querySnap.empty) {
        throw new functions.https.HttpsError('not-found', 'റൂം കോഡ് തെറ്റാണ് അല്ലെങ്കിൽ റൂം നിലവിലില്ല.');
    }
    const roomDoc = querySnap.docs[0];
    const roomData = roomDoc.data();
    if (roomData.status !== 'waiting') {
        throw new functions.https.HttpsError('failed-precondition', 'ഗെയിം ഇതിനകം ആരംഭിച്ചു കഴിഞ്ഞു.');
    }
    if (roomData.players.length >= 6) {
        throw new functions.https.HttpsError('resource-exhausted', 'റൂമിൽ പരമാവധി കളിക്കാർ ആയി (മാക്സിമം 6).');
    }
    const existingPlayer = roomData.players.find((p) => p.id === userId);
    if (!existingPlayer) {
        const newPlayer = {
            id: userId,
            name: playerName,
            cardCount: 0,
            isKnockedOut: false,
            isHost: false,
            calledUno: false,
        };
        await roomDoc.ref.update({
            players: admin.firestore.FieldValue.arrayUnion(newPlayer),
            updatedAt: Date.now(),
        });
    }
    return { roomId: roomDoc.id, roomCode };
});
// 3. START GAME
exports.startGame = functions.https.onCall(async (data, context) => {
    if (!context.auth) {
        throw new functions.https.HttpsError('unauthenticated', 'ലോഗിൻ ചെയ്യണം.');
    }
    const { roomId } = data;
    const userId = context.auth.uid;
    const roomRef = db.collection('rooms').doc(roomId);
    const roomSnap = await roomRef.get();
    if (!roomSnap.exists) {
        throw new functions.https.HttpsError('not-found', 'റൂം കാണാനില്ല.');
    }
    const roomData = roomSnap.data();
    const host = roomData.players.find((p) => p.isHost);
    if (host?.id !== userId) {
        throw new functions.https.HttpsError('permission-denied', 'ഹോസ്റ്റിന് മാത്രമേ കളി ആരംഭിക്കാൻ കഴിയൂ.');
    }
    if (roomData.players.length < 2) {
        throw new functions.https.HttpsError('failed-precondition', 'കളി തുടങ്ങാൻ ചുരുങ്ങിയത് 2 കളിക്കാർ വേണം.');
    }
    // Generate and Shuffle full No Mercy 168 cards deck
    let deck = (0, deck_1.generateNoMercyDeck)();
    // Distribute 7 cards to each player
    const batch = db.batch();
    const updatedPlayers = [];
    for (const player of roomData.players) {
        const hand = deck.splice(0, 7);
        const handRef = roomRef.collection('private_hands').doc(player.id);
        batch.set(handRef, { cards: hand });
        updatedPlayers.push({
            ...player,
            cardCount: 7,
            isKnockedOut: false,
            calledUno: false,
        });
    }
    // Find a valid starting top card (preferably non-wild)
    let topCardIndex = deck.findIndex((c) => c.color !== 'WILD' && c.type === 'NUMBER');
    if (topCardIndex === -1)
        topCardIndex = 0;
    const topCard = deck.splice(topCardIndex, 1)[0];
    // Save remaining draw pile
    const deckRef = roomRef.collection('deck').doc('draw_pile');
    batch.set(deckRef, { cards: deck });
    // Update room public state
    batch.update(roomRef, {
        status: 'in_progress',
        players: updatedPlayers,
        topCard,
        activeColor: topCard.color,
        drawCountPending: 0,
        turnDirection: 1,
        currentTurn: updatedPlayers[0].id,
        updatedAt: Date.now(),
    });
    await batch.commit();
    return { success: true };
});
// 4. PLAY CARD
exports.playCard = functions.https.onCall(async (data, context) => {
    if (!context.auth)
        throw new functions.https.HttpsError('unauthenticated', 'ലോഗിൻ ചെയ്യണം.');
    const { roomId, cardId, chosenColor, swapTargetPlayerId } = data;
    const playerId = context.auth.uid;
    const roomRef = db.collection('rooms').doc(roomId);
    return await db.runTransaction(async (transaction) => {
        const roomSnap = await transaction.get(roomRef);
        if (!roomSnap.exists)
            throw new functions.https.HttpsError('not-found', 'റൂം നിലവിലില്ല.');
        const roomData = roomSnap.data();
        if (roomData.status !== 'in_progress') {
            throw new functions.https.HttpsError('failed-precondition', 'ഗെയിം നിലവിൽ നടക്കുന്നില്ല.');
        }
        if (roomData.currentTurn !== playerId) {
            throw new functions.https.HttpsError('failed-precondition', 'ഇത് നിങ്ങളുടെ ടേൺ അല്ല!');
        }
        // Retrieve Player's Private Hand
        const handRef = roomRef.collection('private_hands').doc(playerId);
        const handSnap = await transaction.get(handRef);
        const userCards = (handSnap.data()?.cards || []);
        const cardIndex = userCards.findIndex((c) => c.id === cardId);
        if (cardIndex === -1) {
            throw new functions.https.HttpsError('invalid-argument', 'ഈ കാർഡ് നിങ്ങളുടെ കൈയിലില്ല!');
        }
        const cardToPlay = userCards[cardIndex];
        // Check validity against top card and current stacking
        const isValid = (0, gameEngine_1.isCardPlayable)(cardToPlay, roomData.topCard, roomData.activeColor, roomData.drawCountPending);
        if (!isValid) {
            throw new functions.https.HttpsError('invalid-argument', 'ഈ കാർഡ് കളിക്കാൻ സാധിക്കില്ല!');
        }
        // Remove played card from hand
        let cardsToRemove = [cardToPlay];
        if (cardToPlay.type === 'DISCARD_ALL') {
            // No Mercy Discard All rule: remove all cards matching this color!
            const matchingColorCards = userCards.filter((c) => c.color === cardToPlay.color);
            cardsToRemove = matchingColorCards;
        }
        const remainingHand = userCards.filter((c) => !cardsToRemove.some((rem) => rem.id === c.id));
        transaction.set(handRef, { cards: remainingHand });
        // Handle No Mercy 7 Swap Hand Rule
        if (cardToPlay.type === 'POINT_SEVEN_SWAP' && swapTargetPlayerId) {
            const targetHandRef = roomRef.collection('private_hands').doc(swapTargetPlayerId);
            const targetHandSnap = await transaction.get(targetHandRef);
            const targetCards = (targetHandSnap.data()?.cards || []);
            // Swap hands!
            transaction.set(handRef, { cards: targetCards });
            transaction.set(targetHandRef, { cards: remainingHand });
        }
        // Update Player summary count
        const updatedPlayers = roomData.players.map((p) => {
            if (p.id === playerId) {
                return {
                    ...p,
                    cardCount: cardToPlay.type === 'POINT_SEVEN_SWAP' && swapTargetPlayerId ? p.cardCount : remainingHand.length,
                    calledUno: remainingHand.length === 1 ? p.calledUno : false,
                };
            }
            return p;
        });
        // Determine Direction and Stacking
        let newDirection = roomData.turnDirection;
        let newPendingDraw = roomData.drawCountPending;
        if (cardToPlay.type === 'REVERSE') {
            newDirection = newDirection === 1 ? -1 : 1;
        }
        const penalty = (0, gameEngine_1.getPenaltyCount)(cardToPlay);
        if (penalty > 0) {
            newPendingDraw += penalty;
        }
        // Determine Next Turn
        let steps = 1;
        if (cardToPlay.type === 'SKIP')
            steps = 2;
        if (cardToPlay.type === 'SKIP_EVERYONE')
            steps = 0; // Current player plays again!
        const nextTurnId = steps === 0
            ? playerId
            : (0, gameEngine_1.getNextPlayerId)(updatedPlayers, playerId, newDirection, steps);
        // Active color logic (if Wild, use player chosen color)
        const newActiveColor = cardToPlay.color === 'WILD' ? chosenColor || 'RED' : cardToPlay.color;
        // Check Win Condition
        const winnerId = (0, gameEngine_1.determineWinner)(updatedPlayers);
        const newStatus = winnerId ? 'ended' : 'in_progress';
        transaction.update(roomRef, {
            topCard: cardToPlay,
            activeColor: newActiveColor,
            currentTurn: nextTurnId,
            turnDirection: newDirection,
            drawCountPending: newPendingDraw,
            players: updatedPlayers,
            winnerId: winnerId || null,
            status: newStatus,
            updatedAt: Date.now(),
        });
        return { success: true, winnerId };
    });
});
// 5. DRAW CARD (Includes Stacking Penalty Consumption & 25 Mercy Rule)
exports.drawCard = functions.https.onCall(async (data, context) => {
    if (!context.auth)
        throw new functions.https.HttpsError('unauthenticated', 'ലോഗിൻ ചെയ്യണം.');
    const { roomId } = data;
    const playerId = context.auth.uid;
    const roomRef = db.collection('rooms').doc(roomId);
    return await db.runTransaction(async (transaction) => {
        const roomSnap = await transaction.get(roomRef);
        if (!roomSnap.exists)
            throw new functions.https.HttpsError('not-found', 'റൂം നിലവിലില്ല.');
        const roomData = roomSnap.data();
        if (roomData.currentTurn !== playerId) {
            throw new functions.https.HttpsError('failed-precondition', 'ഇത് നിങ്ങളുടെ ടേൺ അല്ല!');
        }
        const deckRef = roomRef.collection('deck').doc('draw_pile');
        const deckSnap = await transaction.get(deckRef);
        let drawPile = (deckSnap.data()?.cards || []);
        // How many cards to draw? (If pending stacking penalty exists, draw that amount, else 1)
        const cardsToDrawCount = roomData.drawCountPending > 0 ? roomData.drawCountPending : 1;
        // If deck has fewer cards, re-shuffle a fresh deck
        if (drawPile.length < cardsToDrawCount) {
            const freshDeck = (0, deck_1.generateNoMercyDeck)();
            drawPile = [...drawPile, ...freshDeck];
        }
        const drawnCards = drawPile.splice(0, cardsToDrawCount);
        transaction.set(deckRef, { cards: drawPile });
        // Add to player's private hand
        const handRef = roomRef.collection('private_hands').doc(playerId);
        const handSnap = await transaction.get(handRef);
        const currentCards = (handSnap.data()?.cards || []);
        const updatedHand = [...currentCards, ...drawnCards];
        // Check Mercy Rule (25 Cards Limit)
        const isKnockedOut = (0, gameEngine_1.checkMercyElimination)(updatedHand.length);
        if (isKnockedOut) {
            // Discard their cards into deck / graveyard
            transaction.set(handRef, { cards: [] });
        }
        else {
            transaction.set(handRef, { cards: updatedHand });
        }
        const updatedPlayers = roomData.players.map((p) => {
            if (p.id === playerId) {
                return {
                    ...p,
                    cardCount: isKnockedOut ? 0 : updatedHand.length,
                    isKnockedOut,
                };
            }
            return p;
        });
        const nextTurnId = (0, gameEngine_1.getNextPlayerId)(updatedPlayers, playerId, roomData.turnDirection, 1);
        const winnerId = (0, gameEngine_1.determineWinner)(updatedPlayers);
        transaction.update(roomRef, {
            players: updatedPlayers,
            drawCountPending: 0,
            currentTurn: nextTurnId,
            winnerId: winnerId || null,
            status: winnerId ? 'ended' : 'in_progress',
            updatedAt: Date.now(),
        });
        return {
            cardsDrawn: drawnCards.length,
            isKnockedOut,
            winnerId,
        };
    });
});
// 6. CALL UNO
exports.callUno = functions.https.onCall(async (data, context) => {
    if (!context.auth)
        throw new functions.https.HttpsError('unauthenticated', 'ലോഗിൻ ചെയ്യണം.');
    const { roomId } = data;
    const playerId = context.auth.uid;
    const roomRef = db.collection('rooms').doc(roomId);
    const roomSnap = await roomRef.get();
    if (!roomSnap.exists)
        throw new functions.https.HttpsError('not-found', 'റൂം നിലവിലില്ല.');
    const roomData = roomSnap.data();
    const updatedPlayers = roomData.players.map((p) => {
        if (p.id === playerId)
            return { ...p, calledUno: true };
        return p;
    });
    await roomRef.update({ players: updatedPlayers });
    return { success: true };
});
// 7. SECURE LIVEKIT VOICE TOKEN
exports.getVoiceToken = functions.https.onCall(async (data, context) => {
    if (!context.auth)
        throw new functions.https.HttpsError('unauthenticated', 'ലോഗിൻ ചെയ്യണം.');
    const { roomId } = data;
    const uid = context.auth.uid;
    const roomSnap = await db.collection('rooms').doc(roomId).get();
    if (!roomSnap.exists)
        throw new functions.https.HttpsError('not-found', 'റൂം നിലവിലില്ല.');
    const roomData = roomSnap.data();
    const isMember = roomData.players.some((p) => p.id === uid);
    if (!isMember) {
        throw new functions.https.HttpsError('permission-denied', 'നിങ്ങൾ ഈ റൂമിലെ അംഗമല്ല.');
    }
    const apiKey = process.env.LIVEKIT_API_KEY || 'devkey';
    const apiSecret = process.env.LIVEKIT_API_SECRET || 'secret_livekit_key_uno_no_mercy';
    const at = new livekit_server_sdk_1.AccessToken(apiKey, apiSecret, {
        identity: uid,
        name: context.auth.token.name || `Player_${uid.substring(0, 4)}`,
    });
    at.addGrant({
        roomJoin: true,
        room: roomData.roomCode,
        canPublish: true,
        canSubscribe: true,
    });
    return { token: at.toJwt() };
});
//# sourceMappingURL=index.js.map