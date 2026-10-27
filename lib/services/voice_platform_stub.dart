typedef SignalCallback = void Function(String targetPeerId, String type, String data);
typedef SpeakingCallback = void Function(bool isSpeaking);

void initPlatformMicrophone() {}

void setupPlatformVoiceCallbacks({
  required SignalCallback onSignal,
  required SpeakingCallback onSpeaking,
}) {}

void startPlatformCall(String peerId) {}

void handlePlatformOffer(String peerId, String offerJson) {}

void handlePlatformAnswer(String peerId, String answerJson) {}

void handlePlatformCandidate(String peerId, String candidateJson) {}

void togglePlatformVoiceMute(bool isMuted) {}

void closePlatformVoice() {}
