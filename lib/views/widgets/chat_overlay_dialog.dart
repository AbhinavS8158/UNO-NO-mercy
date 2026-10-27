import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/theme/uno_colors.dart';
import '../../models/chat_message.dart';
import '../../services/game_service.dart';

class ChatOverlayDialog extends StatefulWidget {
  final String roomId;
  final String roomCode;
  final String currentUserName;
  final IGameService gameService;

  const ChatOverlayDialog({
    super.key,
    required this.roomId,
    required this.roomCode,
    required this.currentUserName,
    required this.gameService,
  });

  @override
  State<ChatOverlayDialog> createState() => _ChatOverlayDialogState();
}

class _ChatOverlayDialogState extends State<ChatOverlayDialog> {
  final TextEditingController _textController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  final List<String> _quickTaunts = [
    'NO MERCY! 😈',
    'TAKE +10! 🔥',
    'UNO! 📢',
    'GG! 👏',
    'OMG! 😱',
    'SWAP HANDS! ⇄',
  ];

  void _sendMessage(String text) async {
    final cleanText = text.trim();
    if (cleanText.isEmpty) return;

    _textController.clear();
    await widget.gameService.sendChatMessage(
      roomId: widget.roomId.isNotEmpty ? widget.roomId : widget.roomCode,
      senderName: widget.currentUserName,
      text: cleanText,
    );

    // Auto scroll down
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final effectiveRoomId = widget.roomId.isNotEmpty ? widget.roomId : widget.roomCode;

    return Container(
      height: MediaQuery.of(context).size.height * 0.75,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: const BoxDecoration(
        color: UnoColors.surfaceElevated,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
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
          const SizedBox(height: 12),

          // Header
          Row(
            children: [
              const Icon(Icons.forum_outlined, color: Colors.orangeAccent),
              const SizedBox(width: 10),
              Text(
                'LIVE ROOM CHAT (${widget.roomCode})',
                style: GoogleFonts.bebasNeue(
                  color: Colors.white,
                  fontSize: 18,
                  letterSpacing: 1.2,
                ),
              ),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.close, color: Colors.white70),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),

          const Divider(color: Colors.white12),

          // Live Firestore Messages Stream
          Expanded(
            child: StreamBuilder<List<ChatMessage>>(
              stream: widget.gameService.streamChatMessages(effectiveRoomId),
              builder: (context, snapshot) {
                final messages = snapshot.data ?? [];
                if (messages.isEmpty) {
                  return const Center(
                    child: Text(
                      'മെസ്സേജുകൾ ഒന്നുമില്ല. ആദ്യത്തെ മെസ്സേജ് അയക്കൂ!',
                      style: TextStyle(color: Colors.white38, fontSize: 13),
                    ),
                  );
                }

                return ListView.builder(
                  controller: _scrollController,
                  itemCount: messages.length,
                  itemBuilder: (context, index) {
                    final msg = messages[index];
                    final isMe = msg.senderName == widget.currentUserName;

                    return Align(
                      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
                      child: Container(
                        margin: const EdgeInsets.symmetric(vertical: 4),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: isMe ? UnoColors.blue : UnoColors.surface,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isMe ? Colors.transparent : Colors.white12,
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment:
                              isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                          children: [
                            if (!isMe)
                              Text(
                                msg.senderName,
                                style: const TextStyle(
                                  color: UnoColors.yellow,
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            Text(
                              msg.text,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),

          // Quick Reaction Chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(
              children: _quickTaunts
                  .map(
                    (taunt) => Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: ActionChip(
                        backgroundColor: Colors.black38,
                        side: const BorderSide(color: Colors.white24),
                        label: Text(
                          taunt,
                          style: const TextStyle(color: Colors.white, fontSize: 11),
                        ),
                        onPressed: () => _sendMessage(taunt),
                      ),
                    ),
                  )
                  .toList(),
            ),
          ),

          // Text Field Input
          Padding(
            padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _textController,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      hintText: 'മെസ്സേജ് അയക്കൂ...',
                      hintStyle: const TextStyle(color: Colors.white38),
                      filled: true,
                      fillColor: Colors.black26,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(20),
                        borderSide: BorderSide.none,
                      ),
                    ),
                    onSubmitted: (val) => _sendMessage(val),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.send_rounded, color: Colors.blueAccent),
                  onPressed: () => _sendMessage(_textController.text),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
