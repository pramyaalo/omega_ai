import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:omega_ai/website_preview_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:share_plus/share_plus.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:web_socket_channel/status.dart' as status;
import 'dart:io';
import 'package:path_provider/path_provider.dart';

const kCyan        = Color(0xFF1BA8D4);
const kCyanDark    = Color(0xFF1890B8);
const kCyanLight   = Color(0xFF26C0F0);
const kBgWhite     = Color(0xFFFFFFFF);
const kBgLight     = Color(0xFFF6FAFE);
const kCardBg      = Color(0xFFF0F7FF);
const kCardBorder  = Color(0xFFD1E9F6);
const kBorderLight = Color(0xFFE8EFF5);
const kTextPrimary = Color(0xFF111827);
const kTextSub     = Color(0xFF6B7280);
const kTextMuted   = Color(0xFF9CA3AF);
const kDarkBg      = Color(0xFF0D1B2A);
const kDarkCard    = Color(0xFF1A2744);
const kDarkBorder  = Color(0xFF1E3354);
const kDarkSub     = Color(0xFF8899AA);

const List<Map<String, dynamic>> kCategories = [
  {
    'label': 'Portfolio',   'emoji': '🎨',
    'types': ['Personal Portfolio','Developer Portfolio','Designer Portfolio','Photographer Portfolio','Creative Portfolio'],
  },
  {
    'label': 'Restaurant',  'emoji': '🍽️',
    'types': ['Restaurant Website','Cafe Website','Food Delivery','Bakery Website','Menu Landing Page'],
  },
  {
    'label': 'Agency',      'emoji': '🏢',
    'types': ['Digital Agency','Marketing Agency','Creative Agency','Startup Agency','Consulting Agency'],
  },
  {
    'label': 'Travel',      'emoji': '✈️',
    'types': ['Travel Agency','Tour Booking','Adventure Travel','Hotel Booking','Vacation Landing Page'],
  },
  {
    'label': 'Medical',     'emoji': '🏥',
    'types': ['Hospital Website','Clinic Website','Doctor Portfolio','Dental Clinic','Medical Landing Page'],
  },
  {
    'label': 'Fitness',     'emoji': '💪',
    'types': ['Gym Website','Fitness Trainer','Yoga Studio','Workout Program','Nutrition Coaching'],
  },
  {
    'label': 'Education',   'emoji': '🎓',
    'types': ['School Website','College Website','Online Course','Coaching Center','E-Learning Platform'],
  },
  {
    'label': 'Real Estate', 'emoji': '🏠',
    'types': ['Property Listing','Real Estate Agency','Apartment Showcase','Villa Landing Page','Construction Company'],
  },
  {
    'label': 'Resume',      'emoji': '📄',
    'types': ['Professional Resume','Modern Resume','Creative Resume','Cover Letter','Portfolio Bio'],
  },
];

// ── Prompt builder ─────────────────────────────────────────────────────────
String _buildPrompt(String category, String type, String idea, String tone, String language) {
  // FIX 1: if idea empty, use type as context
  final topic = idea.isNotEmpty ? idea : type;

  return '''Generate a COMPLETE, BEAUTIFUL single-page HTML page.
Type: "$type"
Topic/Details: "$topic"
Category: $category
Tone: $tone
Language: $language

STRICT RULES:
- Output ONLY raw HTML starting with <!DOCTYPE html>
- NO markdown, NO backticks, NO ```html, NO explanation before or after
- Pure HTML + CSS inside <style> tag only (no external CSS frameworks)
- Google Fonts via @import in <style>
- Beautiful design with gradients, hover effects, shadows
- Mobile responsive with flexbox/grid
- All sections relevant to "$topic"
- Professional and complete — ready to use immediately''';
}

class TemplateGeneratorScreen extends StatefulWidget {
  const TemplateGeneratorScreen({super.key});
  @override
  State<TemplateGeneratorScreen> createState() => _TemplateGeneratorScreenState();
}

class _TemplateGeneratorScreenState extends State<TemplateGeneratorScreen>
    with TickerProviderStateMixin {

  int     _selectedCategoryIndex = 0;
  String? _selectedType;
  final   _ideaController        = TextEditingController();
  final   _toneController        = TextEditingController();
  String  _generatedContent      = '';
  bool    _isGenerating          = false;
  bool    _showPreview           = false;
  String  _selectedLanguage      = 'English';

  WebSocketChannel? _channel;

  late AnimationController _slideController;
  late Animation<Offset>   _slideAnimation;

  @override
  void initState() {
    super.initState();
    _loadLanguage();
    _slideController = AnimationController(vsync: this, duration: const Duration(milliseconds: 400));
    _slideAnimation  = Tween<Offset>(begin: const Offset(0, 1), end: Offset.zero)
        .animate(CurvedAnimation(parent: _slideController, curve: Curves.easeOutCubic));
  }

  Future<void> _loadLanguage() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() => _selectedLanguage = prefs.getString('selected_language') ?? 'English');
  }

  @override
  void dispose() {
    _channel?.sink.close(status.goingAway);
    _slideController.dispose();
    _ideaController.dispose();
    _toneController.dispose();
    super.dispose();
  }

  // ── Generate ─────────────────────────────────────────────────────────────

  void _generateTemplate() {
    final cat  = kCategories[_selectedCategoryIndex]['label'] as String;
    final type = _selectedType ?? (kCategories[_selectedCategoryIndex]['types'] as List<String>)[0];
    final idea = _ideaController.text.trim(); // FIX 1: can be empty
    final tone = _toneController.text.trim().isNotEmpty ? _toneController.text.trim() : 'professional';

    final prompt = _buildPrompt(cat, type, idea, tone, _selectedLanguage);

    setState(() {
      _isGenerating     = true;
      _generatedContent = '';
      _showPreview      = false;
    });

    try { _channel?.sink.close(status.goingAway); } catch (_) {}
    _channel = WebSocketChannel.connect(Uri.parse('wss://silo-churn-worst.ngrok-free.dev/ws/chat/'));

    _channel!.stream.listen((data) {
      final decoded = jsonDecode(data);
      final msgType = decoded['type'];
      final text    = decoded['message'] ?? '';
      setState(() {
        if (msgType == 'stream') _generatedContent = text;
        if (msgType == 'done') {
          _isGenerating = false;
          _showPreview  = true;
          _slideController.forward(from: 0);
        }
      });
    }, onError: (_) {
      setState(() => _isGenerating = false);
      _showSnack('Connection error. Check server.');
    });

    _channel!.sink.add(jsonEncode({'message': prompt, 'language': _selectedLanguage, 'model': 'Smart'}));
  }

  String _cleanHtml() {
    return _generatedContent.replaceAll('```html', '').replaceAll('```', '').trim();
  }

  // ── Copy HTML ─────────────────────────────────────────────────────────────

  void _copyHtml() {
    Clipboard.setData(ClipboardData(text: _cleanHtml()));
    _showSnack('HTML copied! ✅ Paste in any .html file and open in browser');
  }

  // ── Save + Share .html file ────────────────────────────────────────────────
  // FIX 2: Use getTemporaryDirectory() + Share.shareXFiles — no FileProvider needed

  Future<void> _shareHtmlFile() async {
    try {
      final html     = _cleanHtml();
      final dir      = await getTemporaryDirectory(); // always works, no permission needed
      final ts       = DateTime.now().millisecondsSinceEpoch;
      final cat      = kCategories[_selectedCategoryIndex]['label'] as String;
      final name     = cat == 'Resume' ? 'resume' : 'template';
      final filePath = '${dir.path}/omega_${name}_$ts.html';

      final file = File(filePath);
      await file.writeAsString(html, encoding: utf8);

      // ShareXFiles handles FileProvider internally — no exception
      await Share.shareXFiles(
        [XFile(filePath, mimeType: 'text/html')],
        text: 'Open in Chrome/Firefox browser to view ✨',
        subject: 'Omega AI — $name',
      );
    } catch (e) {
      _showSnack('Share failed: $e');
    }
  }

  void _resetAll() {
    setState(() { _generatedContent = ''; _showPreview = false; _selectedType = null; });
    _ideaController.clear();
    _toneController.clear();
    _slideController.reset();
  }

  void _showSnack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg), behavior: SnackBarBehavior.floating,
      backgroundColor: kCyan,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      duration: const Duration(seconds: 3),
    ));
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final isDark      = Theme.of(context).brightness == Brightness.dark;
    final bgColor     = isDark ? kDarkBg   : kBgLight;
    final cardColor   = isDark ? kDarkCard : kBgWhite;
    final textColor   = isDark ? Colors.white : kTextPrimary;
    final subColor    = isDark ? kDarkSub  : kTextSub;
    final borderColor = isDark ? kDarkBorder : kBorderLight;
    final category    = kCategories[_selectedCategoryIndex];
    final catLabel    = category['label'] as String;

    return Scaffold(
      backgroundColor: bgColor,
      body: SafeArea(child: Column(children: [

        // ── Header ────────────────────────────────────────────────────────
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
          decoration: BoxDecoration(
            color: isDark ? kDarkBg : kBgWhite,
            border: Border(bottom: BorderSide(color: borderColor, width: 0.8)),
          ),
          child: Row(children: [
            IconButton(icon: Icon(Icons.arrow_back_ios_new_rounded, color: textColor, size: 20),
                onPressed: () => Navigator.pop(context)),
            const Icon(Icons.auto_awesome_rounded, color: kCyan, size: 20),
            const SizedBox(width: 8),
            const Text('Omega ',   style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: kCyan)),
            const Text('Templates', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: kCyan)),
            const Spacer(),
            if (_showPreview)
              TextButton.icon(onPressed: _resetAll,
                  icon: const Icon(Icons.refresh_rounded, size: 16, color: kCyan),
                  label: const Text('Reset', style: TextStyle(color: kCyan, fontSize: 13, fontWeight: FontWeight.w600))),
          ]),
        ),

        // ── Body ──────────────────────────────────────────────────────────
        Expanded(child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

            // Category
            _sectionLabel('Category', textColor),
            const SizedBox(height: 10),
            SizedBox(height: 80, child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: kCategories.length,
              separatorBuilder: (_, __) => const SizedBox(width: 10),
              itemBuilder: (context, i) {
                final cat   = kCategories[i];
                final isSel = i == _selectedCategoryIndex;
                return GestureDetector(
                  onTap: () => setState(() { _selectedCategoryIndex = i; _selectedType = null; }),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    width: 72,
                    decoration: BoxDecoration(
                      gradient: isSel ? const LinearGradient(colors: [kCyanDark, kCyanLight], begin: Alignment.topLeft, end: Alignment.bottomRight) : null,
                      color: isSel ? null : cardColor,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: isSel ? Colors.transparent : kCardBorder),
                      boxShadow: isSel ? [BoxShadow(color: kCyan.withOpacity(0.35), blurRadius: 8, offset: const Offset(0, 3))] : [],
                    ),
                    child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                      Text(cat['emoji'] as String, style: const TextStyle(fontSize: 22)),
                      const SizedBox(height: 4),
                      Text(cat['label'] as String, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: isSel ? Colors.white : kCyan)),
                    ]),
                  ),
                );
              },
            )),

            const SizedBox(height: 18),

            // Template Type
            _sectionLabel('Template Type', textColor),
            const SizedBox(height: 10),
            Wrap(spacing: 8, runSpacing: 8,
              children: (category['types'] as List<String>).map((type) {
                final isSel = type == (_selectedType ?? (category['types'] as List<String>)[0]);
                return GestureDetector(
                  onTap: () => setState(() => _selectedType = type),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      gradient: isSel ? const LinearGradient(colors: [kCyanDark, kCyanLight]) : null,
                      color: isSel ? null : cardColor,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: isSel ? Colors.transparent : kCardBorder),
                      boxShadow: isSel ? [BoxShadow(color: kCyan.withOpacity(0.3), blurRadius: 6, offset: const Offset(0, 2))] : [],
                    ),
                    child: Text(type, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: isSel ? Colors.white : kCyan)),
                  ),
                );
              }).toList(),
            ),

            const SizedBox(height: 18),

            // Topic (optional)
            _sectionLabel('Your Details (optional)', textColor),
            const SizedBox(height: 6),
            Text(
              'Leave empty to generate based on selected type',
              style: TextStyle(fontSize: 11, color: subColor),
            ),
            const SizedBox(height: 8),
            Container(
              decoration: BoxDecoration(color: cardColor, borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: kCardBorder),
                  boxShadow: [BoxShadow(color: Colors.black.withOpacity(isDark ? 0.15 : 0.04), blurRadius: 8, offset: const Offset(0, 2))]),
              child: TextField(
                controller: _ideaController, maxLines: 3,
                style: TextStyle(color: textColor, fontSize: 14),
                decoration: InputDecoration(
                  hintText: catLabel == 'Resume'
                      ? 'e.g. John Doe, Flutter Dev, 3yrs exp (or leave empty)'
                      : 'e.g. Bloom Garden flower shop Chennai (or leave empty)',
                  hintStyle: TextStyle(color: subColor, fontSize: 13),
                  contentPadding: const EdgeInsets.all(14), border: InputBorder.none,
                ),
              ),
            ),

            const SizedBox(height: 12),

            Container(
              decoration: BoxDecoration(color: cardColor, borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: kCardBorder),
                  boxShadow: [BoxShadow(color: Colors.black.withOpacity(isDark ? 0.15 : 0.04), blurRadius: 8, offset: const Offset(0, 2))]),
              child: TextField(
                controller: _toneController,
                style: TextStyle(color: textColor, fontSize: 14),
                decoration: InputDecoration(
                  hintText: 'Tone: professional, elegant, playful...',
                  hintStyle: TextStyle(color: subColor, fontSize: 13),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  border: InputBorder.none,
                  prefixIcon: const Icon(Icons.tune_rounded, color: kCyan, size: 20),
                ),
              ),
            ),

            const SizedBox(height: 20),

            // Generate Button
            SizedBox(
              width: double.infinity, height: 52,
              child: ElevatedButton(
                onPressed: _isGenerating ? null : _generateTemplate,
                style: ElevatedButton.styleFrom(padding: EdgeInsets.zero, elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    disabledBackgroundColor: kCyan.withOpacity(0.5)),
                child: Ink(
                  decoration: BoxDecoration(
                    gradient: _isGenerating ? null : const LinearGradient(colors: [kCyanDark, kCyanLight]),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Container(alignment: Alignment.center,
                    child: _isGenerating
                        ? const Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                      SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)),
                      SizedBox(width: 12),
                      Text('Generating...', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Colors.white)),
                    ])
                        : const Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                      Icon(Icons.auto_awesome_rounded, color: Colors.white, size: 20),
                      SizedBox(width: 8),
                      Text('Generate Template', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Colors.white)),
                    ]),
                  ),
                ),
              ),
            ),

            const SizedBox(height: 20),

            // Generating indicator
            if (_isGenerating)
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(color: cardColor, borderRadius: BorderRadius.circular(14), border: Border.all(color: kCardBorder)),
                child: Column(children: [
                  const CircularProgressIndicator(color: kCyan),
                  const SizedBox(height: 12),
                  Text(catLabel == 'Resume' ? '📄 Building your resume...' : '🌐 Building your template...',
                      style: const TextStyle(color: kCyan, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 4),
                  Text('Writing HTML, CSS, content...', style: TextStyle(color: subColor, fontSize: 12)),
                ]),
              ),

            // Result
            if (_showPreview && !_isGenerating)
              SlideTransition(
                position: _slideAnimation,
                child: _buildResultCard(cardColor, textColor),
              ),

            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => WebsitePreviewScreen(
                        htmlContent: _cleanHtml(),
                      ),
                    ),
                  );
                },
                icon: const Icon(Icons.web_rounded),
                label: const Text("Open Website Preview"),
                style: ElevatedButton.styleFrom(
                  backgroundColor: kCyan,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
          ]),
        )),
      ])),
    );
  }

  // ── Result Card — HTML code viewer ──────────────────────────────────────────

  Widget _buildResultCard(Color card, Color textColor) {
    final html = _cleanHtml();
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: card, borderRadius: BorderRadius.circular(18),
        border: Border.all(color: kCardBorder),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

        // Header
        Container(
          padding: const EdgeInsets.fromLTRB(16, 12, 12, 12),
          decoration: BoxDecoration(
            color: kCyan.withOpacity(0.08),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
          ),
          child: Row(children: [
            const Icon(Icons.check_circle_rounded, color: kCyan, size: 18),
            const SizedBox(width: 8),
            const Text('Template Ready! ✨', style: TextStyle(fontWeight: FontWeight.w700, color: kCyan, fontSize: 13)),
            const Spacer(),
            // Lines count badge
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(color: kCyan.withOpacity(0.12), borderRadius: BorderRadius.circular(10)),
              child: Text('${html.split('\n').length} lines', style: const TextStyle(color: kCyan, fontSize: 10, fontWeight: FontWeight.w600)),
            ),
          ]),
        ),

        // How to use info box
        Container(
          margin: const EdgeInsets.fromLTRB(14, 14, 14, 0),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: kCyan.withOpacity(0.06), borderRadius: BorderRadius.circular(10),
            border: Border.all(color: kCardBorder),
          ),
          child: const Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('💡', style: TextStyle(fontSize: 14)),
            SizedBox(width: 8),
            Expanded(child: Text(
              'Copy HTML → create file.html → open in Chrome/Firefox\nOR Share File → save to phone → open in browser',
              style: TextStyle(color: kCyan, fontSize: 11, height: 1.6),
            )),
          ]),
        ),

        // Action buttons
        Padding(
          padding: const EdgeInsets.all(14),
          child: Column(children: [

            // Copy HTML (primary)
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _copyHtml,
                icon: const Icon(Icons.copy_rounded, size: 18),
                label: const Text('Copy HTML Code'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: kCyan, foregroundColor: Colors.white, elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),

            const SizedBox(height: 10),

            // Share .html file
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _shareHtmlFile,
                icon: const Icon(Icons.share_rounded, size: 18),
                label: const Text('Share as .html File'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: kCyan, side: const BorderSide(color: kCardBorder),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
          ]),
        ),

        // HTML Code preview (scrollable, selectable)
        Container(
          margin: const EdgeInsets.fromLTRB(14, 0, 14, 14),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0xFF0D1B2A),
            borderRadius: BorderRadius.circular(12),
          ),
          constraints: const BoxConstraints(maxHeight: 300),
          child: SingleChildScrollView(
            child: SelectableText(
              html,
              style: const TextStyle(
                color: Color(0xFF26C0F0), fontSize: 11,
                fontFamily: 'monospace', height: 1.6,
              ),
            ),
          ),
        ),
      ]),
    );
  }

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