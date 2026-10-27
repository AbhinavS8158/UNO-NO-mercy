import 'voice_platform_stub.dart'
    if (dart.library.js) 'voice_platform_web.dart' as platform;

void initMicrophone() => platform.initPlatformMicrophone();
void toggleMicMute(bool isMuted) => platform.togglePlatformVoiceMute(isMuted);
