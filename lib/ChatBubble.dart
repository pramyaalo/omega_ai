import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown/flutter_markdown.dart';

class ChatBubble extends StatefulWidget {
  final Map<String, dynamic> message;
  final bool isNew;

  const ChatBubble({
    super.key,
    required this.message,
    this.isNew = false,
  });

  @override
  State<ChatBubble> createState() => _ChatBubbleState();
}

class _ChatBubbleState extends State<ChatBubble>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _fadeAnimation;
  String? _selectedReaction;
  bool _showActions = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    final isMe = widget.message["isMe"] as bool;
    _slideAnimation = Tween<Offset>(
      begin: Offset(isMe ? 1.0 : -1.0, 0),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));

    _fadeAnimation = Tween<double>(begin: 0, end: 1)
        .animate(CurvedAnimation(parent: _controller, curve: Curves.easeIn));

    if (widget.isNew) {
      _controller.forward();
    } else {
      _controller.value = 1.0;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  // ── TIMESTAMP ────────────────────────────────
  String _getTime() {
    final now = DateTime.now();
    final hour = now.hour.toString().padLeft(2, '0');
    final min = now.minute.toString().padLeft(2, '0');
    return '$hour:$min';
  }

  // ── COPY ─────────────────────────────────────
  void _copyMessage(String text) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text("Message copied! ✅"),
        duration: Duration(seconds: 1),
      ),
    );
  }

  // ── REACTION ─────────────────────────────────
  void _showReactionPicker(bool isMe) {
    final reactions = ['👍', '❤️', '😂', '😮', '😢', '🔥'];
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        margin: const EdgeInsets.all(16),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: reactions.map((r) {
            return GestureDetector(
              onTap: () {
                setState(() => _selectedReaction = r);
                Navigator.pop(context);
              },
              child: Text(r, style: const TextStyle(fontSize: 30)),
            );
          }).toList(),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final msg = widget.message;
    final isMe = msg["isMe"] as bool;
    final isTyping = msg["typing"] == true;
    final imageBase64 = msg["imageBase64"];
    final text = msg["text"] ?? "";
    final cardColor = isDark ? const Color(0xFF1E1E1E) : Colors.white;
    final textColor = isDark ? Colors.white : Colors.black;
    final subTextColor = isDark ? Colors.white38 : Colors.black38;

    return FadeTransition(
      opacity: _fadeAnimation,
      child: SlideTransition(
        position: _slideAnimation,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
          child: Row(
            mainAxisAlignment:
            isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [

              // ── AI AVATAR ──────────────────────
              if (!isMe) ...[
                Container(
                  width: 32,
                  height: 32,
                  margin: const EdgeInsets.only(right: 8, bottom: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFF4F7EA6),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Center(
                    child: Text("Ω",
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        )),
                  ),
                ),
              ],

              // ── BUBBLE ─────────────────────────
              Flexible(
                child: Column(
                  crossAxisAlignment:
                  isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                  children: [

                    // Long press — actions show
                    GestureDetector(
                      onLongPress: () => setState(() => _showActions = !_showActions),
                      onDoubleTap: () => _showReactionPicker(isMe),
                      child: Container(
                        constraints: BoxConstraints(
                          maxWidth: MediaQuery.of(context).size.width * 0.68,
                        ),
                        decoration: BoxDecoration(
                          color: isMe ? const Color(0xFF4F7EA6) : cardColor,
                          borderRadius: BorderRadius.only(
                            topLeft: const Radius.circular(18),
                            topRight: const Radius.circular(18),
                            bottomLeft: Radius.circular(isMe ? 18 : 4),
                            bottomRight: Radius.circular(isMe ? 4 : 18),
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.08),
                              blurRadius: 6,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 10),
                        child: isTyping
                            ? const TypingDots()
                            : Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (imageBase64 != null)
                              ClipRRect(
                                borderRadius: BorderRadius.circular(10),
                                child: Image.memory(
                                  base64Decode(imageBase64),
                                  width: 200,
                                  fit: BoxFit.cover,
                                ),
                              ),
                            if (imageBase64 != null)
                              const SizedBox(height: 6),

                            // ✅ Markdown support
                            isMe
                                ? Text(
                              text,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 15,
                                height: 1.4,
                              ),
                            )
                                : MarkdownBody(
                              data: text,
                              styleSheet: MarkdownStyleSheet(
                                p: TextStyle(
                                  color: textColor,
                                  fontSize: 15,
                                  height: 1.4,
                                ),
                                code: TextStyle(
                                  backgroundColor: isDark
                                      ? Colors.black45
                                      : Colors.grey.shade200,
                                  color: Colors.orange,
                                  fontFamily: 'monospace',
                                  fontSize: 13,
                                ),
                                codeblockDecoration: BoxDecoration(
                                  color: isDark
                                      ? Colors.black45
                                      : Colors.grey.shade200,
                                  borderRadius:
                                  BorderRadius.circular(8),
                                ),
                                strong: TextStyle(
                                  color: textColor,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 2),

                    // ── TIMESTAMP + REACTION ───────
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (_selectedReaction != null)
                          GestureDetector(
                            onTap: () => _showReactionPicker(isMe),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: cardColor,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                    color: Colors.grey.withOpacity(0.2)),
                              ),
                              child: Text(_selectedReaction!,
                                  style: const TextStyle(fontSize: 14)),
                            ),
                          ),
                        const SizedBox(width: 4),
                        Text(
                          _getTime(),
                          style: TextStyle(
                            fontSize: 10,
                            color: subTextColor,
                          ),
                        ),
                      ],
                    ),

                    // ── ACTION BUTTONS ─────────────
                    if (_showActions && !isTyping)
                      Container(
                        margin: const EdgeInsets.only(top: 4),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: cardColor,
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.08),
                              blurRadius: 6,
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // Copy
                            _actionBtn(
                              icon: Icons.copy,
                              label: "Copy",
                              onTap: () {
                                _copyMessage(text);
                                setState(() => _showActions = false);
                              },
                            ),
                            const SizedBox(width: 8),
                            // React
                            _actionBtn(
                              icon: Icons.emoji_emotions_outlined,
                              label: "React",
                              onTap: () {
                                setState(() => _showActions = false);
                                _showReactionPicker(isMe);
                              },
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),

              // ── USER AVATAR ────────────────────
              if (isMe) ...[
                Container(
                  width: 32,
                  height: 32,
                  margin: const EdgeInsets.only(left: 8, bottom: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFF3A6A94),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Icon(Icons.person,
                      color: Colors.white, size: 18),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _actionBtn({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Icon(icon, size: 18, color: const Color(0xFF4F7EA6)),
          Text(label,
              style: const TextStyle(fontSize: 10, color: Colors.grey)),
        ],
      ),
    );
  }
}

// ── TYPING DOTS ───────────────────────────────
class TypingDots extends StatefulWidget {
  const TypingDots({super.key});

  @override
  State<TypingDots> createState() => _TypingDotsState();
}

class _TypingDotsState extends State<TypingDots> with TickerProviderStateMixin {
  late List<AnimationController> _controllers;
  late List<Animation<double>> _animations;

  @override
  void initState() {
    super.initState();
    _controllers = List.generate(
      3,
          (i) => AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 600),
      ),
    );
    _animations = _controllers.map((c) {
      return Tween<double>(begin: 0, end: -6).animate(
        CurvedAnimation(parent: c, curve: Curves.easeInOut),
      );
    }).toList();

    for (int i = 0; i < 3; i++) {
      Future.delayed(Duration(milliseconds: i * 200), () {
        if (mounted) _controllers[i].repeat(reverse: true);
      });
    }
  }

  @override
  void dispose() {
    for (var c in _controllers) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 50,
      height: 20,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: List.generate(3, (i) {
          return AnimatedBuilder(
            animation: _animations[i],
            builder: (context, child) {
              return Transform.translate(
                offset: Offset(0, _animations[i].value),
                child: Container(
                  width: 8,
                  height: 8,
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  decoration: BoxDecoration(
                    color: Colors.grey.withOpacity(0.7),
                    shape: BoxShape.circle,
                  ),
                ),
              );
            },
          );
        }),
      ),
    );
  }
}