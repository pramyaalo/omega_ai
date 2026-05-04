import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:url_launcher/url_launcher.dart';

class ChatBubble extends StatefulWidget {
  final Map<String, dynamic> message;
  final bool isNew;

  const ChatBubble({super.key, required this.message, this.isNew = false});

  @override
  State<ChatBubble> createState() => _ChatBubbleState();
}

class _ChatBubbleState extends State<ChatBubble>
    with SingleTickerProviderStateMixin {
  late AnimationController _dotController;
  bool _copied = false;

  static const kCyan       = Color(0xFF1BA8D4);
  static const kCyanDark   = Color(0xFF1890B8);
  static const kCardBg     = Color(0xFFF0F7FF);
  static const kCardBorder = Color(0xFFD1E9F6);
  static const kTextPrimary = Color(0xFF111827);

  @override
  void initState() {
    super.initState();
    _dotController = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 900))
      ..repeat();
  }

  @override
  void dispose() {
    _dotController.dispose();
    super.dispose();
  }

  void _copyText() {
    Clipboard.setData(ClipboardData(text: widget.message['text'] ?? ''));
    setState(() => _copied = true);
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) setState(() => _copied = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark  = Theme.of(context).brightness == Brightness.dark;
    final isMe    = widget.message['isMe'] as bool? ?? false;
    final isAgent = widget.message['isAgent'] as bool? ?? false;
    final typing  = widget.message['typing'] as bool? ?? false;
    final text    = widget.message['text'] as String? ?? '';

    // ── User bubble ───────────────────────────────────────────────────────────
    if (isMe) return _userBubble(isDark, text);

    // ── Agent bubble ──────────────────────────────────────────────────────────
    if (isAgent) return _agentBubble(isDark, text);

    // ── Typing indicator ──────────────────────────────────────────────────────
    if (typing && text.isEmpty) return _typingBubble(isDark);

    // ── Normal AI bubble ──────────────────────────────────────────────────────
    return _aiBubble(isDark, text);
  }

  // ── User bubble ──────────────────────────────────────────────────────────────
  Widget _userBubble(bool isDark, String text) {
    final imgB64 = widget.message['imageBase64'] as String?;
    final imgExt = widget.message['imageExt'] as String? ?? 'jpeg';

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          const SizedBox(width: 60),
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                    colors: [kCyanDark, kCyan],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(18),
                  topRight: Radius.circular(18),
                  bottomLeft: Radius.circular(18),
                  bottomRight: Radius.circular(4),
                ),
                boxShadow: [
                  BoxShadow(color: kCyan.withOpacity(0.25), blurRadius: 8, offset: const Offset(0, 3))
                ],
              ),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                if (imgB64 != null) ...[
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: Image.memory(base64Decode(imgB64), width: 200, fit: BoxFit.cover),
                  ),
                  if (text.isNotEmpty) const SizedBox(height: 8),
                ],
                if (text.isNotEmpty)
                  Text(text, style: const TextStyle(color: Colors.white, fontSize: 14, height: 1.4)),
              ]),
            ),
          ),
          const SizedBox(width: 8),
          CircleAvatar(
            radius: 16,
            backgroundColor: kCyan,
            child: const Icon(Icons.person, color: Colors.white, size: 16),
          ),
        ],
      ),
    );
  }

  // ── Typing dots ──────────────────────────────────────────────────────────────
  Widget _typingBubble(bool isDark) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          _omegaAvatar(),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1A2744) : kCardBg,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(18),
                topRight: Radius.circular(18),
                bottomRight: Radius.circular(18),
                bottomLeft: Radius.circular(4),
              ),
              border: Border.all(color: isDark ? const Color(0xFF1E3354) : kCardBorder),
            ),
            child: AnimatedBuilder(
              animation: _dotController,
              builder: (_, __) {
                return Row(mainAxisSize: MainAxisSize.min, children: [
                  for (int i = 0; i < 3; i++) ...[
                    _dot(i, isDark),
                    if (i < 2) const SizedBox(width: 4),
                  ],
                ]);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _dot(int index, bool isDark) {
    final phase = (_dotController.value - index * 0.2).clamp(0.0, 1.0);
    final opacity = (0.3 + 0.7 * (phase < 0.5 ? phase * 2 : (1 - phase) * 2)).clamp(0.0, 1.0);
    return Container(
      width: 8, height: 8,
      decoration: BoxDecoration(
        color: kCyan.withOpacity(opacity),
        shape: BoxShape.circle,
      ),
    );
  }

  // ── Agent bubble — shows steps + final answer ─────────────────────────────────
  Widget _agentBubble(bool isDark, String text) {
    final steps       = widget.message['agentSteps'] as List? ?? [];
    final agentActive = widget.message['agentActive'] as bool? ?? false;
    final hasAnswer   = text.isNotEmpty;

    final bgColor     = isDark ? const Color(0xFF0F2035) : const Color(0xFFF0FAFF);
    final borderColor = isDark ? const Color(0xFF1B4060) : const Color(0xFFB3E0F2);

    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _omegaAvatar(),
          const SizedBox(width: 8),
          Flexible(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

              // ── Agent badge ────────────────────────────────────────
              Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(colors: [Color(0xFF6C3DE8), Color(0xFF1BA8D4)]),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.auto_awesome, color: Colors.white, size: 12),
                  SizedBox(width: 4),
                  Text("⚡ Agent Mode", style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700)),
                ]),
              ),

              // ── Steps card ─────────────────────────────────────────
              if (steps.isNotEmpty)
                Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: bgColor,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: borderColor),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: steps.asMap().entries.map((e) {
                      final step  = e.value as Map;
                      final label = step['label'] as String? ?? '';
                      final stype = step['step'] as String? ?? '';
                      final isLast = e.key == steps.length - 1;

                      IconData icon;
                      Color    iconColor;
                      switch (stype) {
                        case 'thinking':
                          icon = Icons.psychology_rounded; iconColor = const Color(0xFF6C3DE8);
                        case 'searching':
                          icon = Icons.search;             iconColor = kCyan;
                        case 'observing':
                          icon = Icons.analytics_rounded;  iconColor = Colors.green;
                        default:
                          icon = Icons.circle;             iconColor = Colors.grey;
                      }

                      return Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: Row(children: [
                          // Step icon
                          Container(
                            width: 28, height: 28,
                            decoration: BoxDecoration(
                              color: iconColor.withOpacity(0.12),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Icon(icon, color: iconColor, size: 15),
                          ),
                          const SizedBox(width: 8),
                          Flexible(
                            child: Text(label,
                              style: TextStyle(
                                fontSize: 13,
                                color: isDark ? Colors.white70 : kTextPrimary,
                                fontWeight: isLast && agentActive ? FontWeight.w600 : FontWeight.normal,
                              ),
                            ),
                          ),
                          // Spinner on last active step
                          if (isLast && agentActive) ...[
                            const SizedBox(width: 6),
                            SizedBox(
                              width: 12, height: 12,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: iconColor),
                            ),
                          ] else if (!agentActive || !isLast) ...[
                            const SizedBox(width: 6),
                            Icon(Icons.check_circle, color: Colors.green, size: 14),
                          ],
                        ]),
                      );
                    }).toList(),
                  ),
                ),

              // ── Final answer ───────────────────────────────────────
              if (hasAnswer)
                _answerBubble(isDark, text),

              // ── Still working indicator ────────────────────────────
              if (agentActive && !hasAnswer)
                AnimatedBuilder(
                  animation: _dotController,
                  builder: (_, __) => Row(children: [
                    for (int i = 0; i < 3; i++) ...[_dot(i, isDark), if (i < 2) const SizedBox(width: 4)],
                  ]),
                ),
            ]),
          ),
        ],
      ),
    );
  }

  // ── Normal AI bubble ──────────────────────────────────────────────────────────
  Widget _aiBubble(bool isDark, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _omegaAvatar(),
          const SizedBox(width: 8),
          Flexible(child: _answerBubble(isDark, text)),
        ],
      ),
    );
  }

  // ── Open URL in external browser ─────────────────────────────────────────────
  static Future<void> _openUrl(BuildContext context, String rawUrl) async {
    try {
      String cleaned = rawUrl.trim().replaceAll(RegExp(r'\s+'), '');
      if (!cleaned.startsWith('http://') && !cleaned.startsWith('https://')) {
        cleaned = 'https://$cleaned';
      }
      final uri = Uri.parse(cleaned);
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (e) {
      await Clipboard.setData(ClipboardData(text: rawUrl));
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Link copied! Open in browser manually"),
            backgroundColor: Colors.orange,
          ),
        );
      }
    }
  }
  // ── Link tap popup ────────────────────────────────────────────────────────────
  void _showLinkPopup(BuildContext context, String url) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? const Color(0xFF1A2744) : Colors.white;
    final textColor = isDark ? Colors.white : const Color(0xFF111827);

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          // Handle bar
          Container(
            width: 40, height: 4,
            margin: const EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(
              color: Colors.grey.withOpacity(0.3),
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // URL preview
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF0D1B2A) : const Color(0xFFF0F7FF),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFD1E9F6)),
            ),
            child: Row(children: [
              const Icon(Icons.link, color: kCyan, size: 16),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  url,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: kCyan, fontSize: 12),
                ),
              ),
            ]),
          ),
          const SizedBox(height: 16),

          // Copy link button
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              icon: const Icon(Icons.copy, size: 18),
              label: const Text("Copy Link"),
              style: OutlinedButton.styleFrom(
                foregroundColor: textColor,
                side: BorderSide(color: Colors.grey.withOpacity(0.3)),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: () {
                Clipboard.setData(ClipboardData(text: url));
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: const Row(children: [
                      Icon(Icons.check_circle, color: Colors.white, size: 16),
                      SizedBox(width: 8),
                      Text("Link copied!"),
                    ]),
                    backgroundColor: Colors.green,
                    duration: const Duration(seconds: 2),
                    behavior: SnackBarBehavior.floating,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 10),

          // Open in browser button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              icon: const Icon(Icons.open_in_browser, size: 18),
              label: const Text("Open in Browser"),
              style: ElevatedButton.styleFrom(
                backgroundColor: kCyan,
                foregroundColor: Colors.white,
                elevation: 0,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: () async {
                // ✅ Launch FIRST, then pop — context invalid after pop
                final nav = Navigator.of(context);
                await _openUrl(context, url);
                nav.pop();
              },
            ),
          ),
        ]),
      ),
    );
  }

  // ── Shared answer bubble (used by normal + agent) ─────────────────────────────
  Widget _answerBubble(bool isDark, String text) {
    if (text.isEmpty) return const SizedBox.shrink();

    final bgColor     = isDark ? const Color(0xFF1A2744) : kCardBg;
    final borderColor = isDark ? const Color(0xFF1E3354) : kCardBorder;
    final textColor   = isDark ? Colors.white : kTextPrimary;

    return GestureDetector(
      onLongPress: _copyText,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(18),
            topRight: Radius.circular(18),
            bottomRight: Radius.circular(18),
            bottomLeft: Radius.circular(4),
          ),
          border: Border.all(color: borderColor),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            MarkdownBody(
              data: text,
              onTapLink: (linkText, href, title) {
                if (href != null && href.isNotEmpty) {
                  _showLinkPopup(context, href);
                }
              },
              styleSheet: MarkdownStyleSheet(
                p: TextStyle(color: textColor, fontSize: 14, height: 1.5),
                strong: TextStyle(color: textColor, fontWeight: FontWeight.bold, fontSize: 14),
                em: TextStyle(color: textColor, fontStyle: FontStyle.italic),
                code: TextStyle(
                    fontFamily: 'monospace', fontSize: 13,
                    backgroundColor: isDark ? const Color(0xFF0A1628) : const Color(0xFFE8F4FD),
                    color: kCyan),
                codeblockDecoration: BoxDecoration(
                    color: isDark ? const Color(0xFF0A1628) : const Color(0xFFE8F4FD),
                    borderRadius: BorderRadius.circular(8)),
                listBullet: TextStyle(color: kCyan, fontSize: 14),
                h1: TextStyle(color: textColor, fontSize: 18, fontWeight: FontWeight.bold),
                h2: TextStyle(color: textColor, fontSize: 16, fontWeight: FontWeight.bold),
                h3: TextStyle(color: textColor, fontSize: 14, fontWeight: FontWeight.bold),
              ),
            ),
            // Copy feedback
            if (_copied)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Row(children: [
                  const Icon(Icons.check, color: Colors.green, size: 12),
                  const SizedBox(width: 4),
                  Text("Copied!", style: TextStyle(color: Colors.green, fontSize: 11)),
                ]),
              ),
          ],
        ),
      ),
    );
  }

  Widget _omegaAvatar() {
    return Container(
      width: 30, height: 30,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
            colors: [kCyanDark, kCyan],
            begin: Alignment.topLeft, end: Alignment.bottomRight),
        borderRadius: BorderRadius.circular(8),
        boxShadow: [BoxShadow(color: kCyan.withOpacity(0.3), blurRadius: 6, offset: const Offset(0, 2))],
      ),
      child: const Center(
        child: Text("Ω", style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold)),
      ),
    );
  }
}