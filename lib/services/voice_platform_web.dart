// ignore: avoid_web_libraries_in_flutter
import 'dart:js' as js;
import 'dart:js_util' as js_util;

typedef SignalCallback = void Function(String targetPeerId, String type, String data);
typedef SpeakingCallback = void Function(bool isSpeaking);

void initPlatformMicrophone() {
  try {
    if (js.context.hasProperty('initLocalAudio')) {
      js.context.callMethod('initLocalAudio', []);
    }
  } catch (_) {}
}

void setupPlatformVoiceCallbacks({
  required SignalCallback onSignal,
  required SpeakingCallback onSpeaking,
}) {
  try {
    js.context['onSignalFromWebRTC'] = js_util.allowInterop((peerId, type, data) {
      onSignal(peerId.toString(), type.toString(), data.toString());
    });

    js.context['onSpeakingCallback'] = js_util.allowInterop((isSpeaking) {
      onSpeaking(isSpeaking == true);
    });
  } catch (_) {}
}

void startPlatformCall(String peerId) {
  try {
    if (js.context.hasProperty('createVoiceOffer')) {
      js.context.callMethod('createVoiceOffer', [
        peerId,
        js.context['onSignalFromWebRTC'],
      ]);
    }
  } catch (_) {}
}

void handlePlatformOffer(String peerId, String offerJson) {
  try {
    if (js.context.hasProperty('handleVoiceOffer')) {
      js.context.callMethod('handleVoiceOffer', [
        peerId,
        offerJson,
        js.context['onSignalFromWebRTC'],
      ]);
    }
  } catch (_) {}
}

void handlePlatformAnswer(String peerId, String answerJson) {
  try {
    if (js.context.hasProperty('handleVoiceAnswer')) {
      js.context.callMethod('handleVoiceAnswer', [peerId, answerJson]);
    }
  } catch (_) {}
}

void handlePlatformCandidate(String peerId, String candidateJson) {
  try {
    if (js.context.hasProperty('handleVoiceCandidate')) {
      js.context.callMethod('handleVoiceCandidate', [peerId, candidateJson]);
    }
  } catch (_) {}
}

void togglePlatformVoiceMute(bool isMuted) {
  try {
    if (js.context.hasProperty('toggleVoiceMute')) {
      js.context.callMethod('toggleVoiceMute', [isMuted]);
    }
  } catch (_) {}
}

void closePlatformVoice() {
  try {
    if (js.context.hasProperty('closeAllVoicePeers')) {
      js.context.callMethod('closeAllVoicePeers', []);
    }
  } catch (_) {}
}
