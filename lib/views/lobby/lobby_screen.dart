import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/theme/uno_colors.dart';
import '../../services/game_service.dart';
import '../../services/firebase_game_service.dart';
import '../game_board/game_screen.dart';

class LobbyScreen extends StatefulWidget {
  const LobbyScreen({super.key});

  @override
  State<LobbyScreen> createState() => _LobbyScreenState();
}

class _LobbyScreenState extends State<LobbyScreen> {
  final TextEditingController _nameController = TextEditingController(text: 'Player 1');
  final TextEditingController _codeController = TextEditingController();
  late final IGameService _gameService;

  @override
  void initState() {
    super.initState();
    // Use Live Cloud Firestore if Firebase is initialized, else local
    if (Firebase.apps.isNotEmpty) {
      _gameService = FirebaseGameService();
    } else {
      _gameService = LocalGameService();
    }
  }

  String? _currentRoomCode;
  String? _currentRoomId;
  bool _isLoading = false;
  bool _isNoMercyMode = true;

  final List<String> _joinedPlayers = [];

  StreamSubscription? _roomSubscription;

  @override
  void dispose() {
    _roomSubscription?.cancel();
    _nameController.dispose();
    _codeController.dispose();
    super.dispose();
  }

  void _listenToRoomUpdates(String roomId) {
    _roomSubscription?.cancel();
    _roomSubscription = _gameService.streamRoom(roomId).listen((room) {
      if (!mounted) return;
      setState(() {
        _joinedPlayers.clear();
        for (var p in room.players) {
          _joinedPlayers.add('${p.name} ${p.isHost ? '(Host 👑)' : ''}');
        }
      });

      // If host started the game, automatically take joined players to the GameScreen!
      if (room.status == 'in_progress') {
        _roomSubscription?.cancel();
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => GameScreen(
              roomCode: room.roomCode,
              playerName: _nameController.text.trim().isEmpty ? 'Player' : _nameController.text.trim(),
            ),
          ),
        );
      }
    });
  }

  void _handleCreateRoom() async {
    if (_nameController.text.trim().isEmpty) return;

    setState(() => _isLoading = true);
    try {
      final res = await _gameService.createRoom(
        playerName: _nameController.text.trim(),
        rules: _isNoMercyMode ? 'no_mercy' : 'classic',
      );
      setState(() {
        _currentRoomId = res['roomId'];
        _currentRoomCode = res['roomCode'];
      });
      _listenToRoomUpdates(_currentRoomId!);
    } catch (e) {
      _showError(e.toString());
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _handleJoinRoom() async {
    if (_codeController.text.trim().isEmpty) return;

    setState(() => _isLoading = true);
    try {
      final res = await _gameService.joinRoom(
        roomCode: _codeController.text.trim(),
        playerName: _nameController.text.trim(),
      );
      setState(() {
        _currentRoomId = res['roomId'];
        _currentRoomCode = res['roomCode'];
      });
      _listenToRoomUpdates(_currentRoomId!);
    } catch (e) {
      _showError('റൂം കോഡ് തെറ്റാണ് അല്ലെങ്കിൽ റൂം നിലവിലില്ല!');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _handleStartGame() async {
    if (_currentRoomId == null) return;
    await _gameService.startGame(roomId: _currentRoomId!);
    if (!mounted) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => GameScreen(
          roomCode: _currentRoomCode ?? 'UNO7K2',
          playerName: _nameController.text.trim().isEmpty ? 'Player 1' : _nameController.text.trim(),
        ),
      ),
    );
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.redAccent),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: UnoColors.background,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
            child: ConstrainedBox(
              constraints: const dynamicBoxConstraint(maxWidth: 480),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // App Title / Banner
                  _buildLogoHeader(),

                  const SizedBox(height: 30),

                  // Show Lobby if inside a room, else Show Join / Create options
                  if (_currentRoomCode != null)
                    _buildActiveLobbyView()
                  else
                    _buildEntryForm(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLogoHeader() {
    return Column(
      children: [
        Stack(
          alignment: Alignment.center,
          children: [
            Transform.rotate(
              angle: -0.15,
              child: Container(
                width: 140,
                height: 70,
                decoration: BoxDecoration(
                  color: UnoColors.red,
                  borderRadius: BorderRadius.circular(35),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.redAccent.withOpacity(0.5),
                      blurRadius: 15,
                    ),
                  ],
                ),
              ),
            ),
            Transform.rotate(
              angle: -0.15,
              child: Text(
                'UNO',
                style: GoogleFonts.blackOpsOne(
                  fontSize: 42,
                  color: UnoColors.yellow,
                  fontWeight: FontWeight.w900,
                  shadows: [
                    const Shadow(color: Colors.black, offset: Offset(3, 3), blurRadius: 4),
                  ],
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          'SHOW \'EM NO MERCY',
          style: GoogleFonts.bebasNeue(
            color: Colors.orangeAccent,
            fontSize: 22,
            letterSpacing: 3,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          'Real-time Multiplayer + Voice Chat',
          style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 12),
        ),
      ],
    );
  }

  Widget _buildEntryForm() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: UnoColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Name Input
          TextField(
            controller: _nameController,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              labelText: 'നിങ്ങളുടെ പേര് (Player Name)',
              labelStyle: const TextStyle(color: Colors.white70),
              filled: true,
              fillColor: Colors.black26,
              prefixIcon: const Icon(Icons.person, color: Colors.amber),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),

          const SizedBox(height: 18),

          // No Mercy Mode Switch
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.black26,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'No Mercy Ruleset',
                        style: GoogleFonts.rubik(color: Colors.white, fontWeight: FontWeight.bold),
                      ),
                      const Text(
                        '25 Cards Mercy Knockout + Stacking',
                        style: TextStyle(color: Colors.white54, fontSize: 11),
                      ),
                    ],
                  ),
                ),
                Switch(
                  value: _isNoMercyMode,
                  activeColor: Colors.redAccent,
                  onChanged: (val) => setState(() => _isNoMercyMode = val),
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          // Create Room Button
          ElevatedButton.icon(
            onPressed: _isLoading ? null : _handleCreateRoom,
            icon: const Icon(Icons.add_circle_outline),
            label: const Text('റൂം ക്രിയേറ്റ് ചെയ്യുക (Create Room)'),
            style: ElevatedButton.styleFrom(
              backgroundColor: UnoColors.red,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),

          const Padding(
            padding: EdgeInsets.symmetric(vertical: 14),
            child: Row(
              children: [
                Expanded(child: Divider(color: Colors.white24)),
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 10),
                  child: Text('അല്ലെങ്കിൽ', style: TextStyle(color: Colors.white54, fontSize: 12)),
                ),
                Expanded(child: Divider(color: Colors.white24)),
              ],
            ),
          ),

          // Room Code Join Input
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _codeController,
                  textCapitalization: TextCapitalization.characters,
                  style: GoogleFonts.rubik(color: Colors.white, fontWeight: FontWeight.bold, letterSpacing: 2),
                  decoration: InputDecoration(
                    hintText: 'ROOM CODE (e.g. UNO7K2)',
                    hintStyle: const TextStyle(color: Colors.white38, letterSpacing: 1),
                    filled: true,
                    fillColor: Colors.black26,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              ElevatedButton(
                onPressed: _isLoading ? null : _handleJoinRoom,
                style: ElevatedButton.styleFrom(
                  backgroundColor: UnoColors.blue,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text('JOIN'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildActiveLobbyView() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: UnoColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'LOBBY: GAME ROOM READY',
            style: GoogleFonts.bebasNeue(color: Colors.white, fontSize: 20, letterSpacing: 1.5),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),

          // Copyable Room Code Box
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.black38,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: UnoColors.yellow, width: 1.5),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('ROOM CODE', style: TextStyle(color: Colors.white54, fontSize: 10)),
                    Text(
                      _currentRoomCode ?? '',
                      style: GoogleFonts.rubik(
                        color: UnoColors.yellow,
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 3,
                      ),
                    ),
                  ],
                ),
                IconButton(
                  icon: const Icon(Icons.copy, color: Colors.white),
                  tooltip: 'Copy Code',
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: _currentRoomCode ?? ''));
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('റൂം കോഡ് കോപ്പി ചെയ്തു! സുഹൃത്തുക്കൾക്ക് അയക്കൂ.')),
                    );
                  },
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // Joined Players List
          const Text('കളിക്കാർ (Players Joined):', style: TextStyle(color: Colors.white70, fontSize: 13)),
          const SizedBox(height: 8),

          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.black26,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Column(
              children: _joinedPlayers
                  .map((p) => ListTile(
                        dense: true,
                        leading: const CircleAvatar(
                          radius: 12,
                          backgroundColor: Colors.green,
                          child: Icon(Icons.check, size: 14, color: Colors.white),
                        ),
                        title: Text(p, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                      ))
                  .toList(),
            ),
          ),

          const SizedBox(height: 20),

          // Start Game Button
          ElevatedButton(
            onPressed: _handleStartGame,
            style: ElevatedButton.styleFrom(
              backgroundColor: UnoColors.green,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: Text(
              'കളി ആരംഭിക്കുക (START GAME)',
              style: GoogleFonts.bebasNeue(fontSize: 18, letterSpacing: 1.2),
            ),
          ),
        ],
      ),
    );
  }
}

class dynamicBoxConstraint extends BoxConstraints {
  const dynamicBoxConstraint({super.maxWidth});
}
