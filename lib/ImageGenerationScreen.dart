import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:web_socket_channel/status.dart' as status;
import 'package:gal/gal.dart';
class ImageGeneratorScreen extends StatefulWidget {
  const ImageGeneratorScreen({super.key});

  @override
  State<ImageGeneratorScreen> createState() => _ImageGeneratorScreenState();
}

class _ImageGeneratorScreenState extends State<ImageGeneratorScreen>
    with SingleTickerProviderStateMixin {

  // ── Colors — exact same as NewChatScreen ───────────────────
  static const kCyan        = Color(0xFF1BA8D4);
  static const kCyanDark    = Color(0xFF1890B8);
  static const kCyanLight   = Color(0xFF26C0F0);
  static const kCardBg      = Color(0xFFF0F7FF);
  static const kCardBorder  = Color(0xFFD1E9F6);
  static const kBorderLight = Color(0xFFE8EFF5);
  static const kTextPrimary = Color(0xFF111827);
  static const kTextSub     = Color(0xFF6B7280);
  static const kTextMuted   = Color(0xFF9CA3AF);
  static const kDarkBg      = Color(0xFF0D1B2A);
  static const kDarkCard    = Color(0xFF1A2744);
  static const kDarkBorder  = Color(0xFF1E3354);

  static const String BASE_URL = 'https://silo-churn-worst.ngrok-free.dev';

  // ── State ──────────────────────────────────────────────────
  final _promptController   = TextEditingController();
  final _negativeController = TextEditingController();

  bool       _isGenerating    = false;
  bool       _isEnhancing     = false;   // AI prompt enhance loading
  Uint8List? _generatedImage;
  String     _selectedModel   = 'Realistic';
  String     _selectedSize    = '512×512';
  String     _currentPrompt   = '';
  String     _enhancedBadge   = ''; // shows "✨ Enhanced" when prompt was enhanced
  List<String> _promptHistory = []; // last 5 prompts

  late AnimationController _shimmerController;
  WebSocketChannel? _wsChannel;

  final List<String> _models = [
    'Realistic', 'Artistic', 'Anime', 'Fast', 'Photorealistic'
  ];

  final Map<String, Map<String, int>> _sizes = {
    '512×512': {'width': 512,  'height': 512},
    '768×512': {'width': 768,  'height': 512},
    '512×768': {'width': 512,  'height': 768},
    '768×768': {'width': 768,  'height': 768},
  };

  final List<Map<String, dynamic>> _suggestions = [
    {'emoji': '🌅', 'label': 'Sunset',     'prompt': 'Beautiful sunset over the ocean, golden hour, realistic photography'},
    {'emoji': '🏙️', 'label': 'City Night', 'prompt': 'Futuristic city at night, neon lights, cyberpunk style'},
    {'emoji': '🌿', 'label': 'Nature',     'prompt': 'Lush green forest with sunlight filtering through trees, photorealistic'},
    {'emoji': '🎨', 'label': 'Abstract',   'prompt': 'Colorful abstract digital art, vibrant swirling patterns'},
    {'emoji': '🐉', 'label': 'Fantasy',    'prompt': 'Epic fantasy dragon flying over mountains, detailed digital art'},
    {'emoji': '👤', 'label': 'Portrait',   'prompt': 'Professional portrait of a person, studio lighting, detailed face'},
    {'emoji': '🚀', 'label': 'Space',      'prompt': 'Stunning view of nebula and stars in deep space, NASA style'},
    {'emoji': '🍜', 'label': 'Food',       'prompt': 'Delicious ramen bowl with toppings, food photography, 4K'},
  ];

  @override
  void initState() {
    super.initState();
    _shimmerController = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1500))
      ..repeat();
  }

  @override
  void dispose() {
    _wsChannel?.sink.close(status.goingAway);
    _shimmerController.dispose();
    _promptController.dispose();
    _negativeController.dispose();
    super.dispose();
  }

  // ── AI Prompt Enhancer — uses WebSocket chat ───────────────
  Future<void> _enhancePrompt() async {
    final raw = _promptController.text.trim();
    if (raw.isEmpty) { _showSnack('Enter a prompt first!', Colors.orange); return; }

    setState(() { _isEnhancing = true; _enhancedBadge = ''; });

    try {
      _wsChannel?.sink.close(status.goingAway);
      _wsChannel = WebSocketChannel.connect(
          Uri.parse('wss://silo-churn-worst.ngrok-free.dev/ws/chat/'));

      final enhanceInstruction =
          'You are an expert Stable Diffusion prompt engineer. '
          'Enhance this image prompt to be more detailed and vivid for better AI image generation. '
          'Add artistic style, lighting, camera details, mood. Keep it under 100 words. '
          'Return ONLY the enhanced prompt, nothing else: "$raw"';

      String enhanced = '';

      _wsChannel!.sink.add(jsonEncode({
        'message': enhanceInstruction,
        'model':   'Smart',
        'language': 'English',
      }));

      await for (final data in _wsChannel!.stream) {
        if (!mounted) break;
        final decoded = jsonDecode(data as String);
        final type    = decoded['type'] as String? ?? '';
        if (type == 'stream') {
          enhanced = decoded['message'] ?? '';
        }
        if (type == 'done') break;
      }

      if (enhanced.isNotEmpty && mounted) {
        setState(() {
          _promptController.text = enhanced;
          _enhancedBadge         = '✨ AI Enhanced';
        });
        _showSnack('Prompt enhanced! ✨', kCyan);
      }
    } catch (e) {
      _showSnack('Enhance failed: $e', Colors.red);
    } finally {
      if (mounted) setState(() => _isEnhancing = false);
    }
  }

  // ── Generate Image ─────────────────────────────────────────
  Future<void> _generateImage() async {
    final prompt = _promptController.text.trim();
    if (prompt.isEmpty) { _showSnack("Enter a prompt first!", Colors.orange); return; }

    setState(() {
      _isGenerating  = true;
      _generatedImage = null;
      _currentPrompt  = prompt;
      _enhancedBadge  = '';
    });

    // Save to history (max 5)
    _promptHistory.remove(prompt);
    _promptHistory.insert(0, prompt);
    if (_promptHistory.length > 5) _promptHistory = _promptHistory.sublist(0, 5);

    try {
      final sizeMap = _sizes[_selectedSize]!;

      // Auto negative prompt if empty
      final negPrompt = _negativeController.text.trim().isNotEmpty
          ? _negativeController.text.trim()
          : 'ugly, blurry, low quality, distorted, watermark, text, bad anatomy, deformed';

      final response = await http.post(
        Uri.parse('$BASE_URL/api/generate-image/'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'prompt':          prompt,
          'model':           _selectedModel,
          'negative_prompt': negPrompt,
          'width':           sizeMap['width'],
          'height':          sizeMap['height'],
        }),
      ).timeout(const Duration(seconds: 150));

      if (response.statusCode == 200) {
        final data   = jsonDecode(response.body);
        final imgB64 = data['image'] as String;
        setState(() => _generatedImage = base64Decode(imgB64));
      } else {
        final err = jsonDecode(response.body)['error'] ?? 'Unknown error';
        _showSnack("Error: $err", Colors.red);
      }
    } catch (e) {
      _showSnack("Failed: $e", Colors.red);
    } finally {
      setState(() => _isGenerating = false);
    }
  }

  // ── Save ───────────────────────────────────────────────────
  Future<void> _saveImage() async {
    if (_generatedImage == null) return;
    try {
      await Gal.putImageBytes(
        _generatedImage!,
        name: 'omega_ai_${DateTime.now().millisecondsSinceEpoch}',
      );
      _showSnack("✅ Image Saved to Gallery!", Colors.green);
    } on GalException catch (e) {
      _showSnack("Save aagala: ${e.type.message}", Colors.red);
    } catch (e) {
      _showSnack("Save error: $e", Colors.red);
    }
  }

  // ── Share ──────────────────────────────────────────────────
  Future<void> _shareImage() async {
    if (_generatedImage == null) return;
    try {
      final dir  = await getTemporaryDirectory();
      final file = File('${dir.path}/omega_ai_share.png');
      await file.writeAsBytes(_generatedImage!);
      await Share.shareXFiles(
        [XFile(file.path, name: 'omega_ai_image.png', mimeType: 'image/png')],
        text: 'Generated by Omega AI: $_currentPrompt',
      );
    } catch (e) { _showSnack("Share error: $e", Colors.red); }
  }

  void _showSnack(String msg, Color color) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg), backgroundColor: color,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      duration: const Duration(seconds: 3),
    ));
  }

  // ════════════════════════════════════════════════════════════
  // BUILD
  // ════════════════════════════════════════════════════════════
  @override
  Widget build(BuildContext context) {
    final isDark      = Theme.of(context).brightness == Brightness.dark;
    final bgColor     = isDark ? kDarkBg   : const Color(0xFFF6FAFE);
    final cardColor   = isDark ? kDarkCard : Colors.white;
    final textColor   = isDark ? Colors.white : kTextPrimary;
    final borderColor = isDark ? kDarkBorder : kBorderLight;

    return Scaffold(
      backgroundColor: bgColor,

      // ── Header — same style as NewChatScreen ───────────────
      appBar: AppBar(
        backgroundColor: isDark ? kDarkBg : Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_rounded, color: textColor, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: Row(children: [
          Container(
            width: 28, height: 28,
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [kCyanDark, kCyanLight]),
              borderRadius: BorderRadius.circular(7),
            ),
            child: const Icon(Icons.auto_awesome, color: Colors.white, size: 15),
          ),
          const SizedBox(width: 8),
          const Text('Omega ', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: kCyan)),
          const Text('Images', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: kCyan)),
        ]),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Divider(height: 1, color: borderColor),
        ),
      ),

      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

          // ── Image Preview ─────────────────────────────────
          _imagePreview(isDark, borderColor),
          const SizedBox(height: 16),

          // ── Quick suggestions ─────────────────────────────
          if (_generatedImage == null && !_isGenerating) ...[
            _sectionLabel('✨ Quick ideas', textColor),
            const SizedBox(height: 8),
            _suggestionChips(),
            const SizedBox(height: 16),
          ],

          // ── Prompt History ────────────────────────────────
          if (_promptHistory.isNotEmpty && _generatedImage == null && !_isGenerating) ...[
            _sectionLabel('🕒 Recent prompts', textColor),
            const SizedBox(height: 8),
            _historyChips(textColor),
            const SizedBox(height: 16),
          ],

          // ── Prompt Input ──────────────────────────────────
          _sectionLabel('📝 Prompt', textColor),
          const SizedBox(height: 8),
          _promptInput(isDark, textColor, borderColor),
          const SizedBox(height: 8),

          // ── Enhance button ────────────────────────────────
          _enhanceButton(),
          const SizedBox(height: 14),

          // ── Settings Row ──────────────────────────────────
          _settingsRow(isDark, textColor, borderColor),
          const SizedBox(height: 14),

          // ── Negative Prompt ───────────────────────────────
          _negativePromptInput(isDark, textColor, borderColor),
          const SizedBox(height: 18),

          // ── Generate Button ───────────────────────────────
          _generateButton(),
          const SizedBox(height: 30),
        ]),
      ),
    );
  }

  // ── Image Preview ──────────────────────────────────────────
  Widget _imagePreview(bool isDark, Color borderColor) {
    if (_isGenerating) {
      return AnimatedBuilder(
        animation: _shimmerController,
        builder: (_, __) {
          final shimmer = _shimmerController.value;
          return Container(
            width: double.infinity, height: 300,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              gradient: LinearGradient(
                begin: Alignment.topLeft, end: Alignment.bottomRight,
                colors: isDark
                    ? [const Color(0xFF1A2744), const Color(0xFF0D1B2A), const Color(0xFF1A2744)]
                    : [const Color(0xFFE8F4FD), const Color(0xFFF0F7FF), const Color(0xFFE8F4FD)],
                stops: [0.0, shimmer, 1.0],
              ),
              border: Border.all(color: kCyan.withOpacity(0.3)),
            ),
            child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              const SizedBox(width: 40, height: 40,
                  child: CircularProgressIndicator(color: kCyan, strokeWidth: 3)),
              const SizedBox(height: 16),
              const Text("🎨 Generating image...",
                  style: TextStyle(color: kCyan, fontWeight: FontWeight.w600, fontSize: 14)),
              const SizedBox(height: 6),
              Text("This may take 30-60 seconds",
                  style: TextStyle(color: isDark ? Colors.white38 : kTextMuted, fontSize: 12)),
            ]),
          );
        },
      );
    }

    if (_generatedImage != null) {
      return Column(children: [
        ClipRRect(borderRadius: BorderRadius.circular(16),
            child: Image.memory(_generatedImage!, width: double.infinity, fit: BoxFit.cover)),
        const SizedBox(height: 10),
        Row(children: [
          Expanded(child: OutlinedButton.icon(
            icon: const Icon(Icons.download_rounded, size: 18),
            label: const Text("Save"),
            style: OutlinedButton.styleFrom(
              foregroundColor: kCyan, side: const BorderSide(color: kCyan),
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: _saveImage,
          )),
          const SizedBox(width: 8),
          Expanded(child: OutlinedButton.icon(
            icon: const Icon(Icons.share_rounded, size: 18),
            label: const Text("Share"),
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.green, side: const BorderSide(color: Colors.green),
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: _shareImage,
          )),
          const SizedBox(width: 8),
          Expanded(child: ElevatedButton.icon(
            icon: const Icon(Icons.refresh_rounded, size: 18),
            label: const Text("Again"),
            style: ElevatedButton.styleFrom(
              backgroundColor: kCyan, foregroundColor: Colors.white, elevation: 0,
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: _generateImage,
          )),
        ]),
        if (_currentPrompt.isNotEmpty) ...[
          const SizedBox(height: 8),
          Container(
            width: double.infinity, padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: kCyan.withOpacity(0.08), borderRadius: BorderRadius.circular(10),
              border: Border.all(color: kCyan.withOpacity(0.2)),
            ),
            child: Text('"$_currentPrompt"',
                style: const TextStyle(color: kCyan, fontSize: 12, fontStyle: FontStyle.italic)),
          ),
        ],
      ]);
    }

    // Empty state
    return Container(
      width: double.infinity, height: 200,
      decoration: BoxDecoration(
        color: kCyan.withOpacity(0.05), borderRadius: BorderRadius.circular(16),
        border: Border.all(color: kCyan.withOpacity(0.2)),
      ),
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Container(
          width: 60, height: 60,
          decoration: BoxDecoration(
            gradient: const LinearGradient(colors: [kCyanDark, kCyanLight]),
            borderRadius: BorderRadius.circular(16),
          ),
          child: const Icon(Icons.auto_awesome, color: Colors.white, size: 28),
        ),
        const SizedBox(height: 14),
        const Text("AI Image Generator",
            style: TextStyle(color: kCyan, fontSize: 16, fontWeight: FontWeight.bold)),
        const SizedBox(height: 6),
        const Text("Describe any image and generate it instantly",
            style: TextStyle(color: kTextMuted, fontSize: 12)),
      ]),
    );
  }

  // ── Suggestion Chips ───────────────────────────────────────
  Widget _suggestionChips() {
    return SizedBox(
      height: 40,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: _suggestions.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (_, i) {
          final s = _suggestions[i];
          return GestureDetector(
            onTap: () => setState(() {
              _promptController.text = s['prompt'];
              _enhancedBadge = '';
            }),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: kCyan.withOpacity(0.08), borderRadius: BorderRadius.circular(20),
                border: Border.all(color: kCyan.withOpacity(0.3)),
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Text(s['emoji'], style: const TextStyle(fontSize: 14)),
                const SizedBox(width: 5),
                Text(s['label'], style: const TextStyle(
                    color: kCyan, fontSize: 12, fontWeight: FontWeight.w500)),
              ]),
            ),
          );
        },
      ),
    );
  }

  // ── History Chips ──────────────────────────────────────────
  Widget _historyChips(Color textColor) {
    return SizedBox(
      height: 36,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: _promptHistory.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (_, i) {
          final p = _promptHistory[i];
          final short = p.length > 30 ? '${p.substring(0, 30)}...' : p;
          return GestureDetector(
            onTap: () => setState(() {
              _promptController.text = p;
              _enhancedBadge = '';
            }),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.grey.withOpacity(0.1), borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.grey.withOpacity(0.3)),
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.history, color: kTextMuted, size: 13),
                const SizedBox(width: 5),
                Text(short, style: const TextStyle(color: kTextMuted, fontSize: 11)),
              ]),
            ),
          );
        },
      ),
    );
  }

  // ── Prompt Input ───────────────────────────────────────────
  Widget _promptInput(bool isDark, Color textColor, Color borderColor) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Container(
        decoration: BoxDecoration(
          color: isDark ? kDarkCard : Colors.white, borderRadius: BorderRadius.circular(14),
          border: Border.all(color: borderColor),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(isDark ? 0.15 : 0.04), blurRadius: 8, offset: const Offset(0, 2))],
        ),
        child: TextField(
          controller: _promptController,
          style: TextStyle(color: textColor, fontSize: 14),
          maxLines: 3, minLines: 2,
          onChanged: (_) => setState(() => _enhancedBadge = ''),
          decoration: InputDecoration(
            hintText: "Describe the image you want...\ne.g. A futuristic city at sunset, cinematic, 4K",
            hintStyle: const TextStyle(color: kTextMuted, fontSize: 13),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
            contentPadding: const EdgeInsets.all(14),
            suffixIcon: _promptController.text.isNotEmpty
                ? IconButton(icon: const Icon(Icons.clear, color: kTextMuted, size: 18),
                onPressed: () => setState(() { _promptController.clear(); _enhancedBadge = ''; }))
                : null,
          ),
        ),
      ),
      // Enhanced badge
      if (_enhancedBadge.isNotEmpty) ...[
        const SizedBox(height: 6),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            gradient: const LinearGradient(colors: [kCyanDark, kCyanLight]),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(_enhancedBadge,
              style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600)),
        ),
      ],
    ]);
  }

  // ── AI Enhance Button ──────────────────────────────────────
  Widget _enhanceButton() {
    return GestureDetector(
      onTap: _isEnhancing ? null : _enhancePrompt,
      child: Container(
        width: double.infinity, padding: const EdgeInsets.symmetric(vertical: 11),
        decoration: BoxDecoration(
          color: kCyan.withOpacity(0.08), borderRadius: BorderRadius.circular(12),
          border: Border.all(color: kCyan.withOpacity(0.3)),
        ),
        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          _isEnhancing
              ? const SizedBox(width: 14, height: 14,
              child: CircularProgressIndicator(color: kCyan, strokeWidth: 2))
              : const Icon(Icons.auto_fix_high_rounded, color: kCyan, size: 16),
          const SizedBox(width: 8),
          Text(
            _isEnhancing ? 'AI enhancing prompt...' : '✨ Enhance with AI',
            style: const TextStyle(color: kCyan, fontSize: 13, fontWeight: FontWeight.w600),
          ),
        ]),
      ),
    );
  }

  // ── Settings Row ───────────────────────────────────────────
  Widget _settingsRow(bool isDark, Color textColor, Color borderColor) {
    return Row(children: [
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text("Style", style: TextStyle(color: kTextSub, fontSize: 11, fontWeight: FontWeight.w600)),
        const SizedBox(height: 4),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: isDark ? kDarkCard : Colors.white,
            borderRadius: BorderRadius.circular(10), border: Border.all(color: borderColor),
          ),
          child: DropdownButtonHideUnderline(child: DropdownButton<String>(
            value: _selectedModel, isExpanded: true,
            style: TextStyle(color: textColor, fontSize: 13),
            dropdownColor: isDark ? kDarkCard : Colors.white,
            icon: const Icon(Icons.keyboard_arrow_down, color: kCyan, size: 18),
            items: _models.map((m) => DropdownMenuItem(
                value: m, child: Text(m, style: TextStyle(color: textColor, fontSize: 13)))).toList(),
            onChanged: (v) => setState(() => _selectedModel = v!),
          )),
        ),
      ])),
      const SizedBox(width: 12),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text("Size", style: TextStyle(color: kTextSub, fontSize: 11, fontWeight: FontWeight.w600)),
        const SizedBox(height: 4),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: isDark ? kDarkCard : Colors.white,
            borderRadius: BorderRadius.circular(10), border: Border.all(color: borderColor),
          ),
          child: DropdownButtonHideUnderline(child: DropdownButton<String>(
            value: _selectedSize, isExpanded: true,
            style: TextStyle(color: textColor, fontSize: 13),
            dropdownColor: isDark ? kDarkCard : Colors.white,
            icon: const Icon(Icons.keyboard_arrow_down, color: kCyan, size: 18),
            items: _sizes.keys.map((s) => DropdownMenuItem(
                value: s, child: Text(s, style: TextStyle(color: textColor, fontSize: 13)))).toList(),
            onChanged: (v) => setState(() => _selectedSize = v!),
          )),
        ),
      ])),
    ]);
  }

  // ── Negative Prompt ────────────────────────────────────────
  Widget _negativePromptInput(bool isDark, Color textColor, Color borderColor) {
    return ExpansionTile(
      tilePadding: EdgeInsets.zero, childrenPadding: EdgeInsets.zero,
      title: const Text("⛔ Negative Prompt (optional)",
          style: TextStyle(color: kTextSub, fontSize: 13, fontWeight: FontWeight.w500)),
      iconColor: kCyan, collapsedIconColor: kTextMuted,
      children: [
        const SizedBox(height: 8),
        TextField(
          controller: _negativeController,
          style: TextStyle(color: textColor, fontSize: 13), maxLines: 2,
          decoration: InputDecoration(
            hintText: "Things to avoid (leave empty for smart auto-fill)",
            hintStyle: const TextStyle(color: kTextMuted, fontSize: 12),
            filled: true, fillColor: isDark ? kDarkCard : Colors.white,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: borderColor)),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: borderColor)),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: kCyan)),
            contentPadding: const EdgeInsets.all(12),
          ),
        ),
        const SizedBox(height: 6),
        const Text("💡 Leave empty — smart defaults auto-applied",
            style: TextStyle(color: kTextMuted, fontSize: 11)),
      ],
    );
  }

  // ── Generate Button ────────────────────────────────────────
  Widget _generateButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: _isGenerating || _isEnhancing ? null : _generateImage,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent, shadowColor: Colors.transparent,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          disabledBackgroundColor: kCyan.withOpacity(0.4),
        ),
        child: Ink(
          decoration: BoxDecoration(
            gradient: (_isGenerating || _isEnhancing) ? null
                : const LinearGradient(colors: [kCyanDark, kCyanLight], begin: Alignment.centerLeft, end: Alignment.centerRight),
            borderRadius: BorderRadius.circular(14),
            color: (_isGenerating || _isEnhancing) ? kCyan.withOpacity(0.4) : null,
          ),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 16),
            alignment: Alignment.center,
            child: _isGenerating
                ? const Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)),
              SizedBox(width: 10),
              Text("Generating...", style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w600)),
            ])
                : const Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              Icon(Icons.auto_awesome, color: Colors.white, size: 20),
              SizedBox(width: 8),
              Text("Generate Image", style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w600)),
            ]),
          ),
        ),
      ),
    );
  }

  // ── Section Label ──────────────────────────────────────────
  Widget _sectionLabel(String text, Color color) {
    return Row(children: [
      Container(width: 3, height: 15,
          decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [kCyanDark, kCyanLight], begin: Alignment.topCenter, end: Alignment.bottomCenter),
              borderRadius: BorderRadius.circular(2))),
      const SizedBox(width: 8),
      Text(text, style: TextStyle(fontWeight: FontWeight.w700, color: color, fontSize: 13, letterSpacing: 0.2)),
    ]);
  }
}