import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

class ImageGeneratorScreen extends StatefulWidget {
  const ImageGeneratorScreen({super.key});

  @override
  State<ImageGeneratorScreen> createState() => _ImageGeneratorScreenState();
}

class _ImageGeneratorScreenState extends State<ImageGeneratorScreen>
    with SingleTickerProviderStateMixin {

  // ── Colors ──────────────────────────────────────────────────
  static const kCyan       = Color(0xFF1BA8D4);
  static const kCyanDark   = Color(0xFF1890B8);
  static const kCyanLight  = Color(0xFF26C0F0);
  static const kBgWhite    = Color(0xFFFFFFFF);
  static const kCardBg     = Color(0xFFF0F7FF);
  static const kCardBorder = Color(0xFFD1E9F6);
  static const kBorderLight= Color(0xFFE8EFF5);
  static const kTextPrimary= Color(0xFF111827);
  static const kTextSub    = Color(0xFF6B7280);
  static const kTextMuted  = Color(0xFF9CA3AF);
  static const kDarkBg     = Color(0xFF0D1B2A);
  static const kDarkCard   = Color(0xFF1A2744);
  static const kDarkBorder = Color(0xFF1E3354);

  static const String BASE_URL = 'https://silo-churn-worst.ngrok-free.dev';

  // ── State ────────────────────────────────────────────────────
  final _promptController    = TextEditingController();
  final _negativeController  = TextEditingController();

  bool       _isGenerating   = false;
  Uint8List? _generatedImage;
  String     _selectedModel  = 'Realistic';
  String     _selectedSize   = '512×512';
  String     _currentPrompt  = '';

  late AnimationController _shimmerController;

  final List<String> _models = [
    'Realistic', 'Artistic', 'Anime', 'Fast', 'Photorealistic'
  ];

  final Map<String, Map<String, int>> _sizes = {
    '512×512':  {'width': 512,  'height': 512},
    '768×512':  {'width': 768,  'height': 512},
    '512×768':  {'width': 512,  'height': 768},
    '768×768':  {'width': 768,  'height': 768},
  };

  // Quick prompt suggestions
  final List<Map<String, dynamic>> _suggestions = [
    {'emoji': '🌅', 'label': 'Sunset',       'prompt': 'Beautiful sunset over the ocean, golden hour, realistic photography'},
    {'emoji': '🏙️', 'label': 'City Night',   'prompt': 'Futuristic city at night, neon lights, cyberpunk style'},
    {'emoji': '🌿', 'label': 'Nature',        'prompt': 'Lush green forest with sunlight filtering through trees, photorealistic'},
    {'emoji': '🎨', 'label': 'Abstract',      'prompt': 'Colorful abstract digital art, vibrant swirling patterns'},
    {'emoji': '🐉', 'label': 'Fantasy',       'prompt': 'Epic fantasy dragon flying over mountains, detailed digital art'},
    {'emoji': '👤', 'label': 'Portrait',      'prompt': 'Professional portrait of a person, studio lighting, detailed face'},
    {'emoji': '🚀', 'label': 'Space',         'prompt': 'Stunning view of nebula and stars in deep space, NASA style'},
    {'emoji': '🍜', 'label': 'Food',          'prompt': 'Delicious ramen bowl with toppings, food photography, 4K'},
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
    _shimmerController.dispose();
    _promptController.dispose();
    _negativeController.dispose();
    super.dispose();
  }

  // ── Generate ─────────────────────────────────────────────────
  Future<void> _generateImage() async {
    final prompt = _promptController.text.trim();
    if (prompt.isEmpty) {
      _showSnack("Enter a prompt first!", Colors.orange);
      return;
    }
    setState(() {
      _isGenerating   = true;
      _generatedImage = null;
      _currentPrompt  = prompt;
    });

    try {
      final sizeMap = _sizes[_selectedSize]!;
      final response = await http.post(
        Uri.parse('$BASE_URL/api/generate-image/'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'prompt':          prompt,
          'model':           _selectedModel,
          'negative_prompt': _negativeController.text.trim(),
          'width':           sizeMap['width'],
          'height':          sizeMap['height'],
        }),
      ).timeout(const Duration(seconds: 150));

      if (response.statusCode == 200) {
        final data    = jsonDecode(response.body);
        final imgB64  = data['image'] as String;
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

  // ── Save Image ───────────────────────────────────────────────
  Future<void> _saveImage() async {
    if (_generatedImage == null) return;
    try {
      final dir      = Directory('/storage/emulated/0/Download');
      final exists   = await dir.exists();
      final saveDir  = exists ? dir : await getTemporaryDirectory();
      final fileName = 'omega_ai_${DateTime.now().millisecondsSinceEpoch}.png';
      final file     = File('${saveDir.path}/$fileName');
      await file.writeAsBytes(_generatedImage!);
      _showSnack("✅ Saved to Downloads: $fileName", Colors.green);
    } catch (e) {
      _showSnack("Save error: $e", Colors.red);
    }
  }

  // ── Share Image ──────────────────────────────────────────────
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
    } catch (e) {
      _showSnack("Share error: $e", Colors.red);
    }
  }

  void _showSnack(String msg, Color color) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: color,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      duration: const Duration(seconds: 3),
    ));
  }

  // ════════════════════════════════════════════════════════════
  //  BUILD
  // ════════════════════════════════════════════════════════════
  @override
  Widget build(BuildContext context) {
    final isDark      = Theme.of(context).brightness == Brightness.dark;
    final bgColor     = isDark ? kDarkBg    : kBgWhite;
    final cardColor   = isDark ? kDarkCard  : kCardBg;
    final textColor   = isDark ? Colors.white : kTextPrimary;
    final borderColor = isDark ? kDarkBorder : kBorderLight;

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: bgColor,
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
          Text("Image Generator", style: TextStyle(
              color: textColor, fontSize: 17, fontWeight: FontWeight.w700)),
        ]),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Divider(height: 1, color: borderColor),
        ),
      ),

      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

          // ── Image Preview ──────────────────────────────────
          _imagePreview(isDark, cardColor, borderColor),
          const SizedBox(height: 16),

          // ── Suggestions ────────────────────────────────────
          if (_generatedImage == null && !_isGenerating) ...[
            Text("✨ Quick ideas", style: TextStyle(
                color: textColor, fontSize: 13, fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            _suggestionChips(),
            const SizedBox(height: 16),
          ],

          // ── Prompt Input ───────────────────────────────────
          _promptInput(isDark, cardColor, textColor, borderColor),
          const SizedBox(height: 12),

          // ── Settings Row ───────────────────────────────────
          _settingsRow(isDark, cardColor, textColor, borderColor),
          const SizedBox(height: 12),

          // ── Negative Prompt (collapsible) ──────────────────
          _negativePromptInput(isDark, cardColor, textColor, borderColor),
          const SizedBox(height: 16),

          // ── Generate Button ────────────────────────────────
          _generateButton(isDark),
          const SizedBox(height: 30),
        ]),
      ),
    );
  }

  // ── Image Preview ─────────────────────────────────────────────
  Widget _imagePreview(bool isDark, Color cardColor, Color borderColor) {
    if (_isGenerating) {
      return AnimatedBuilder(
        animation: _shimmerController,
        builder: (_, __) {
          final shimmer = _shimmerController.value;
          return Container(
            width: double.infinity,
            height: 300,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: isDark
                    ? [const Color(0xFF1A2744), const Color(0xFF0D1B2A), const Color(0xFF1A2744)]
                    : [const Color(0xFFE8F4FD), const Color(0xFFF0F7FF), const Color(0xFFE8F4FD)],
                stops: [0.0, shimmer, 1.0],
              ),
              border: Border.all(color: kCyan.withOpacity(0.3)),
            ),
            child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              SizedBox(
                width: 40, height: 40,
                child: CircularProgressIndicator(
                    color: kCyan, strokeWidth: 3,
                    value: null),
              ),
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
        ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Image.memory(
            _generatedImage!,
            width: double.infinity,
            fit: BoxFit.cover,
          ),
        ),
        const SizedBox(height: 10),
        // Action buttons
        Row(children: [
          Expanded(child: OutlinedButton.icon(
            icon: const Icon(Icons.download_rounded, size: 18),
            label: const Text("Save"),
            style: OutlinedButton.styleFrom(
              foregroundColor: kCyan,
              side: const BorderSide(color: kCyan),
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: _saveImage,
          )),
          const SizedBox(width: 10),
          Expanded(child: OutlinedButton.icon(
            icon: const Icon(Icons.share_rounded, size: 18),
            label: const Text("Share"),
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.green,
              side: const BorderSide(color: Colors.green),
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: _shareImage,
          )),
          const SizedBox(width: 10),
          Expanded(child: ElevatedButton.icon(
            icon: const Icon(Icons.refresh_rounded, size: 18),
            label: const Text("Again"),
            style: ElevatedButton.styleFrom(
              backgroundColor: kCyan,
              foregroundColor: Colors.white,
              elevation: 0,
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: _generateImage,
          )),
        ]),
        if (_currentPrompt.isNotEmpty) ...[
          const SizedBox(height: 8),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: kCyan.withOpacity(0.08),
              borderRadius: BorderRadius.circular(10),
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
      width: double.infinity,
      height: 220,
      decoration: BoxDecoration(
        color: kCyan.withOpacity(0.05),
        borderRadius: BorderRadius.circular(16),
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
        const Text("AI Image Generator", style: TextStyle(
            color: kCyan, fontSize: 16, fontWeight: FontWeight.bold)),
        const SizedBox(height: 6),
        const Text("Type a prompt and generate any image",
            style: TextStyle(color: kTextMuted, fontSize: 12)),
      ]),
    );
  }

  // ── Suggestion Chips ──────────────────────────────────────────
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
            onTap: () => setState(() => _promptController.text = s['prompt']),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: kCyan.withOpacity(0.08),
                borderRadius: BorderRadius.circular(20),
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

  // ── Prompt Input ──────────────────────────────────────────────
  Widget _promptInput(bool isDark, Color cardColor, Color textColor, Color borderColor) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? kDarkCard : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: borderColor),
        boxShadow: [BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.15 : 0.04),
            blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: TextField(
        controller: _promptController,
        style: TextStyle(color: textColor, fontSize: 14),
        maxLines: 3, minLines: 2,
        decoration: InputDecoration(
          hintText: "Describe the image you want to generate...\ne.g. A futuristic city at sunset, cinematic, 4K",
          hintStyle: const TextStyle(color: kTextMuted, fontSize: 13),
          filled: true,
          fillColor: Colors.transparent,
          border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide.none),
          contentPadding: const EdgeInsets.all(14),
          suffixIcon: _promptController.text.isNotEmpty
              ? IconButton(
              icon: const Icon(Icons.clear, color: kTextMuted, size: 18),
              onPressed: () => setState(() => _promptController.clear()))
              : null,
        ),
        onChanged: (_) => setState(() {}),
      ),
    );
  }

  // ── Settings Row ──────────────────────────────────────────────
  Widget _settingsRow(bool isDark, Color cardColor, Color textColor, Color borderColor) {
    return Row(children: [
      // Model selector
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text("Style", style: TextStyle(color: kTextSub, fontSize: 11, fontWeight: FontWeight.w600)),
        const SizedBox(height: 4),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: isDark ? kDarkCard : Colors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: borderColor),
          ),
          child: DropdownButtonHideUnderline(child: DropdownButton<String>(
            value: _selectedModel,
            isExpanded: true,
            style: TextStyle(color: textColor, fontSize: 13),
            dropdownColor: isDark ? kDarkCard : Colors.white,
            icon: const Icon(Icons.keyboard_arrow_down, color: kCyan, size: 18),
            items: _models.map((m) => DropdownMenuItem(
              value: m,
              child: Text(m, style: TextStyle(color: textColor, fontSize: 13)),
            )).toList(),
            onChanged: (v) => setState(() => _selectedModel = v!),
          )),
        ),
      ])),
      const SizedBox(width: 12),
      // Size selector
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text("Size", style: TextStyle(color: kTextSub, fontSize: 11, fontWeight: FontWeight.w600)),
        const SizedBox(height: 4),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: isDark ? kDarkCard : Colors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: borderColor),
          ),
          child: DropdownButtonHideUnderline(child: DropdownButton<String>(
            value: _selectedSize,
            isExpanded: true,
            style: TextStyle(color: textColor, fontSize: 13),
            dropdownColor: isDark ? kDarkCard : Colors.white,
            icon: const Icon(Icons.keyboard_arrow_down, color: kCyan, size: 18),
            items: _sizes.keys.map((s) => DropdownMenuItem(
              value: s,
              child: Text(s, style: TextStyle(color: textColor, fontSize: 13)),
            )).toList(),
            onChanged: (v) => setState(() => _selectedSize = v!),
          )),
        ),
      ])),
    ]);
  }

  // ── Negative Prompt ───────────────────────────────────────────
  Widget _negativePromptInput(bool isDark, Color cardColor, Color textColor, Color borderColor) {
    return ExpansionTile(
      tilePadding: EdgeInsets.zero,
      childrenPadding: EdgeInsets.zero,
      title: Text("⛔ Negative Prompt (optional)",
          style: TextStyle(color: kTextSub, fontSize: 13, fontWeight: FontWeight.w500)),
      iconColor: kCyan, collapsedIconColor: kTextMuted,
      children: [
        const SizedBox(height: 8),
        TextField(
          controller: _negativeController,
          style: TextStyle(color: textColor, fontSize: 13),
          maxLines: 2,
          decoration: InputDecoration(
            hintText: "Things to avoid: blurry, ugly, watermark, bad anatomy...",
            hintStyle: const TextStyle(color: kTextMuted, fontSize: 12),
            filled: true,
            fillColor: isDark ? kDarkCard : Colors.white,
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(color: borderColor)),
            enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(color: borderColor)),
            focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: kCyan)),
            contentPadding: const EdgeInsets.all(12),
          ),
        ),
      ],
    );
  }

  // ── Generate Button ───────────────────────────────────────────
  Widget _generateButton(bool isDark) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: _isGenerating ? null : _generateImage,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          shadowColor: Colors.transparent,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ).copyWith(
          backgroundColor: WidgetStateProperty.resolveWith((states) =>
          states.contains(WidgetState.disabled)
              ? kCyan.withOpacity(0.4) : null),
        ),
        child: Ink(
          decoration: BoxDecoration(
            gradient: _isGenerating ? null : const LinearGradient(
                colors: [kCyanDark, kCyanLight],
                begin: Alignment.centerLeft,
                end: Alignment.centerRight),
            borderRadius: BorderRadius.circular(14),
            color: _isGenerating ? kCyan.withOpacity(0.4) : null,
          ),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 16),
            alignment: Alignment.center,
            child: _isGenerating
                ? const Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              SizedBox(width: 18, height: 18,
                  child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)),
              SizedBox(width: 10),
              Text("Generating...", style: TextStyle(
                  color: Colors.white, fontSize: 15, fontWeight: FontWeight.w600)),
            ])
                : const Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              Icon(Icons.auto_awesome, color: Colors.white, size: 20),
              SizedBox(width: 8),
              Text("Generate Image", style: TextStyle(
                  color: Colors.white, fontSize: 15, fontWeight: FontWeight.w600)),
            ]),
          ),
        ),
      ),
    );
  }
}