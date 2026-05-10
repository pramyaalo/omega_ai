import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:file_picker/file_picker.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:open_filex/open_filex.dart';

class DocumentAnalyzerScreen extends StatefulWidget {
  const DocumentAnalyzerScreen({super.key});

  @override
  State<DocumentAnalyzerScreen> createState() => _DocumentAnalyzerScreenState();
}

class _DocumentAnalyzerScreenState extends State<DocumentAnalyzerScreen>
    with SingleTickerProviderStateMixin {

  // ── Colors ──────────────────────────────────────────────────
  static const kCyan        = Color(0xFF1BA8D4);
  static const kCyanDark    = Color(0xFF1890B8);
  static const kCyanLight   = Color(0xFF26C0F0);
  static const kBgWhite     = Color(0xFFFFFFFF);
  static const kCardBg      = Color(0xFFF0F7FF);
  static const kCardBorder  = Color(0xFFD1E9F6);
  static const kBorderLight = Color(0xFFE8EFF5);
  static const kTextPrimary = Color(0xFF111827);
  static const kTextSub     = Color(0xFF6B7280);
  static const kTextMuted   = Color(0xFF9CA3AF);
  static const kDarkBg      = Color(0xFF0D1B2A);
  static const kDarkCard    = Color(0xFF1A2744);
  static const kDarkBorder  = Color(0xFF1E3354);

  // Change this to your server URL
  static const String BASE_URL = 'https://silo-churn-worst.ngrok-free.dev';

  // ── State ────────────────────────────────────────────────────
  PlatformFile? _selectedFile;
  Map<String, dynamic>? _analysisResult;
  bool _isAnalyzing = false;
  bool _isEditing   = false;
  String _editInstruction = "";
  int _activeTab = 0; // 0=Summary, 1=Key Points, 2=Insights, 3=Raw Text

  late AnimationController _animController;
  late Animation<double> _fadeAnim;

  final _editController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(vsync: this, duration: const Duration(milliseconds: 600));
    _fadeAnim = CurvedAnimation(parent: _animController, curve: Curves.easeIn);
  }

  @override
  void dispose() {
    _animController.dispose();
    _editController.dispose();
    super.dispose();
  }

  // ── File Picker ──────────────────────────────────────────────
  Future<void> _pickFile() async {
    final result = await FilePicker.platform.pickFiles(
      withData: true,
      type: FileType.custom,
      allowedExtensions: ['pdf', 'docx', 'doc', 'xlsx', 'xls', 'pptx', 'ppt', 'csv', 'txt'],
    );
    if (result != null && result.files.isNotEmpty) {
      setState(() {
        _selectedFile   = result.files.first;
        _analysisResult = null;
        _activeTab      = 0;
      });
    }
  }

  // ── Analyze Document ─────────────────────────────────────────
  Future<void> _analyzeDocument() async {
    if (_selectedFile == null) return;
    setState(() => _isAnalyzing = true);

    try {
      final bytes   = _selectedFile!.bytes ?? await File(_selectedFile!.path!).readAsBytes();
      final b64     = base64Encode(bytes);

      final response = await http.post(
        Uri.parse('$BASE_URL/api/analyze-document/'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'file':      b64,
          'file_name': _selectedFile!.name,
          'language':  'English',
        }),
      ).timeout(const Duration(seconds: 60));

      if (response.statusCode == 200) {
        final result = jsonDecode(response.body);
        setState(() => _analysisResult = result);
        _animController.forward(from: 0);
      } else {
        _showError("Analysis failed: ${response.statusCode}");
      }
    } catch (e) {
      _showError("Error: $e");
    } finally {
      setState(() => _isAnalyzing = false);
    }
  }

  // ── Edit + Download ──────────────────────────────────────────
  Future<void> _editAndDownload() async {
    if (_selectedFile == null || _editController.text.trim().isEmpty) return;
    setState(() => _isEditing = true);

    try {
      final bytes = _selectedFile!.bytes ?? await File(_selectedFile!.path!).readAsBytes();
      final b64   = base64Encode(bytes);

      final response = await http.post(
        Uri.parse('$BASE_URL/api/edit-document/'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'file':        b64,
          'file_name':   _selectedFile!.name,
          'instruction': _editController.text.trim(),
        }),
      ).timeout(const Duration(seconds: 60));

      if (response.statusCode == 200) {
        final result      = jsonDecode(response.body);
        final editedB64   = result['file'] as String;
        String fileName   = result['file_name'] as String;
        final editedBytes = base64Decode(editedB64);

        // Tamil/translated files → .txt
        final instruction = _editController.text.trim().toLowerCase();
        if (instruction.contains('tamil') || instruction.contains('translate') ||
            instruction.contains('hindi') || instruction.contains('spanish')) {
          fileName = fileName.replaceAll(RegExp(r'\.[^.]+$'), '_translated.txt');
        }

        // ── Save directly to Downloads folder ──────────────
        String savedPath = '';
        try {
          // Android Downloads folder
          final downloadsDir = Directory('/storage/emulated/0/Download');
          if (await downloadsDir.exists()) {
            final file = File('${downloadsDir.path}/$fileName');
            await file.writeAsBytes(editedBytes);
            savedPath = file.path;
          } else {
            // Fallback: app documents directory
            final dir  = await getApplicationDocumentsDirectory();
            final file = File('${dir.path}/$fileName');
            await file.writeAsBytes(editedBytes);
            savedPath = file.path;
          }
        } catch (e) {
          // Final fallback: temp + share
          final dir  = await getTemporaryDirectory();
          final file = File('${dir.path}/$fileName');
          await file.writeAsBytes(editedBytes);
          await Share.shareXFiles([XFile(file.path, name: fileName)]);
          return;
        }

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Row(children: [
              const Icon(Icons.download_done_rounded, color: Colors.white, size: 18),
              const SizedBox(width: 8),
              Expanded(child: Text(
                "Saved to Downloads: $fileName",
                overflow: TextOverflow.ellipsis,
              )),
            ]),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 4),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            action: SnackBarAction(
              label: "Open",
              textColor: Colors.white,
              onPressed: () async {
                await OpenFilex.open(savedPath);
              },
            ),
          ));
        }
      } else {
        _showError("Edit failed: ${response.statusCode}");
      }
    } catch (e) {
      _showError("Download error: $e");
    } finally {
      setState(() => _isEditing = false);
    }
  }

  void _showError(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: Colors.red,
      behavior: SnackBarBehavior.floating,
    ));
  }

  // ── File type icon ───────────────────────────────────────────
  IconData _fileIcon(String name) {
    final ext = name.toLowerCase().split('.').last;
    switch (ext) {
      case 'pdf':  return Icons.picture_as_pdf;
      case 'docx':
      case 'doc':  return Icons.description;
      case 'xlsx':
      case 'xls':  return Icons.table_chart;
      case 'pptx':
      case 'ppt':  return Icons.slideshow;
      case 'csv':  return Icons.grid_on;
      default:     return Icons.insert_drive_file;
    }
  }

  Color _fileColor(String name) {
    final ext = name.toLowerCase().split('.').last;
    switch (ext) {
      case 'pdf':  return Colors.red;
      case 'docx':
      case 'doc':  return const Color(0xFF2B579A);
      case 'xlsx':
      case 'xls':  return const Color(0xFF217346);
      case 'pptx':
      case 'ppt':  return const Color(0xFFD24726);
      case 'csv':  return Colors.green;
      default:     return kCyan;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark      = Theme.of(context).brightness == Brightness.dark;
    final bgColor     = isDark ? kDarkBg   : kBgWhite;
    final cardColor   = isDark ? kDarkCard : kCardBg;
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
            child: const Icon(Icons.description_rounded, color: Colors.white, size: 16),
          ),
          const SizedBox(width: 8),
          Text("Document Analyzer",
              style: TextStyle(color: textColor, fontSize: 17, fontWeight: FontWeight.w700)),
        ]),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Divider(height: 1, color: borderColor),
        ),
      ),

      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

          // ── Upload Card ──────────────────────────────────────
          _uploadCard(isDark, cardColor, textColor, borderColor),
          const SizedBox(height: 16),

          // ── Analyze Button ───────────────────────────────────
          if (_selectedFile != null && _analysisResult == null)
            _analyzeButton(isDark),

          // ── Loading ──────────────────────────────────────────
          if (_isAnalyzing)
            _loadingCard(isDark, cardColor, borderColor),

          // ── Analysis Result ──────────────────────────────────
          if (_analysisResult != null) ...[
            FadeTransition(
              opacity: _fadeAnim,
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

                // Meta chips
                _metaChips(isDark, textColor),
                const SizedBox(height: 16),

                // Tab selector
                _tabSelector(isDark, textColor),
                const SizedBox(height: 14),

                // Tab content
                _tabContent(isDark, cardColor, textColor, borderColor),
                const SizedBox(height: 20),

                // Edit section
                _editSection(isDark, cardColor, textColor, borderColor),
              ]),
            ),
          ],
        ]),
      ),
    );
  }

  // ── Upload Card ───────────────────────────────────────────────
  Widget _uploadCard(bool isDark, Color cardColor, Color textColor, Color borderColor) {
    return GestureDetector(
      onTap: _pickFile,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: _selectedFile != null ? kCyan : borderColor,
            width: _selectedFile != null ? 1.5 : 1,
          ),
        ),
        child: _selectedFile == null
            ? Column(children: [
          Container(
            width: 56, height: 56,
            decoration: BoxDecoration(
              color: kCyan.withOpacity(0.1),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(Icons.upload_file_rounded, color: kCyan, size: 28),
          ),
          const SizedBox(height: 12),
          Text("Tap to upload document",
              style: TextStyle(color: textColor, fontSize: 15, fontWeight: FontWeight.w600)),
          const SizedBox(height: 6),
          const Text("PDF, DOCX, XLSX, PPTX, CSV, TXT",
              style: TextStyle(color: kTextMuted, fontSize: 12)),
        ])
            : Row(children: [
          Container(
            width: 48, height: 48,
            decoration: BoxDecoration(
              color: _fileColor(_selectedFile!.name).withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(_fileIcon(_selectedFile!.name),
                color: _fileColor(_selectedFile!.name), size: 26),
          ),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(_selectedFile!.name, maxLines: 1, overflow: TextOverflow.ellipsis,
                style: TextStyle(color: textColor, fontSize: 14, fontWeight: FontWeight.w600)),
            Text("${(_selectedFile!.size / 1024).toStringAsFixed(1)} KB",
                style: const TextStyle(color: kTextMuted, fontSize: 12)),
          ])),
          IconButton(
            icon: const Icon(Icons.close, color: kTextMuted, size: 18),
            onPressed: () => setState(() { _selectedFile = null; _analysisResult = null; }),
          ),
        ]),
      ),
    );
  }

  // ── Analyze Button ────────────────────────────────────────────
  Widget _analyzeButton(bool isDark) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: SizedBox(
        width: double.infinity,
        child: ElevatedButton.icon(
          icon: const Icon(Icons.auto_awesome, size: 18),
          label: const Text("Analyze Document", style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
          style: ElevatedButton.styleFrom(
            backgroundColor: kCyan,
            foregroundColor: Colors.white,
            elevation: 0,
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          ),
          onPressed: _analyzeDocument,
        ),
      ),
    );
  }

  // ── Loading Card ──────────────────────────────────────────────
  Widget _loadingCard(bool isDark, Color cardColor, Color borderColor) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: kCyan.withOpacity(0.3)),
      ),
      child: Column(children: [
        const CircularProgressIndicator(color: kCyan, strokeWidth: 3),
        const SizedBox(height: 14),
        const Text("🧠 Analyzing document...",
            style: TextStyle(color: kCyan, fontWeight: FontWeight.w600, fontSize: 14)),
        const SizedBox(height: 4),
        Text("Extracting text, insights & key points",
            style: TextStyle(color: isDark ? Colors.white38 : kTextMuted, fontSize: 12)),
      ]),
    );
  }

  // ── Meta Chips ────────────────────────────────────────────────
  Widget _metaChips(bool isDark, Color textColor) {
    final r = _analysisResult!;
    final chips = [
      {'icon': Icons.article,    'label': r['type'] ?? 'Document'},
      {'icon': Icons.language,   'label': r['language'] ?? 'English'},
      {'icon': Icons.mood,       'label': r['sentiment'] ?? 'Neutral'},
      {'icon': Icons.straighten, 'label': r['file_size'] ?? ''},
    ];
    return Wrap(spacing: 8, runSpacing: 8,
      children: chips.where((c) => (c['label'] as String).isNotEmpty).map((c) =>
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: kCyan.withOpacity(0.1),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: kCyan.withOpacity(0.3)),
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(c['icon'] as IconData, color: kCyan, size: 13),
              const SizedBox(width: 5),
              Text(c['label'] as String, style: const TextStyle(color: kCyan, fontSize: 12, fontWeight: FontWeight.w500)),
            ]),
          ),
      ).toList(),
    );
  }

  // ── Tab Selector ──────────────────────────────────────────────
  Widget _tabSelector(bool isDark, Color textColor) {
    final tabs = ["Summary", "Key Points", "Insights", "Raw Text"];
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: tabs.asMap().entries.map((e) {
          final active = e.key == _activeTab;
          return GestureDetector(
            onTap: () => setState(() => _activeTab = e.key),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              margin: const EdgeInsets.only(right: 8),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: active ? kCyan : Colors.transparent,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: active ? kCyan : kBorderLight),
              ),
              child: Text(e.value,
                  style: TextStyle(
                    color: active ? Colors.white : kTextSub,
                    fontWeight: active ? FontWeight.w600 : FontWeight.normal,
                    fontSize: 13,
                  )),
            ),
          );
        }).toList(),
      ),
    );
  }

  // ── Tab Content ───────────────────────────────────────────────
  Widget _tabContent(bool isDark, Color cardColor, Color textColor, Color borderColor) {
    final r = _analysisResult!;

    switch (_activeTab) {
      case 0: // Summary
        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: cardColor,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: borderColor),
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            // Title
            Text(r['title'] ?? 'Document', style: TextStyle(
                color: textColor, fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            // Summary
            Text(r['summary'] ?? 'No summary available.',
                style: TextStyle(color: textColor, fontSize: 14, height: 1.6)),
            if ((r['topics'] as List?)?.isNotEmpty == true) ...[
              const SizedBox(height: 14),
              Text("Topics", style: TextStyle(color: kCyan, fontSize: 13, fontWeight: FontWeight.w600)),
              const SizedBox(height: 6),
              Wrap(spacing: 6, runSpacing: 6,
                children: (r['topics'] as List).map((t) => Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: isDark ? Colors.white.withOpacity(0.07) : kBorderLight,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(t.toString(), style: TextStyle(color: textColor, fontSize: 12)),
                )).toList(),
              ),
            ],
          ]),
        );

      case 1: // Key Points
        final points = (r['key_points'] as List?) ?? [];
        return Column(
          children: points.asMap().entries.map((e) => Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: cardColor,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: borderColor),
            ),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Container(
                width: 24, height: 24,
                decoration: BoxDecoration(color: kCyan, borderRadius: BorderRadius.circular(6)),
                child: Center(child: Text("${e.key + 1}",
                    style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold))),
              ),
              const SizedBox(width: 10),
              Expanded(child: Text(e.value.toString(),
                  style: TextStyle(color: textColor, fontSize: 14, height: 1.5))),
            ]),
          )).toList(),
        );

      case 2: // Insights
        final insights = (r['insights'] as List?) ?? [];
        final actions  = (r['action_items'] as List?) ?? [];
        return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          if (insights.isNotEmpty) ...[
            Text("💡 Insights", style: TextStyle(color: textColor, fontSize: 14, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            ...insights.map((ins) => Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFF6C3DE8).withOpacity(0.08),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFF6C3DE8).withOpacity(0.25)),
              ),
              child: Row(children: [
                const Icon(Icons.lightbulb_outline, color: Color(0xFF6C3DE8), size: 18),
                const SizedBox(width: 10),
                Expanded(child: Text(ins.toString(),
                    style: TextStyle(color: textColor, fontSize: 13, height: 1.5))),
              ]),
            )),
          ],
          if (actions.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text("✅ Action Items", style: TextStyle(color: textColor, fontSize: 14, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            ...actions.map((a) => Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.green.withOpacity(0.08),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.green.withOpacity(0.25)),
              ),
              child: Row(children: [
                const Icon(Icons.task_alt, color: Colors.green, size: 18),
                const SizedBox(width: 10),
                Expanded(child: Text(a.toString(),
                    style: TextStyle(color: textColor, fontSize: 13, height: 1.5))),
              ]),
            )),
          ],
        ]);

      case 3: // Raw Text
        return Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF0A1628) : const Color(0xFFF8F9FA),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: borderColor),
          ),
          child: SelectableText(
            r['extracted_text'] ?? 'No text extracted.',
            style: TextStyle(color: textColor, fontSize: 12, height: 1.6, fontFamily: 'monospace'),
          ),
        );

      default:
        return const SizedBox();
    }
  }

  // ── Edit Section ──────────────────────────────────────────────
  Widget _editSection(bool isDark, Color cardColor, Color textColor, Color borderColor) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(
            width: 30, height: 30,
            decoration: BoxDecoration(
              color: Colors.orange.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.edit_rounded, color: Colors.orange, size: 16),
          ),
          const SizedBox(width: 10),
          Text("Edit & Download", style: TextStyle(
              color: textColor, fontSize: 15, fontWeight: FontWeight.bold)),
        ]),
        const SizedBox(height: 14),

        // Quick edit presets
        Wrap(spacing: 8, runSpacing: 8, children: [
          "Summarize it",
          "Fix grammar",
          "Translate to Tamil",
          "Make it formal",
          "Add bullet points",
        ].map((preset) => GestureDetector(
          onTap: () => setState(() => _editController.text = preset),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: isDark ? Colors.white.withOpacity(0.06) : kBorderLight,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Text(preset, style: TextStyle(color: kTextSub, fontSize: 12)),
          ),
        )).toList()),

        const SizedBox(height: 12),

        // Instruction input
        TextField(
          controller: _editController,
          style: TextStyle(color: textColor, fontSize: 14),
          maxLines: 2,
          decoration: InputDecoration(
            hintText: "Give AI an edit instruction...",
            hintStyle: const TextStyle(color: kTextMuted, fontSize: 13),
            filled: true,
            fillColor: isDark ? Colors.white.withOpacity(0.05) : Colors.white,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: borderColor),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: borderColor),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: kCyan, width: 1.5),
            ),
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          ),
        ),
        const SizedBox(height: 12),

        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            icon: _isEditing
                ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                : const Icon(Icons.download_rounded, size: 18),
            label: Text(_isEditing ? "Processing..." : "Edit & Download File",
                style: const TextStyle(fontWeight: FontWeight.w600)),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange,
              foregroundColor: Colors.white,
              elevation: 0,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: _isEditing ? null : _editAndDownload,
          ),
        ),
      ]),
    );
  }
}