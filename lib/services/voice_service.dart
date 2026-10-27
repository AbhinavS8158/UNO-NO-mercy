import 'dart:async';

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
  Timer? _speakerSimulationTimer;

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
    // Connects to WebRTC RTC Room with Token
    _isConnected = true;
    _connectionController.add(true);

    // Simulated active speaking detection
    _speakerSimulationTimer?.cancel();
    _speakerSimulationTimer = Timer.periodic(const Duration(seconds: 3), (timer) {
      if (!_isConnected || _isDeafened) return;
      // Toggle speaking state for visual waveform
      if (_currentSpeakers.contains('Vikram')) {
        _currentSpeakers.remove('Vikram');
      } else {
        _currentSpeakers.add('Vikram');
      }
      _activeSpeakersController.add(Set.from(_currentSpeakers));
    });
  }

  @override
  Future<void> disconnect() async {
    _speakerSimulationTimer?.cancel();
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
    if (_isDeafened) {
      _currentSpeakers.clear();
      _activeSpeakersController.add({});
    }
    _connectionController.add(_isConnected);
  }
}
