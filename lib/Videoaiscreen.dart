import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:share_plus/share_plus.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:web_socket_channel/status.dart' as status;

const List<Map<String, dynamic>> kVideoTypes = [
  {'label': 'YouTube',       'icon': '▶️', 'color': Color(0xFFFF0000)},
  {'label': 'Instagram Reel','icon': '📱', 'color': Color(0xFFE91E63)},
  {'label': 'Short Film',    'icon': '🎬', 'color': Color(0xFF1A73E8)},
  {'label': 'Ad / Promo',    'icon': '📢', 'color': Color(0xFFFF6D00)},
  {'label': 'Documentary',   'icon': '🎥', 'color': Color(0xFF607D8B)},
  {'label': 'Tutorial',      'icon': '📚', 'color': Color(0xFF2B9348)},
  {'label': 'Podcast',       'icon': '🎙️', 'color': Color(0xFF9C27B0)},
  {'label': 'Vlog',          'icon': '🤳', 'color': Color(0xFFFFB300)},
];

const List<Map<String, String>> kDurations = [
  {'label': '30 sec',  'value': '30 seconds'},
  {'label': '1 min',   'value': '1 minute'},
  {'label': '3 min',   'value': '3 minutes'},
  {'label': '5 min',   'value': '5 minutes'},
  {'label': '10 min',  'value': '10 minutes'},
  {'label': '15+ min', 'value': '15+ minutes'},
];

const List<Map<String, dynamic>> kTones = [
  {'label': 'Energetic',    'icon': '⚡', 'color': Color(0xFFFFB300)},
  {'label': 'Cinematic',    'icon': '🎞️', 'color': Color(0xFF1A73E8)},
  {'label': 'Funny',        'icon': '😂', 'color': Color(0xFFFF6D00)},
  {'label': 'Educational',  'icon': '🎓', 'color': Color(0xFF2B9348)},
  {'label': 'Emotional',    'icon': '❤️', 'color': Color(0xFFE91E63)},
  {'label': 'Motivational', 'icon': '💪', 'color': Color(0xFF9C27B0)},
];

class VideoAiScreen extends StatefulWidget {
  const VideoAiScreen({super.key});

  @override
  State<VideoAiScreen> createState() => _VideoAiScreenState();
}

class _VideoAiScreenState extends State<VideoAiScreen>
    with TickerProviderStateMixin {

  final TextEditingController _ideaController = TextEditingController();
  final TextEditingController _targetController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  int _selectedVideoTypeIndex = 0;
  int _selectedDurationIndex = 1;
  int _selectedToneIndex = 0;
  String _generatedScript = '';
  bool _isGenerating = false;
  bool _showResult = false;
  String _selectedLanguage = 'English';

  WebSocketChannel? _channel;

  late AnimationController _slideController;
  late AnimationController _pulseController;
  late Animation<Offset> _slideAnim;
  late Animation<double> _pulseAnim;

  @override
  void initState() {
    super.initState();
    _loadLanguage();
    _slideController = AnimationController(vsync: this, duration: const Duration(milliseconds: 500));
    _pulseController = AnimationController(vsync: this, duration: const Duration(milliseconds: 900))..repeat(reverse: true);
    _slideAnim = Tween<Offset>(begin: const Offset(0, 0.5), end: Offset.zero)
        .animate(CurvedAnimation(parent: _slideController, curve: Curves.easeOutCubic));
    _pulseAnim = Tween<double>(begin: 0.97, end: 1.03)
        .animate(CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut));
  }

  Future<void> _loadLanguage() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() => _selectedLanguage = prefs.getString('selected_language') ?? 'English');
  }

  @override
  void dispose() {
    _channel?.sink.close(status.goingAway);
    _slideController.dispose();
    _pulseController.dispose();
    _ideaController.dispose();
    _targetController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _generate() {
    final idea = _ideaController.text.trim();
    if (idea.isEmpty) {
      _showSnack('Please enter your video idea or topic!');
      return;
    }

    setState(() { _isGenerating = true; _generatedScript = ''; _showResult = false; });
    _slideController.reset();

    final videoType = kVideoTypes[_selectedVideoTypeIndex];
    final duration = kDurations[_selectedDurationIndex];
    final tone = kTones[_selectedToneIndex];
    final target = _targetController.text.trim().isNotEmpty
        ? _targetController.text.trim()
        : 'general audience';

    final prompt =
        'You are a professional video scriptwriter and creative director. '
        'Create a complete, detailed video script for the following:\n\n'
        'VIDEO DETAILS:\n'
        '- Topic/Idea: $idea\n'
        '- Video Type: ${videoType['label']}\n'
        '- Duration: ${duration['value']}\n'
        '- Tone/Style: ${tone['label']}\n'
        '- Target Audience: $target\n\n'
        'Provide the complete video package:\n\n'
        '🎬 VIDEO TITLE\n'
        '(3 catchy title options)\n\n'
        '📋 CONCEPT SUMMARY\n'
        '(2-3 sentences overview)\n\n'
        '🎯 HOOK (First 5 seconds)\n'
        '(What grabs attention immediately)\n\n'
        '🎭 SHOT BY SHOT BREAKDOWN\n'
        'For each scene provide:\n'
        '- Timestamp\n'
        '- Scene description\n'
        '- Camera shot type (Wide/Close-up/Medium etc)\n'
        '- Dialogue/Voiceover text\n'
        '- On-screen text/graphics\n\n'
        '🎵 MUSIC & SOUND DESIGN\n'
        '- Background music mood/genre\n'
        '- Sound effects needed\n'
        '- Music timing notes\n\n'
        '✂️ EDITING NOTES\n'
        '- Transitions to use\n'
        '- Color grade suggestion\n'
        '- Pacing notes\n\n'
        '📱 THUMBNAIL CONCEPT\n'
        '(Detailed description of thumbnail)\n\n'
        '#️⃣ SEO & HASHTAGS\n'
        '- Video description (first 2 lines)\n'
        '- 10 relevant hashtags\n'
        '- Tags/Keywords\n\n'
        'Language: $_selectedLanguage\n'
        'Make it creative, engaging and ready to shoot!';

    try {
      _channel?.sink.close(status.goingAway);
      _channel = WebSocketChannel.connect(Uri.parse('ws://192.168.1.4:8000/ws/chat/'));

      _channel!.stream.listen((data) {
        final decoded = jsonDecode(data);
        setState(() {
          if (decoded['type'] == 'stream') _generatedScript = decoded['message'] ?? '';
          if (decoded['type'] == 'done') {
            _isGenerating = false;
            _showResult = true;
            _slideController.forward();
            Future.delayed(const Duration(milliseconds: 300), () {
              if (_scrollController.hasClients) {
                _scrollController.animateTo(
                  _scrollController.position.maxScrollExtent,
                  duration: const Duration(milliseconds: 500),
                  curve: Curves.easeOut,
                );
              }
            });
          }
        });
      }, onError: (_) {
        setState(() => _isGenerating = false);
        _showSnack('Connection error. Check server.');
      });

      _channel!.sink.add(jsonEncode({
        'message': prompt,
        'language': _selectedLanguage,
        'model': 'Llama 3.3 70B', // ✅ Best model for creative script writing
      }));
    } catch (e) {
      setState(() => _isGenerating = false);
      _showSnack('Error: $e');
    }
  }

  void _resetAll() {
    setState(() {
      _generatedScript = '';
      _showResult = false;
      _ideaController.clear();
      _targetController.clear();
    });
    _slideController.reset();
  }

  void _showSnack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      duration: const Duration(seconds: 2),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? const Color(0xFF121212) : const Color(0xFFAACBE5);
    final card = isDark ? const Color(0xFF1E1E1E) : Colors.white;
    final textColor = isDark ? Colors.white : Colors.black87;
    final subColor = isDark ? Colors.white54 : Colors.black54;
    const accent = Color(0xFFE94560);

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle(
        statusBarColor: bg,
        statusBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
      ),
      child: Scaffold(
        backgroundColor: bg,
        body: SafeArea(
          child: Column(children: [

            // ── Header ──
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 8, 16, 0),
              child: Row(children: [
                IconButton(
                  icon: Icon(Icons.arrow_back_ios_new_rounded, color: textColor),
                  onPressed: () => Navigator.pop(context),
                ),
                const SizedBox(width: 4),
                const Text('🎬', style: TextStyle(fontSize: 22)),
                const SizedBox(width: 8),
                Text('Video AI', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: textColor)),
                const Spacer(),
                if (_showResult)
                  TextButton.icon(
                    onPressed: _resetAll,
                    icon: const Icon(Icons.refresh_rounded, size: 16),
                    label: const Text('Reset'),
                    style: TextButton.styleFrom(foregroundColor: accent),
                  ),
              ]),
            ),

            Expanded(
              child: SingleChildScrollView(
                controller: _scrollController,
                padding: const EdgeInsets.all(16),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

                  // ── Info banner ──
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: accent.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: accent.withOpacity(0.3)),
                    ),
                    child: Row(children: [
                      const Text('🎬', style: TextStyle(fontSize: 16)),
                      const SizedBox(width: 8),
                      Expanded(child: Text(
                        'AI generates complete script, shot breakdown, music & SEO',
                        style: TextStyle(color: accent, fontSize: 12, fontWeight: FontWeight.w500),
                      )),
                    ]),
                  ),

                  const SizedBox(height: 18),

                  // ── Video idea ──
                  Text('Video Idea / Topic', style: TextStyle(fontWeight: FontWeight.w600, color: textColor, fontSize: 14)),
                  const SizedBox(height: 8),
                  Container(
                    decoration: BoxDecoration(
                      color: card,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: accent.withOpacity(0.3)),
                    ),
                    child: TextField(
                      controller: _ideaController,
                      maxLines: 3,
                      style: TextStyle(color: textColor),
                      decoration: InputDecoration(
                        hintText: 'e.g. How to start a business with zero investment in India...',
                        hintStyle: TextStyle(color: subColor, fontSize: 13),
                        contentPadding: const EdgeInsets.all(14),
                        border: InputBorder.none,
                      ),
                    ),
                  ),

                  const SizedBox(height: 18),

                  // ── Video type ──
                  Text('Video Type', style: TextStyle(fontWeight: FontWeight.w600, color: textColor, fontSize: 14)),
                  const SizedBox(height: 10),
                  SizedBox(
                    height: 82,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: kVideoTypes.length,
                      separatorBuilder: (_, __) => const SizedBox(width: 10),
                      itemBuilder: (_, i) {
                        final vt = kVideoTypes[i];
                        final isSelected = i == _selectedVideoTypeIndex;
                        final color = vt['color'] as Color;
                        return GestureDetector(
                          onTap: () => setState(() => _selectedVideoTypeIndex = i),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 180),
                            width: 78,
                            decoration: BoxDecoration(
                              color: isSelected ? color : card,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: isSelected ? color : color.withOpacity(0.3), width: isSelected ? 2 : 1),
                              boxShadow: isSelected ? [BoxShadow(color: color.withOpacity(0.3), blurRadius: 8, offset: const Offset(0, 3))] : [],
                            ),
                            child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                              Text(vt['icon'] as String, style: const TextStyle(fontSize: 22)),
                              const SizedBox(height: 4),
                              Text(vt['label'] as String,
                                  textAlign: TextAlign.center,
                                  style: TextStyle(fontSize: 9, fontWeight: FontWeight.w600,
                                      color: isSelected ? Colors.white : color)),
                            ]),
                          ),
                        );
                      },
                    ),
                  ),

                  const SizedBox(height: 18),

                  // ── Duration ──
                  Text('Duration', style: TextStyle(fontWeight: FontWeight.w600, color: textColor, fontSize: 14)),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8, runSpacing: 8,
                    children: List.generate(kDurations.length, (i) {
                      final isSelected = i == _selectedDurationIndex;
                      return GestureDetector(
                        onTap: () => setState(() => _selectedDurationIndex = i),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 180),
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          decoration: BoxDecoration(
                            color: isSelected ? accent : card,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: isSelected ? accent : accent.withOpacity(0.3)),
                          ),
                          child: Text(kDurations[i]['label']!,
                              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600,
                                  color: isSelected ? Colors.white : accent)),
                        ),
                      );
                    }),
                  ),

                  const SizedBox(height: 18),

                  // ── Tone ──
                  Text('Tone / Style', style: TextStyle(fontWeight: FontWeight.w600, color: textColor, fontSize: 14)),
                  const SizedBox(height: 10),
                  Row(
                    children: List.generate(kTones.length, (i) {
                      final t = kTones[i];
                      final isSelected = i == _selectedToneIndex;
                      final color = t['color'] as Color;
                      return Expanded(child: GestureDetector(
                        onTap: () => setState(() => _selectedToneIndex = i),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 180),
                          margin: EdgeInsets.only(right: i < kTones.length - 1 ? 6 : 0),
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          decoration: BoxDecoration(
                            color: isSelected ? color : card,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: isSelected ? color : color.withOpacity(0.3)),
                          ),
                          child: Column(children: [
                            Text(t['icon'] as String, style: const TextStyle(fontSize: 16)),
                            const SizedBox(height: 2),
                            Text(t['label'] as String,
                                textAlign: TextAlign.center,
                                style: TextStyle(fontSize: 8, fontWeight: FontWeight.w600,
                                    color: isSelected ? Colors.white : color)),
                          ]),
                        ),
                      ));
                    }),
                  ),

                  const SizedBox(height: 18),

                  // ── Target audience ──
                  Text('Target Audience (optional)', style: TextStyle(fontWeight: FontWeight.w600, color: textColor, fontSize: 14)),
                  const SizedBox(height: 8),
                  Container(
                    decoration: BoxDecoration(
                      color: card,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: accent.withOpacity(0.2)),
                    ),
                    child: TextField(
                      controller: _targetController,
                      style: TextStyle(color: textColor, fontSize: 13),
                      decoration: InputDecoration(
                        hintText: 'e.g. Students aged 18-25, entrepreneurs, Tamil audience...',
                        hintStyle: TextStyle(color: subColor, fontSize: 12),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        border: InputBorder.none,
                        prefixIcon: Icon(Icons.people_rounded, color: accent, size: 20),
                      ),
                    ),
                  ),

                  const SizedBox(height: 20),

                  // ── Generate button ──
                  ScaleTransition(
                    scale: _isGenerating ? _pulseAnim : const AlwaysStoppedAnimation(1.0),
                    child: SizedBox(
                      width: double.infinity, height: 54,
                      child: ElevatedButton(
                        onPressed: _isGenerating ? null : _generate,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: accent,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          elevation: 4,
                          shadowColor: accent.withOpacity(0.4),
                        ),
                        child: _isGenerating
                            ? Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                          const SizedBox(width: 20, height: 20,
                              child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)),
                          const SizedBox(width: 12),
                          const Text('Writing Script...', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                        ])
                            : const Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                          Text('🎬', style: TextStyle(fontSize: 20)),
                          SizedBox(width: 10),
                          Text('Generate Video Script', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                        ]),
                      ),
                    ),
                  ),

                  const SizedBox(height: 20),

                  // ── Streaming result ──
                  if (_isGenerating && _generatedScript.isNotEmpty)
                    _buildResultCard(card, textColor, accent, isStreaming: true),

                  // ── Final result ──
                  if (_showResult && !_isGenerating)
                    SlideTransition(
                      position: _slideAnim,
                      child: _buildResultCard(card, textColor, accent, isStreaming: false),
                    ),

                  const SizedBox(height: 20),
                ]),
              ),
            ),
          ]),
        ),
      ),
    );
  }

  Widget _buildResultCard(Color card, Color textColor, Color accent, {required bool isStreaming}) {
    final videoType = kVideoTypes[_selectedVideoTypeIndex];
    final tone = kTones[_selectedToneIndex];
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: card,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: accent.withOpacity(0.3)),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 12, offset: const Offset(0, 4))],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

        // Result header
        Container(
          padding: const EdgeInsets.fromLTRB(16, 14, 12, 14),
          decoration: BoxDecoration(
            color: accent.withOpacity(0.1),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Row(children: [
            Text(videoType['icon'] as String, style: const TextStyle(fontSize: 20)),
            const SizedBox(width: 8),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(
                isStreaming ? 'Writing your script...' : 'Script Ready! 🎬',
                style: TextStyle(fontWeight: FontWeight.w700, color: accent, fontSize: 14),
              ),
              Text(
                '${videoType['label']} • ${kDurations[_selectedDurationIndex]['label']} • ${tone['label']}',
                style: TextStyle(fontSize: 11, color: accent.withOpacity(0.7)),
              ),
            ])),
            if (!isStreaming) ...[
              IconButton(
                icon: Icon(Icons.copy_rounded, color: accent, size: 20),
                onPressed: () { Clipboard.setData(ClipboardData(text: _generatedScript)); _showSnack('Script copied! ✅'); },
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
              ),
              IconButton(
                icon: Icon(Icons.share_rounded, color: accent, size: 20),
                onPressed: () => Share.share('🎬 Video Script\n\n$_generatedScript\n\n— Omega AI'),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
              ),
            ],
          ]),
        ),

        // Script content
        Padding(
          padding: const EdgeInsets.all(16),
          child: SelectableText(
            _generatedScript,
            style: TextStyle(color: textColor, fontSize: 13.5, height: 1.65),
          ),
        ),

        // Action buttons
        if (!isStreaming)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Row(children: [
              Expanded(child: OutlinedButton.icon(
                onPressed: () { Clipboard.setData(ClipboardData(text: _generatedScript)); _showSnack('Copied! ✅'); },
                icon: const Icon(Icons.copy_rounded, size: 16),
                label: const Text('Copy Script'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: accent,
                  side: BorderSide(color: accent.withOpacity(0.5)),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  padding: const EdgeInsets.symmetric(vertical: 10),
                ),
              )),
              const SizedBox(width: 10),
              Expanded(child: ElevatedButton.icon(
                onPressed: () => Share.share('🎬 Video Script\n\n$_generatedScript\n\n— Omega AI'),
                icon: const Icon(Icons.share_rounded, size: 16),
                label: const Text('Share'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: accent,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  padding: const EdgeInsets.symmetric(vertical: 10),
                ),
              )),
            ]),
          ),
      ]),
    );
  }
}