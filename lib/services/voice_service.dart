import 'dart:async';
import 'package:flutter/foundation.dart';
import 'game_service.dart';
import 'voice_platform.dart';

abstract class IVoiceService {
  bool get isConnected;
  bool get isMuted;
  bool get isDeafened;
  bool get isSpeaking;

  Future<void> connect({required String roomCode, required String token});
  Future<void> connectToRoom({
    required IGameService gameService,
    required String roomId,
    required String myPlayerId,
  });
  void syncRoomPlayers(List<String> playerIds);
  Future<void> disconnect();
  void toggleMute();
  void toggleDeafen();

  Stream<bool> get connectionStatusStream;
  Stream<Set<String>> get activeSpeakersStream;
}

class LiveKitVoiceService implements IVoiceService {
  // Singleton instance to keep audio streaming across screens without disconnect
  static final LiveKitVoiceService _instance = LiveKitVoiceService._internal();
  factory LiveKitVoiceService() => _instance;
  LiveKitVoiceService._internal();

  static LiveKitVoiceService get instance => _instance;

  bool _isConnected = false;
  bool _isMuted = false;
  bool _isDeafened = false;
  bool _isSpeaking = false;

  final _connectionController = StreamController<bool>.broadcast();
  final _activeSpeakersController = StreamController<Set<String>>.broadcast();

  IGameService? _gameService;
  String? _currentRoomId;
  String? _myPlayerId;
  StreamSubscription? _signalsSubscription;

  final Set<String> _connectedPeers = {};

  @override
  bool get isConnected => _isConnected;

  @override
  bool get isMuted => _isMuted;

  @override
  bool get isDeafened => _isDeafened;

  @override
  bool get isSpeaking => _isSpeaking;

  @override
  Stream<bool> get connectionStatusStream => _connectionController.stream;

  @override
  Stream<Set<String>> get activeSpeakersStream => _activeSpeakersController.stream;

  @override
  Future<void> connect({required String roomCode, required String token}) async {
    try {
      initMicrophone();
    } catch (e) {
      debugPrint('Voice mic init note: $e');
    }
    _isConnected = true;
    _connectionController.add(true);
  }

  @override
  Future<void> connectToRoom({
    required IGameService gameService,
    required String roomId,
    required String myPlayerId,
  }) async {
    // If already connected to the same room, avoid restarting
    if (_isConnected && _currentRoomId == roomId && _myPlayerId == myPlayerId) {
      return;
    }

    _gameService = gameService;
    _currentRoomId = roomId;
    _myPlayerId = myPlayerId;
    _connectedPeers.clear();

    try {
      initMicrophone();
    } catch (e) {
      debugPrint('Voice mic init error: $e');
    }

    // Setup WebRTC callbacks from JS
    setupVoiceCallbacks(
      onSignal: (targetPeerId, type, data) {
        if (_currentRoomId != null && _myPlayerId != null) {
          _gameService?.sendVoiceSignal(
            roomId: _currentRoomId!,
            targetId: targetPeerId,
            senderId: _myPlayerId!,
            type: type,
            data: data,
          );
        }
      },
      onSpeaking: (speaking) {
        _isSpeaking = speaking;
        if (speaking) {
          _activeSpeakersController.add({_myPlayerId ?? 'me'});
        } else {
          _activeSpeakersController.add({});
        }
      },
    );

    // Listen to incoming WebRTC signals from Firestore for this player
    _signalsSubscription?.cancel();
    _signalsSubscription = _gameService
        ?.streamVoiceSignals(roomId: roomId, myPlayerId: myPlayerId)
        .listen((signals) {
      for (final sig in signals) {
        final sigId = sig['id'] as String?;
        final from = sig['from'] as String? ?? '';
        final type = sig['type'] as String? ?? '';
        final data = sig['data'] as String? ?? '';

        if (from.isNotEmpty && data.isNotEmpty) {
          if (type == 'offer') {
            handleVoiceOffer(from, data);
          } else if (type == 'answer') {
            handleVoiceAnswer(from, data);
          } else if (type == 'candidate') {
            handleVoiceCandidate(from, data);
          }
        }

        // Delete processed signal to prevent repeat execution
        if (sigId != null && sigId.isNotEmpty) {
          _gameService?.deleteVoiceSignal(roomId: roomId, signalId: sigId);
        }
      }
    });

    _isConnected = true;
    _isMuted = false;
    _connectionController.add(true);
  }

  @override
  void syncRoomPlayers(List<String> playerIds) {
    if (!_isConnected || _myPlayerId == null) return;

    for (final otherId in playerIds) {
      if (otherId == _myPlayerId) continue;

      if (!_connectedPeers.contains(otherId)) {
        _connectedPeers.add(otherId);

        // Tie-breaker: player with smaller UID initiates the WebRTC offer
        if (_myPlayerId!.compareTo(otherId) < 0) {
          debugPrint('Voice: Initiating WebRTC call to peer: $otherId');
          startVoiceCall(otherId);
        } else {
          debugPrint('Voice: Waiting for offer from peer: $otherId');
        }
      }
    }
  }

  @override
  Future<void> disconnect() async {
    _signalsSubscription?.cancel();
    _signalsSubscription = null;
    try {
      closeVoice();
    } catch (_) {}
    _connectedPeers.clear();
    _isConnected = false;
    _currentRoomId = null;
    _connectionController.add(false);
    _activeSpeakersController.add({});
  }

  @override
  void toggleMute() {
    _isMuted = !_isMuted;
    try {
      toggleMicMute(_isMuted);
    } catch (_) {}
    _connectionController.add(_isConnected);
  }

  @override
  void toggleDeafen() {
    _isDeafened = !_isDeafened;
    _connectionController.add(_isConnected);
  }
}
