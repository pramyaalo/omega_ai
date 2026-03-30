import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:share_plus/share_plus.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:web_socket_channel/status.dart' as status;

class WallMeasurementScreen extends StatefulWidget {
  const WallMeasurementScreen({super.key});

  @override
  State<WallMeasurementScreen> createState() => _WallMeasurementScreenState();
}

class _WallMeasurementScreenState extends State<WallMeasurementScreen>
    with TickerProviderStateMixin {

  XFile? _selectedImage;
  String _selectedUnit = 'Feet';
  String _additionalInfo = '';
  final TextEditingController _infoController = TextEditingController();
  String _generatedResult = '';
  bool _isGenerating = false;
  bool _showResult = false;
  String _selectedLanguage = 'English';

  WebSocketChannel? _channel;
  final ImagePicker _picker = ImagePicker();
  final ScrollController _scrollController = ScrollController();

  late AnimationController _slideController;
  late AnimationController _pulseController;
  late Animation<Offset> _slideAnim;
  late Animation<double> _pulseAnim;

  final List<String> _units = ['Feet', 'Meters', 'Inches', 'Centimeters'];

  final List<Map<String, dynamic>> _wallTypes = [
    {'label': 'Single Wall',   'icon': '🧱', 'desc': 'One flat wall'},
    {'label': 'Room (4 walls)','icon': '🏠', 'desc': 'Full room'},
    {'label': 'L-Shaped',      'icon': '📐', 'desc': 'Corner walls'},
    {'label': 'With Windows',  'icon': '🪟', 'desc': 'Walls with openings'},
  ];
  int _selectedWallType = 0;

  @override
  void initState() {
    super.initState();
    _loadLanguage();
    _slideController = AnimationController(vsync: this, duration: const Duration(milliseconds: 500));
    _pulseController = AnimationController(vsync: this, duration: const Duration(milliseconds: 900))..repeat(reverse: true);
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

  Future<void> _pickImage(ImageSource source) async {
    final img = await _picker.pickImage(source: source, imageQuality: 90);
    if (img != null) {
      setState(() {
        _selectedImage = img;
        _showResult = false;
        _generatedResult = '';
      });
      _slideController.reset();
    }
  }

  void _showImagePicker() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final card = isDark ? const Color(0xFF1E1E1E) : Colors.white;
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
        decoration: BoxDecoration(color: card, borderRadius: const BorderRadius.vertical(top: Radius.circular(24))),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(width: 40, height: 4, margin: const EdgeInsets.only(bottom: 20),
              decoration: BoxDecoration(color: Colors.grey.withOpacity(0.3), borderRadius: BorderRadius.circular(2))),
          const Text('Upload Wall Photo', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          const Text('For best results, take a straight-on photo of the wall', style: TextStyle(color: Colors.grey, fontSize: 12)),
          const SizedBox(height: 20),
          Row(children: [
            Expanded(child: _srcBtn(Icons.camera_alt_rounded, 'Camera', const Color(0xFFFF6D00), () {
              Navigator.pop(context); _pickImage(ImageSource.camera);
            })),
            const SizedBox(width: 12),
            Expanded(child: _srcBtn(Icons.photo_library_rounded, 'Gallery', const Color(0xFF4F7EA6), () {
              Navigator.pop(context); _pickImage(ImageSource.gallery);
            })),
          ]),
        ]),
      ),
    );
  }

  Widget _srcBtn(IconData icon, String label, Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 18),
        decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(16), border: Border.all(color: color.withOpacity(0.3))),
        child: Column(children: [
          Icon(icon, color: color, size: 30),
          const SizedBox(height: 8),
          Text(label, style: TextStyle(color: color, fontWeight: FontWeight.w600)),
        ]),
      ),
    );
  }

  void _analyze() async {
    if (_selectedImage == null) { _showSnack('Please upload a wall photo first!'); return; }

    setState(() { _isGenerating = true; _generatedResult = ''; _showResult = false; });
    _slideController.reset();

    final bytes = await File(_selectedImage!.path).readAsBytes();
    final base64Image = base64Encode(bytes);
    final ext = _selectedImage!.path.split('.').last.toLowerCase();
    final wallType = _wallTypes[_selectedWallType];

    final prompt =
        'You are an expert architectural measurement analyst. Analyze this wall/room photo carefully.\n\n'
        'MEASUREMENT UNIT: $_selectedUnit\n'
        'WALL TYPE: ${wallType['label']} — ${wallType['desc']}\n'
        '${_additionalInfo.isNotEmpty ? 'ADDITIONAL INFO: $_additionalInfo\n' : ''}'
        '\nProvide a detailed measurement analysis:\n\n'
        '📏 ESTIMATED DIMENSIONS\n'
        '- Wall Height: (estimate in $_selectedUnit)\n'
        '- Wall Width: (estimate in $_selectedUnit)\n'
        '- Total Wall Area: (in square $_selectedUnit)\n'
        '- Wall Perimeter: (if room)\n\n'
        '🪟 OPENINGS DETECTED\n'
        '- Windows: (count, estimated size each)\n'
        '- Doors: (count, estimated size each)\n'
        '- Net Wall Area: (total minus openings)\n\n'
        '🎨 MATERIAL ESTIMATES\n'
        '- Paint needed: (liters for 2 coats)\n'
        '- Tiles needed: (if applicable, in sq ft/m)\n'
        '- Wallpaper needed: (rolls estimate)\n\n'
        '⚠️ MEASUREMENT NOTES\n'
        '- Accuracy level: (Low/Medium/High based on photo quality)\n'
        '- Tips to improve accuracy\n'
        '- Any visible issues (cracks, dampness, etc.)\n\n'
        '💡 RECOMMENDATIONS\n'
        '- Surface preparation needed\n'
        '- Suggested next steps\n\n'
        'Note: These are AI-estimated measurements based on visual analysis. '
        'For precise measurements, use physical measuring tools.\n\n'
        'Language: $_selectedLanguage';

    try {
      _channel?.sink.close(status.goingAway);
      _channel = WebSocketChannel.connect(Uri.parse('ws://192.168.1.4:8000/ws/chat/'));
      _channel!.stream.listen((data) {
        final decoded = jsonDecode(data);
        setState(() {
          if (decoded['type'] == 'stream') _generatedResult = decoded['message'] ?? '';
          if (decoded['type'] == 'done') {
            _isGenerating = false;
            _showResult = true;
            _slideController.forward();
            // ✅ Auto scroll to result
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
      }, onError: (_) { setState(() => _isGenerating = false); _showSnack('Connection error.'); });

      _channel!.sink.add(jsonEncode({
        'message': prompt,
        'image': base64Image,
        'image_ext': ext,
        'language': _selectedLanguage,
      }));
    } catch (e) {
      setState(() => _isGenerating = false);
      _showSnack('Error: $e');
    }
  }

  void _resetAll() {
    setState(() { _selectedImage = null; _generatedResult = ''; _showResult = false; _infoController.clear(); _additionalInfo = ''; });
    _slideController.reset();
  }

  void _showSnack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)), duration: const Duration(seconds: 2)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? const Color(0xFF121212) : const Color(0xFFAACBE5);
    final card = isDark ? const Color(0xFF1E1E1E) : Colors.white;
    final textColor = isDark ? Colors.white : Colors.black87;
    final subColor = isDark ? Colors.white54 : Colors.black54;
    const accent = Color(0xFFFF6D00);

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle(statusBarColor: bg, statusBarIconBrightness: isDark ? Brightness.light : Brightness.dark),
      child: Scaffold(
        backgroundColor: bg,
        body: SafeArea(
          child: Column(children: [

            // ── Header ──
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 8, 16, 0),
              child: Row(children: [
                IconButton(icon: Icon(Icons.arrow_back_ios_new_rounded, color: textColor), onPressed: () => Navigator.pop(context)),
                const SizedBox(width: 4),
                const Text('📏', style: TextStyle(fontSize: 22)),
                const SizedBox(width: 8),
                Text('Wall Measurement', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: textColor)),
                const Spacer(),
                if (_selectedImage != null || _showResult)
                  TextButton.icon(onPressed: _resetAll,
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

                  // ── Tips banner ──
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: accent.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: accent.withOpacity(0.3)),
                    ),
                    child: Row(children: [
                      const Icon(Icons.tips_and_updates_rounded, color: accent, size: 18),
                      const SizedBox(width: 8),
                      Expanded(child: Text('Tip: Take a straight-on, well-lit photo for best results',
                          style: TextStyle(color: accent, fontSize: 12, fontWeight: FontWeight.w500))),
                    ]),
                  ),

                  const SizedBox(height: 16),

                  // ── Upload image ──
                  Text('Upload Wall Photo', style: TextStyle(fontWeight: FontWeight.w600, color: textColor, fontSize: 14)),
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
                        border: Border.all(color: _selectedImage != null ? accent : accent.withOpacity(0.3),
                            width: _selectedImage != null ? 2 : 1),
                      ),
                      child: _selectedImage != null
                          ? Stack(children: [
                        ClipRRect(borderRadius: BorderRadius.circular(18),
                            child: Image.file(File(_selectedImage!.path), width: double.infinity, height: 220, fit: BoxFit.cover)),
                        Positioned(bottom: 10, right: 10,
                          child: GestureDetector(onTap: _showImagePicker,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(color: Colors.black.withOpacity(0.6), borderRadius: BorderRadius.circular(20)),
                              child: const Row(mainAxisSize: MainAxisSize.min, children: [
                                Icon(Icons.edit_rounded, color: Colors.white, size: 14),
                                SizedBox(width: 4),
                                Text('Change', style: TextStyle(color: Colors.white, fontSize: 12)),
                              ]),
                            ),
                          ),
                        ),
                      ])
                          : Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                        ScaleTransition(scale: _pulseAnim,
                          child: Container(width: 56, height: 56,
                              decoration: BoxDecoration(color: accent.withOpacity(0.1), shape: BoxShape.circle),
                              child: const Icon(Icons.add_photo_alternate_rounded, color: accent, size: 28)),
                        ),
                        const SizedBox(height: 10),
                        const Text('Tap to upload wall photo', style: TextStyle(color: accent, fontWeight: FontWeight.w600)),
                        Text('Camera or Gallery', style: TextStyle(color: subColor, fontSize: 12)),
                      ]),
                    ),
                  ),

                  const SizedBox(height: 18),

                  // ── Wall type ──
                  Text('Wall Type', style: TextStyle(fontWeight: FontWeight.w600, color: textColor, fontSize: 14)),
                  const SizedBox(height: 10),
                  Row(children: List.generate(_wallTypes.length, (i) {
                    final w = _wallTypes[i];
                    final isSelected = i == _selectedWallType;
                    return Expanded(child: GestureDetector(
                      onTap: () => setState(() => _selectedWallType = i),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 180),
                        margin: EdgeInsets.only(right: i < _wallTypes.length - 1 ? 8 : 0),
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        decoration: BoxDecoration(
                          color: isSelected ? accent : card,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: isSelected ? accent : accent.withOpacity(0.3)),
                        ),
                        child: Column(children: [
                          Text(w['icon'] as String, style: const TextStyle(fontSize: 18)),
                          const SizedBox(height: 3),
                          Text(w['label'] as String,
                              textAlign: TextAlign.center,
                              style: TextStyle(fontSize: 9, fontWeight: FontWeight.w600,
                                  color: isSelected ? Colors.white : accent)),
                        ]),
                      ),
                    ));
                  })),

                  const SizedBox(height: 18),

                  // ── Unit selector ──
                  Text('Measurement Unit', style: TextStyle(fontWeight: FontWeight.w600, color: textColor, fontSize: 14)),
                  const SizedBox(height: 10),
                  Row(children: _units.map((unit) {
                    final isSelected = unit == _selectedUnit;
                    return Expanded(child: GestureDetector(
                      onTap: () => setState(() => _selectedUnit = unit),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 180),
                        margin: EdgeInsets.only(right: unit != _units.last ? 8 : 0),
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        decoration: BoxDecoration(
                          color: isSelected ? accent : card,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: isSelected ? accent : accent.withOpacity(0.3)),
                        ),
                        child: Center(child: Text(unit,
                            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600,
                                color: isSelected ? Colors.white : accent))),
                      ),
                    ));
                  }).toList()),

                  const SizedBox(height: 18),

                  // ── Additional info ──
                  Text('Additional Info (optional)', style: TextStyle(fontWeight: FontWeight.w600, color: textColor, fontSize: 14)),
                  const SizedBox(height: 8),
                  Container(
                    decoration: BoxDecoration(color: card, borderRadius: BorderRadius.circular(16), border: Border.all(color: accent.withOpacity(0.2))),
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
                        prefixIcon: const Icon(Icons.info_outline_rounded, color: accent, size: 20),
                      ),
                    ),
                  ),

                  const SizedBox(height: 20),

                  // ── Analyze button ──
                  SizedBox(
                    width: double.infinity, height: 54,
                    child: ElevatedButton(
                      onPressed: _isGenerating ? null : _analyze,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: accent, foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        elevation: 4, shadowColor: accent.withOpacity(0.4),
                      ),
                      child: _isGenerating
                          ? const Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                        SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)),
                        SizedBox(width: 12),
                        Text('Analyzing Wall...', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                      ])
                          : const Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                        Text('📏', style: TextStyle(fontSize: 20)),
                        SizedBox(width: 10),
                        Text('Analyze & Measure', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                      ]),
                    ),
                  ),

                  const SizedBox(height: 20),

                  // ── Streaming result ──
                  if (_isGenerating && _generatedResult.isNotEmpty)
                    _buildResultCard(card, textColor, isStreaming: true),

                  // ── Final result ──
                  if (_showResult && !_isGenerating)
                    SlideTransition(position: _slideAnim,
                        child: _buildResultCard(card, textColor, isStreaming: false)),

                  const SizedBox(height: 20),
                ]),
              ),
            ),
          ]),
        ),
      ),
    );
  }

  Widget _buildResultCard(Color card, Color textColor, {required bool isStreaming}) {
    const accent = Color(0xFFFF6D00);
    final wallType = _wallTypes[_selectedWallType];
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: card, borderRadius: BorderRadius.circular(20),
        border: Border.all(color: accent.withOpacity(0.3)),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 12, offset: const Offset(0, 4))],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
          padding: const EdgeInsets.fromLTRB(16, 14, 12, 14),
          decoration: BoxDecoration(
            color: accent.withOpacity(0.1),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Row(children: [
            Text(wallType['icon'] as String, style: const TextStyle(fontSize: 20)),
            const SizedBox(width: 8),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(isStreaming ? 'Analyzing...' : 'Measurement Report ✅',
                  style: TextStyle(fontWeight: FontWeight.w700, color: accent, fontSize: 14)),
              Text('${wallType['label']} • $_selectedUnit', style: TextStyle(fontSize: 11, color: accent.withOpacity(0.7))),
            ])),
            if (!isStreaming) ...[
              IconButton(icon: const Icon(Icons.copy_rounded, color: accent, size: 20),
                  onPressed: () { Clipboard.setData(ClipboardData(text: _generatedResult)); _showSnack('Copied! ✅'); },
                  padding: EdgeInsets.zero, constraints: const BoxConstraints(minWidth: 36, minHeight: 36)),
              IconButton(icon: const Icon(Icons.share_rounded, color: accent, size: 20),
                  onPressed: () => Share.share('📏 Wall Measurement Report\n\n$_generatedResult\n\n— Omega AI'),
                  padding: EdgeInsets.zero, constraints: const BoxConstraints(minWidth: 36, minHeight: 36)),
            ],
          ]),
        ),
        Padding(
          padding: const EdgeInsets.all(16),
          child: SelectableText(_generatedResult,
              style: TextStyle(color: textColor, fontSize: 13.5, height: 1.65)),
        ),
        if (!isStreaming)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Row(children: [
              Expanded(child: OutlinedButton.icon(
                onPressed: () { Clipboard.setData(ClipboardData(text: _generatedResult)); _showSnack('Copied! ✅'); },
                icon: const Icon(Icons.copy_rounded, size: 16),
                label: const Text('Copy Report'),
                style: OutlinedButton.styleFrom(foregroundColor: accent, side: BorderSide(color: accent.withOpacity(0.5)),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), padding: const EdgeInsets.symmetric(vertical: 10)),
              )),
              const SizedBox(width: 10),
              Expanded(child: ElevatedButton.icon(
                onPressed: () => Share.share('📏 Wall Measurement\n\n$_generatedResult\n\n— Omega AI'),
                icon: const Icon(Icons.share_rounded, size: 16),
                label: const Text('Share'),
                style: ElevatedButton.styleFrom(backgroundColor: accent, foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), padding: const EdgeInsets.symmetric(vertical: 10)),
              )),
            ]),
          ),
      ]),
    );
  }
}