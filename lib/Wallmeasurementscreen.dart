import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:share_plus/share_plus.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:web_socket_channel/status.dart' as status;
import 'package:path_provider/path_provider.dart';
import 'package:gal/gal.dart';

// ═══════════════════════════════════════════════════════════════
// MATH HELPERS
// ═══════════════════════════════════════════════════════════════

double _mCos(double x) {
  double r = 1, t = 1;
  for (int i = 1; i <= 8; i++) { t *= -x * x / ((2 * i - 1) * (2 * i)); r += t; }
  return r;
}

double _mSin(double x) {
  double r = x, t = x;
  for (int i = 1; i <= 8; i++) { t *= -x * x / ((2 * i) * (2 * i + 1)); r += t; }
  return r;
}

// ═══════════════════════════════════════════════════════════════
// MEASUREMENT PAINTER
// ═══════════════════════════════════════════════════════════════

class MeasurementPainter extends CustomPainter {
  final List<Map<String, dynamic>> measurements;
  MeasurementPainter(this.measurements);

  @override
  void paint(Canvas canvas, Size size) {
    final linePaint = Paint()
      ..color = const Color(0xFF1BA8D4)
      ..strokeWidth = 2.5                // ✅ FIX: was missing =
      ..style = PaintingStyle.stroke;

    final bgPaint = Paint()
      ..color = const Color(0xFF1BA8D4).withOpacity(0.90)
      ..style = PaintingStyle.fill;

    for (final m in measurements) {
      final double x1    = (m['x1'] as double) * size.width;
      final double y1    = (m['y1'] as double) * size.height;
      final double x2    = (m['x2'] as double) * size.width;
      final double y2    = (m['y2'] as double) * size.height;
      final String label = m['label'] as String;

      canvas.drawLine(Offset(x1, y1), Offset(x2, y2), linePaint);
      _drawTick(canvas, linePaint, Offset(x1, y1), Offset(x2, y2));
      _drawTick(canvas, linePaint, Offset(x2, y2), Offset(x1, y1));

      final midX = (x1 + x2) / 2;
      final midY = (y1 + y2) / 2;
      _drawLabel(canvas, label, Offset(midX, midY), bgPaint);
    }
  }

  void _drawTick(Canvas canvas, Paint paint, Offset at, Offset toward) {
    final dir  = (toward - at).direction;
    final perp = dir + 1.5708;
    canvas.drawLine(
      Offset(at.dx + 8 * _mCos(perp), at.dy + 8 * _mSin(perp)),
      Offset(at.dx - 8 * _mCos(perp), at.dy - 8 * _mSin(perp)),
      paint,
    );
  }

  void _drawLabel(Canvas canvas, String text, Offset center, Paint bg) {
    final tp = TextPainter(
      text: TextSpan(
        text: text,
        style: const TextStyle(
          color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    final rect = RRect.fromRectAndRadius(
      Rect.fromCenter(
          center: center,
          width:  tp.width + 16,
          height: tp.height + 8),
      const Radius.circular(6),
    );
    canvas.drawRRect(rect, bg);
    tp.paint(canvas, Offset(center.dx - tp.width / 2, center.dy - tp.height / 2));
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

// ═══════════════════════════════════════════════════════════════
// SCREEN
// ═══════════════════════════════════════════════════════════════

class WallMeasurementScreen extends StatefulWidget {
  const WallMeasurementScreen({super.key});
  @override
  State<WallMeasurementScreen> createState() => _WallMeasurementScreenState();
}

class _WallMeasurementScreenState extends State<WallMeasurementScreen>
    with TickerProviderStateMixin {

  XFile?  _selectedImage;
  String  _selectedUnit    = 'Feet';
  String  _additionalInfo  = '';
  String  _generatedResult = '';
  bool    _isGenerating    = false;
  bool    _showResult      = false;
  String  _selectedLanguage = 'English';
  bool    _isSaving        = false;

  List<Map<String, dynamic>> _measurements = [];
  final GlobalKey            _afterImageKey = GlobalKey();

  final TextEditingController _infoController   = TextEditingController();
  final ImagePicker           _picker           = ImagePicker();
  final ScrollController      _scrollController = ScrollController();
  WebSocketChannel?           _channel;

  late AnimationController _slideController;
  late AnimationController _pulseController;
  late Animation<Offset>   _slideAnim;
  late Animation<double>   _pulseAnim;

  final List<String> _units = ['Feet', 'Meters', 'Inches', 'Centimeters'];

  final List<Map<String, dynamic>> _wallTypes = [
    {'label': 'Single Wall',    'icon': '🧱', 'desc': 'One flat wall'},
    {'label': 'Room (4 walls)', 'icon': '🏠', 'desc': 'Full room'},
    {'label': 'L-Shaped',       'icon': '📐', 'desc': 'Corner walls'},
    {'label': 'With Windows',   'icon': '🪟', 'desc': 'Walls with openings'},
  ];
  int _selectedWallType = 0;

  static const kAccent = Color(0xFF1BA8D4);

  @override
  void initState() {
    super.initState();
    _loadLanguage();
    _slideController = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 500));
    _pulseController = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 900))
      ..repeat(reverse: true);
    _slideAnim = Tween<Offset>(begin: const Offset(0, 0.5), end: Offset.zero)
        .animate(CurvedAnimation(parent: _slideController, curve: Curves.easeOutCubic));
    _pulseAnim = Tween<double>(begin: 0.95, end: 1.05)
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
    _infoController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  // ── Image pick ────────────────────────────────────────────────

  Future<void> _pickImage(ImageSource source) async {
    final img = await _picker.pickImage(source: source, imageQuality: 90);
    if (img != null) {
      setState(() {
        _selectedImage   = img;
        _showResult      = false;
        _generatedResult = '';
        _measurements    = [];
      });
      _slideController.reset();
    }
  }

  void _showImagePicker() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final card   = isDark ? const Color(0xFF1E1E1E) : Colors.white;
    showModalBottomSheet(
      context: context, backgroundColor: Colors.transparent,
      builder: (_) => Container(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
        decoration: BoxDecoration(
            color: card,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24))),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(width: 40, height: 4, margin: const EdgeInsets.only(bottom: 20),
              decoration: BoxDecoration(color: Colors.grey.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(2))),
          const Text('Upload Wall Photo',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          const Text('For best results, take a straight-on photo of the wall',
              style: TextStyle(color: Colors.grey, fontSize: 12)),
          const SizedBox(height: 20),
          Row(children: [
            Expanded(child: _srcBtn(Icons.camera_alt_rounded, 'Camera', kAccent,
                    () { Navigator.pop(context); _pickImage(ImageSource.camera); })),
            const SizedBox(width: 12),
            Expanded(child: _srcBtn(Icons.photo_library_rounded, 'Gallery',
                const Color(0xFF4F7EA6),
                    () { Navigator.pop(context); _pickImage(ImageSource.gallery); })),
          ]),
        ]),
      ),
    );
  }

  Widget _srcBtn(IconData icon, String label, Color color, VoidCallback onTap) =>
      GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 18),
          decoration: BoxDecoration(color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: color.withOpacity(0.3))),
          child: Column(children: [
            Icon(icon, color: color, size: 30),
            const SizedBox(height: 8),
            Text(label, style: TextStyle(color: color, fontWeight: FontWeight.w600)),
          ]),
        ),
      );

  // ═══════════════════════════════════════════════════════════
  // PARSE MEASUREMENTS — top-level helper, no nested function
  // ═══════════════════════════════════════════════════════════

  /// Extract first match from [text] using any of [patterns].
  String _extractValue(String text, List<String> patterns) {
    for (final p in patterns) {
      final m = RegExp(p, caseSensitive: false, dotAll: false).firstMatch(text);
      if (m != null) {
        for (int i = 1; i <= m.groupCount; i++) {
          final g = m.group(i);
          if (g != null && g.trim().isNotEmpty) return g.trim();
        }
      }
    }
    return '';
  }

  List<Map<String, dynamic>> _parseMeasurements(String text) {
    // ── Height ──────────────────────────────────────────────
    final height = _extractValue(text, [
      r'[Ww]all\s+[Hh]eight\s*[:\-–]+\s*(?:approximately\s+)?([0-9]+(?:\.[0-9]+)?(?:\s*[-–]\s*[0-9]+(?:\.[0-9]+)?)?\s*(?:ft|feet|m|meters?|in|inches?|cm|centimeters?)?)',
      r'[Hh]eight\s*[:\-–]+\s*(?:approximately\s+)?([0-9]+(?:\.[0-9]+)?(?:\s*[-–]\s*[0-9]+(?:\.[0-9]+)?)?\s*(?:ft|feet|m|meters?|in|inches?|cm|centimeters?)?)',
      r'[Hh]eight[^\n]*?([0-9]+(?:\.[0-9]+)?)\s*(?:ft|feet|m|in|cm)',
    ]);

    // ── Width ────────────────────────────────────────────────
    final width = _extractValue(text, [
      r'[Ww]all\s+[Ww]idth\s*[:\-–]+\s*(?:approximately\s+)?([0-9]+(?:\.[0-9]+)?(?:\s*[-–]\s*[0-9]+(?:\.[0-9]+)?)?\s*(?:ft|feet|m|meters?|in|inches?|cm|centimeters?)?)',
      r'[Ww]idth\s*[:\-–]+\s*(?:approximately\s+)?([0-9]+(?:\.[0-9]+)?(?:\s*[-–]\s*[0-9]+(?:\.[0-9]+)?)?\s*(?:ft|feet|m|meters?|in|inches?|cm|centimeters?)?)',
      r'[Ww]idth[^\n]*?([0-9]+(?:\.[0-9]+)?)\s*(?:ft|feet|m|in|cm)',
    ]);

    // ── Area ─────────────────────────────────────────────────
    final area = _extractValue(text, [
      r'[Tt]otal\s+[Ww]all\s+[Aa]rea\s*[:\-–]+\s*([0-9]+(?:\.[0-9]+)?\s*(?:sq(?:uare)?\s*)?(?:ft|feet|m|meters?|in|cm)?)',
      r'[Ww]all\s+[Aa]rea\s*[:\-–]+\s*([0-9]+(?:\.[0-9]+)?\s*[^\n]{0,20})',
      r'[Aa]rea\s*[:\-–]+\s*([0-9]+(?:\.[0-9]+)?\s*[^\n]{0,20})',
    ]);

    // ── Net area ─────────────────────────────────────────────
    final net = _extractValue(text, [
      r'[Nn]et\s+[Ww]all\s+[Aa]rea\s*[:\-–]+\s*([0-9]+(?:\.[0-9]+)?\s*[^\n]{0,20})',
    ]);

    final lines = <Map<String, dynamic>>[];

    // Vertical line — Height (left side)
    lines.add({
      'x1': 0.07, 'y1': 0.06,
      'x2': 0.07, 'y2': 0.92,
      'label': height.isNotEmpty ? 'H: $height' : 'Height',
    });

    // Horizontal line — Width (top)
    lines.add({
      'x1': 0.10, 'y1': 0.05,
      'x2': 0.92, 'y2': 0.05,
      'label': width.isNotEmpty ? 'W: $width' : 'Width',
    });

    // Area — bottom center
    if (area.isNotEmpty) {
      lines.add({
        'x1': 0.22, 'y1': 0.93,
        'x2': 0.78, 'y2': 0.93,
        'label': '📐 $area',
      });
    }

    // Net area — just above area line
    if (net.isNotEmpty && net != area) {
      lines.add({
        'x1': 0.22, 'y1': 0.85,
        'x2': 0.78, 'y2': 0.85,
        'label': 'Net: $net',
      });
    }

    return lines;
  }

  // ── Save to gallery ───────────────────────────────────────────

  Future<void> _saveToGallery() async {
    setState(() => _isSaving = true);
    try {
      final boundary = _afterImageKey.currentContext?.findRenderObject()
      as RenderRepaintBoundary?;
      if (boundary == null) { _showSnack('Could not capture image'); return; }

      final image    = await boundary.toImage(pixelRatio: 3.0);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      final bytes    = byteData!.buffer.asUint8List();

      final dir  = await getTemporaryDirectory();
      final file = File(
          '${dir.path}/wall_measurement_${DateTime.now().millisecondsSinceEpoch}.png');
      await file.writeAsBytes(bytes);
      await Gal.putImage(file.path);
      _showSnack('✅ Saved to Gallery!');
    } catch (e) {
      _showSnack('Error saving: $e');
    } finally {
      setState(() => _isSaving = false);
    }
  }

  // ── Share annotated image ─────────────────────────────────────

  Future<void> _shareAnnotatedImage() async {
    try {
      final boundary = _afterImageKey.currentContext?.findRenderObject()
      as RenderRepaintBoundary?;
      if (boundary == null) { _shareTextOnly(); return; }

      final image    = await boundary.toImage(pixelRatio: 2.5);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      final bytes    = byteData!.buffer.asUint8List();

      final dir  = await getTemporaryDirectory();
      final file = File('${dir.path}/wall_measurement.png');
      await file.writeAsBytes(bytes);

      await Share.shareXFiles(
        [XFile(file.path)],
        text: '📏 Wall Measurement Report\n\n$_generatedResult\n\n— Omega AI',
      );
    } catch (e) {
      _shareTextOnly();
    }
  }

  void _shareTextOnly() =>
      Share.share('📏 Wall Measurement Report\n\n$_generatedResult\n\n— Omega AI');

  // ── Analyze ───────────────────────────────────────────────────

  void _analyze() async {
    if (_selectedImage == null) {
      _showSnack('Please upload a wall photo first!');
      return;
    }

    setState(() {
      _isGenerating    = true;
      _generatedResult = '';
      _showResult      = false;
      _measurements    = [];
    });
    _slideController.reset();

    final bytes       = await _selectedImage!.readAsBytes();
    final base64Image = base64Encode(bytes);
    String ext        = _selectedImage!.path.split('.').last.toLowerCase();
    if (ext == 'jpg') ext = 'jpeg';

    final wallType = _wallTypes[_selectedWallType];

    final prompt =
        'You are an expert architectural measurement analyst. Analyze this wall/room photo carefully.\n\n'
        'MEASUREMENT UNIT: $_selectedUnit\n'
        'WALL TYPE: ${wallType['label']} — ${wallType['desc']}\n'
        '${_additionalInfo.isNotEmpty ? 'ADDITIONAL INFO: $_additionalInfo\n' : ''}'
        '\nProvide a detailed measurement analysis. '
        'IMPORTANT: Always write measurements in this EXACT format with the number first:\n\n'
        '📏 ESTIMATED DIMENSIONS\n'
        '- Wall Height: 9 $_selectedUnit\n'
        '- Wall Width: 12 $_selectedUnit\n'
        '- Total Wall Area: 108 square $_selectedUnit\n'
        '- Wall Perimeter: (if room)\n\n'
        '(Replace the example numbers with your actual estimates for THIS photo)\n\n'
        '🪟 OPENINGS DETECTED\n'
        '- Windows: (count, estimated size each)\n'
        '- Doors: (count, estimated size each)\n'
        '- Net Wall Area: (total minus openings)\n\n'
        '🎨 MATERIAL ESTIMATES\n'
        '- Paint needed: (liters for 2 coats)\n'
        '- Tiles needed: (if applicable)\n'
        '- Wallpaper needed: (rolls estimate)\n\n'
        '⚠️ MEASUREMENT NOTES\n'
        '- Accuracy level: (Low/Medium/High)\n'
        '- Tips to improve accuracy\n'
        '- Any visible issues\n\n'
        '💡 RECOMMENDATIONS\n'
        '- Surface preparation needed\n'
        '- Suggested next steps\n\n'
        'Note: AI-estimated measurements. For precise results, use physical tools.\n\n'
        'Language: $_selectedLanguage';

    try {
      _channel?.sink.close(status.goingAway);
      _channel = WebSocketChannel.connect(
          Uri.parse('wss://silo-churn-worst.ngrok-free.dev/ws/chat/'));

      _channel!.stream.listen((data) {
        final decoded = jsonDecode(data);
        setState(() {
          if (decoded['type'] == 'stream') {
            _generatedResult = decoded['message'] ?? '';
          }
          if (decoded['type'] == 'done') {
            _isGenerating = false;
            _showResult   = true;
            _measurements = _parseMeasurements(_generatedResult);
            _slideController.forward();
            Future.delayed(const Duration(milliseconds: 400), () {
              if (_scrollController.hasClients) {
                _scrollController.animateTo(
                  _scrollController.position.maxScrollExtent,
                  duration: const Duration(milliseconds: 600),
                  curve: Curves.easeOut,
                );
              }
            });
          }
        });
      }, onError: (_) {
        setState(() => _isGenerating = false);
        _showSnack('Connection error. Try again.');
      });

      _channel!.sink.add(jsonEncode({
        'message':   prompt,
        'image':     base64Image,
        'image_ext': ext,
        'language':  _selectedLanguage,
      }));
    } catch (e) {
      setState(() => _isGenerating = false);
      _showSnack('Error: $e');
    }
  }

  void _resetAll() {
    setState(() {
      _selectedImage   = null;
      _generatedResult = '';
      _showResult      = false;
      _measurements    = [];
    });
    _infoController.clear();
    _additionalInfo = '';
    _slideController.reset();
  }

  void _showSnack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg), behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      duration: const Duration(seconds: 2),
    ));
  }

  // ── Build ─────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final isDark    = Theme.of(context).brightness == Brightness.dark;
    final bg        = isDark ? const Color(0xFF121212) : const Color(0xFFAACBE5);
    final card      = isDark ? const Color(0xFF1E1E1E) : Colors.white;
    final textColor = isDark ? Colors.white : Colors.black87;
    final subColor  = isDark ? Colors.white54 : Colors.black54;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle(
        statusBarColor: bg,
        statusBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
      ),
      child: Scaffold(
        backgroundColor: bg,
        body: SafeArea(
          child: Column(children: [

            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 8, 16, 0),
              child: Row(children: [
                IconButton(
                  icon: Icon(Icons.arrow_back_ios_new_rounded, color: textColor),
                  onPressed: () => Navigator.pop(context),
                ),
                const SizedBox(width: 4),
                const Text('📏', style: TextStyle(fontSize: 22)),
                const SizedBox(width: 8),
                Text('Wall Measurement',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold,
                        color: textColor)),
                const Spacer(),
                if (_selectedImage != null || _showResult)
                  TextButton.icon(
                    onPressed: _resetAll,
                    icon: const Icon(Icons.refresh_rounded, size: 16),
                    label: const Text('Reset'),
                    style: TextButton.styleFrom(foregroundColor: kAccent),
                  ),
              ]),
            ),

            Expanded(
              child: SingleChildScrollView(
                controller: _scrollController,
                padding: const EdgeInsets.all(16),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

                  // Tip banner
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: kAccent.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: kAccent.withOpacity(0.3)),
                    ),
                    child: Row(children: [
                      const Icon(Icons.tips_and_updates_rounded,
                          color: kAccent, size: 18),
                      const SizedBox(width: 8),
                      Expanded(child: Text(
                        'Tip: Take a straight-on, well-lit photo for best results',
                        style: TextStyle(color: kAccent, fontSize: 12,
                            fontWeight: FontWeight.w500),
                      )),
                    ]),
                  ),

                  const SizedBox(height: 16),

                  // Upload
                  Text('Upload Wall Photo',
                      style: TextStyle(fontWeight: FontWeight.w600,
                          color: textColor, fontSize: 14)),
                  const SizedBox(height: 10),
                  GestureDetector(
                    onTap: _showImagePicker,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      width: double.infinity,
                      height: _selectedImage != null ? 220 : 150,
                      decoration: BoxDecoration(
                        color: card,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: _selectedImage != null
                              ? kAccent : kAccent.withOpacity(0.3),
                          width: _selectedImage != null ? 2 : 1,
                        ),
                      ),
                      child: _selectedImage != null
                          ? Stack(children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(18),
                          child: Image.file(File(_selectedImage!.path),
                              width: double.infinity, height: 220,
                              fit: BoxFit.cover),
                        ),
                        Positioned(bottom: 10, right: 10,
                          child: GestureDetector(
                            onTap: _showImagePicker,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(
                                  color: Colors.black.withOpacity(0.6),
                                  borderRadius: BorderRadius.circular(20)),
                              child: const Row(mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.edit_rounded,
                                        color: Colors.white, size: 14),
                                    SizedBox(width: 4),
                                    Text('Change',
                                        style: TextStyle(color: Colors.white,
                                            fontSize: 12)),
                                  ]),
                            ),
                          ),
                        ),
                      ])
                          : Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            ScaleTransition(
                              scale: _pulseAnim,
                              child: Container(
                                width: 56, height: 56,
                                decoration: BoxDecoration(
                                    color: kAccent.withOpacity(0.1),
                                    shape: BoxShape.circle),
                                child: const Icon(
                                    Icons.add_photo_alternate_rounded,
                                    color: kAccent, size: 28),
                              ),
                            ),
                            const SizedBox(height: 10),
                            const Text('Tap to upload wall photo',
                                style: TextStyle(color: kAccent,
                                    fontWeight: FontWeight.w600)),
                            Text('Camera or Gallery',
                                style: TextStyle(color: subColor, fontSize: 12)),
                          ]),
                    ),
                  ),

                  const SizedBox(height: 18),

                  // Wall type
                  Text('Wall Type', style: TextStyle(fontWeight: FontWeight.w600,
                      color: textColor, fontSize: 14)),
                  const SizedBox(height: 10),
                  Row(children: List.generate(_wallTypes.length, (i) {
                    final w   = _wallTypes[i];
                    final sel = i == _selectedWallType;
                    return Expanded(child: GestureDetector(
                      onTap: () => setState(() => _selectedWallType = i),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 180),
                        margin: EdgeInsets.only(
                            right: i < _wallTypes.length - 1 ? 8 : 0),
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        decoration: BoxDecoration(
                          color: sel ? kAccent : card,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                              color: sel ? kAccent : kAccent.withOpacity(0.3)),
                        ),
                        child: Column(children: [
                          Text(w['icon'] as String,
                              style: const TextStyle(fontSize: 18)),
                          const SizedBox(height: 3),
                          Text(w['label'] as String,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                  fontSize: 9, fontWeight: FontWeight.w600,
                                  color: sel ? Colors.white : kAccent)),
                        ]),
                      ),
                    ));
                  })),

                  const SizedBox(height: 18),

                  // Unit
                  Text('Measurement Unit',
                      style: TextStyle(fontWeight: FontWeight.w600,
                          color: textColor, fontSize: 14)),
                  const SizedBox(height: 10),
                  Row(children: _units.map((unit) {
                    final sel = unit == _selectedUnit;
                    return Expanded(child: GestureDetector(
                      onTap: () => setState(() => _selectedUnit = unit),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 180),
                        margin: EdgeInsets.only(
                            right: unit != _units.last ? 8 : 0),
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        decoration: BoxDecoration(
                          color: sel ? kAccent : card,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                              color: sel ? kAccent : kAccent.withOpacity(0.3)),
                        ),
                        child: Center(child: Text(unit,
                            style: TextStyle(
                                fontSize: 11, fontWeight: FontWeight.w600,
                                color: sel ? Colors.white : kAccent))),
                      ),
                    ));
                  }).toList()),

                  const SizedBox(height: 18),

                  // Additional info
                  Text('Additional Info (optional)',
                      style: TextStyle(fontWeight: FontWeight.w600,
                          color: textColor, fontSize: 14)),
                  const SizedBox(height: 8),
                  Container(
                    decoration: BoxDecoration(
                        color: card, borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: kAccent.withOpacity(0.2))),
                    child: TextField(
                      controller: _infoController,
                      maxLines: 2,
                      style: TextStyle(color: textColor, fontSize: 13),
                      onChanged: (v) => _additionalInfo = v,
                      decoration: InputDecoration(
                        hintText: 'e.g. Room is approx 10x12 ft, has 2 windows...',
                        hintStyle: TextStyle(color: subColor, fontSize: 12),
                        contentPadding: const EdgeInsets.all(14),
                        border: InputBorder.none,
                        prefixIcon: const Icon(Icons.info_outline_rounded,
                            color: kAccent, size: 20),
                      ),
                    ),
                  ),

                  const SizedBox(height: 20),

                  // Analyze button
                  SizedBox(
                    width: double.infinity, height: 54,
                    child: ElevatedButton(
                      onPressed: _isGenerating ? null : _analyze,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: kAccent, foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16)),
                        elevation: 4, shadowColor: kAccent.withOpacity(0.4),
                      ),
                      child: _isGenerating
                          ? const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            SizedBox(width: 20, height: 20,
                                child: CircularProgressIndicator(
                                    color: Colors.white, strokeWidth: 2)),
                            SizedBox(width: 12),
                            Text('Analyzing Wall...',
                                style: TextStyle(fontSize: 15,
                                    fontWeight: FontWeight.w600)),
                          ])
                          : const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text('📏', style: TextStyle(fontSize: 20)),
                            SizedBox(width: 10),
                            Text('Analyze & Measure',
                                style: TextStyle(fontSize: 15,
                                    fontWeight: FontWeight.w600)),
                          ]),
                    ),
                  ),

                  const SizedBox(height: 20),

                  // Streaming
                  if (_isGenerating && _generatedResult.isNotEmpty)
                    _buildStreamingCard(card, textColor),

                  // Full result
                  if (_showResult && !_isGenerating)
                    SlideTransition(
                      position: _slideAnim,
                      child: _buildFullResult(card, textColor),
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

  Widget _buildStreamingCard(Color card, Color textColor) {
    return Container(
      width: double.infinity, margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: card, borderRadius: BorderRadius.circular(16),
        border: Border.all(color: kAccent.withOpacity(0.3)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Row(children: [
          SizedBox(width: 16, height: 16,
              child: CircularProgressIndicator(color: kAccent, strokeWidth: 2)),
          SizedBox(width: 10),
          Text('Analyzing...',
              style: TextStyle(color: kAccent, fontWeight: FontWeight.w600)),
        ]),
        const SizedBox(height: 12),
        Text(_generatedResult,
            style: TextStyle(color: textColor, fontSize: 13, height: 1.6)),
      ]),
    );
  }

  Widget _buildFullResult(Color card, Color textColor) {
    final wallType = _wallTypes[_selectedWallType];
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

      Text('Before & After',
          style: TextStyle(fontWeight: FontWeight.w700,
              color: textColor, fontSize: 15)),
      const SizedBox(height: 10),

      Row(crossAxisAlignment: CrossAxisAlignment.start, children: [

        // BEFORE
        Expanded(child: Column(children: [
          Container(
            padding: const EdgeInsets.symmetric(vertical: 5),
            decoration: BoxDecoration(color: Colors.grey.withOpacity(0.15),
                borderRadius: BorderRadius.circular(8)),
            child: const Center(child: Text('Before',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600,
                    color: Colors.grey))),
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Image.file(File(_selectedImage!.path),
                height: 200, width: double.infinity, fit: BoxFit.cover),
          ),
        ])),

        const SizedBox(width: 10),

        // AFTER — with measurement overlay
        Expanded(child: Column(children: [
          Container(
            padding: const EdgeInsets.symmetric(vertical: 5),
            decoration: BoxDecoration(
                color: kAccent.withOpacity(0.12),
                borderRadius: BorderRadius.circular(8)),
            child: const Center(child: Text('After ✨',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600,
                    color: kAccent))),
          ),
          const SizedBox(height: 6),
          RepaintBoundary(
            key: _afterImageKey,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: SizedBox(
                height: 200, width: double.infinity,
                child: Stack(fit: StackFit.expand, children: [
                  Image.file(File(_selectedImage!.path), fit: BoxFit.cover),
                  Container(color: Colors.black.withOpacity(0.06)),
                  CustomPaint(painter: MeasurementPainter(_measurements)),
                ]),
              ),
            ),
          ),
        ])),
      ]),

      const SizedBox(height: 12),

      // Save / Share
      Row(children: [
        Expanded(child: ElevatedButton.icon(
          onPressed: _isSaving ? null : _saveToGallery,
          icon: _isSaving
              ? const SizedBox(width: 14, height: 14,
              child: CircularProgressIndicator(
                  color: Colors.white, strokeWidth: 2))
              : const Icon(Icons.download_rounded, size: 16),
          label: Text(_isSaving ? 'Saving...' : 'Save to Gallery'),
          style: ElevatedButton.styleFrom(
            backgroundColor: kAccent, foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12)),
            padding: const EdgeInsets.symmetric(vertical: 10),
            elevation: 0,
          ),
        )),
        const SizedBox(width: 10),
        Expanded(child: OutlinedButton.icon(
          onPressed: _shareAnnotatedImage,
          icon: const Icon(Icons.share_rounded, size: 16),
          label: const Text('Share'),
          style: OutlinedButton.styleFrom(
            foregroundColor: kAccent,
            side: BorderSide(color: kAccent.withOpacity(0.5)),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12)),
            padding: const EdgeInsets.symmetric(vertical: 10),
          ),
        )),
      ]),

      const SizedBox(height: 16),

      // Report text card
      Container(
        width: double.infinity,
        decoration: BoxDecoration(
          color: card, borderRadius: BorderRadius.circular(20),
          border: Border.all(color: kAccent.withOpacity(0.3)),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.06),
              blurRadius: 12, offset: const Offset(0, 4))],
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(
            padding: const EdgeInsets.fromLTRB(16, 14, 12, 14),
            decoration: BoxDecoration(
              color: kAccent.withOpacity(0.1),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: Row(children: [
              Text(wallType['icon'] as String,
                  style: const TextStyle(fontSize: 20)),
              const SizedBox(width: 8),
              Expanded(child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('Measurement Report ✅',
                    style: TextStyle(fontWeight: FontWeight.w700,
                        color: kAccent, fontSize: 14)),
                Text('${wallType['label']} • $_selectedUnit',
                    style: TextStyle(fontSize: 11,
                        color: kAccent.withOpacity(0.7))),
              ])),
              IconButton(
                icon: const Icon(Icons.copy_rounded, color: kAccent, size: 20),
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: _generatedResult));
                  _showSnack('Copied! ✅');
                },
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
              ),
            ]),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: SelectableText(_generatedResult,
                style: TextStyle(color: textColor, fontSize: 13.5, height: 1.65)),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Row(children: [
              Expanded(child: OutlinedButton.icon(
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: _generatedResult));
                  _showSnack('Copied! ✅');
                },
                icon: const Icon(Icons.copy_rounded, size: 16),
                label: const Text('Copy Report'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: kAccent,
                  side: BorderSide(color: kAccent.withOpacity(0.5)),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  padding: const EdgeInsets.symmetric(vertical: 10),
                ),
              )),
              const SizedBox(width: 10),
              Expanded(child: ElevatedButton.icon(
                onPressed: _shareTextOnly,
                icon: const Icon(Icons.share_rounded, size: 16),
                label: const Text('Share Report'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: kAccent, foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  elevation: 0,
                ),
              )),
            ]),
          ),
        ]),
      ),
    ]);
  }
}