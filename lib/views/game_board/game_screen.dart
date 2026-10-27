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

  // Active game states
  UnoCard _topCard = const UnoCard(
    id: 'top_init',
    color: CardColor.red,
    type: CardType.number,
    numberValue: 7,
  );
  CardColor _activeColor = CardColor.red;
  int _pendingDrawCount = 0;
  bool _isClockwise = true;
  int _remainingDeckCount = 140;
  String _currentTurn = '';

  // Player's Own Hand (Unique cards)
  List<UnoCard> _playerHand = [];
  UnoCard? _selectedCard;

  // Active Real Opponents (Only players who actually joined this room!)
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

        // Filter out ME: Show ONLY real opponents who joined this room!
        _opponents = room.players.where((p) => p.id != _myUid).toList();

        // Check if game has ended
        if (room.winnerId != null) {
          _showWinnerDialog(room.winnerId!);
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

  void _initVoiceChannel() {
    _voiceService.connect(roomCode: widget.roomCode, token: 'live_token');
    _voiceService.activeSpeakersStream.listen((speakers) {
      if (mounted) {
        setState(() => _activeSpeakers = speakers);
      }
    });
  }

  @override
  void dispose() {
    _speechBubbleTimer?.cancel();
    _chatSubscription?.cancel();
    _roomSubscription?.cancel();
    _handSubscription?.cancel();
    _voiceService.disconnect();
    super.dispose();
  }

  void _handleCardSelected(UnoCard card) {
    setState(() {
      _selectedCard = (_selectedCard?.id == card.id) ? null : card;
    });
  }

  void _handleCardPlayed(UnoCard card) async {
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
      swapTargetPlayerId = await _showSwapTargetDialog();
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
          });
          // Commit move to Firebase Server
          await _gameService.playCard(
            roomId: effectiveRoomId,
            cardId: card.id,
            chosenColor: chosenColor,
            swapTargetPlayerId: swapTargetPlayerId,
          );
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
    final effectiveRoomId = widget.roomId.isNotEmpty ? widget.roomId : widget.roomCode;
    await _gameService.drawCard(roomId: effectiveRoomId);
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
                  onCardSelected: _handleCardSelected,
                  onCardPlayed: _handleCardPlayed,
                ),
              ],
            ),

            if (_flyingCardWidget != null) _flyingCardWidget!,
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
          IconButton(
            tooltip: 'Live Voice Chat',
            icon: Icon(
              _voiceService.isMuted ? Icons.mic_off : Icons.mic,
              color: _voiceService.isConnected
                  ? (_voiceService.isMuted ? Colors.redAccent : Colors.greenAccent)
                  : Colors.white38,
            ),
            onPressed: _openVoiceSettings,
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
                    Text(
                      opp.name,
                      style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
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
                isMyTurn ? '👉 നിങ്ങളുടെ ടേൺ ആണ്!' : '⏳ എതിരാളിയുടെ ടേൺ...',
                style: TextStyle(
                  color: isMyTurn ? Colors.greenAccent : Colors.white38,
                  fontSize: 11,
                  fontWeight: isMyTurn ? FontWeight.bold : FontWeight.normal,
                ),
              ),
            ],
          ),
          ElevatedButton(
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('UNO വിളിച്ചു! 📢'),
                  backgroundColor: Colors.amber,
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: UnoColors.yellow,
              foregroundColor: Colors.black,
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            ),
            child: Text(
              'CALL UNO!',
              style: GoogleFonts.bebasNeue(fontSize: 16, letterSpacing: 1.2),
            ),
          ),
        ],
      ),
    );
  }
}
