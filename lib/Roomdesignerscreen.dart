import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:share_plus/share_plus.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:web_socket_channel/status.dart' as status;
import 'package:gal/gal.dart';
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

const List<Map<String, dynamic>> kRoomStyles = [
  {'label': 'Modern',        'icon': '🏙️'},
  {'label': 'Scandinavian',  'icon': '🌿'},
  {'label': 'Luxury',        'icon': '✨'},
  {'label': 'Industrial',    'icon': '🔩'},
  {'label': 'Bohemian',      'icon': '🎨'},
  {'label': 'Japanese',      'icon': '🍵'},
  {'label': 'Mediterranean', 'icon': '🌊'},
  {'label': 'Classic',       'icon': '🏛️'},
];

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

  XFile?      _selectedImage;
  Uint8List?  _generatedImageBytes;
  int         _selectedStyleIndex = 0;
  String      _selectedRoomType   = 'Living Room';
  String      _additionalNotes    = '';
  bool        _isGenerating       = false;
  String      _statusMessage      = '';
  String      _selectedLanguage   = 'English';

  final _notesController = TextEditingController();
  final _picker          = ImagePicker();
  WebSocketChannel? _channel;

  late AnimationController _pulseController;
  late Animation<double>   _pulseAnim;

  @override
  void initState() {
    super.initState();
    _loadLanguage();
    _pulseController = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1200))
      ..repeat(reverse: true);
    _pulseAnim = Tween<double>(begin: 0.93, end: 1.07)
        .animate(CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut));
  }

  Future<void> _loadLanguage() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() => _selectedLanguage = prefs.getString('selected_language') ?? 'English');
  }

  @override
  void dispose() {
    _channel?.sink.close(status.goingAway);
    _pulseController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _pickImage(ImageSource source) async {
    final img = await _picker.pickImage(source: source, imageQuality: 80, maxWidth: 1024);
    if (img != null && mounted) {
      setState(() {
        _selectedImage       = img;
        _generatedImageBytes = null;
        _statusMessage       = '';
      });
    }
  }

  void _showImagePicker() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
        decoration: BoxDecoration(
          color: isDark ? kDarkCard : kBgWhite,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          border: Border(top: BorderSide(color: isDark ? kDarkBorder : kBorderLight)),
        ),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(width: 40, height: 4, margin: const EdgeInsets.only(bottom: 20),
              decoration: BoxDecoration(color: kCyan.withOpacity(0.3), borderRadius: BorderRadius.circular(2))),
          Text('Select Room Photo', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : kTextPrimary)),
          const SizedBox(height: 20),
          Row(children: [
            Expanded(child: _sourceBtn(Icons.camera_alt_rounded, 'Camera',
                    () { Navigator.pop(context); _pickImage(ImageSource.camera); })),
            const SizedBox(width: 12),
            Expanded(child: _sourceBtn(Icons.photo_library_rounded, 'Gallery',
                    () { Navigator.pop(context); _pickImage(ImageSource.gallery); })),
          ]),
        ]),
      ),
    );
  }

  Widget _sourceBtn(IconData icon, String label, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 18),
        decoration: BoxDecoration(color: kCyan.withOpacity(0.08),
            borderRadius: BorderRadius.circular(16), border: Border.all(color: kCardBorder)),
        child: Column(children: [
          Container(padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: kCyan.withOpacity(0.12), shape: BoxShape.circle),
              child: Icon(icon, color: kCyan, size: 26)),
          const SizedBox(height: 8),
          Text(label, style: const TextStyle(color: kCyan, fontWeight: FontWeight.w600, fontSize: 13)),
        ]),
      ),
    );
  }

  Future<void> _generateDesign() async {
    if (_selectedImage == null) { _showSnack('Please upload a room photo first!'); return; }

    setState(() {
      _isGenerating        = true;
      _generatedImageBytes = null;
      _statusMessage       = '🔍 Analyzing your room...';
    });

    try {
      await _channel?.sink.close(status.goingAway);
      _channel = null;

      final bytes       = await File(_selectedImage!.path).readAsBytes();
      final base64Image = base64Encode(bytes);
      final ext         = _selectedImage!.path.split('.').last.toLowerCase();
      final style       = kRoomStyles[_selectedStyleIndex];

      _channel = WebSocketChannel.connect(
          Uri.parse('wss://silo-churn-worst.ngrok-free.dev/ws/chat/'));

      bool imageReceived = false;
      final msgBuffer   = StringBuffer();

      _channel!.stream.listen(
            (data) {
          if (!mounted) return;

          final rawStr = data is String ? data : String.fromCharCodes(data as List<int>);

          Map<String, dynamic> decoded;
          try {
            decoded = jsonDecode(rawStr);
            msgBuffer.clear();
          } catch (_) {
            msgBuffer.write(rawStr);
            try {
              decoded = jsonDecode(msgBuffer.toString());
              msgBuffer.clear();
            } catch (_) {
              return;
            }
          }

          final type = decoded['type'] as String? ?? '';
          setState(() {
            if (type == 'room_status') _statusMessage = decoded['message'] ?? 'Generating...';
            if (type == 'room_image') {
              final imgB64 = decoded['image'] as String? ?? '';
              if (imgB64.isNotEmpty) {
                _generatedImageBytes = base64Decode(imgB64);
                imageReceived        = true;
              }
            }
            if (type == 'room_error') { _statusMessage = decoded['message'] ?? 'Error'; _isGenerating = false; }
            if (type == 'done')       { _isGenerating  = false; _statusMessage = ''; }
          });
        },
        onError: (e) {
          if (!mounted) return;
          setState(() { _isGenerating = false; _statusMessage = ''; });
          _showSnack('Connection error. Please try again.');
        },
        onDone: () {
          if (!mounted) return;
          if (imageReceived) { setState(() { _isGenerating = false; _statusMessage = ''; }); return; }
          if (_isGenerating) { setState(() { _isGenerating = false; _statusMessage = ''; }); _showSnack('Connection closed. Please try again.'); }
        },
      );

      _channel!.sink.add(jsonEncode({
        'type': 'room_generate', 'image': base64Image, 'image_ext': ext,
        'style': style['label'], 'room_type': _selectedRoomType,
        'notes': _additionalNotes, 'language': _selectedLanguage,
      }));
    } catch (e) {
      if (!mounted) return;
      setState(() { _isGenerating = false; _statusMessage = ''; });
      _showSnack('Failed: $e');
    }
  }

  void _resetAll() {
    setState(() { _selectedImage = null; _generatedImageBytes = null; _statusMessage = ''; _isGenerating = false; });
    _notesController.clear();
    _additionalNotes = '';
  }

  Future<void> _saveImage() async {
    if (_generatedImageBytes == null) return;
    try {
      final dir  = await getTemporaryDirectory();
      final file = File('${dir.path}/omega_room_design.jpg');
      await file.writeAsBytes(_generatedImageBytes!);
      await Share.shareXFiles([XFile(file.path)], text: 'Room redesigned by Omega AI 🏠✨');
    } catch (e) { _showSnack('Failed to save: $e'); }
  }
  Future<void> _downloadImage() async {
    if (_generatedImageBytes == null) return;

    try {

      // Permission
      await Gal.requestAccess();

      // Temp file create
      final dir = await getTemporaryDirectory();

      final file = File(
        '${dir.path}/omega_room_${DateTime.now().millisecondsSinceEpoch}.jpg',
      );

      await file.writeAsBytes(_generatedImageBytes!);

      // Save to gallery
      await Gal.putImage(file.path);

      _showSnack("Image saved to gallery ✅");

    } catch (e) {
      _showSnack("Error: $e");
    }
  }
  void _showSnack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg), behavior: SnackBarBehavior.floating,
      backgroundColor: kCyan,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      duration: const Duration(seconds: 2),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final isDark      = Theme.of(context).brightness == Brightness.dark;
    final bgColor     = isDark ? kDarkBg   : kBgLight;
    final cardColor   = isDark ? kDarkCard : kBgWhite;
    final textColor   = isDark ? Colors.white : kTextPrimary;
    final subColor    = isDark ? kDarkSub  : kTextSub;
    final borderColor = isDark ? kDarkBorder : kBorderLight;

    return Scaffold(
      backgroundColor: bgColor,
      // ── Full screen loading overlay — always visible regardless of scroll ──
      body: Stack(children: [

        SafeArea(child: Column(children: [

          // ── Header ──────────────────────────────────────────────────────
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
            decoration: BoxDecoration(
              color: isDark ? kDarkBg : kBgWhite,
              border: Border(bottom: BorderSide(color: borderColor, width: 0.8)),
            ),
            child: Row(children: [
              IconButton(
                icon: Icon(Icons.arrow_back_ios_new_rounded, color: textColor, size: 20),
                onPressed: () => Navigator.pop(context),
              ),
              const Text('Omega ', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: kCyan)),
              const Text('Room',   style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: kCyan)),
              const SizedBox(width: 6),
              const Text('🏠', style: TextStyle(fontSize: 18)),
              const Spacer(),
              if (_selectedImage != null || _generatedImageBytes != null)
                TextButton.icon(
                  onPressed: _resetAll,
                  icon: const Icon(Icons.refresh_rounded, size: 16, color: kCyan),
                  label: const Text('Reset', style: TextStyle(color: kCyan, fontSize: 13, fontWeight: FontWeight.w600)),
                ),
            ]),
          ),

          // ── Scrollable body ──────────────────────────────────────────────
          Expanded(child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

              // ── Before / After ─────────────────────────────────────────
              if (_selectedImage != null) ...[
                Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Expanded(child: Column(children: [
                    Text('Before', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: subColor)),
                    const SizedBox(height: 6),
                    ClipRRect(borderRadius: BorderRadius.circular(12),
                        child: Image.file(File(_selectedImage!.path),
                            height: 160, width: double.infinity, fit: BoxFit.cover)),
                  ])),
                  Padding(padding: const EdgeInsets.only(top: 28),
                      child: Icon(Icons.arrow_forward_rounded, color: kCyan, size: 26)),
                  Expanded(child: Column(children: [
                    Text('After ✨', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600,
                        color: _generatedImageBytes != null ? kCyan : subColor)),
                    const SizedBox(height: 6),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: _generatedImageBytes != null
                          ? Stack(children: [
                        Image.memory(_generatedImageBytes!, height: 160, width: double.infinity, fit: BoxFit.cover),
                        Positioned(top: 8, right: 8,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                  gradient: const LinearGradient(colors: [kCyanDark, kCyanLight]),
                                  borderRadius: BorderRadius.circular(20)),
                              child: const Text('Done ✓', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                            )),
                      ])
                          : Container(
                        height: 160,
                        decoration: BoxDecoration(
                            color: isDark ? kDarkCard : kCardBg,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: kCardBorder)),
                        child: const Center(child: Icon(Icons.auto_awesome_rounded, color: kCyan, size: 32)),
                      ),
                    ),
                  ])),
                ]),

                if (_generatedImageBytes != null) ...[
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _downloadImage,
                      icon: const Icon(Icons.download_rounded, size: 18),
                      label: const Text('Download Image'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: kCyan,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: const BorderSide(color: kCyan),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                ],

                const SizedBox(height: 10),
                TextButton.icon(
                  onPressed: _showImagePicker,
                  icon: const Icon(Icons.edit_rounded, size: 14, color: kCyan),
                  label: const Text('Change Photo', style: TextStyle(color: kCyan, fontSize: 12, fontWeight: FontWeight.w600)),
                ),
                const SizedBox(height: 8),
              ],

              // ── Upload card ─────────────────────────────────────────────
              if (_selectedImage == null) ...[
                _sectionLabel('Upload Room Photo', textColor),
                const SizedBox(height: 10),
                GestureDetector(
                  onTap: _showImagePicker,
                  child: Container(
                    width: double.infinity, height: 150,
                    decoration: BoxDecoration(
                      color: isDark ? kDarkCard : kCardBg,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: kCardBorder),
                      boxShadow: [BoxShadow(color: Colors.black.withOpacity(isDark ? 0.15 : 0.04), blurRadius: 8, offset: const Offset(0, 2))],
                    ),
                    child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                      ScaleTransition(scale: _pulseAnim,
                        child: Container(width: 58, height: 58,
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(colors: [kCyanDark, kCyanLight], begin: Alignment.topLeft, end: Alignment.bottomRight),
                              shape: BoxShape.circle,
                              boxShadow: [BoxShadow(color: kCyan.withOpacity(0.35), blurRadius: 14, offset: const Offset(0, 4))],
                            ),
                            child: const Icon(Icons.add_photo_alternate_rounded, color: Colors.white, size: 28)),
                      ),
                      const SizedBox(height: 12),
                      const Text('Tap to upload room photo', style: TextStyle(color: kCyan, fontWeight: FontWeight.w600, fontSize: 14)),
                      const SizedBox(height: 4),
                      Text('Camera or Gallery', style: TextStyle(color: subColor, fontSize: 12)),
                    ]),
                  ),
                ),
                const SizedBox(height: 20),
              ],

              // ── Room Type ───────────────────────────────────────────────
              _sectionLabel('Room Type', textColor),
              const SizedBox(height: 10),
              SizedBox(height: 38, child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: kRoomTypes.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (_, i) {
                  final isSel = kRoomTypes[i] == _selectedRoomType;
                  return GestureDetector(
                    onTap: () => setState(() { _selectedRoomType = kRoomTypes[i]; _generatedImageBytes = null; _statusMessage = ''; }),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      decoration: BoxDecoration(
                        gradient: isSel ? const LinearGradient(colors: [kCyanDark, kCyanLight]) : null,
                        color: isSel ? null : (isDark ? kDarkCard : kBgWhite),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: isSel ? Colors.transparent : kCardBorder),
                        boxShadow: isSel ? [BoxShadow(color: kCyan.withOpacity(0.3), blurRadius: 8, offset: const Offset(0, 3))] : [],
                      ),
                      child: Center(child: Text(kRoomTypes[i], style: TextStyle(
                          fontSize: 12, fontWeight: FontWeight.w600, color: isSel ? Colors.white : kCyan))),
                    ),
                  );
                },
              )),

              const SizedBox(height: 20),

              // ── Style Grid ──────────────────────────────────────────────
              _sectionLabel('Design Style', textColor),
              const SizedBox(height: 10),
              GridView.builder(
                shrinkWrap: true, physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 4, crossAxisSpacing: 10, mainAxisSpacing: 10, childAspectRatio: 0.85),
                itemCount: kRoomStyles.length,
                itemBuilder: (_, i) {
                  final style = kRoomStyles[i];
                  final isSel = i == _selectedStyleIndex;
                  return GestureDetector(
                    onTap: () => setState(() { _selectedStyleIndex = i; _generatedImageBytes = null; _statusMessage = ''; }),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      decoration: BoxDecoration(
                        gradient: isSel ? const LinearGradient(colors: [kCyanDark, kCyanLight], begin: Alignment.topLeft, end: Alignment.bottomRight) : null,
                        color: isSel ? null : (isDark ? kDarkCard : kCardBg),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: isSel ? Colors.transparent : kCardBorder, width: isSel ? 0 : 1.2),
                        boxShadow: isSel ? [BoxShadow(color: kCyan.withOpacity(0.35), blurRadius: 10, offset: const Offset(0, 4))] : [],
                      ),
                      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                        Text(style['icon'] as String, style: const TextStyle(fontSize: 24)),
                        const SizedBox(height: 5),
                        Text(style['label'] as String, textAlign: TextAlign.center,
                            style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: isSel ? Colors.white : kCyan)),
                      ]),
                    ),
                  );
                },
              ),

              const SizedBox(height: 18),

              // ── Notes ───────────────────────────────────────────────────
              Container(
                decoration: BoxDecoration(
                  color: isDark ? kDarkCard : kBgWhite, borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: kCardBorder),
                  boxShadow: [BoxShadow(color: Colors.black.withOpacity(isDark ? 0.15 : 0.04), blurRadius: 8, offset: const Offset(0, 2))],
                ),
                child: TextField(
                  controller: _notesController, maxLines: 2,
                  style: TextStyle(color: textColor, fontSize: 14),
                  onChanged: (v) => _additionalNotes = v,
                  decoration: InputDecoration(
                    hintText: 'Notes: budget, colors, storage needs...',
                    hintStyle: TextStyle(color: subColor, fontSize: 13),
                    contentPadding: const EdgeInsets.all(14), border: InputBorder.none,
                    prefixIcon: const Icon(Icons.note_rounded, color: kCyan, size: 20),
                  ),
                ),
              ),

              const SizedBox(height: 20),

              // ── Generate Button ─────────────────────────────────────────
              SizedBox(
                width: double.infinity, height: 52,
                child: ElevatedButton(
                  onPressed: _isGenerating ? null : _generateDesign,
                  style: ElevatedButton.styleFrom(
                    padding: EdgeInsets.zero, elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    disabledBackgroundColor: kCyan.withOpacity(0.5),
                  ),
                  child: Ink(
                    decoration: BoxDecoration(
                      gradient: _isGenerating ? null : const LinearGradient(colors: [kCyanDark, kCyanLight]),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Container(
                      alignment: Alignment.center,
                      child: _isGenerating
                          ? Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                        const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)),
                        const SizedBox(width: 10),
                        const Text('Generating...', style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600)),
                      ])
                          : const Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                        Icon(Icons.auto_awesome_rounded, color: Colors.white, size: 20),
                        SizedBox(width: 10),
                        Text('Redesign My Room', style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w700)),
                      ]),
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 32),
            ]),
          )),
        ])),

        // ── LOADING OVERLAY — always on top, always visible ────────────────
        if (_isGenerating)
          Positioned.fill(
            child: Container(
              color: Colors.black.withOpacity(0.65),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Animated cyan ring
                  Container(
                    width: 90, height: 90,
                    decoration: BoxDecoration(
                      color: kDarkCard,
                      shape: BoxShape.circle,
                      boxShadow: [BoxShadow(color: kCyan.withOpacity(0.4), blurRadius: 24, spreadRadius: 4)],
                    ),
                    child: const Padding(
                      padding: EdgeInsets.all(18),
                      child: CircularProgressIndicator(color: kCyan, strokeWidth: 3),
                    ),
                  ),
                  const SizedBox(height: 28),
                  // Status text
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 40),
                    child: Text(
                      _statusMessage.isNotEmpty ? _statusMessage : 'Generating...',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.white, fontSize: 16,
                        fontWeight: FontWeight.w600, height: 1.5,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Please wait ~30 seconds',
                    style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 13),
                  ),
                ],
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
          borderRadius: BorderRadius.circular(2),
        ),
      ),
      const SizedBox(width: 8),
      Text(text, style: TextStyle(fontWeight: FontWeight.w700, color: color, fontSize: 13, letterSpacing: 0.2)),
    ]);
  }
}