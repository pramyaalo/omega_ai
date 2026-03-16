import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:share_plus/share_plus.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:web_socket_channel/status.dart' as status;

// ─────────────────────────────────────────────
// Template categories + types
// ─────────────────────────────────────────────
const List<Map<String, dynamic>> kCategories = [
  {
    'label': 'Business',
    'icon': Icons.business_center_rounded,
    'color': Color(0xFF1A73E8),
    'types': [
      'Business Proposal',
      'Project Report',
      'Meeting Agenda',
      'Executive Summary',
      'Invoice',
    ],
  },
  {
    'label': 'Email',
    'icon': Icons.email_rounded,
    'color': Color(0xFF34A853),
    'types': [
      'Professional Email',
      'Follow-up Email',
      'Apology Email',
      'Cold Outreach',
      'Thank You Email',
    ],
  },
  {
    'label': 'Resume',
    'icon': Icons.person_rounded,
    'color': Color(0xFFEA4335),
    'types': [
      'Software Engineer CV',
      'Fresher Resume',
      'Cover Letter',
      'LinkedIn Summary',
      'Portfolio Bio',
    ],
  },
  {
    'label': 'Social',
    'icon': Icons.share_rounded,
    'color': Color(0xFFFF6D00),
    'types': [
      'Instagram Caption',
      'Twitter/X Post',
      'LinkedIn Post',
      'YouTube Description',
      'Product Launch Post',
    ],
  },
  {
    'label': 'Legal',
    'icon': Icons.gavel_rounded,
    'color': Color(0xFF9C27B0),
    'types': [
      'NDA Agreement',
      'Privacy Policy',
      'Terms & Conditions',
      'Freelance Contract',
      'Disclaimer',
    ],
  },
  {
    'label': 'Creative',
    'icon': Icons.auto_awesome_rounded,
    'color': Color(0xFFFF4081),
    'types': [
      'Blog Post',
      'Story Outline',
      'Product Description',
      'Ad Copy',
      'Tagline Ideas',
    ],
  },
];

class TemplateGeneratorScreen extends StatefulWidget {
  const TemplateGeneratorScreen({super.key});

  @override
  State<TemplateGeneratorScreen> createState() => _TemplateGeneratorScreenState();
}

class _TemplateGeneratorScreenState extends State<TemplateGeneratorScreen>
    with TickerProviderStateMixin {

  // State
  int _selectedCategoryIndex = 0;
  String? _selectedType;
  final TextEditingController _ideaController = TextEditingController();
  final TextEditingController _toneController = TextEditingController();
  String _generatedTemplate = '';
  bool _isGenerating = false;
  bool _showPreview = false;
  String _selectedLanguage = 'English';

  // WebSocket
  WebSocketChannel? _channel;

  // Animation
  late AnimationController _shimmerController;
  late AnimationController _slideController;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _loadLanguage();
    _shimmerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();
    _slideController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 1),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _slideController, curve: Curves.easeOutCubic));
  }

  Future<void> _loadLanguage() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() => _selectedLanguage = prefs.getString('selected_language') ?? 'English');
  }

  @override
  void dispose() {
    _channel?.sink.close(status.goingAway);
    _shimmerController.dispose();
    _slideController.dispose();
    _ideaController.dispose();
    _toneController.dispose();
    super.dispose();
  }

  // ── Generate via WebSocket ──
  void _generateTemplate() {
    final idea = _ideaController.text.trim();
    if (idea.isEmpty) {
      _showSnack('Please enter your idea or topic!');
      return;
    }
    final type = _selectedType ?? kCategories[_selectedCategoryIndex]['types'][0];
    final tone = _toneController.text.trim().isNotEmpty
        ? _toneController.text.trim()
        : 'professional';

    final prompt =
        'Generate a complete, ready-to-use "$type" template for the following idea/topic: "$idea". '
        'Tone: $tone. '
        'Make it detailed, professional, and fully filled with relevant placeholder content. '
        'Format it clearly with proper sections, headings, and structure. '
        'Language: $_selectedLanguage.';

    setState(() {
      _isGenerating = true;
      _generatedTemplate = '';
      _showPreview = false;
    });

    try { _channel?.sink.close(status.goingAway); } catch (_) {}
    _channel = WebSocketChannel.connect(Uri.parse('ws://192.168.1.4:8000/ws/chat/'));

    _channel!.stream.listen((data) {
      final decoded = jsonDecode(data);
      final type_ = decoded['type'];
      final text = decoded['message'] ?? '';

      setState(() {
        if (type_ == 'stream') {
          _generatedTemplate = text;
        }
        if (type_ == 'done') {
          _isGenerating = false;
          _showPreview = true;
          _slideController.forward(from: 0);
        }
      });
    }, onError: (_) {
      setState(() => _isGenerating = false);
      _showSnack('Connection error. Check server.');
    });

    _channel!.sink.add(jsonEncode({
      'message': prompt,
      'language': _selectedLanguage,
    }));
  }

  void _copyTemplate() {
    Clipboard.setData(ClipboardData(text: _generatedTemplate));
    _showSnack('Template copied! ✅');
  }

  void _shareTemplate() {
    if (_generatedTemplate.isEmpty) return;
    Share.share(_generatedTemplate, subject: 'Template from Omega AI');
  }

  void _resetAll() {
    setState(() {
      _generatedTemplate = '';
      _showPreview = false;
      _ideaController.clear();
      _toneController.clear();
      _selectedType = null;
    });
    _slideController.reset();
  }

  void _showSnack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? const Color(0xFF121212) : const Color(0xFFAACBE5);
    final card = isDark ? const Color(0xFF1E1E1E) : Colors.white;
    final textColor = isDark ? Colors.white : Colors.black87;
    final subColor = isDark ? Colors.white54 : Colors.black54;
    final category = kCategories[_selectedCategoryIndex];
    final accent = category['color'] as Color;

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
                Icon(Icons.auto_awesome_rounded, color: accent, size: 24),
                const SizedBox(width: 8),
                Text('Template Generator',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: textColor)),
                const Spacer(),
                if (_showPreview)
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
                padding: const EdgeInsets.all(16),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

                  // ── Category selector ──
                  Text('Select Category', style: TextStyle(fontWeight: FontWeight.w600, color: textColor, fontSize: 14)),
                  const SizedBox(height: 10),
                  SizedBox(
                    height: 80,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: kCategories.length,
                      separatorBuilder: (_, __) => const SizedBox(width: 10),
                      itemBuilder: (context, i) {
                        final cat = kCategories[i];
                        final isSelected = i == _selectedCategoryIndex;
                        final catColor = cat['color'] as Color;
                        return GestureDetector(
                          onTap: () => setState(() {
                            _selectedCategoryIndex = i;
                            _selectedType = null;
                          }),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            width: 72,
                            decoration: BoxDecoration(
                              color: isSelected ? catColor : card,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: isSelected ? catColor : catColor.withOpacity(0.3),
                                width: isSelected ? 2 : 1,
                              ),
                              boxShadow: isSelected ? [
                                BoxShadow(color: catColor.withOpacity(0.3), blurRadius: 8, offset: const Offset(0, 3))
                              ] : [],
                            ),
                            child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                              Icon(cat['icon'] as IconData,
                                  color: isSelected ? Colors.white : catColor, size: 26),
                              const SizedBox(height: 4),
                              Text(cat['label'] as String,
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w600,
                                    color: isSelected ? Colors.white : catColor,
                                  )),
                            ]),
                          ),
                        );
                      },
                    ),
                  ),

                  const SizedBox(height: 18),

                  // ── Template type ──
                  Text('Template Type', style: TextStyle(fontWeight: FontWeight.w600, color: textColor, fontSize: 14)),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: (category['types'] as List<String>).map((type) {
                      final isSelected = type == (_selectedType ?? category['types'][0]);
                      return GestureDetector(
                        onTap: () => setState(() => _selectedType = type),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 180),
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                          decoration: BoxDecoration(
                            color: isSelected ? accent : card,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: isSelected ? accent : accent.withOpacity(0.3),
                            ),
                          ),
                          child: Text(type,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                                color: isSelected ? Colors.white : accent,
                              )),
                        ),
                      );
                    }).toList(),
                  ),

                  const SizedBox(height: 18),

                  // ── Idea input ──
                  Text('Your Idea / Topic', style: TextStyle(fontWeight: FontWeight.w600, color: textColor, fontSize: 14)),
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
                        hintText: 'e.g. Mobile app development proposal for a startup...',
                        hintStyle: TextStyle(color: subColor, fontSize: 13),
                        contentPadding: const EdgeInsets.all(14),
                        border: InputBorder.none,
                      ),
                    ),
                  ),

                  const SizedBox(height: 12),

                  // ── Tone input ──
                  Text('Tone (optional)', style: TextStyle(fontWeight: FontWeight.w600, color: textColor, fontSize: 14)),
                  const SizedBox(height: 8),
                  Container(
                    decoration: BoxDecoration(
                      color: card,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: accent.withOpacity(0.2)),
                    ),
                    child: TextField(
                      controller: _toneController,
                      style: TextStyle(color: textColor),
                      decoration: InputDecoration(
                        hintText: 'e.g. professional, casual, formal, friendly...',
                        hintStyle: TextStyle(color: subColor, fontSize: 13),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        border: InputBorder.none,
                        prefixIcon: Icon(Icons.tune_rounded, color: accent, size: 20),
                      ),
                    ),
                  ),

                  const SizedBox(height: 20),

                  // ── Generate button ──
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton(
                      onPressed: _isGenerating ? null : _generateTemplate,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: accent,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        elevation: 4,
                        shadowColor: accent.withOpacity(0.4),
                      ),
                      child: _isGenerating
                          ? Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                        SizedBox(
                          width: 18, height: 18,
                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                        ),
                        const SizedBox(width: 12),
                        const Text('Generating...', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                      ])
                          : Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                        const Icon(Icons.auto_awesome_rounded, size: 20),
                        const SizedBox(width: 8),
                        const Text('Generate Template', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                      ]),
                    ),
                  ),

                  const SizedBox(height: 20),

                  // ── Streaming preview ──
                  if (_isGenerating && _generatedTemplate.isNotEmpty) ...[
                    _buildPreviewCard(card, textColor, subColor, accent, isStreaming: true),
                  ],

                  // ── Final preview ──
                  if (_showPreview && !_isGenerating) ...[
                    SlideTransition(
                      position: _slideAnimation,
                      child: _buildPreviewCard(card, textColor, subColor, accent, isStreaming: false),
                    ),
                  ],

                  const SizedBox(height: 20),
                ]),
              ),
            ),
          ]),
        ),
      ),
    );
  }

  Widget _buildPreviewCard(Color card, Color textColor, Color subColor, Color accent, {required bool isStreaming}) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: card,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: accent.withOpacity(0.3)),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 12, offset: const Offset(0, 4))],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Preview header
        Container(
          padding: const EdgeInsets.fromLTRB(16, 14, 12, 14),
          decoration: BoxDecoration(
            color: accent.withOpacity(0.1),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Row(children: [
            Icon(isStreaming ? Icons.pending_rounded : Icons.check_circle_rounded,
                color: accent, size: 20),
            const SizedBox(width: 8),
            Text(
              isStreaming ? 'Generating Preview...' : 'Template Ready! ✨',
              style: TextStyle(fontWeight: FontWeight.w700, color: accent, fontSize: 14),
            ),
            const Spacer(),
            if (!isStreaming) ...[
              // Copy button
              IconButton(
                icon: Icon(Icons.copy_rounded, color: accent, size: 20),
                onPressed: _copyTemplate,
                tooltip: 'Copy',
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
              ),
              // Share button
              IconButton(
                icon: Icon(Icons.share_rounded, color: accent, size: 20),
                onPressed: _shareTemplate,
                tooltip: 'Share',
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
              ),
            ],
          ]),
        ),

        // Template content
        Padding(
          padding: const EdgeInsets.all(16),
          child: SelectableText(
            _generatedTemplate,
            style: TextStyle(
              color: textColor,
              fontSize: 13.5,
              height: 1.6,
              fontFamily: 'monospace',
            ),
          ),
        ),

        // Action buttons (only when done)
        if (!isStreaming)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Row(children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _copyTemplate,
                  icon: const Icon(Icons.copy_rounded, size: 16),
                  label: const Text('Copy All'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: accent,
                    side: BorderSide(color: accent.withOpacity(0.5)),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _shareTemplate,
                  icon: const Icon(Icons.share_rounded, size: 16),
                  label: const Text('Share'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: accent,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                  ),
                ),
              ),
            ]),
          ),
      ]),
    );
  }
}