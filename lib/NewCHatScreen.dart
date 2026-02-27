import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:web_socket_channel/status.dart' as status;
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'SettingsScreen.dart';

class NewChatScreen extends StatefulWidget {
  final String? initialMessage;
  const NewChatScreen({super.key, this.initialMessage});

  @override
  State<NewChatScreen> createState() => _NewChatScreenState();
}

class _NewChatScreenState extends State<NewChatScreen> {
  final TextEditingController messageController = TextEditingController();
  WebSocketChannel? channel;
  final ImagePicker _picker = ImagePicker();
  XFile? selectedImage;
  PlatformFile? selectedFile;

  List<Map<String, dynamic>> sessions = [];
  String currentSessionId = "";
  List<Map<String, dynamic>> messages = [];

  @override
  void initState() {
    super.initState();
    _loadSessions().then((_) {
      if (widget.initialMessage != null && widget.initialMessage!.isNotEmpty) {
        messageController.text = widget.initialMessage!;
        Future.delayed(const Duration(milliseconds: 500), () {
          setState(() {});
        });
      }
    });
  }

  String _generateId() => DateTime.now().millisecondsSinceEpoch.toString();

  Future<void> _loadSessions() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString('sessions');
    if (saved != null) {
      final List decoded = jsonDecode(saved);
      setState(() {
        sessions = decoded.cast<Map<String, dynamic>>();
      });
    }
    _startNewSession();
  }

  Future<void> _saveSessions() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('sessions', jsonEncode(sessions));
  }

  void _startNewSession() {
    final id = _generateId();
    setState(() {
      currentSessionId = id;
      messages = [];
    });
    try { channel?.sink.close(status.goingAway); } catch (_) {}
    _connectWebSocket();
  }

  void _loadSession(Map<String, dynamic> session) {
    setState(() {
      currentSessionId = session['id'];
      messages = List<Map<String, dynamic>>.from(
        (session['messages'] as List).map((m) => Map<String, dynamic>.from(m)),
      );
    });
    Navigator.pop(context);
    try { channel?.sink.close(status.goingAway); } catch (_) {}
    _connectWebSocket();
  }

  void _deleteSession(String id) {
    setState(() => sessions.removeWhere((s) => s['id'] == id));
    _saveSessions();
    if (currentSessionId == id) _startNewSession();
  }

  void _saveCurrentSession() {
    if (messages.isEmpty) return;
    final firstMsg = messages.firstWhere(
          (m) => m['isMe'] == true,
      orElse: () => {"text": "New Chat"},
    );
    final title = (firstMsg['text'] as String).length > 30
        ? (firstMsg['text'] as String).substring(0, 30) + "..."
        : firstMsg['text'] as String;
    final toSave = messages.map((m) => {
      "text": m["text"] ?? "",
      "isMe": m["isMe"],
    }).toList();
    final existingIndex = sessions.indexWhere((s) => s['id'] == currentSessionId);
    if (existingIndex >= 0) {
      sessions[existingIndex] = {'id': currentSessionId, 'title': title, 'messages': toSave};
    } else {
      sessions.insert(0, {'id': currentSessionId, 'title': title, 'messages': toSave});
    }
    _saveSessions();
  }

  void _connectWebSocket() {
    try { channel?.sink.close(status.goingAway); } catch (_) {}
    channel = WebSocketChannel.connect(Uri.parse('ws://192.168.1.4:8000/ws/chat/'));
    channel!.stream.listen(
          (data) {
        final decoded = jsonDecode(data);
        final type = decoded["type"];
        final text = decoded["message"] ?? "";
        setState(() {
          if (type == "typing") {
            messages.add({"text": "", "isMe": false, "typing": true});
          }
          if (type == "stream") {
            for (int i = messages.length - 1; i >= 0; i--) {
              if (messages[i]["isMe"] == false) {
                messages[i]["text"] = text;
                messages[i].remove("typing");
                break;
              }
            }
          }
          if (type == "done") {
            for (int i = messages.length - 1; i >= 0; i--) {
              if (messages[i]["isMe"] == false) {
                messages[i].remove("typing");
                break;
              }
            }
            _saveCurrentSession();
          }
        });
      },
      onError: (error) {
        Future.delayed(const Duration(seconds: 2), _connectWebSocket);
      },
      onDone: () {},
    );
  }

  void _sendMessage() {
    final text = messageController.text.trim();
    if (text.isEmpty && selectedImage == null && selectedFile == null) return;
    if (channel == null) { _connectWebSocket(); return; }
    if (selectedImage != null) {
      _sendImage(text);
    } else if (selectedFile != null) {
      _sendFile(text);
    } else {
      setState(() => messages.add({"text": text, "isMe": true}));
      channel!.sink.add(jsonEncode({"message": text}));
      messageController.clear();
    }
  }

  Future<void> _sendImage(String caption) async {
    final bytes = await File(selectedImage!.path).readAsBytes();
    final base64Image = base64Encode(bytes);
    final ext = selectedImage!.path.split('.').last.toLowerCase();
    setState(() {
      messages.add({
        "text": caption.isNotEmpty ? caption : "📷 Image",
        "isMe": true,
        "imageBase64": base64Image,
        "imageExt": ext,
      });
      selectedImage = null;
    });
    channel!.sink.add(jsonEncode({
      "message": caption.isNotEmpty ? caption : "What is in this image?",
      "image": base64Image,
      "image_ext": ext,
    }));
    messageController.clear();
  }

  Future<void> _sendFile(String caption) async {
    final bytes = selectedFile!.bytes ?? await File(selectedFile!.path!).readAsBytes();
    final base64File = base64Encode(bytes);
    final name = selectedFile!.name;
    setState(() {
      messages.add({"text": "📎 $name", "isMe": true});
      selectedFile = null;
    });
    channel!.sink.add(jsonEncode({
      "message": caption.isNotEmpty ? caption : "Analyze this file: $name",
      "file": base64File,
      "file_name": name,
    }));
    messageController.clear();
  }

  Future<void> _pickImage(ImageSource source) async {
    final image = await _picker.pickImage(source: source);
    if (image != null) setState(() { selectedImage = image; selectedFile = null; });
  }

  Future<void> _pickFile() async {
    final result = await FilePicker.platform.pickFiles(withData: true);
    if (result != null && result.files.isNotEmpty) {
      setState(() { selectedFile = result.files.first; selectedImage = null; });
    }
  }

  void _showAttachmentSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) {
        return Container(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
          decoration: const BoxDecoration(
            color: Color(0xFF4F7EA6),
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40, height: 4,
                margin: const EdgeInsets.only(bottom: 20),
                decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2)),
              ),
              const Align(
                alignment: Alignment.centerLeft,
                child: Text("Attach", style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  _attachOption(Icons.camera_alt_rounded, "Camera", const Color(0xFF0F3460), () { Navigator.pop(context); _pickImage(ImageSource.camera); }),
                  const SizedBox(width: 12),
                  _attachOption(Icons.photo_library_rounded, "Gallery", const Color(0xFF16213E), () { Navigator.pop(context); _pickImage(ImageSource.gallery); }),
                  const SizedBox(width: 12),
                  _attachOption(Icons.insert_drive_file_rounded, "Files", const Color(0xFF0F3460), () { Navigator.pop(context); _pickFile(); }),
                ],
              ),
              const SizedBox(height: 24),
              const Align(
                alignment: Alignment.centerLeft,
                child: Text("Quick Actions", style: TextStyle(color: Colors.white70, fontSize: 14, fontWeight: FontWeight.w600)),
              ),
              const SizedBox(height: 12),
              GridView.count(
                crossAxisCount: 3,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisSpacing: 10,
                mainAxisSpacing: 10,
                childAspectRatio: 1.1,
                children: [
                  _quickAction(Icons.image_search_rounded, "Create Image", const Color(0xFFE94560), () { Navigator.pop(context); messageController.text = "Create an image of "; }),
                  _quickAction(Icons.psychology_rounded, "Deep Think", const Color(0xFF533483), () { Navigator.pop(context); messageController.text = "Think deeply and explain: "; }),
                  _quickAction(Icons.travel_explore_rounded, "Web Search", const Color(0xFF0F3460), () { Navigator.pop(context); messageController.text = "Search and tell me about: "; }),
                  _quickAction(Icons.shopping_bag_rounded, "Shopping", const Color(0xFF2B9348), () { Navigator.pop(context); messageController.text = "Best options to buy: "; }),
                  _quickAction(Icons.science_rounded, "Research", const Color(0xFFB5451B), () { Navigator.pop(context); messageController.text = "Research and summarize: "; }),
                  _quickAction(Icons.school_rounded, "Study", const Color(0xFF1B4332), () { Navigator.pop(context); messageController.text = "Teach me about: "; }),
                  _quickAction(Icons.explore_rounded, "Explore", const Color(0xFF2D6A4F), () { Navigator.pop(context); messageController.text = "Explore the topic: "; }),
                  _quickAction(Icons.calculate_rounded, "Math", const Color(0xFF6A0572), () { Navigator.pop(context); messageController.text = "Solve this: "; }),
                  _quickAction(Icons.code_rounded, "Code", const Color(0xFF1A1A4E), () { Navigator.pop(context); messageController.text = "Write code for: "; }),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _attachOption(IconData icon, String label, Color color, VoidCallback onTap) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.white10)),
          child: Column(
            children: [
              Icon(icon, color: Colors.white, size: 28),
              const SizedBox(height: 6),
              Text(label, style: const TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w500)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _quickAction(IconData icon, String label, Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(14), border: Border.all(color: Colors.white10)),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: Colors.white, size: 24),
            const SizedBox(height: 6),
            Text(label, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white70, fontSize: 10, fontWeight: FontWeight.w500)),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    channel?.sink.close(status.goingAway);
    messageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? const Color(0xFF121212) : const Color(0xFFAACBE5);
    final cardColor = isDark ? const Color(0xFF1E1E1E) : Colors.white;
    final textColor = isDark ? Colors.white : Colors.black;
    final drawerBg = isDark ? const Color(0xFF1A1A1A) : const Color(0xFFEAF3FB);
    final subTextColor = isDark ? Colors.white38 : Colors.black54;

    return Scaffold(
      backgroundColor: bgColor,

      // ── DRAWER ───────────────────────────────
      drawer: Drawer(
        backgroundColor: drawerBg,
        child: SafeArea(
          child: Column(
            children: [

              // Header
              Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(16, 20, 16, 16),
                color: const Color(0xFF4F7EA6),
                child: const Text("Ω OMEGA AI",
                    style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold, letterSpacing: 1)),
              ),

              // New Chat
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text("New Chat"),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF4F7EA6),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: () { Navigator.pop(context); _startNewSession(); },
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // History title
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text("Recent Chats",
                      style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: subTextColor, letterSpacing: 0.5)),
                ),
              ),

              const SizedBox(height: 8),

              // Chat list
              Expanded(
                child: sessions.isEmpty
                    ? Center(child: Text("No chats yet", style: TextStyle(color: subTextColor)))
                    : ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  itemCount: sessions.length,
                  itemBuilder: (context, index) {
                    final session = sessions[index];
                    final isActive = session['id'] == currentSessionId;
                    return Container(
                      margin: const EdgeInsets.only(bottom: 4),
                      decoration: BoxDecoration(
                        color: isActive ? const Color(0xFF4F7EA6).withOpacity(0.15) : Colors.transparent,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: ListTile(
                        leading: const Icon(Icons.chat_bubble_outline, color: Color(0xFF4F7EA6), size: 20),
                        title: Text(
                          session['title'] ?? 'Chat ${index + 1}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 14,
                            color: textColor,
                            fontWeight: isActive ? FontWeight.w600 : FontWeight.normal,
                          ),
                        ),
                        trailing: IconButton(
                          icon: const Icon(Icons.delete_outline, color: Colors.red, size: 18),
                          onPressed: () => _deleteSession(session['id']),
                        ),
                        onTap: () => _loadSession(session),
                      ),
                    );
                  },
                ),
              ),

              const Divider(height: 1),

              // Settings
              ListTile(
                leading: Icon(Icons.settings_outlined, color: subTextColor),
                title: Text("Settings", style: TextStyle(fontWeight: FontWeight.w500, color: textColor)),
                trailing: Icon(Icons.chevron_right, color: subTextColor),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(context, MaterialPageRoute(builder: (_) => const SettingsScreen()));
                },
              ),

              // Profile card
              Builder(
                builder: (context) {
                  final user = FirebaseAuth.instance.currentUser;
                  final displayName = user?.displayName ?? user?.email?.split('@')[0] ?? "User";
                  final email = user?.email ?? "guest@omega.ai";
                  final firstLetter = displayName.isNotEmpty ? displayName[0].toUpperCase() : "U";
                  return Container(
                    margin: const EdgeInsets.fromLTRB(8, 0, 8, 8),
                    decoration: BoxDecoration(
                      color: cardColor,
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 6, offset: const Offset(0, 2))],
                    ),
                    child: ListTile(
                      leading: CircleAvatar(
                        radius: 20,
                        backgroundColor: const Color(0xFF4F7EA6),
                        child: Text(firstLetter, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                      ),
                      title: Text(displayName,
                          style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: textColor),
                          overflow: TextOverflow.ellipsis),
                      subtitle: Text(email,
                          style: const TextStyle(fontSize: 11, color: Colors.grey),
                          overflow: TextOverflow.ellipsis),
                      trailing: const Icon(Icons.settings, color: Color(0xFF4F7EA6), size: 20),
                      onTap: () {
                        Navigator.pop(context);
                        Navigator.push(context, MaterialPageRoute(builder: (_) => const SettingsScreen()));
                      },
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),

      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: Column(
            children: [

              // ── HEADER ───────────────────────────
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Builder(
                    builder: (context) => IconButton(
                      icon: Icon(Icons.menu, color: textColor),
                      onPressed: () => Scaffold.of(context).openDrawer(),
                    ),
                  ),
                  Row(
                    children: [
                      Text("Ω", style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: textColor)),
                      const SizedBox(width: 6),
                      Text("OMEGA AI", style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600, color: textColor)),
                    ],
                  ),
                  IconButton(
                    icon: const Icon(Icons.add, color: Color(0xFF4F7EA6)),
                    onPressed: _startNewSession,
                    tooltip: "New Chat",
                  ),
                ],
              ),

              const SizedBox(height: 10),

              // ── CHAT LIST ────────────────────────
              Expanded(
                child: messages.isEmpty
                    ? Center(
                    child: Text("Start a new conversation!",
                        style: TextStyle(color: subTextColor, fontSize: 16)))
                    : ListView.builder(
                  itemCount: messages.length,
                  itemBuilder: (context, index) {
                    final msg = messages[index];
                    final isMe = msg["isMe"] as bool;
                    final isTyping = msg["typing"] == true;
                    final imageBase64 = msg["imageBase64"];

                    return Align(
                      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
                      child: Container(
                        margin: const EdgeInsets.symmetric(vertical: 4),
                        padding: const EdgeInsets.all(10),
                        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.7),
                        decoration: BoxDecoration(
                          color: isMe ? const Color(0xFF4F7EA6) : cardColor,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: isTyping
                            ? Text("🤖 Typing...",
                            style: TextStyle(fontStyle: FontStyle.italic, color: subTextColor))
                            : Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (imageBase64 != null)
                              ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: Image.memory(base64Decode(imageBase64), width: 200, fit: BoxFit.cover),
                              ),
                            if (imageBase64 != null) const SizedBox(height: 6),
                            Text(
                              msg["text"] ?? "",
                              style: TextStyle(
                                color: isMe ? Colors.white : textColor,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),

              // ── IMAGE PREVIEW ────────────────────
              if (selectedImage != null)
                Container(
                  margin: const EdgeInsets.only(bottom: 6),
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(color: cardColor, borderRadius: BorderRadius.circular(12)),
                  child: Row(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.file(File(selectedImage!.path), width: 60, height: 60, fit: BoxFit.cover),
                      ),
                      const SizedBox(width: 10),
                      Text("Image selected", style: TextStyle(color: textColor)),
                      const Spacer(),
                      IconButton(icon: const Icon(Icons.close, color: Colors.red), onPressed: () => setState(() => selectedImage = null)),
                    ],
                  ),
                ),

              // ── FILE PREVIEW ─────────────────────
              if (selectedFile != null)
                Container(
                  margin: const EdgeInsets.only(bottom: 6),
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(color: cardColor, borderRadius: BorderRadius.circular(12)),
                  child: Row(
                    children: [
                      const Icon(Icons.insert_drive_file, color: Color(0xFF4F7EA6), size: 40),
                      const SizedBox(width: 10),
                      Expanded(child: Text(selectedFile!.name, overflow: TextOverflow.ellipsis, style: TextStyle(color: textColor))),
                      IconButton(icon: const Icon(Icons.close, color: Colors.red), onPressed: () => setState(() => selectedFile = null)),
                    ],
                  ),
                ),

              // ── INPUT BAR ────────────────────────
              Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  color: cardColor,
                  borderRadius: BorderRadius.circular(30),
                ),
                child: Row(
                  children: [
                    IconButton(
                      icon: Icon(Icons.add, color: textColor),
                      onPressed: _showAttachmentSheet,
                    ),
                    Expanded(
                      child: TextField(
                        controller: messageController,
                        style: TextStyle(color: textColor),
                        decoration: InputDecoration(
                          hintText: "Ask anything...",
                          hintStyle: TextStyle(color: subTextColor),
                          border: InputBorder.none,
                        ),
                        onSubmitted: (_) => _sendMessage(),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.send, color: Color(0xFF4F7EA6)),
                      onPressed: _sendMessage,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}