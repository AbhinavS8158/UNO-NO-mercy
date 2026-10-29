import 'dart:js_interop';
import 'dart:js_interop_unsafe';

typedef SignalCallback = void Function(String targetPeerId, String type, String data);
typedef SpeakingCallback = void Function(bool isSpeaking);

void initPlatformMicrophone() {
  try {
    if (globalContext.has('initLocalAudio')) {
      globalContext.callMethod('initLocalAudio'.toJS);
    }
  } catch (_) {}
}

void setupPlatformVoiceCallbacks({
  required SignalCallback onSignal,
  required SpeakingCallback onSpeaking,
}) {
  try {
    globalContext['onSignalFromWebRTC'] = ((JSAny? peerId, JSAny? type, JSAny? data) {
      onSignal(peerId?.toString() ?? '', type?.toString() ?? '', data?.toString() ?? '');
    }).toJS;

    globalContext['onSpeakingCallback'] = ((JSAny? isSpeaking) {
      onSpeaking(isSpeaking != null && isSpeaking.dartify() == true);
    }).toJS;
  } catch (_) {}
}

void startPlatformCall(String peerId) {
  try {
    if (globalContext.has('createVoiceOffer')) {
      globalContext.callMethod(
        'createVoiceOffer'.toJS,
        peerId.toJS,
        globalContext['onSignalFromWebRTC'],
      );
    }
  } catch (_) {}
}

void handlePlatformOffer(String peerId, String offerJson) {
  try {
    if (globalContext.has('handleVoiceOffer')) {
      globalContext.callMethod(
        'handleVoiceOffer'.toJS,
        peerId.toJS,
        offerJson.toJS,
        globalContext['onSignalFromWebRTC'],
      );
    }
  } catch (_) {}
}

void handlePlatformAnswer(String peerId, String answerJson) {
  try {
    if (globalContext.has('handleVoiceAnswer')) {
      globalContext.callMethod('handleVoiceAnswer'.toJS, peerId.toJS, answerJson.toJS);
    }
  } catch (_) {}
}

void handlePlatformCandidate(String peerId, String candidateJson) {
  try {
    if (globalContext.has('handleVoiceCandidate')) {
      globalContext.callMethod('handleVoiceCandidate'.toJS, peerId.toJS, candidateJson.toJS);
    }
  } catch (_) {}
}

void togglePlatformVoiceMute(bool isMuted) {
  try {
    if (globalContext.has('toggleVoiceMute')) {
      globalContext.callMethod('toggleVoiceMute'.toJS, isMuted.toJS);
    }
  } catch (_) {}
}

void closePlatformVoice() {
  try {
    if (globalContext.has('closeAllVoicePeers')) {
      globalContext.callMethod('closeAllVoicePeers'.toJS);
    }
  } catch (_) {}
}
