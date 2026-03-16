import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:share_plus/share_plus.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:web_socket_channel/status.dart' as status;

// ── Room styles ──
const List<Map<String, dynamic>> kRoomStyles = [
  {'label': 'Modern',      'icon': '🏙️', 'color': Color(0xFF1A73E8), 'desc': 'Clean lines, minimalist, contemporary'},
  {'label': 'Scandinavian','icon': '🌿', 'color': Color(0xFF2B9348), 'desc': 'Light, natural, cozy & functional'},
  {'label': 'Luxury',      'icon': '✨', 'color': Color(0xFFFFB300), 'desc': 'Rich textures, gold accents, premium'},
  {'label': 'Industrial',  'icon': '🔩', 'color': Color(0xFF607D8B), 'desc': 'Raw materials, exposed brick, metal'},
  {'label': 'Bohemian',    'icon': '🎨', 'color': Color(0xFFE91E63), 'desc': 'Colorful, eclectic, artistic & free'},
  {'label': 'Japanese',    'icon': '🍵', 'color': Color(0xFF795548), 'desc': 'Zen, minimalist, natural materials'},
  {'label': 'Mediterranean','icon': '🌊', 'color': Color(0xFF00BCD4), 'desc': 'Blue & white, terracotta, breezy'},
  {'label': 'Classic',     'icon': '🏛️', 'color': Color(0xFF9C27B0), 'desc': 'Traditional, elegant, timeless'},
];

// ── Room types ──
const List<String> kRoomTypes = [
  'Living Room', 'Bedroom', 'Kitchen', 'Bathroom',
  'Office', 'Dining Room', 'Kids Room', 'Balcony',
];

class RoomDesignerScreen extends StatefulWidget {
  const RoomDesignerScreen({super.key});

  @override
  State<RoomDesignerScreen> createState() => _RoomDesignerScreenState();
}

class _RoomDesignerScreenState extends State<RoomDesignerScreen>
    with TickerProviderStateMixin {

  // State
  XFile? _selectedImage;
  int _selectedStyleIndex = 0;
  String _selectedRoomType = 'Living Room';
  String _additionalNotes = '';
  final TextEditingController _notesController = TextEditingController();
  String _generatedResult = '';
  bool _isGenerating = false;
  bool _showResult = false;
  String _selectedLanguage = 'English';

  // WebSocket
  WebSocketChannel? _channel;

  // Image picker
  final ImagePicker _picker = ImagePicker();

  // Animations
  late AnimationController _slideController;
  late AnimationController _pulseController;
  late Animation<Offset> _slideAnim;
  late Animation<double> _pulseAnim;

  @override
  void initState() {
    super.initState();
    _loadLanguage();
    _slideController = AnimationController(vsync: this, duration: const Duration(milliseconds: 500));
    _pulseController = AnimationController(vsync: this, duration: const Duration(milliseconds: 1000))..repeat(reverse: true);
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
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _pickImage(ImageSource source) async {
    final img = await _picker.pickImage(source: source, imageQuality: 85);
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
          const Text('Select Image', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 20),
          Row(children: [
            Expanded(child: _imageSourceBtn(Icons.camera_alt_rounded, 'Camera', const Color(0xFF4F7EA6), () {
              Navigator.pop(context); _pickImage(ImageSource.camera);
            })),
            const SizedBox(width: 12),
            Expanded(child: _imageSourceBtn(Icons.photo_library_rounded, 'Gallery', const Color(0xFF2B9348), () {
              Navigator.pop(context); _pickImage(ImageSource.gallery);
            })),
          ]),
        ]),
      ),
    );
  }

  Widget _imageSourceBtn(IconData icon, String label, Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 18),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Column(children: [
          Icon(icon, color: color, size: 32),
          const SizedBox(height: 8),
          Text(label, style: TextStyle(color: color, fontWeight: FontWeight.w600)),
        ]),
      ),
    );
  }

  void _generateDesign() async {
    if (_selectedImage == null) {
      _showSnack('Please upload a room photo first!');
      return;
    }

    setState(() {
      _isGenerating = true;
      _generatedResult = '';
      _showResult = false;
    });
    _slideController.reset();

    // Read image as base64
    final bytes = await File(_selectedImage!.path).readAsBytes();
    final base64Image = base64Encode(bytes);
    final ext = _selectedImage!.path.split('.').last.toLowerCase();
    final style = kRoomStyles[_selectedStyleIndex];

    final prompt =
        'You are an expert interior designer. Analyze this room image and provide a detailed redesign plan.\n\n'
        'DESIGN STYLE: ${style['label']} — ${style['desc']}\n'
        'ROOM TYPE: $_selectedRoomType\n'
        '${_additionalNotes.isNotEmpty ? 'ADDITIONAL NOTES: $_additionalNotes\n' : ''}'
        '\nProvide:\n'
        '1. 🎨 COLOR PALETTE — Specific colors with hex codes\n'
        '2. 🪑 FURNITURE RECOMMENDATIONS — Key pieces with descriptions\n'
        '3. 💡 LIGHTING SUGGESTIONS — Types and placement\n'
        '4. 🖼️ WALL & DECOR IDEAS — Art, textures, materials\n'
        '5. 🌿 ACCESSORIES & PLANTS — Final touches\n'
        '6. 💰 ESTIMATED BUDGET RANGE — Low / Mid / High\n'
        '7. ⭐ TOP 3 PRIORITY CHANGES — Most impactful improvements\n\n'
        'Be specific, practical and inspiring. Language: $_selectedLanguage.';

    try {
      _channel?.sink.close(status.goingAway);
      _channel = WebSocketChannel.connect(Uri.parse('ws://192.168.1.4:8000/ws/chat/'));

      _channel!.stream.listen((data) {
        final decoded = jsonDecode(data);
        final type = decoded['type'];
        final text = decoded['message'] ?? '';
        setState(() {
          if (type == 'stream') _generatedResult = text;
          if (type == 'done') {
            _isGenerating = false;
            _showResult = true;
            _slideController.forward();
          }
        });
      }, onError: (_) {
        setState(() => _isGenerating = false);
        _showSnack('Connection error. Check server.');
      });

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
    setState(() {
      _selectedImage = null;
      _generatedResult = '';
      _showResult = false;
      _notesController.clear();
      _additionalNotes = '';
    });
    _slideController.reset();
  }

  void _shareResult() {
    if (_generatedResult.isEmpty) return;
    Share.share(
      '🏠 Room Design Plan — ${kRoomStyles[_selectedStyleIndex]['label']} $_selectedRoomType\n\n$_generatedResult\n\n— Generated by Omega AI',
      subject: 'Room Design by Omega AI',
    );
  }

  void _copyResult() {
    Clipboard.setData(ClipboardData(text: _generatedResult));
    _showSnack('Design plan copied! ✅');
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
    final accent = const Color(0xFF2B9348);

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
                const Text('🏠', style: TextStyle(fontSize: 22)),
                const SizedBox(width: 8),
                Text('Room Designer', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: textColor)),
                const Spacer(),
                if (_selectedImage != null || _showResult)
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

                  // ── Upload image ──
                  Text('Upload Room Photo', style: TextStyle(fontWeight: FontWeight.w600, color: textColor, fontSize: 14)),
                  const SizedBox(height: 10),

                  GestureDetector(
                    onTap: _showImagePicker,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      width: double.infinity,
                      height: _selectedImage != null ? 220 : 160,
                      decoration: BoxDecoration(
                        color: card,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: _selectedImage != null ? accent : accent.withOpacity(0.3),
                          width: _selectedImage != null ? 2 : 1,
                          style: _selectedImage != null ? BorderStyle.solid : BorderStyle.solid,
                        ),
                      ),
                      child: _selectedImage != null
                          ? Stack(children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(18),
                          child: Image.file(File(_selectedImage!.path), width: double.infinity, height: 220, fit: BoxFit.cover),
                        ),
                        Positioned(
                          bottom: 10, right: 10,
                          child: GestureDetector(
                            onTap: _showImagePicker,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(
                                color: Colors.black.withOpacity(0.6),
                                borderRadius: BorderRadius.circular(20),
                              ),
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
                        ScaleTransition(
                          scale: _pulseAnim,
                          child: Container(
                            width: 60, height: 60,
                            decoration: BoxDecoration(color: accent.withOpacity(0.1), shape: BoxShape.circle),
                            child: Icon(Icons.add_photo_alternate_rounded, color: accent, size: 30),
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text('Tap to upload room photo', style: TextStyle(color: accent, fontWeight: FontWeight.w600)),
                        const SizedBox(height: 4),
                        Text('Camera or Gallery', style: TextStyle(color: subColor, fontSize: 12)),
                      ]),
                    ),
                  ),

                  const SizedBox(height: 20),

                  // ── Room type ──
                  Text('Room Type', style: TextStyle(fontWeight: FontWeight.w600, color: textColor, fontSize: 14)),
                  const SizedBox(height: 10),
                  SizedBox(
                    height: 38,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: kRoomTypes.length,
                      separatorBuilder: (_, __) => const SizedBox(width: 8),
                      itemBuilder: (_, i) {
                        final isSelected = kRoomTypes[i] == _selectedRoomType;
                        return GestureDetector(
                          onTap: () => setState(() => _selectedRoomType = kRoomTypes[i]),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 180),
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            decoration: BoxDecoration(
                              color: isSelected ? accent : card,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: isSelected ? accent : accent.withOpacity(0.3)),
                            ),
                            child: Center(
                              child: Text(kRoomTypes[i],
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: isSelected ? Colors.white : accent,
                                  )),
                            ),
                          ),
                        );
                      },
                    ),
                  ),

                  const SizedBox(height: 20),

                  // ── Design style ──
                  Text('Design Style', style: TextStyle(fontWeight: FontWeight.w600, color: textColor, fontSize: 14)),
                  const SizedBox(height: 10),
                  GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 4,
                      crossAxisSpacing: 10,
                      mainAxisSpacing: 10,
                      childAspectRatio: 0.85,
                    ),
                    itemCount: kRoomStyles.length,
                    itemBuilder: (_, i) {
                      final style = kRoomStyles[i];
                      final isSelected = i == _selectedStyleIndex;
                      final color = style['color'] as Color;
                      return GestureDetector(
                        onTap: () => setState(() => _selectedStyleIndex = i),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          decoration: BoxDecoration(
                            color: isSelected ? color : card,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: isSelected ? color : color.withOpacity(0.3), width: isSelected ? 2 : 1),
                            boxShadow: isSelected ? [BoxShadow(color: color.withOpacity(0.3), blurRadius: 8, offset: const Offset(0, 3))] : [],
                          ),
                          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                            Text(style['icon'] as String, style: const TextStyle(fontSize: 24)),
                            const SizedBox(height: 4),
                            Text(style['label'] as String,
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                  color: isSelected ? Colors.white : color,
                                )),
                          ]),
                        ),
                      );
                    },
                  ),

                  const SizedBox(height: 18),

                  // ── Additional notes ──
                  Text('Additional Notes (optional)', style: TextStyle(fontWeight: FontWeight.w600, color: textColor, fontSize: 14)),
                  const SizedBox(height: 8),
                  Container(
                    decoration: BoxDecoration(
                      color: card,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: accent.withOpacity(0.2)),
                    ),
                    child: TextField(
                      controller: _notesController,
                      maxLines: 2,
                      style: TextStyle(color: textColor, fontSize: 13),
                      onChanged: (v) => _additionalNotes = v,
                      decoration: InputDecoration(
                        hintText: 'e.g. Budget under ₹50,000, prefer earthy tones, need more storage...',
                        hintStyle: TextStyle(color: subColor, fontSize: 12),
                        contentPadding: const EdgeInsets.all(14),
                        border: InputBorder.none,
                        prefixIcon: Icon(Icons.note_rounded, color: accent, size: 20),
                      ),
                    ),
                  ),

                  const SizedBox(height: 20),

                  // ── Generate button ──
                  SizedBox(
                    width: double.infinity,
                    height: 54,
                    child: ElevatedButton(
                      onPressed: _isGenerating ? null : _generateDesign,
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
                        const Text('Analyzing & Designing...', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                      ])
                          : Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                        const Text('🏠', style: TextStyle(fontSize: 20)),
                        const SizedBox(width: 10),
                        const Text('Generate Design Plan', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                      ]),
                    ),
                  ),

                  const SizedBox(height: 20),

                  // ── Streaming result ──
                  if (_isGenerating && _generatedResult.isNotEmpty)
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
    final style = kRoomStyles[_selectedStyleIndex];
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
            Text(style['icon'] as String, style: const TextStyle(fontSize: 20)),
            const SizedBox(width: 8),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(
                  isStreaming ? 'Designing your room...' : '${style['label']} Design Plan ✨',
                  style: TextStyle(fontWeight: FontWeight.w700, color: accent, fontSize: 14),
                ),
                Text(_selectedRoomType, style: TextStyle(fontSize: 11, color: accent.withOpacity(0.7))),
              ]),
            ),
            if (!isStreaming) ...[
              IconButton(
                icon: Icon(Icons.copy_rounded, color: accent, size: 20),
                onPressed: _copyResult,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
              ),
              IconButton(
                icon: Icon(Icons.share_rounded, color: accent, size: 20),
                onPressed: _shareResult,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
              ),
            ],
          ]),
        ),

        // Result content
        Padding(
          padding: const EdgeInsets.all(16),
          child: SelectableText(
            _generatedResult,
            style: TextStyle(color: textColor, fontSize: 13.5, height: 1.65),
          ),
        ),

        // Action buttons
        if (!isStreaming)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Row(children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _copyResult,
                  icon: const Icon(Icons.copy_rounded, size: 16),
                  label: const Text('Copy Plan'),
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
                  onPressed: _shareResult,
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