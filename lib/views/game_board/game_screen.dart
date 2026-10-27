import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/theme/uno_colors.dart';
import '../../models/uno_card.dart';
import '../../services/voice_service.dart';
import '../widgets/card_fan_layout.dart';
import '../widgets/voice_control_bar.dart';
import '../widgets/chat_overlay_dialog.dart';
import 'table_center_view.dart';
import 'animated_card_overlay.dart';

class GameScreen extends StatefulWidget {
  final String roomCode;
  final String playerName;

  const GameScreen({
    super.key,
    this.roomCode = 'UNO7K2',
    this.playerName = 'Player 1',
  });

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> {
  // Game Table States
  late UnoCard _topCard;
  CardColor _activeColor = CardColor.red;
  int _pendingDrawCount = 0;
  bool _isClockwise = true;
  int _remainingDeckCount = 88;

  // Voice Service
  final IVoiceService _voiceService = LiveKitVoiceService();
  Set<String> _activeSpeakers = {};

  // Player Hand
  List<UnoCard> _playerHand = [];
  UnoCard? _selectedCard;

  // Active flying animation
  Widget? _flyingCardWidget;

  // Mock Opponents for Multiplayer Preview
  final List<Map<String, dynamic>> _opponents = [
    {'name': 'Rahul', 'cardCount': 5, 'isTurn': false, 'isKnockedOut': false},
    {'name': 'Anu', 'cardCount': 19, 'isTurn': false, 'isKnockedOut': false},
    {'name': 'Vikram', 'cardCount': 23, 'isTurn': true, 'isKnockedOut': false},
  ];

  @override
  void initState() {
    super.initState();
    _initSampleGame();
    _initVoiceChannel();
  }

  void _initVoiceChannel() {
    // Automatically connect to secure LiveKit voice room on join
    _voiceService.connect(roomCode: widget.roomCode, token: 'mock_token');
    _voiceService.activeSpeakersStream.listen((speakers) {
      if (mounted) {
        setState(() {
          _activeSpeakers = speakers;
        });
      }
    });
  }

  @override
  void dispose() {
    _voiceService.disconnect();
    super.dispose();
  }

  void _initSampleGame() {
    _topCard = const UnoCard(
      id: 'top_init',
      color: CardColor.red,
      type: CardType.number,
      numberValue: 7,
    );
    _activeColor = CardColor.red;

    // Varied hand with No Mercy specials
    _playerHand = [
      const UnoCard(id: 'c1', color: CardColor.red, type: CardType.number, numberValue: 7),
      const UnoCard(id: 'c2', color: CardColor.blue, type: CardType.number, numberValue: 7),
      const UnoCard(id: 'c3', color: CardColor.red, type: CardType.skip),
      const UnoCard(id: 'c4', color: CardColor.yellow, type: CardType.drawTwo),
      const UnoCard(id: 'c5', color: CardColor.wild, type: CardType.drawFour),
      const UnoCard(id: 'c6', color: CardColor.red, type: CardType.drawSix),
      const UnoCard(id: 'c7', color: CardColor.wild, type: CardType.drawTen),
      const UnoCard(id: 'c8', color: CardColor.green, type: CardType.discardAll),
      const UnoCard(id: 'c9', color: CardColor.blue, type: CardType.skipEveryone),
      const UnoCard(id: 'c10', color: CardColor.yellow, type: CardType.pointSevenSwap),
    ];
  }

  void _handleCardSelected(UnoCard card) {
    setState(() {
      _selectedCard = (_selectedCard?.id == card.id) ? null : card;
    });
  }

  void _handleCardPlayed(UnoCard card) {
    if (!card.canPlayOn(_topCard, pendingDrawCount: _pendingDrawCount)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${card.displayLabel} ഈ സമയത്ത് കളിക്കാൻ കഴിയില്ല!'),
          backgroundColor: Colors.redAccent,
          duration: const Duration(milliseconds: 1500),
        ),
      );
      return;
    }

    final screenSize = MediaQuery.of(context).size;
    final startOffset = Offset(screenSize.width * 0.4, screenSize.height * 0.7);
    final endOffset = Offset(screenSize.width * 0.5 - 45, screenSize.height * 0.38);

    setState(() {
      _flyingCardWidget = FlyingCardAnimation(
        card: card,
        startOffset: startOffset,
        endOffset: endOffset,
        onCompleted: () {
          setState(() {
            _flyingCardWidget = null;
            _topCard = card;
            _activeColor = card.isWild ? CardColor.blue : card.color;
            _playerHand.removeWhere((c) => c.id == card.id);
            _selectedCard = null;

            if (card.isDrawPenalty) {
              _pendingDrawCount += card.penaltyCount;
            } else {
              _pendingDrawCount = 0;
            }

            if (card.type == CardType.reverse) {
              _isClockwise = !_isClockwise;
            }
          });
        },
      );
    });
  }

  void _drawCardFromDeck() {
    if (_playerHand.length >= 25) {
      _showMercyKnockoutDialog();
      return;
    }

    final colors = [CardColor.red, CardColor.blue, CardColor.green, CardColor.yellow];
    final randomColor = colors[math.Random().nextInt(colors.length)];
    final newCard = UnoCard(
      id: 'draw_${DateTime.now().millisecondsSinceEpoch}',
      color: randomColor,
      type: CardType.number,
      numberValue: math.Random().nextInt(10),
    );

    setState(() {
      _playerHand.add(newCard);
      if (_remainingDeckCount > 1) _remainingDeckCount--;
      if (_pendingDrawCount > 0) _pendingDrawCount = 0;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('ഡെക്കിൽ നിന്ന് ഒരു കാർഡ് എടുത്തു: ${newCard.displayLabel}'),
        duration: const Duration(milliseconds: 1000),
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
              'MERCY RULE KNOCKOUT!',
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
              setState(() => _initSampleGame());
            },
            child: const Text('വീണ്ടും തുടങ്ങുക (Restart)', style: TextStyle(color: Colors.amber)),
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
        roomCode: widget.roomCode,
        currentUserName: widget.playerName,
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

                // Opponents Bar with Active Voice Speaking Glow
                _buildOpponentsBar(),

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
          // Voice Chat Indicator (LiveKit)
          IconButton(
            tooltip: 'LiveKit Voice Controls',
            icon: Icon(
              _voiceService.isMuted ? Icons.mic_off : Icons.mic,
              color: _voiceService.isConnected
                  ? (_voiceService.isMuted ? Colors.redAccent : Colors.greenAccent)
                  : Colors.white38,
            ),
            onPressed: _openVoiceSettings,
          ),
          // Text Chat Overlay Button
          IconButton(
            tooltip: 'Text Chat',
            icon: const Icon(Icons.chat_bubble_outline, color: Colors.amber),
            onPressed: _openTextChat,
          ),
        ],
      ),
    );
  }

  Widget _buildOpponentsBar() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: _opponents.map((opp) {
          final count = opp['cardCount'] as int;
          final isDanger = count >= 20;
          final isSpeaking = _activeSpeakers.contains(opp['name']);

          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: opp['isTurn'] ? Colors.white12 : UnoColors.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isSpeaking
                    ? Colors.greenAccent
                    : (opp['isTurn']
                        ? UnoColors.yellow
                        : (isDanger ? Colors.redAccent : Colors.transparent)),
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
                Stack(
                  alignment: Alignment.bottomRight,
                  children: [
                    CircleAvatar(
                      radius: 14,
                      backgroundColor: isDanger ? Colors.red : Colors.blueGrey,
                      child: Text(
                        opp['name'][0],
                        style: const TextStyle(fontSize: 12, color: Colors.white, fontWeight: FontWeight.bold),
                      ),
                    ),
                    if (isSpeaking)
                      const CircleAvatar(
                        radius: 5,
                        backgroundColor: Colors.greenAccent,
                        child: Icon(Icons.volume_up, size: 7, color: Colors.black),
                      ),
                  ],
                ),
                const SizedBox(width: 8),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      opp['name'],
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
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            'നിങ്ങളുടെ കാർഡുകൾ: ${_playerHand.length}/25 ${(_playerHand.length >= 20) ? '⚠️' : ''}',
            style: TextStyle(
              color: _playerHand.length >= 20 ? Colors.redAccent : Colors.white70,
              fontWeight: FontWeight.bold,
              fontSize: 13,
            ),
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
