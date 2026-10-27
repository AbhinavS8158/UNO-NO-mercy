// ignore: avoid_web_libraries_in_flutter
import 'dart:js' as js;

void initPlatformMicrophone() {
  try {
    if (js.context.hasProperty('initVoiceMicrophone')) {
      js.context.callMethod('initVoiceMicrophone', []);
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
