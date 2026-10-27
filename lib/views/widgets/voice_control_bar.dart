import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/theme/uno_colors.dart';
import '../../services/voice_service.dart';

class VoiceControlSheet extends StatefulWidget {
  final String roomCode;
  final IVoiceService voiceService;

  const VoiceControlSheet({
    super.key,
    required this.roomCode,
    required this.voiceService,
  });

  @override
  State<VoiceControlSheet> createState() => _VoiceControlSheetState();
}

class _VoiceControlSheetState extends State<VoiceControlSheet> {
  @override
  Widget build(BuildContext context) {
    final vs = widget.voiceService;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: const BoxDecoration(
        color: UnoColors.surfaceElevated,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.white24,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 16),

          // Channel Header
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: vs.isConnected ? Colors.green.withOpacity(0.2) : Colors.red.withOpacity(0.2),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  vs.isConnected ? Icons.volume_up : Icons.volume_off,
                  color: vs.isConnected ? Colors.greenAccent : Colors.redAccent,
                  size: 22,
                ),
              ),
              const SizedBox(width: 14),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'VOICE CHANNEL: ${widget.roomCode}',
                    style: GoogleFonts.bebasNeue(
                      color: Colors.white,
                      fontSize: 18,
                      letterSpacing: 1.2,
                    ),
                  ),
                  Text(
                    vs.isConnected
                        ? 'LiveKit RTC Connected (Encrypted)'
                        : 'Disconnected from voice room',
                    style: TextStyle(
                      color: vs.isConnected ? Colors.greenAccent : Colors.white54,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
              const Spacer(),
              // Connect / Disconnect button
              TextButton(
                onPressed: () {
                  setState(() {
                    if (vs.isConnected) {
                      vs.disconnect();
                    } else {
                      vs.connect(roomCode: widget.roomCode, token: 'dev_token');
                    }
                  });
                },
                child: Text(
                  vs.isConnected ? 'LEAVE' : 'CONNECT',
                  style: TextStyle(
                    color: vs.isConnected ? Colors.redAccent : Colors.greenAccent,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 20),

          // Audio Controls (Mute / Deafen)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.black26,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                // Mic Button
                InkWell(
                  onTap: vs.isConnected
                      ? () => setState(() => vs.toggleMute())
                      : null,
                  borderRadius: BorderRadius.circular(12),
                  child: Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Column(
                      children: [
                        Icon(
                          vs.isMuted ? Icons.mic_off : Icons.mic,
                          color: vs.isMuted ? Colors.redAccent : Colors.greenAccent,
                          size: 28,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          vs.isMuted ? 'Unmute' : 'Mute',
                          style: const TextStyle(color: Colors.white70, fontSize: 11),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(
                  height: 36,
                  child: VerticalDivider(color: Colors.white24),
                ),

                // Deafen Button
                InkWell(
                  onTap: vs.isConnected
                      ? () => setState(() => vs.toggleDeafen())
                      : null,
                  borderRadius: BorderRadius.circular(12),
                  child: Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Column(
                      children: [
                        Icon(
                          vs.isDeafened ? Icons.headset_off : Icons.headset,
                          color: vs.isDeafened ? Colors.redAccent : Colors.white,
                          size: 28,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          vs.isDeafened ? 'Undeafen' : 'Deafen',
                          style: const TextStyle(color: Colors.white70, fontSize: 11),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),
          const Text(
            'സെർവർ പരിശോധിച്ച ഓതറൈസേഷൻ ടോക്കൺ വഴി ഈ റൂമിലുള്ളവർക്ക് മാത്രമേ സംസാരിക്കാൻ കഴിയൂ.',
            style: TextStyle(color: Colors.white38, fontSize: 11),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}
