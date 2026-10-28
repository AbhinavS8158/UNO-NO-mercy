import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/theme/uno_colors.dart';
import '../../models/uno_card.dart';
import '../../models/game_room.dart';
import '../../models/chat_message.dart';
import '../../services/game_service.dart';
import '../../services/firebase_game_service.dart';
import '../../services/voice_service.dart';
import '../widgets/card_fan_layout.dart';
import '../widgets/uno_card_widget.dart';
import '../widgets/voice_control_bar.dart';
import '../widgets/chat_overlay_dialog.dart';
import '../widgets/rules_dialog.dart';
import 'table_center_view.dart';
import 'animated_card_overlay.dart';

class GameScreen extends StatefulWidget {
  final String roomId;
  final String roomCode;
  final String playerName;

  const GameScreen({
    super.key,
    this.roomId = '',
    this.roomCode = 'UNO7K2',
    this.playerName = 'Player 1',
  });

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> {
  late final IGameService _gameService;
  final IVoiceService _voiceService = LiveKitVoiceService();

  StreamSubscription<GameRoom>? _roomSubscription;
  StreamSubscription<List<UnoCard>>? _handSubscription;
  StreamSubscription<List<ChatMessage>>? _chatSubscription;

  // In-Game 5-second Toast Speech Bubble
  ChatMessage? _activeSpeechBubble;
  Timer? _speechBubbleTimer;
  double _bubbleOpacity = 1.0;

  // 2-Second Universal UNO Call Alert
  String? _activeUnoAlertMessage;
  Timer? _unoAlertTimer;
  double _unoAlertOpacity = 1.0;
  int? _lastProcessedUnoCallTimestamp;

  // Active game states
  UnoCard _topCard = const UnoCard(
    id: 'top_init',
    color: CardColor.red,
    type: CardType.number,
    numberValue: 7,
  );
  String? _previousTopCardId;
  CardColor _activeColor = CardColor.red;
  int _pendingDrawCount = 0;
  bool _isClockwise = true;
  int _remainingDeckCount = 140;
  String _currentTurn = '';

  // Player's Own Hand (Unique cards)
  List<UnoCard> _playerHand = [];
  UnoCard? _selectedCard;
  bool _hasDrawnThisTurn = false;

  // Active Real Opponents (Only players who actually joined this room!)
  List<PlayerSummary> _allPlayers = [];
  List<PlayerSummary> _opponents = [];
  Set<String> _activeSpeakers = {};

  // Flying Card Animation
  Widget? _flyingCardWidget;

  String get _myUid {
    if (_gameService is FirebaseGameService) {
      return (_gameService as FirebaseGameService).currentUid;
    }
    return 'player_me';
  }

  @override
  void initState() {
    super.initState();
    if (Firebase.apps.isNotEmpty) {
      _gameService = FirebaseGameService();
    } else {
      _gameService = LocalGameService();
    }

    _initGameStreams();
    _initVoiceChannel();
  }

  void _initGameStreams() {
    final effectiveRoomId = widget.roomId.isNotEmpty ? widget.roomId : widget.roomCode;

    // 1. Listen to Real-time Room Updates (Top card, turns, actual players)
    _roomSubscription = _gameService.streamRoom(effectiveRoomId).listen((room) {
      if (!mounted) return;
      setState(() {
        _topCard = room.topCard;
        _activeColor = room.activeColor;
        _pendingDrawCount = room.drawCountPending;
        _isClockwise = room.turnDirection == 1;
        _currentTurn = room.currentTurn;
        _remainingDeckCount = room.remainingDeckCount;
        if (room.currentTurn != _myUid) {
          _hasDrawnThisTurn = false;
        }

        // Keep full list of players in room
        _allPlayers = room.players;

        // Filter out ME: Show ONLY real opponents who joined this room!
        _opponents = room.players.where((p) => p.id != _myUid).toList();

        // Notify if 7's SWAP or 0's PASS was played by another player
        if (_previousTopCardId != null && _previousTopCardId != room.topCard.id && room.currentTurn == _myUid) {
          if (room.topCard.type == CardType.pointSevenSwap) {
            ScaffoldMessenger.of(context).hideCurrentSnackBar();
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('⇄ 7 SWAP! കാർഡുകൾ പരസ്പരം കൈമാറി!'),
                backgroundColor: Colors.purpleAccent,
                duration: Duration(seconds: 2),
              ),
            );
          } else if (room.topCard.type == CardType.pointZeroPass) {
            ScaffoldMessenger.of(context).hideCurrentSnackBar();
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('🔄 0 PASS! കാർഡുകൾ അടുത്തയാൾക്ക് കൈമാറി!'),
                backgroundColor: Colors.teal,
                duration: Duration(seconds: 2),
              ),
            );
          }
        }
        _previousTopCardId = room.topCard.id;

        // Synchronize WebRTC voice peers with players in room
        _voiceService.syncRoomPlayers(room.players.map((p) => p.id).toList());

        // Check if game has ended
        if (room.winnerId != null) {
          _showWinnerDialog(room.winnerId!);
        }

        // Universal Real-time UNO Call across ALL devices!
        if (room.lastUnoCall != null) {
          final ts = room.lastUnoCall!['timestamp'] as int? ?? 0;
          if (_lastProcessedUnoCallTimestamp == null || ts > _lastProcessedUnoCallTimestamp!) {
            _lastProcessedUnoCallTimestamp = ts;
            final caller = room.lastUnoCall!['callerName'] ?? 'Player';
            _triggerUnoCallBanner("$caller UNO വിളിച്ചു കേട്ടോ.....");
          }
        }
      });
    });

    // 2. Listen to My Own Unique Private Hand
    _handSubscription = _gameService.streamPrivateHand(effectiveRoomId, _myUid).listen((hand) {
      if (!mounted) return;
      setState(() {
        _playerHand = hand;
        // Check 25 cards mercy rule
        if (_playerHand.length >= 25) {
          _showMercyKnockoutDialog();
        }
      });
    });

    // 3. Listen to Real-time In-Game Chat & Taunts (5-second fade bubble)
    bool isFirstLoad = true;
    _chatSubscription = _gameService.streamChatMessages(effectiveRoomId).listen((messages) {
      if (!mounted) return;
      if (messages.isNotEmpty) {
        if (!isFirstLoad) {
          final latest = messages.last;
          _showInGameSpeechBubble(latest);
        }
        isFirstLoad = false;
      }
    });
  }

  void _showInGameSpeechBubble(ChatMessage msg) {
    _speechBubbleTimer?.cancel();
    setState(() {
      _activeSpeechBubble = msg;
      _bubbleOpacity = 1.0;
    });

    // Fade out after 4.5s and remove at 5s
    _speechBubbleTimer = Timer(const Duration(milliseconds: 4500), () {
      if (mounted) setState(() => _bubbleOpacity = 0.0);
      Timer(const Duration(milliseconds: 500), () {
        if (mounted) setState(() => _activeSpeechBubble = null);
      });
    });
  }

  void _triggerUnoCallBanner(String message) {
    _unoAlertTimer?.cancel();
    setState(() {
      _activeUnoAlertMessage = message;
      _unoAlertOpacity = 1.0;
    });

    // Fade out at 1.5s, disappear at 2.0s!
    _unoAlertTimer = Timer(const Duration(milliseconds: 1500), () {
      if (mounted) setState(() => _unoAlertOpacity = 0.0);
      Timer(const Duration(milliseconds: 500), () {
        if (mounted) setState(() => _activeUnoAlertMessage = null);
      });
    });
  }

  void _initVoiceChannel() {
    final effectiveRoomId = widget.roomId.isNotEmpty ? widget.roomId : widget.roomCode;
    _voiceService.connectToRoom(
      gameService: _gameService,
      roomId: effectiveRoomId,
      myPlayerId: _gameService.currentUid,
    );
    _voiceService.activeSpeakersStream.listen((speakers) {
      if (mounted) {
        setState(() => _activeSpeakers = speakers);
      }
    });
  }

  @override
  void dispose() {
    _unoAlertTimer?.cancel();
    _speechBubbleTimer?.cancel();
    _chatSubscription?.cancel();
    _roomSubscription?.cancel();
    _handSubscription?.cancel();
    _voiceService.disconnect();
    super.dispose();
  }

  void _handleCardSelected(UnoCard card) {
    final isMyTurn = _currentTurn == _myUid || _currentTurn.isEmpty;
    if (!isMyTurn) {
      String activePlayerName = 'Opponent';
      final activeMatch = _allPlayers.where((p) => p.id == _currentTurn);
      if (activeMatch.isNotEmpty) {
        activePlayerName = activeMatch.first.name;
      }
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('ഇപ്പോൾ $activePlayerName-ന്റെ ടേൺ ആണ്! നിങ്ങളുടെ ടേൺ ആകുമ്പോൾ മാത്രമേ കാർഡ് വെക്കാൻ സാധിക്കൂ.'),
          backgroundColor: Colors.redAccent,
          duration: const Duration(seconds: 2),
        ),
      );
      return;
    }
    setState(() {
      _selectedCard = (_selectedCard?.id == card.id) ? null : card;
    });
  }

  void _handleCardPlayed(UnoCard card) async {
    final isMyTurn = _currentTurn == _myUid || _currentTurn.isEmpty;
    if (!isMyTurn) {
      String activePlayerName = 'Opponent';
      final activeMatch = _allPlayers.where((p) => p.id == _currentTurn);
      if (activeMatch.isNotEmpty) {
        activePlayerName = activeMatch.first.name;
      }
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('ഇപ്പോൾ $activePlayerName-ന്റെ ടേൺ ആണ്! കാർഡ് വെക്കാൻ കഴിയില്ല.'),
          backgroundColor: Colors.redAccent,
          duration: const Duration(seconds: 2),
        ),
      );
      return;
    }

    final effectiveRoomId = widget.roomId.isNotEmpty ? widget.roomId : widget.roomCode;

    // Validate Playability
    if (!card.canPlayOn(_topCard, pendingDrawCount: _pendingDrawCount)) {
      String reason = '${card.displayLabel} ഈ സമയത്ത് കളിക്കാൻ കഴിയില്ല!';
      if (_pendingDrawCount > 0) {
        reason = '+$_pendingDrawCount പെനാൽറ്റി നിലവിലുണ്ട്! +${_topCard.penaltyCount} അല്ലെങ്കിൽ അതിൽ കൂടുതൽ ഉള്ള ഡ്രോ കാർഡ് മാത്രമേ സ്റ്റാക്ക് ചെയ്യാൻ പറ്റൂ (അല്ലെങ്കിൽ കാർഡ് ഡ്രോ ചെയ്യുക).';
      } else if (card.isDrawPenalty && _topCard.isDrawPenalty && card.penaltyCount < _topCard.penaltyCount) {
        reason = '+${_topCard.penaltyCount}-ന് മുകളിൽ ചെറിയ പെനാൽറ്റി കാർഡ് (${card.displayLabel}) വെക്കാൻ കഴിയില്ല! (No Lower Stacking)';
      }
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(reason, style: const TextStyle(fontWeight: FontWeight.bold)),
          backgroundColor: Colors.redAccent,
          duration: const Duration(seconds: 2),
        ),
      );
      return;
    }

    // 1. If Wild card, prompt for color selection
    CardColor chosenColor = card.color;
    if (card.isWild) {
      final selectedColor = await _showColorPickerDialog();
      if (selectedColor == null) return; // User cancelled
      chosenColor = selectedColor;
    }

    // 2. If 7's Swap card, prompt for target player selection
    String? swapTargetPlayerId;
    if (card.type == CardType.pointSevenSwap && _opponents.isNotEmpty) {
      if (_opponents.length == 1) {
        swapTargetPlayerId = _opponents.first.id;
      } else {
        swapTargetPlayerId = await _showSwapTargetDialog();
      }
    }

    // 3. If Discard All card, ask player which matching card should be placed on TOP!
    String? discardAllTopCardId;
    UnoCard cardToAnimate = card;
    if (card.type == CardType.discardAll) {
      final matchingColorCards = _playerHand.where((c) => c.color == card.color).toList();
      if (matchingColorCards.length > 1) {
        final chosenTopCard = await _showDiscardAllTopCardDialog(matchingColorCards, card);
        if (chosenTopCard == null) return; // User cancelled
        discardAllTopCardId = chosenTopCard.id;
        cardToAnimate = chosenTopCard;
      } else {
        discardAllTopCardId = card.id;
      }
    }

    final screenSize = MediaQuery.of(context).size;
    final startOffset = Offset(screenSize.width * 0.4, screenSize.height * 0.7);
    final endOffset = Offset(screenSize.width * 0.5 - 45, screenSize.height * 0.38);

    setState(() {
      _flyingCardWidget = FlyingCardAnimation(
        card: cardToAnimate,
        startOffset: startOffset,
        endOffset: endOffset,
        onCompleted: () async {
          setState(() {
            _flyingCardWidget = null;
            _selectedCard = null;
            _hasDrawnThisTurn = false;
          });
          // Commit move to Firebase Server
          await _gameService.playCard(
            roomId: effectiveRoomId,
            cardId: card.id,
            chosenColor: chosenColor,
            swapTargetPlayerId: swapTargetPlayerId,
            discardAllTopCardId: discardAllTopCardId,
          );

          if (card.type == CardType.skipEveryone && mounted) {
            ScaffoldMessenger.of(context).hideCurrentSnackBar();
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('⚡ SKIP EVERYONE! ബാക്കി എല്ലാവരെയും സ്കിപ്പ് ചെയ്തു. നിങ്ങൾ വീണ്ടും കളിക്കുക!'),
                backgroundColor: Colors.amber,
                duration: Duration(seconds: 2),
              ),
            );
          } else if (card.type == CardType.pointSevenSwap && mounted) {
            ScaffoldMessenger.of(context).hideCurrentSnackBar();
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('⇄ 7 SWAP! കാർഡുകൾ പരസ്പരം കൈമാറി!'),
                backgroundColor: Colors.purpleAccent,
                duration: Duration(seconds: 2),
              ),
            );
          } else if (card.type == CardType.pointZeroPass && mounted) {
            ScaffoldMessenger.of(context).hideCurrentSnackBar();
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('🔄 0 PASS! കാർഡുകൾ അടുത്തയാൾക്ക് കൈമാറി!'),
                backgroundColor: Colors.teal,
                duration: Duration(seconds: 2),
              ),
            );
          } else if (card.type == CardType.discardAll && mounted) {
            ScaffoldMessenger.of(context).hideCurrentSnackBar();
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('💥 DISCARD ALL! ആ കളറിലുള്ള എല്ലാ കാർഡുകളും ഡിസ്കാർഡ് ചെയ്തു!'),
                backgroundColor: Colors.deepPurpleAccent,
                duration: Duration(seconds: 2),
              ),
            );
          }
        },
      );
    });
  }

  Future<CardColor?> _showColorPickerDialog() async {
    return showDialog<CardColor>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: UnoColors.surfaceElevated,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'SELECT COLOR 🎨',
          style: GoogleFonts.bebasNeue(color: Colors.white, fontSize: 22),
          textAlign: TextAlign.center,
        ),
        content: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _colorButton(CardColor.red, UnoColors.red),
            _colorButton(CardColor.blue, UnoColors.blue),
            _colorButton(CardColor.green, UnoColors.green),
            _colorButton(CardColor.yellow, UnoColors.yellow),
          ],
        ),
      ),
    );
  }

  Widget _colorButton(CardColor color, Color colorVal) {
    return InkWell(
      onTap: () => Navigator.pop(context, color),
      child: Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          color: colorVal,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(color: colorVal.withOpacity(0.5), blurRadius: 8),
          ],
        ),
      ),
    );
  }

  Future<String?> _showSwapTargetDialog() async {
    return showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: UnoColors.surfaceElevated,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          '7\'s SWAP: CHOOSE PLAYER ⇄',
          style: GoogleFonts.bebasNeue(color: Colors.amber, fontSize: 20),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: _opponents.map((opp) {
            return ListTile(
              leading: CircleAvatar(
                backgroundColor: UnoColors.yellow,
                child: Text(opp.name.isNotEmpty ? opp.name[0] : 'P'),
              ),
              title: Text(opp.name, style: const TextStyle(color: Colors.white)),
              subtitle: Text('${opp.cardCount} cards', style: const TextStyle(color: Colors.white54)),
              onTap: () => Navigator.pop(context, opp.id),
            );
          }).toList(),
        ),
      ),
    );
  }

  Future<UnoCard?> _showDiscardAllTopCardDialog(List<UnoCard> cards, UnoCard defaultCard) async {
    return showDialog<UnoCard>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: UnoColors.surfaceElevated,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Column(
          children: [
            Text(
              'DISCARD ALL: ഏത് കാർഡ് മുകളിൽ വേണം?',
              style: GoogleFonts.bebasNeue(color: UnoColors.yellow, fontSize: 22, letterSpacing: 1.2),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 6),
            const Text(
              'മുകളിൽ വെക്കാൻ ആഗ്രഹിക്കുന്ന കാർഡ് തിരഞ്ഞെടുക്കുക',
              style: TextStyle(color: Colors.white70, fontSize: 13),
              textAlign: TextAlign.center,
            ),
          ],
        ),
        content: SizedBox(
          width: double.maxFinite,
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: cards.map((c) {
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
                  child: InkWell(
                    onTap: () => Navigator.pop(context, c),
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: c.id == defaultCard.id ? UnoColors.yellow : Colors.transparent,
                          width: 2,
                        ),
                      ),
                      child: UnoCardWidget(
                        card: c,
                        width: 75,
                        height: 110,
                        isPlayable: true,
                        onTap: () => Navigator.pop(context, c),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ),
      ),
    );
  }

  void _drawCardFromDeck() async {
    final isMyTurn = _currentTurn == _myUid || _currentTurn.isEmpty;
    if (!isMyTurn) {
      String activePlayerName = 'Opponent';
      final activeMatch = _allPlayers.where((p) => p.id == _currentTurn);
      if (activeMatch.isNotEmpty) {
        activePlayerName = activeMatch.first.name;
      }
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('ഇപ്പോൾ $activePlayerName-ന്റെ ടേൺ ആണ്! നിങ്ങളുടെ ടേൺ ആകുമ്പോൾ കാർഡ് എടുക്കാം.'),
          backgroundColor: Colors.redAccent,
          duration: const Duration(seconds: 2),
        ),
      );
      return;
    }

    if (_hasDrawnThisTurn) {
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('നിങ്ങൾ ഇതിനകം കാർഡ് എടുത്തു കഴിഞ്ഞു! കയ്യിലുള്ള കാർഡ് വെക്കുകയോ "PASS" അമർത്തുകയോ ചെയ്യുക.'),
          backgroundColor: Colors.orangeAccent,
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }

    final effectiveRoomId = widget.roomId.isNotEmpty ? widget.roomId : widget.roomCode;
    final int countBeingDrawn = _pendingDrawCount > 0 ? _pendingDrawCount : 1;

    // Trigger visual draw animation from center deck to player hand
    final screenSize = MediaQuery.of(context).size;
    final startOffset = Offset(screenSize.width * 0.35, screenSize.height * 0.35);
    final endOffset = Offset(screenSize.width * 0.5 - 40, screenSize.height * 0.78);

    setState(() {
      _selectedCard = null;
      _remainingDeckCount = (_remainingDeckCount - countBeingDrawn).clamp(0, 999);
      _flyingCardWidget = FlyingCardAnimation(
        card: const UnoCard(id: 'flying_drawn', color: CardColor.wild, type: CardType.number),
        startOffset: startOffset,
        endOffset: endOffset,
        onCompleted: () {
          if (mounted) setState(() => _flyingCardWidget = null);
        },
      );
    });

    try {
      await _gameService.drawCard(roomId: effectiveRoomId);
      if (mounted) {
        setState(() {
          _hasDrawnThisTurn = countBeingDrawn == 1;
        });
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              countBeingDrawn > 1
                  ? '⚠️ +$countBeingDrawn പെനാൽറ്റി കാർഡുകൾ എടുത്തു!'
                  : '🃏 കാർഡ് എടുത്തു! മാച്ച് ഉണ്ടെങ്കിൽ കാർഡ് വെക്കാം, അല്ലെങ്കിൽ "PASS" അമർത്തുക.',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            backgroundColor: countBeingDrawn > 1 ? Colors.orangeAccent : UnoColors.blue,
            duration: const Duration(milliseconds: 2000),
          ),
        );
      }
    } catch (e) {
      debugPrint('Draw card error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('കാർഡ് എടുക്കാൻ കഴിഞ്ഞില്ല: $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  void _handlePassTurn() async {
    final effectiveRoomId = widget.roomId.isNotEmpty ? widget.roomId : widget.roomCode;
    setState(() {
      _hasDrawnThisTurn = false;
      _selectedCard = null;
    });
    try {
      await _gameService.passTurn(roomId: effectiveRoomId);
      if (mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('ടേൺ അടുത്ത കളിക്കാരനിലേക്ക് പാസ്സ് ചെയ്തു.'),
            backgroundColor: Colors.blueGrey,
            duration: Duration(milliseconds: 1500),
          ),
        );
      }
    } catch (e) {
      debugPrint('Pass turn error: $e');
    }
  }

  void _showWinnerDialog(String winnerId) {
    final isMeWinner = winnerId == _myUid;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: UnoColors.surfaceElevated,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          isMeWinner ? '🎉 YOU WON!' : '🏆 GAME OVER',
          style: GoogleFonts.bebasNeue(
            color: isMeWinner ? Colors.greenAccent : Colors.amber,
            fontSize: 26,
          ),
        ),
        content: Text(
          isMeWinner
            ? 'നിങ്ങൾ UNO Show \'em No Mercy വിജയിച്ചിരിക്കുന്നു! 👑'
            : 'എതിരാളി എല്ലാ കാർഡുകളും കളിച്ചു വിജയിച്ചു!',
          style: const TextStyle(color: Colors.white),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pop(context);
            },
            child: const Text('ലോബിയിലേക്ക് മടങ്ങുക (Return to Lobby)', style: TextStyle(color: Colors.amber)),
          ),
        ],
      ),
    );
  }

  void _showMercyKnockoutDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: UnoColors.surfaceElevated,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            const Icon(Icons.dangerous, color: Colors.redAccent, size: 30),
            const SizedBox(width: 10),
            Text(
              'MERCY KNOCKOUT! ☠️',
              style: GoogleFonts.bebasNeue(color: Colors.redAccent, fontSize: 24),
            ),
          ],
        ),
        content: const Text(
          'നിങ്ങളുടെ കൈയിൽ 25 കാർഡുകൾ ആയി! UNO Show \'em No Mercy നിയമപ്രകാരം നിങ്ങൾ ഗെയിമിൽ നിന്ന് പുറത്തായിരിക്കുന്നു!',
          style: TextStyle(color: Colors.white),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pop(context);
            },
            child: const Text('മടങ്ങുക (Exit)', style: TextStyle(color: Colors.amber)),
          ),
        ],
      ),
    );
  }

  void _openVoiceSettings() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => VoiceControlSheet(
        roomCode: widget.roomCode,
        voiceService: _voiceService,
      ),
    );
  }

  void _openTextChat() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => ChatOverlayDialog(
        roomId: widget.roomId.isNotEmpty ? widget.roomId : widget.roomCode,
        roomCode: widget.roomCode,
        currentUserName: widget.playerName,
        gameService: _gameService,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF070609),
      body: Container(
        decoration: const BoxDecoration(
          gradient: RadialGradient(
            center: Alignment(0.0, -0.45),
            radius: 1.35,
            colors: [
              Color(0xFF2C0A0F), // Rich atmospheric crimson glow
              Color(0xFF16080B),
              Color(0xFF0D0B0F),
              Color(0xFF060608), // Pitch dark table edge
            ],
            stops: [0.0, 0.35, 0.72, 1.0],
          ),
        ),
        child: SafeArea(
          child: Stack(
            children: [
              Column(
                children: [
                  // 1. Top Header Bar (Opponent Profile Capsule + Controls)
                  _buildHeaderBar(),

                  // 2. Center-Top Floating Turn Indicator Capsule (e.g. 🟢 YOUR TURN)
                  _buildFloatingTurnBadge(),

                  // In-Game 5-Second Fade Speech Bubble
                  if (_activeSpeechBubble != null)
                    AnimatedOpacity(
                      opacity: _bubbleOpacity,
                      duration: const Duration(milliseconds: 500),
                      child: Container(
                        margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 4),
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFFE65100), Color(0xFFFF8F00)],
                          ),
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.orangeAccent.withOpacity(0.5),
                              blurRadius: 10,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.chat_bubble, color: Colors.white, size: 16),
                            const SizedBox(width: 8),
                            Text(
                              '${_activeSpeechBubble!.senderName}: ',
                              style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 13),
                            ),
                            Flexible(
                              child: Text(
                                _activeSpeechBubble!.text,
                                style: const TextStyle(color: Colors.white, fontSize: 13),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                  // 3. Central Table (Deck with HUD brackets & Discard Pile with Neon Glow)
                  Expanded(
                    child: TableCenterView(
                      topCard: _topCard,
                      activeColor: _activeColor,
                      pendingDrawCount: _pendingDrawCount,
                      remainingDeckCards: _remainingDeckCount,
                      isClockwise: _isClockwise,
                      playerCardCount: _playerHand.length,
                      onDrawDeckTapped: _drawCardFromDeck,
                    ),
                  ),

                  // 4. Player Action Bar (Uno Call & Draw/Pass Buttons)
                  _buildPlayerActionBar(),

                  // 5. Player's Curved Fanned Cards
                  CardFanLayout(
                    cards: _playerHand,
                    selectedCard: _selectedCard,
                    topCard: _topCard,
                    pendingDrawCount: _pendingDrawCount,
                    isMyTurn: _currentTurn == _myUid || _currentTurn.isEmpty,
                    onCardSelected: _handleCardSelected,
                    onCardPlayed: _handleCardPlayed,
                  ),
                ],
              ),

              if (_flyingCardWidget != null) _flyingCardWidget!,

              // 2-Second Universal UNO Call Banner across ALL players
              if (_activeUnoAlertMessage != null)
                Center(
                  child: AnimatedOpacity(
                    opacity: _unoAlertOpacity,
                    duration: const Duration(milliseconds: 400),
                    child: Container(
                      margin: const EdgeInsets.symmetric(horizontal: 24),
                      padding: const EdgeInsets.symmetric(horizontal: 26, vertical: 16),
                      decoration: BoxDecoration(
                        color: UnoColors.yellow,
                        borderRadius: BorderRadius.circular(30),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.amberAccent.withOpacity(0.9),
                            blurRadius: 30,
                            spreadRadius: 6,
                          ),
                        ],
                        border: Border.all(color: Colors.white, width: 3.5),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.campaign_rounded, color: Colors.black, size: 34),
                          const SizedBox(width: 10),
                          Flexible(
                            child: Text(
                              _activeUnoAlertMessage!,
                              style: GoogleFonts.rubik(
                                color: Colors.black,
                                fontSize: 18,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  /// Floating Turn Badge below header (Matching open-mercy.com UI)
  Widget _buildFloatingTurnBadge() {
    final isMyTurn = _currentTurn == _myUid || _currentTurn.isEmpty;
    String turnPlayerName = widget.playerName;
    if (!isMyTurn) {
      final activeMatch = _allPlayers.where((p) => p.id == _currentTurn);
      turnPlayerName = activeMatch.isNotEmpty ? activeMatch.first.name : 'Opponent';
    }

    final accentColor = isMyTurn ? const Color(0xFF00E676) : Colors.amberAccent;
    final bgColor = isMyTurn ? const Color(0xFF0E2418) : const Color(0xFF26190F);

    return Center(
      child: Container(
        margin: const EdgeInsets.only(top: 8, bottom: 2),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: accentColor.withOpacity(0.4), width: 1.0),
          boxShadow: [
            BoxShadow(
              color: accentColor.withOpacity(0.2),
              blurRadius: 10,
              spreadRadius: 1,
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: accentColor,
                boxShadow: [
                  BoxShadow(
                    color: accentColor.withOpacity(0.8),
                    blurRadius: 6,
                    spreadRadius: 1,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Text(
              isMyTurn ? 'YOUR TURN' : '$turnPlayerName\'S TURN',
              style: GoogleFonts.rubik(
                color: accentColor,
                fontSize: 11,
                fontWeight: FontWeight.w900,
                letterSpacing: 1.2,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Rich Top Header Bar matching Open-Mercy screenshot:
  /// Left: Shield Avatar Badge + Opponent Name + Golden Card Count
  /// Right: Room Code, Mic Toggle, Chat, Rules, Exit
  Widget _buildHeaderBar() {
    final primaryOpponent = _opponents.isNotEmpty ? _opponents.first : null;
    final opponentName = primaryOpponent?.name ?? 'WAITING...';
    final opponentCardCount = primaryOpponent?.cardCount ?? 7;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      child: Row(
        children: [
          // Left: Opponent Profile Capsule (Shield + Name + Card Count)
          if (primaryOpponent != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: const Color(0xFF181318),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: Colors.white12, width: 1.0),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.4),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Shield Icon Avatar
                  Container(
                    width: 30,
                    height: 30,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: const Color(0xFF281820),
                      border: Border.all(color: Colors.white24, width: 1.0),
                    ),
                    child: const Center(
                      child: Icon(Icons.shield_outlined, color: Colors.white70, size: 17),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        opponentName.toUpperCase(),
                        style: GoogleFonts.rubik(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.6,
                        ),
                      ),
                      Text(
                        '$opponentCardCount cards',
                        style: GoogleFonts.rubik(
                          color: UnoColors.yellow,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            )
          else
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.white10,
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Text(
                'WAITING FOR OPPONENT...',
                style: TextStyle(color: Colors.white54, fontSize: 11, fontWeight: FontWeight.bold),
              ),
            ),

          const Spacer(),

          // Right Controls (Room Code, Voice Chat, Chat, Rules, Exit)
          // Room Code Pill
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0xFF181318),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.white12, width: 1.0),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.tag_rounded, size: 14, color: Colors.white54),
                const SizedBox(width: 4),
                Text(
                  widget.roomCode,
                  style: GoogleFonts.rubik(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 6),

          // Live Voice Mic Button
          GestureDetector(
            onLongPress: _openVoiceSettings,
            child: _buildHeaderIconButton(
              icon: _voiceService.isMuted ? Icons.mic_off_rounded : Icons.mic_rounded,
              color: _voiceService.isConnected
                  ? (_voiceService.isMuted ? Colors.redAccent : Colors.greenAccent)
                  : Colors.white38,
              onPressed: () {
                setState(() => _voiceService.toggleMute());
                ScaffoldMessenger.of(context).hideCurrentSnackBar();
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    duration: const Duration(milliseconds: 1200),
                    backgroundColor: _voiceService.isMuted ? Colors.redAccent : Colors.green,
                    content: Text(
                      _voiceService.isMuted ? '🔇 മൈക്ക് ഓഫ് ചെയ്തു (Muted)' : '🎙️ മൈക്ക് ഓൺ ആണ് (Unmuted)',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(width: 6),

          // Text Chat Button
          _buildHeaderIconButton(
            icon: Icons.chat_bubble_outline_rounded,
            color: Colors.amberAccent,
            onPressed: _openTextChat,
          ),
          const SizedBox(width: 6),

          // Game Rules Button
          _buildHeaderIconButton(
            icon: Icons.help_outline_rounded,
            color: Colors.white70,
            onPressed: () => showDialog(
              context: context,
              builder: (context) => const RulesDialog(),
            ),
          ),
          const SizedBox(width: 6),

          // Exit / Leave Game Button
          _buildHeaderIconButton(
            icon: Icons.logout_rounded,
            color: Colors.redAccent,
            onPressed: () {
              Navigator.pop(context);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildHeaderIconButton({
    required IconData icon,
    required Color color,
    required VoidCallback onPressed,
  }) {
    return InkWell(
      onTap: onPressed,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: const Color(0xFF181318),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.white12, width: 1.0),
        ),
        child: Center(
          child: Icon(icon, color: color, size: 18),
        ),
      ),
    );
  }

  Widget _buildPlayerActionBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Player's Name and card count badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0xFF141318),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white12, width: 1.0),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.person_rounded, size: 14, color: Colors.white70),
                const SizedBox(width: 6),
                Text(
                  widget.playerName,
                  style: GoogleFonts.rubik(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: _playerHand.length >= 20 ? Colors.redAccent.withOpacity(0.3) : Colors.white12,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '${_playerHand.length} cards',
                    style: GoogleFonts.rubik(
                      color: _playerHand.length >= 20 ? Colors.redAccent : Colors.white70,
                      fontWeight: FontWeight.bold,
                      fontSize: 11,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Action Buttons: PASS / DRAW CARD / CALL UNO
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (_hasDrawnThisTurn)
                ElevatedButton.icon(
                  onPressed: _handlePassTurn,
                  icon: const Icon(Icons.arrow_forward_rounded, size: 15, color: Colors.black),
                  label: Text(
                    'PASS TURN',
                    style: GoogleFonts.rubik(fontSize: 12, fontWeight: FontWeight.w900, color: Colors.black),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.amberAccent,
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    elevation: 4,
                  ),
                )
              else
                ElevatedButton.icon(
                  onPressed: _drawCardFromDeck,
                  icon: Icon(
                    _pendingDrawCount > 0 ? Icons.warning_amber_rounded : Icons.add_card_rounded,
                    size: 15,
                    color: Colors.white,
                  ),
                  label: Text(
                    _pendingDrawCount > 0 ? 'DRAW +$_pendingDrawCount' : 'DRAW',
                    style: GoogleFonts.rubik(fontSize: 12, fontWeight: FontWeight.w900),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _pendingDrawCount > 0 ? Colors.redAccent : const Color(0xFF1E88E5),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    elevation: 3,
                  ),
                ),
              const SizedBox(width: 8),
              ElevatedButton(
                onPressed: () async {
                  final effectiveRoomId = widget.roomId.isNotEmpty ? widget.roomId : widget.roomCode;
                  await _gameService.callUno(
                    roomId: effectiveRoomId,
                    callerName: widget.playerName,
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: UnoColors.yellow,
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  elevation: 4,
                  shadowColor: UnoColors.yellow.withOpacity(0.5),
                ),
                child: Text(
                  'UNO!',
                  style: GoogleFonts.rubik(fontSize: 13, fontWeight: FontWeight.w900, letterSpacing: 1.0),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
