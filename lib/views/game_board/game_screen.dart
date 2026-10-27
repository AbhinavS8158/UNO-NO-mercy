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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${card.displayLabel} ഈ സമയത്ത് കളിക്കാൻ കഴിയില്ല! (No Mercy Stacking Rule)'),
          backgroundColor: Colors.redAccent,
          duration: const Duration(milliseconds: 1500),
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

    final screenSize = MediaQuery.of(context).size;
    final startOffset = Offset(screenSize.width * 0.4, screenSize.height * 0.7);
    final endOffset = Offset(screenSize.width * 0.5 - 45, screenSize.height * 0.38);

    setState(() {
      _flyingCardWidget = FlyingCardAnimation(
        card: card,
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
      backgroundColor: UnoColors.background,
      body: SafeArea(
        child: Stack(
          children: [
            Column(
              children: [
                // Top Header Bar
                _buildHeaderBar(),

                // Real Opponents Bar (ONLY players who actually joined!)
                _buildRealOpponentsBar(),

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

                // Central Table (Deck & Discard Pile)
                Expanded(
                  child: TableCenterView(
                    topCard: _topCard,
                    activeColor: _activeColor,
                    pendingDrawCount: _pendingDrawCount,
                    remainingDeckCards: _remainingDeckCount,
                    isClockwise: _isClockwise,
                    onDrawDeckTapped: _drawCardFromDeck,
                  ),
                ),

                // Player Action Bar (Uno Call & Count)
                _buildPlayerActionBar(),

                // Player's Curved Fanned Cards
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
    );
  }

  Widget _buildHeaderBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: const BoxDecoration(
        color: UnoColors.surface,
        border: Border(bottom: BorderSide(color: Colors.white10)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.red.withOpacity(0.2),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.redAccent),
            ),
            child: Text(
              'ROOM: ${widget.roomCode}',
              style: GoogleFonts.rubik(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 13,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.black45,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              'NO MERCY',
              style: GoogleFonts.bebasNeue(color: Colors.orangeAccent, fontSize: 13, letterSpacing: 1),
            ),
          ),
          const Spacer(),
          IconButton(
            tooltip: 'Game Rules',
            icon: const Icon(Icons.help_outline_rounded, color: UnoColors.yellow),
            onPressed: () => showDialog(
              context: context,
              builder: (context) => const RulesDialog(),
            ),
          ),
          GestureDetector(
            onLongPress: _openVoiceSettings,
            child: IconButton(
              tooltip: 'Live Voice Chat (Tap to Mute/Unmute, Long press for Settings)',
              icon: Icon(
                _voiceService.isMuted ? Icons.mic_off : Icons.mic,
                color: _voiceService.isConnected
                    ? (_voiceService.isMuted ? Colors.redAccent : Colors.greenAccent)
                    : Colors.white38,
              ),
              onPressed: () {
                setState(() {
                  _voiceService.toggleMute();
                });
                ScaffoldMessenger.of(context).hideCurrentSnackBar();
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    duration: const Duration(milliseconds: 1200),
                    backgroundColor: _voiceService.isMuted ? Colors.redAccent : Colors.green,
                    content: Text(
                      _voiceService.isMuted
                          ? '🔇 മൈക്ക് ഓഫ് ചെയ്തു (Muted)'
                          : '🎙️ മൈക്ക് ഓൺ ആണ് (Unmuted)',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                );
              },
            ),
          ),
          IconButton(
            tooltip: 'Text Chat',
            icon: const Icon(Icons.chat_bubble_outline, color: Colors.amber),
            onPressed: _openTextChat,
          ),
        ],
      ),
    );
  }

  Widget _buildRealOpponentsBar() {
    if (_opponents.isEmpty) {
      return Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: const Text(
          'മറ്റ് കളിക്കാർക്കായി കാത്തിരിക്കുന്നു...',
          style: TextStyle(color: Colors.white54, fontSize: 12),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: _opponents.map((opp) {
          final count = opp.cardCount;
          final isDanger = count >= 20;
          final isSpeaking = _activeSpeakers.contains(opp.name);
          final isTurn = opp.id == _currentTurn;

          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: isTurn ? Colors.white12 : UnoColors.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isSpeaking
                    ? Colors.greenAccent
                    : (isTurn ? UnoColors.yellow : (isDanger ? Colors.redAccent : Colors.transparent)),
                width: isSpeaking ? 2.5 : 1.5,
              ),
              boxShadow: isSpeaking
                  ? [
                      BoxShadow(
                        color: Colors.greenAccent.withOpacity(0.5),
                        blurRadius: 8,
                        spreadRadius: 1,
                      )
                    ]
                  : null,
            ),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 14,
                  backgroundColor: isDanger ? Colors.red : Colors.blueGrey,
                  child: Text(
                    opp.name.isNotEmpty ? opp.name[0].toUpperCase() : 'P',
                    style: const TextStyle(fontSize: 12, color: Colors.white, fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(width: 8),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          opp.name,
                          style: TextStyle(
                            color: isTurn ? UnoColors.yellow : Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        if (isTurn) ...[
                          const SizedBox(width: 4),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                            decoration: BoxDecoration(
                              color: UnoColors.yellow,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: const Text(
                              'TURN',
                              style: TextStyle(
                                color: Colors.black,
                                fontSize: 8,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    Text(
                      '$count Cards ${isDanger ? '⚠️' : ''}',
                      style: TextStyle(
                        color: isDanger ? Colors.redAccent : Colors.white70,
                        fontSize: 10,
                        fontWeight: isDanger ? FontWeight.bold : FontWeight.normal,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildPlayerActionBar() {
    final isMyTurn = _currentTurn == _myUid || _currentTurn.isEmpty;
    String turnPlayerName = widget.playerName;
    if (!isMyTurn) {
      final activeMatch = _allPlayers.where((p) => p.id == _currentTurn);
      turnPlayerName = activeMatch.isNotEmpty ? activeMatch.first.name : 'Opponent';
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'നിങ്ങളുടെ കാർഡുകൾ: ${_playerHand.length}/25',
                style: TextStyle(
                  color: _playerHand.length >= 20 ? Colors.redAccent : Colors.white70,
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
              ),
              Text(
                isMyTurn
                    ? '👉 നിങ്ങളുടെ ടേൺ ആണ്! (${widget.playerName})'
                    : '⏳ $turnPlayerName-ന്റെ ടേൺ ആണ്...',
                style: TextStyle(
                  color: isMyTurn ? Colors.greenAccent : Colors.amberAccent,
                  fontSize: 12,
                  fontWeight: isMyTurn ? FontWeight.bold : FontWeight.w600,
                ),
              ),
            ],
          ),
          Row(
            children: [
              if (_hasDrawnThisTurn)
                ElevatedButton.icon(
                  onPressed: _handlePassTurn,
                  icon: const Icon(Icons.arrow_forward_rounded, size: 16, color: Colors.black),
                  label: Text(
                    'PASS (പാസ്സ് ചെയ്യുക)',
                    style: GoogleFonts.bebasNeue(fontSize: 15, letterSpacing: 1.0, color: Colors.black),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.amberAccent,
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                    elevation: 4,
                  ),
                )
              else
                ElevatedButton.icon(
                  onPressed: _drawCardFromDeck,
                  icon: Icon(
                    _pendingDrawCount > 0 ? Icons.warning_amber_rounded : Icons.add_card,
                    size: 15,
                    color: Colors.white,
                  ),
                  label: Text(
                    _pendingDrawCount > 0 ? 'DRAW +$_pendingDrawCount' : 'DRAW CARD',
                    style: GoogleFonts.bebasNeue(fontSize: 15, letterSpacing: 1.0),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _pendingDrawCount > 0 ? Colors.redAccent : UnoColors.blue,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
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
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                ),
                child: Text(
                  'CALL UNO!',
                  style: GoogleFonts.bebasNeue(fontSize: 16, letterSpacing: 1.2),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
