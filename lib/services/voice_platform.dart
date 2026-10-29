import 'voice_platform_stub.dart'
    if (dart.library.js_interop) 'voice_platform_web.dart' as platform;

export 'voice_platform_stub.dart'
    if (dart.library.js_interop) 'voice_platform_web.dart';

void initMicrophone() => platform.initPlatformMicrophone();
void toggleMicMute(bool isMuted) => platform.togglePlatformVoiceMute(isMuted);
void setupVoiceCallbacks({
  required platform.SignalCallback onSignal,
  required platform.SpeakingCallback onSpeaking,
}) =>
    platform.setupPlatformVoiceCallbacks(onSignal: onSignal, onSpeaking: onSpeaking);
void startVoiceCall(String peerId) => platform.startPlatformCall(peerId);
void handleVoiceOffer(String peerId, String offerJson) =>
    platform.handlePlatformOffer(peerId, offerJson);
void handleVoiceAnswer(String peerId, String answerJson) =>
    platform.handlePlatformAnswer(peerId, answerJson);
void handleVoiceCandidate(String peerId, String candidateJson) =>
    platform.handlePlatformCandidate(peerId, candidateJson);
void closeVoice() => platform.closePlatformVoice();
