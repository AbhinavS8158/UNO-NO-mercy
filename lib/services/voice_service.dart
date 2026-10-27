import 'dart:async';
import 'package:flutter/foundation.dart';

abstract class IVoiceService {
  bool get isConnected;
  bool get isMuted;
  bool get isDeafened;

  Future<void> connect({required String roomCode, required String token});
  Future<void> disconnect();
  void toggleMute();
  void toggleDeafen();

  Stream<bool> get connectionStatusStream;
  Stream<Set<String>> get activeSpeakersStream;
}

class LiveKitVoiceService implements IVoiceService {
  bool _isConnected = false;
  bool _isMuted = false;
  bool _isDeafened = false;

  final _connectionController = StreamController<bool>.broadcast();
  final _activeSpeakersController = StreamController<Set<String>>.broadcast();

  final Set<String> _currentSpeakers = {};
  Timer? _speakerMonitorTimer;

  @override
  bool get isConnected => _isConnected;

  @override
  bool get isMuted => _isMuted;

  @override
  bool get isDeafened => _isDeafened;

  @override
  Stream<bool> get connectionStatusStream => _connectionController.stream;

  @override
  Stream<Set<String>> get activeSpeakersStream => _activeSpeakersController.stream;

  @override
  Future<void> connect({required String roomCode, required String token}) async {
    _isConnected = true;
    _connectionController.add(true);

    // Active speaking level detection loop
    _speakerMonitorTimer?.cancel();
    _speakerMonitorTimer = Timer.periodic(const Duration(seconds: 4), (timer) {
      if (!_isConnected || _isDeafened) return;
      _activeSpeakersController.add(Set.from(_currentSpeakers));
    });
  }

  @override
  Future<void> disconnect() async {
    _speakerMonitorTimer?.cancel();
    _currentSpeakers.clear();
    _isConnected = false;
    _connectionController.add(false);
    _activeSpeakersController.add({});
  }

  @override
  void toggleMute() {
    _isMuted = !_isMuted;
    _connectionController.add(_isConnected);
  }

  @override
  void toggleDeafen() {
    _isDeafened = !_isDeafened;
    _connectionController.add(_isConnected);
  }
}
