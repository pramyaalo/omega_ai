import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'DocumentAnalyzerScreen.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:web_socket_channel/status.dart' as status;
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:speech_to_text/speech_to_text.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';
import 'SettingsScreen.dart';
import 'ChatBubble.dart';

class NewChatScreen extends StatefulWidget {
  final String? initialMessage;
  const NewChatScreen({super.key, this.initialMessage});

  @override
  State<NewChatScreen> createState() => _NewChatScreenState();
}

class _NewChatScreenState extends State<NewChatScreen> {
  final TextEditingController messageController = TextEditingController();
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  WebSocketChannel? channel;
  final ImagePicker _picker = ImagePicker();
  XFile? selectedImage;
  PlatformFile? selectedFile;

  List<Map<String, dynamic>> sessions = [];
  String currentSessionId = "";
  List<Map<String, dynamic>> messages = [];
  final SpeechToText _speech = SpeechToText();
  bool _isListening = false;
  bool _isSearching = false;
  String _searchQuery = "";
  List<Map<String, dynamic>> _searchResults = [];
  String _selectedLanguage = "English";
  String _selectedModel = "Llama 3.1 8B";
  bool _isTemporary = false;

  // ── Website-exact color palette ──────────────────────────────
  static const kCyan        = Color(0xFF1BA8D4);   // "Omega AI" cyan
  static const kCyanDark    = Color(0xFF1890B8);   // button gradient start
  static const kCyanLight   = Color(0xFF26C0F0);   // button gradient end
  static const kBgWhite     = Color(0xFFFFFFFF);   // main bg
  static const kBgLight     = Color(0xFFF6FAFE);   // page bg
  static const kSidebarBg   = Color(0xFFFFFFFF);   // sidebar
  static const kCardBg      = Color(0xFFF0F7FF);   // quick-action card
  static const kCardBorder  = Color(0xFFD1E9F6);   // card border
  static const kBorderLight = Color(0xFFE8EFF5);   // dividers / input border
  static const kTextPrimary = Color(0xFF111827);   // headings
  static const kTextSub     = Color(0xFF6B7280);   // sub text
  static const kTextMuted   = Color(0xFF9CA3AF);   // placeholder

  // dark-mode counterparts
  static const kDarkBg      = Color(0xFF0D1B2A);
  static const kDarkBg2     = Color(0xFF0A2540);
  static const kDarkCard    = Color(0xFF1A2744);
  static const kDarkSidebar = Color(0xFF112035);
  static const kDarkBorder  = Color(0xFF1E3354);
  static const kDarkSub     = Color(0xFF8899AA);

  // ── Quick-action cards (website's 4 cards) ───────────────────
  final List<Map<String, dynamic>> _quickCards = [
    {'icon': Icons.edit_document,       'label': 'Edit & return file',    'prompt': 'Edit this file: ',            'route': null},
    {'icon': Icons.code_rounded,        'label': 'Write or fix code',     'prompt': 'Write code for: ',            'route': null},
    {'icon': Icons.summarize_rounded,   'label': 'Analyze & summarize',   'prompt': 'Analyze and summarize: ',     'route': null},
    {'icon': Icons.image_outlined,      'label': 'Generate an image',     'prompt': 'Generate an image of: ',      'route': null},
    {'icon': Icons.description_rounded, 'label': 'Document Analyzer',     'prompt': '',                            'route': 'doc_analyzer'},
    {'icon': Icons.translate_rounded,   'label': 'Translate text',        'prompt': 'Translate this to English: ', 'route': null},
  ];

  // ── i18n ─────────────────────────────────────────────────────
  Map<String, Map<String, String>> _uiText = {
    "English": {
      "title": "Omega AI", "newChat": "New Chat",
      "recentChats": "Recent Chats", "pinnedChats": "Pinned Chats",
      "noChats": "No chats yet", "settings": "Settings",
      "askAnything": "Ask Omega anything...", "listening": "Listening...",
      "searchHint": "Search messages...", "noResults": "No results found",
      "noMessages": "No messages found", "tryDifferent": "Try a different keyword",
      "howCanIHelp": "Welcome to", "subTitle": "Your autonomous AI assistant. I detect intent, process files, and deliver structured answers — all without follow-up questions.",
      "imageSelected": "Image selected", "attach": "Attach",
      "quickActions": "Quick Actions", "exportShare": "Export & Share",
      "exportPdf": "Export PDF", "shareChat": "Share Chat",
      "noMessagesToShare": "No messages to share!", "noMessagesToExport": "No messages to export!",
      "temporaryChat": "Temporary Chat", "tempChatHint": "This chat won't be saved",
    },
    "Tamil": {
      "title": "ஒமேகா AI", "newChat": "புதிய அரட்டை",
      "recentChats": "சமீபத்திய அரட்டைகள்", "pinnedChats": "பின் செய்யப்பட்டவை",
      "noChats": "அரட்டைகள் இல்லை", "settings": "அமைப்புகள்",
      "askAnything": "எதையும் கேளுங்கள்...", "listening": "கேட்கிறேன்...",
      "searchHint": "செய்திகளை தேடுங்கள்...", "noResults": "முடிவுகள் இல்லை",
      "noMessages": "செய்திகள் கிடைக்கவில்லை", "tryDifferent": "வேறு வார்த்தை முயற்சிக்கவும்",
      "howCanIHelp": "வரவேற்கிறோம்", "subTitle": "உங்கள் AI உதவியாளர்",
      "imageSelected": "படம் தேர்ந்தெடுக்கப்பட்டது", "attach": "இணைக்கவும்",
      "quickActions": "விரைவு செயல்கள்", "exportShare": "ஏற்றுமதி & பகிர்வு",
      "exportPdf": "PDF ஏற்றுமதி", "shareChat": "அரட்டை பகிர்வு",
      "noMessagesToShare": "பகிர செய்திகள் இல்லை!", "noMessagesToExport": "ஏற்றுமதி செய்ய செய்திகள் இல்லை!",
      "temporaryChat": "தற்காலிக அரட்டை", "tempChatHint": "இந்த அரட்டை சேமிக்கப்படாது",
    },
    "Hindi": {
      "title": "ओमेगा AI", "newChat": "नई चैट",
      "recentChats": "हाल की चैट", "pinnedChats": "पिन की गई चैट",
      "noChats": "कोई चैट नहीं", "settings": "सेटिंग्स",
      "askAnything": "कुछ भी पूछें...", "listening": "सुन रहा हूँ...",
      "searchHint": "संदेश खोजें...", "noResults": "कोई परिणाम नहीं",
      "noMessages": "कोई संदेश नहीं मिला", "tryDifferent": "कोई और शब्द आज़माएं",
      "howCanIHelp": "स्वागत है", "subTitle": "आपका AI सहायक",
      "imageSelected": "छवि चुनी गई", "attach": "संलग्न करें",
      "quickActions": "त्वरित क्रियाएं", "exportShare": "निर्यात और साझा करें",
      "exportPdf": "PDF निर्यात", "shareChat": "चैट साझा करें",
      "noMessagesToShare": "साझा करने के लिए कोई संदेश नहीं!", "noMessagesToExport": "निर्यात के लिए कोई संदेश नहीं!",
      "temporaryChat": "अस्थायी चैट", "tempChatHint": "यह चैट सेव नहीं होगी",
    },
    "Spanish": {
      "title": "OMEGA IA", "newChat": "Nueva conversación",
      "recentChats": "Chats recientes", "pinnedChats": "Chats fijados",
      "noChats": "Sin conversaciones", "settings": "Configuración",
      "askAnything": "Pregunta lo que sea...", "listening": "Escuchando...",
      "searchHint": "Buscar mensajes...", "noResults": "Sin resultados",
      "noMessages": "No se encontraron mensajes", "tryDifferent": "Intenta otra palabra",
      "howCanIHelp": "Bienvenido a", "subTitle": "Tu asistente AI autónomo",
      "imageSelected": "Imagen seleccionada", "attach": "Adjuntar",
      "quickActions": "Acciones rápidas", "exportShare": "Exportar y compartir",
      "exportPdf": "Exportar PDF", "shareChat": "Compartir chat",
      "noMessagesToShare": "¡No hay mensajes para compartir!", "noMessagesToExport": "¡No hay mensajes para exportar!",
      "temporaryChat": "Chat temporal", "tempChatHint": "Este chat no se guardará",
    },
  };

  String _t(String key) => _uiText[_selectedLanguage]?[key] ?? _uiText["English"]![key] ?? key;

  // ── helpers ──────────────────────────────────────────────────
  void _togglePin(String id) {
    setState(() {
      final idx = sessions.indexWhere((s) => s['id'] == id);
      if (idx >= 0) sessions[idx]['pinned'] = !(sessions[idx]['pinned'] ?? false);
    });
    _saveSessions();
  }

  List<Map<String, dynamic>> get _pinnedSessions   => sessions.where((s) => s['pinned'] == true).toList();
  List<Map<String, dynamic>> get _unpinnedSessions => sessions.where((s) => s['pinned'] != true).toList();

  void _toggleTemporary() {
    setState(() { _isTemporary = !_isTemporary; messages = []; currentSessionId = _generateId(); });
    try { channel?.sink.close(status.goingAway); } catch (_) {}
    _connectWebSocket();
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Row(children: [
        Icon(_isTemporary ? Icons.timer : Icons.save, color: Colors.white, size: 18),
        const SizedBox(width: 8),
        Text(_isTemporary ? _t('tempChatHint') : "Chat will be saved normally"),
      ]),
      backgroundColor: _isTemporary ? Colors.orange : const Color(0xFF2B9348),
      duration: const Duration(seconds: 2),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    ));
  }

  @override
  void initState() {
    super.initState();
    _initSpeech();
    _loadLanguage();
    _loadSessions().then((_) {
      if (widget.initialMessage != null && widget.initialMessage!.isNotEmpty) {
        messageController.text = widget.initialMessage!;
        Future.delayed(const Duration(milliseconds: 500), () => setState(() {}));
      }
    });
  }

  Future<void> _loadLanguage() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() => _selectedLanguage = prefs.getString('selected_language') ?? 'English');
    _selectedModel = prefs.getString('selected_model') ?? 'Llama 3.1 8B';
  }

  void _scrollToBottom() {
    Future.delayed(const Duration(milliseconds: 100), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(_scrollController.position.maxScrollExtent,
            duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
      }
    });
  }

  Future<String> _getSessionKey() async {
    final user = FirebaseAuth.instance.currentUser;
    return 'sessions_${user?.uid ?? 'guest'}';
  }

  Future<void> _initSpeech() async { await _speech.initialize(); setState(() {}); }

  Future<void> _startListening() async {
    if (!_isListening) {
      bool available = await _speech.initialize(
        onStatus: (s) {
          if (s == 'done' || s == 'notListening') {
            setState(() => _isListening = false);
            if (messageController.text.trim().isNotEmpty) _sendMessage();
          }
        },
        onError: (error) => setState(() => _isListening = false),
      );
      if (available) {
        setState(() => _isListening = true);
        String localeId = 'en_US';
        if (_selectedLanguage == 'Tamil') localeId = 'ta_IN';
        if (_selectedLanguage == 'Hindi') localeId = 'hi_IN';
        if (_selectedLanguage == 'Spanish') localeId = 'es_ES';
        await _speech.listen(
          onResult: (result) {
            setState(() => messageController.text = result.recognizedWords);
            if (result.finalResult) {
              setState(() => _isListening = false);
              _speech.stop();
              Future.delayed(const Duration(milliseconds: 300), () {
                if (messageController.text.trim().isNotEmpty) _sendMessage();
              });
            }
          },
          localeId: localeId,
          listenMode: ListenMode.confirmation,
        );
      }
    } else {
      setState(() => _isListening = false);
      await _speech.stop();
      if (messageController.text.trim().isNotEmpty) {
        Future.delayed(const Duration(milliseconds: 300), () => _sendMessage());
      }
    }
  }

  String _generateId() => DateTime.now().millisecondsSinceEpoch.toString();

  Future<void> _loadSessions() async {
    final prefs = await SharedPreferences.getInstance();
    final sessionKey = await _getSessionKey();
    final oldSaved = prefs.getString('sessions');
    final newSaved = prefs.getString(sessionKey);
    if (newSaved != null) {
      final List decoded = jsonDecode(newSaved);
      setState(() => sessions = decoded.cast<Map<String, dynamic>>());
    } else if (oldSaved != null) {
      final List decoded = jsonDecode(oldSaved);
      setState(() => sessions = decoded.cast<Map<String, dynamic>>());
      await prefs.setString(sessionKey, oldSaved);
      await prefs.remove('sessions');
    } else {
      setState(() => sessions = []);
    }
    _startNewSession();
  }

  Future<void> _saveSessions() async {
    final prefs = await SharedPreferences.getInstance();
    final sessionKey = await _getSessionKey();
    await prefs.setString(sessionKey, jsonEncode(sessions));
  }

  void _startNewSession() {
    final id = _generateId();
    setState(() { currentSessionId = id; messages = []; _isTemporary = false; });
    try { channel?.sink.close(status.goingAway); } catch (_) {}
    _connectWebSocket();
  }

  void _loadSession(Map<String, dynamic> session) {
    setState(() {
      currentSessionId = session['id'];
      messages = List<Map<String, dynamic>>.from(
          (session['messages'] as List).map((m) => Map<String, dynamic>.from(m)));
      _isTemporary = false;
    });
    Navigator.pop(context); // drawer மட்டும் close பண்ணும்
    try { channel?.sink.close(status.goingAway); } catch (_) {}
    _connectWebSocket();
    _scrollToBottom();
  }

  // Search result-ல் இருந்து load — Navigator.pop இல்லாம
  void _loadSessionFromSearch(Map<String, dynamic> session) {
    setState(() {
      currentSessionId = session['id'];
      messages = List<Map<String, dynamic>>.from(
          (session['messages'] as List).map((m) => Map<String, dynamic>.from(m)));
      _isTemporary = false;
      _isSearching = false;
      _searchController.clear();
      _searchQuery = "";
      _searchResults = [];
    });
    try { channel?.sink.close(status.goingAway); } catch (_) {}
    _connectWebSocket();
    _scrollToBottom();
  }

  void _deleteSession(String id) {
    setState(() => sessions.removeWhere((s) => s['id'] == id));
    _saveSessions();
    if (currentSessionId == id) _startNewSession();
  }

  void _saveCurrentSession() {
    if (_isTemporary || messages.isEmpty) return;
    final firstMsg = messages.firstWhere((m) => m['isMe'] == true, orElse: () => {"text": "New Chat"});
    final title = (firstMsg['text'] as String).length > 30
        ? '${(firstMsg['text'] as String).substring(0, 30)}...'
        : firstMsg['text'] as String;
    final toSave = messages.map((m) => {"text": m["text"] ?? "", "isMe": m["isMe"]}).toList();
    final existingIndex = sessions.indexWhere((s) => s['id'] == currentSessionId);
    if (existingIndex >= 0) {
      final pinned = sessions[existingIndex]['pinned'] ?? false;
      sessions[existingIndex] = {'id': currentSessionId, 'title': title, 'messages': toSave, 'pinned': pinned};
    } else {
      sessions.insert(0, {'id': currentSessionId, 'title': title, 'messages': toSave, 'pinned': false});
    }
    _saveSessions();
  }

  void _connectWebSocket() {
    try { channel?.sink.close(status.goingAway); } catch (_) {}
    channel = WebSocketChannel.connect(Uri.parse('wss://silo-churn-worst.ngrok-free.dev/ws/chat/'));
    channel!.stream.listen((data) {
      final decoded = jsonDecode(data);
      final type    = decoded["type"];
      final text    = decoded["message"] ?? "";

      setState(() {
        // ── Normal typing indicator ─────────────────────────────────
        if (type == "typing") {
          messages.add({"text": "", "isMe": false, "typing": true});
        }

        // ── Agent mode activated ────────────────────────────────────
        if (type == "agent_start") {
          // Replace typing bubble with agent bubble
          for (int i = messages.length - 1; i >= 0; i--) {
            if (messages[i]["isMe"] == false) {
              messages[i]["isAgent"]     = true;
              messages[i]["agentSteps"]  = <Map<String, dynamic>>[];
              messages[i]["agentActive"] = true;
              break;
            }
          }
        }

        // ── Agent step update ───────────────────────────────────────
        if (type == "agent_step") {
          for (int i = messages.length - 1; i >= 0; i--) {
            if (messages[i]["isMe"] == false && messages[i]["isAgent"] == true) {
              final steps = List<Map<String, dynamic>>.from(
                  messages[i]["agentSteps"] as List? ?? []);
              // Update existing step index or add new
              final idx = decoded["index"] as int? ?? steps.length;
              final stepData = {"step": decoded["step"], "label": decoded["label"]};
              if (idx < steps.length) {
                steps[idx] = stepData;
              } else {
                steps.add(stepData);
              }
              messages[i]["agentSteps"] = steps;
              break;
            }
          }
        }

        // ── Streaming final answer ──────────────────────────────────
        if (type == "stream") {
          for (int i = messages.length - 1; i >= 0; i--) {
            if (messages[i]["isMe"] == false) {
              messages[i]["text"]        = text;
              messages[i]["agentActive"] = false;
              messages[i].remove("typing");
              break;
            }
          }
        }

        // ── Done ────────────────────────────────────────────────────
        if (type == "done") {
          for (int i = messages.length - 1; i >= 0; i--) {
            if (messages[i]["isMe"] == false) {
              messages[i].remove("typing");
              messages[i]["agentActive"] = false;
              break;
            }
          }
          _saveCurrentSession();
        }
      });
      _scrollToBottom();
    },
        onError: (error) => Future.delayed(const Duration(seconds: 2), _connectWebSocket),
        onDone: () {});
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
      channel!.sink.add(jsonEncode({"message": text, "language": _selectedLanguage, "model": "Llama 3.1 8B"}));
      messageController.clear();
      _scrollToBottom();
    }
  }

  Future<void> _sendImage(String caption) async {
    final bytes = await File(selectedImage!.path).readAsBytes();
    final base64Image = base64Encode(bytes);
    final ext = selectedImage!.path.split('.').last.toLowerCase();
    setState(() {
      messages.add({"text": caption.isNotEmpty ? caption : "📷 Image", "isMe": true, "imageBase64": base64Image, "imageExt": ext});
      selectedImage = null;
    });
    channel!.sink.add(jsonEncode({"message": caption.isNotEmpty ? caption : "What is in this image?", "image": base64Image, "image_ext": ext, "language": _selectedLanguage, "model": _selectedModel}));
    messageController.clear();
    _scrollToBottom();
  }

  Future<void> _sendFile(String caption) async {
    final bytes = selectedFile!.bytes ?? await File(selectedFile!.path!).readAsBytes();
    final base64File = base64Encode(bytes);
    final name = selectedFile!.name;
    setState(() { messages.add({"text": "📎 $name", "isMe": true}); selectedFile = null; });
    channel!.sink.add(jsonEncode({"message": caption.isNotEmpty ? caption : "Analyze this file: $name", "file": base64File, "file_name": name, "language": _selectedLanguage, "model": _selectedModel}));
    messageController.clear();
    _scrollToBottom();
  }

  Future<void> _pickImage(ImageSource source) async {
    final image = await _picker.pickImage(source: source);
    if (image != null) setState(() { selectedImage = image; selectedFile = null; });
  }

  Future<void> _pickFile() async {
    final result = await FilePicker.platform.pickFiles(withData: true);
    if (result != null && result.files.isNotEmpty) setState(() { selectedFile = result.files.first; selectedImage = null; });
  }

  void _performSearch(String query) {
    if (query.trim().isEmpty) { setState(() => _searchResults = []); return; }
    final q = query.toLowerCase();
    final results = <Map<String, dynamic>>[];
    for (final session in sessions) {
      final msgs = session['messages'] as List? ?? [];
      for (final msg in msgs) {
        if ((msg['text'] ?? '').toString().toLowerCase().contains(q))
          results.add({'sessionId': session['id'], 'sessionTitle': session['title'] ?? 'Chat', 'text': msg['text'] ?? '', 'isMe': msg['isMe']});
      }
    }
    for (final msg in messages) {
      if ((msg['text'] ?? '').toString().toLowerCase().contains(q) && msg['typing'] != true) {
        final alreadyAdded = results.any((r) => r['sessionId'] == currentSessionId && r['text'] == msg['text']);
        if (!alreadyAdded) results.add({'sessionId': currentSessionId, 'sessionTitle': 'Current Chat', 'text': msg['text'] ?? '', 'isMe': msg['isMe']});
      }
    }
    setState(() => _searchResults = results);
  }

  Widget _highlightText(String text, String query, {bool isMe = false}) {
    if (query.isEmpty) return Text(text, style: TextStyle(fontSize: 13, color: isMe ? Colors.white : kTextPrimary));
    final lowerText = text.toLowerCase();
    final spans = <TextSpan>[];
    int start = 0;
    while (true) {
      final idx = lowerText.indexOf(query.toLowerCase(), start);
      if (idx == -1) { spans.add(TextSpan(text: text.substring(start))); break; }
      if (idx > start) spans.add(TextSpan(text: text.substring(start, idx)));
      spans.add(TextSpan(text: text.substring(idx, idx + query.length),
          style: const TextStyle(backgroundColor: Color(0xFFFFEB3B), color: Colors.black, fontWeight: FontWeight.bold)));
      start = idx + query.length;
    }
    return RichText(text: TextSpan(style: TextStyle(fontSize: 13, color: isMe ? Colors.white : kTextPrimary), children: spans));
  }

  void _shareChat() {
    if (messages.isEmpty) { ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(_t('noMessagesToShare')))); return; }
    final user = FirebaseAuth.instance.currentUser;
    final userName = user?.displayName ?? user?.email?.split('@')[0] ?? "User";
    final now = DateTime.now();
    final buffer = StringBuffer();
    buffer.writeln("🤖 *Omega AI Chat*\n📅 ${now.day}/${now.month}/${now.year}\n─────────────────────");
    for (final msg in messages) {
      if (msg['typing'] == true) continue;
      final text = msg['text']?.toString() ?? '';
      if (text.isEmpty) continue;
      buffer.writeln(msg['isMe'] as bool ? "\n👤 *$userName:*" : "\n🤖 *Omega AI:*");
      buffer.writeln(text);
    }
    buffer.writeln("\n─────────────────────\nShared from Omega AI App");
    Share.share(buffer.toString(), subject: "Omega AI Chat - ${now.day}/${now.month}/${now.year}");
  }

  void _showExportSheet() {
    if (messages.isEmpty) { ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(_t('noMessagesToExport')))); return; }
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showModalBottomSheet(
      context: context, backgroundColor: Colors.transparent,
      builder: (_) => Container(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
        decoration: BoxDecoration(
          color: isDark ? kDarkCard : kBgWhite,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(width: 40, height: 4, margin: const EdgeInsets.only(bottom: 20),
              decoration: BoxDecoration(color: Colors.grey.withOpacity(0.3), borderRadius: BorderRadius.circular(2))),
          Text(_t('exportShare'), style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : kTextPrimary)),
          const SizedBox(height: 20),
          Row(children: [
            Expanded(child: GestureDetector(
              onTap: () { Navigator.pop(context); _exportChatAsPDF(); },
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 20),
                decoration: BoxDecoration(color: kCyan.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(16), border: Border.all(color: kCardBorder)),
                child: Column(children: [
                  const Icon(Icons.picture_as_pdf, color: kCyan, size: 36),
                  const SizedBox(height: 8),
                  Text(_t('exportPdf'), style: const TextStyle(color: kCyan, fontWeight: FontWeight.w600, fontSize: 14)),
                  const SizedBox(height: 4),
                  const Text("Save as PDF file", style: TextStyle(color: kTextMuted, fontSize: 11)),
                ]),
              ),
            )),
            const SizedBox(width: 12),
            Expanded(child: GestureDetector(
              onTap: () { Navigator.pop(context); _shareChat(); },
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 20),
                decoration: BoxDecoration(color: Colors.green.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.green.withOpacity(0.3))),
                child: Column(children: [
                  const Icon(Icons.share_rounded, color: Colors.green, size: 36),
                  const SizedBox(height: 8),
                  Text(_t('shareChat'), style: const TextStyle(color: Colors.green, fontWeight: FontWeight.w600, fontSize: 14)),
                  const SizedBox(height: 4),
                  const Text("WhatsApp, Gmail...", style: TextStyle(color: kTextMuted, fontSize: 11)),
                ]),
              ),
            )),
          ]),
        ]),
      ),
    );
  }

  Future<void> _exportChatAsPDF() async {
    if (messages.isEmpty) return;
    showDialog(context: context, barrierDismissible: false, builder: (_) => const Center(child: CircularProgressIndicator(color: kCyan)));
    try {
      final pdf = pw.Document();
      final user = FirebaseAuth.instance.currentUser;
      final userName = user?.displayName ?? user?.email?.split('@')[0] ?? "User";
      final now = DateTime.now();
      pdf.addPage(pw.MultiPage(
        pageFormat: PdfPageFormat.a4, margin: const pw.EdgeInsets.all(32),
        build: (pw.Context ctx) => [
          pw.Container(
            padding: const pw.EdgeInsets.all(16),
            decoration: pw.BoxDecoration(color: PdfColor.fromHex('#1BA8D4'), borderRadius: pw.BorderRadius.circular(8)),
            child: pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
              pw.Text('Ω Omega AI', style: pw.TextStyle(color: PdfColors.white, fontSize: 20, fontWeight: pw.FontWeight.bold)),
              pw.Text('Chat Export', style: const pw.TextStyle(color: PdfColors.white, fontSize: 12)),
            ]),
          ),
          pw.SizedBox(height: 8),
          pw.Text('Exported: ${now.day}/${now.month}/${now.year}  |  User: $userName',
              style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey)),
          pw.SizedBox(height: 12), pw.Divider(), pw.SizedBox(height: 8),
          ...messages.where((m) => m['typing'] != true && (m['text'] ?? '').toString().isNotEmpty).map((msg) {
            final isMe = msg['isMe'] as bool;
            return pw.Container(
              margin: const pw.EdgeInsets.only(bottom: 14),
              child: pw.Column(crossAxisAlignment: isMe ? pw.CrossAxisAlignment.end : pw.CrossAxisAlignment.start, children: [
                pw.Text(isMe ? userName : 'Omega AI',
                    style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold,
                        color: isMe ? PdfColor.fromHex('#1BA8D4') : PdfColors.grey700)),
                pw.SizedBox(height: 4),
                pw.Container(
                  padding: const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: pw.BoxDecoration(
                      color: isMe ? PdfColor.fromHex('#1BA8D4') : PdfColor.fromHex('#F0F7FF'),
                      borderRadius: pw.BorderRadius.circular(12)),
                  child: pw.Text(msg['text'].toString(),
                      style: pw.TextStyle(fontSize: 11, color: isMe ? PdfColors.white : PdfColors.black)),
                ),
              ]),
            );
          }).toList(),
          pw.SizedBox(height: 16), pw.Divider(), pw.SizedBox(height: 8),
          pw.Center(child: pw.Text('Generated by Omega AI • ${now.day}/${now.month}/${now.year}',
              style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey))),
        ],
      ));
      if (mounted) Navigator.pop(context);
      await Printing.sharePdf(bytes: await pdf.save(), filename: 'omega_chat_${now.millisecondsSinceEpoch}.pdf');
    } catch (e) {
      if (mounted) Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("PDF error: $e")));
    }
  }

  void _showAttachmentSheet() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showModalBottomSheet(
      context: context, isScrollControlled: true, backgroundColor: Colors.transparent,
      builder: (_) => Container(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
        decoration: BoxDecoration(
          color: isDark ? kDarkCard : kBgWhite,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          border: Border(top: BorderSide(color: isDark ? kDarkBorder : kBorderLight)),
        ),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(width: 40, height: 4, margin: const EdgeInsets.only(bottom: 20),
              decoration: BoxDecoration(color: kBorderLight, borderRadius: BorderRadius.circular(2))),
          Align(alignment: Alignment.centerLeft,
              child: Text(_t('attach'), style: TextStyle(color: isDark ? Colors.white : kTextPrimary,
                  fontSize: 18, fontWeight: FontWeight.bold))),
          const SizedBox(height: 16),
          Row(children: [
            _attachOption(Icons.camera_alt_rounded,         "Camera",  () { Navigator.pop(context); _pickImage(ImageSource.camera); }),
            const SizedBox(width: 10),
            _attachOption(Icons.photo_library_rounded,      "Gallery", () { Navigator.pop(context); _pickImage(ImageSource.gallery); }),
            const SizedBox(width: 10),
            _attachOption(Icons.insert_drive_file_rounded,  "Files",   () { Navigator.pop(context); _pickFile(); }),
          ]),
          const SizedBox(height: 24),
          Align(alignment: Alignment.centerLeft,
              child: Text(_t('quickActions'), style: TextStyle(color: isDark ? kDarkSub : kTextSub,
                  fontSize: 13, fontWeight: FontWeight.w600))),
          const SizedBox(height: 12),
          GridView.count(
            crossAxisCount: 3, shrinkWrap: true, physics: const NeverScrollableScrollPhysics(),
            crossAxisSpacing: 10, mainAxisSpacing: 10, childAspectRatio: 1.1,
            children: [
              _quickActionTile(Icons.image_search_rounded,    "Create Image",      const Color(0xFFE94560), () { Navigator.pop(context); messageController.text = "Create an image of "; }),
              _quickActionTile(Icons.psychology_rounded,      "Deep Think",        const Color(0xFF533483), () { Navigator.pop(context); messageController.text = "Think deeply and explain: "; }),
              _quickActionTile(Icons.travel_explore_rounded,  "Web Search",        kCyanDark,               () { Navigator.pop(context); messageController.text = "Search and tell me about: "; }),
              _quickActionTile(Icons.description_rounded,     "Doc Analyzer",      kCyan,                   () { Navigator.pop(context); Navigator.push(context, MaterialPageRoute(builder: (_) => const DocumentAnalyzerScreen())); }),
              _quickActionTile(Icons.shopping_bag_rounded,    "Shopping",          const Color(0xFF2B9348), () { Navigator.pop(context); messageController.text = "Best options to buy: "; }),
              _quickActionTile(Icons.science_rounded,         "Research",          const Color(0xFFB5451B), () { Navigator.pop(context); messageController.text = "Research and summarize: "; }),
              _quickActionTile(Icons.school_rounded,          "Study",             const Color(0xFF1B4332), () { Navigator.pop(context); messageController.text = "Teach me about: "; }),
              _quickActionTile(Icons.explore_rounded,         "Explore",           const Color(0xFF2D6A4F), () { Navigator.pop(context); messageController.text = "Explore the topic: "; }),
              _quickActionTile(Icons.calculate_rounded,       "Math",              const Color(0xFF6A0572), () { Navigator.pop(context); messageController.text = "Solve this: "; }),
              _quickActionTile(Icons.code_rounded,            "Code",              const Color(0xFF1A1A4E), () { Navigator.pop(context); messageController.text = "Write code for: "; }),
            ],
          ),
        ]),
      ),
    );
  }

  Widget _attachOption(IconData icon, String label, VoidCallback onTap) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Expanded(child: GestureDetector(onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: isDark ? kDarkBg : kCardBg,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: isDark ? kDarkBorder : kCardBorder),
        ),
        child: Column(children: [
          Icon(icon, color: kCyan, size: 26),
          const SizedBox(height: 6),
          Text(label, style: TextStyle(color: isDark ? Colors.white70 : kTextSub, fontSize: 12, fontWeight: FontWeight.w500)),
        ]),
      ),
    ));
  }

  Widget _quickActionTile(IconData icon, String label, Color color, VoidCallback onTap) {
    return GestureDetector(onTap: onTap,
      child: Container(
        decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(14)),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(icon, color: Colors.white, size: 24),
          const SizedBox(height: 6),
          Text(label, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white70, fontSize: 10, fontWeight: FontWeight.w500)),
        ]),
      ),
    );
  }

  Widget _sessionTile(Map<String, dynamic> session, Color textColor, Color subTextColor) {
    final isActive = session['id'] == currentSessionId;
    final isPinned = session['pinned'] == true;
    return Container(
      margin: const EdgeInsets.only(bottom: 2),
      decoration: BoxDecoration(
        color: isActive ? kCyan.withOpacity(0.08) : Colors.transparent,
        borderRadius: BorderRadius.circular(8),
      ),
      child: ListTile(
        dense: true,
        leading: Icon(isPinned ? Icons.push_pin : Icons.chat_bubble_outline,
            color: isPinned ? const Color(0xFFFFB300) : kCyan, size: 18),
        title: Text(session['title'] ?? 'Chat', maxLines: 1, overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 13, color: textColor,
                fontWeight: isActive ? FontWeight.w600 : FontWeight.normal)),
        trailing: PopupMenuButton<String>(
          icon: const Icon(Icons.more_vert, color: kTextMuted, size: 16),
          onSelected: (val) {
            if (val == 'pin') _togglePin(session['id']);
            if (val == 'delete') _deleteSession(session['id']);
          },
          itemBuilder: (_) => [
            PopupMenuItem(value: 'pin',
                child: Row(children: [
                  Icon(isPinned ? Icons.push_pin_outlined : Icons.push_pin, color: const Color(0xFFFFB300), size: 16),
                  const SizedBox(width: 8), Text(isPinned ? 'Unpin' : 'Pin'),
                ])),
            const PopupMenuItem(value: 'delete',
                child: Row(children: [
                  Icon(Icons.delete_outline, color: Colors.red, size: 16),
                  SizedBox(width: 8), Text('Delete', style: TextStyle(color: Colors.red)),
                ])),
          ],
        ),
        onTap: () => _loadSession(session),
      ),
    );
  }

  @override
  void dispose() {
    channel?.sink.close(status.goingAway);
    messageController.dispose();
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  // ════════════════════════════════════════════════════════════
  //  BUILD
  // ════════════════════════════════════════════════════════════
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // ── Theme-aware tokens (exactly matches website in light mode) ──
    final bgColor      = isDark ? kDarkBg      : kBgWhite;
    final cardColor    = isDark ? kDarkCard    : kBgWhite;
    final drawerBg     = isDark ? kDarkSidebar : kSidebarBg;
    final textColor    = isDark ? Colors.white : kTextPrimary;
    final subColor     = isDark ? kDarkSub     : kTextSub;
    final borderColor  = isDark ? kDarkBorder  : kBorderLight;

    final pinned   = _pinnedSessions;
    final unpinned = _unpinnedSessions;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
        systemNavigationBarColor: bgColor,
      ),
      child: Scaffold(
        backgroundColor: bgColor,

        // ── DRAWER ──────────────────────────────────────────────
        drawer: Drawer(
          backgroundColor: drawerBg,
          elevation: 0,
          child: SafeArea(child: Column(children: [

            // Sidebar header
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(16, 18, 16, 14),
              decoration: BoxDecoration(
                border: Border(bottom: BorderSide(color: borderColor)),
              ),
              child: Row(children: [
                Container(
                  width: 32, height: 32,
                  decoration: BoxDecoration(color: kCyan, borderRadius: BorderRadius.circular(8)),
                  child: const Center(child: Text("Ω", style: TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.bold))),
                ),
                const SizedBox(width: 10),
                Text("Omega AI", style: TextStyle(color: textColor, fontSize: 18, fontWeight: FontWeight.bold)),
              ]),
            ),

            // New Chat button
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 14, 14, 8),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.add, size: 17),
                  label: Text(_t('newChat'), style: const TextStyle(fontWeight: FontWeight.w600)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: kCyan,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  onPressed: () { Navigator.pop(context); _startNewSession(); },
                ),
              ),
            ),

            // Recent label
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 6, 18, 6),
              child: Align(alignment: Alignment.centerLeft,
                  child: Text("RECENT", style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700,
                      color: subColor, letterSpacing: 1.0))),
            ),

            Expanded(
              child: sessions.isEmpty
                  ? Center(child: Text(_t('noChats'), style: TextStyle(color: subColor, fontSize: 13)))
                  : ListView(padding: const EdgeInsets.symmetric(horizontal: 8), children: [
                if (pinned.isNotEmpty) ...[
                  Padding(padding: const EdgeInsets.fromLTRB(8, 4, 8, 4),
                      child: Row(children: [
                        const Icon(Icons.push_pin, color: Color(0xFFFFB300), size: 13),
                        const SizedBox(width: 4),
                        Text(_t('pinnedChats'), style: const TextStyle(fontWeight: FontWeight.w600,
                            fontSize: 11, color: Color(0xFFFFB300), letterSpacing: 0.4)),
                      ])),
                  ...pinned.map((s) => _sessionTile(s, textColor, subColor)),
                  Divider(height: 16, color: borderColor),
                ],
                ...unpinned.map((s) => _sessionTile(s, textColor, subColor)),
              ]),
            ),

            Divider(height: 1, color: borderColor),

            // Settings row
            ListTile(
              dense: true,
              leading: Icon(Icons.settings_outlined, color: subColor, size: 20),
              title: Text(_t('settings'), style: TextStyle(color: textColor, fontSize: 14, fontWeight: FontWeight.w500)),
              trailing: Icon(Icons.chevron_right, color: subColor, size: 18),
              onTap: () async {
                Navigator.pop(context);
                await Navigator.push(context, MaterialPageRoute(builder: (_) => const SettingsScreen()));
                _loadLanguage();
              },
            ),

            // User card
            Builder(builder: (context) {
              final user = FirebaseAuth.instance.currentUser;
              final displayName = user?.displayName ?? user?.email?.split('@')[0] ?? "User";
              final email = user?.email ?? "guest@omega.ai";
              final firstLetter = displayName.isNotEmpty ? displayName[0].toUpperCase() : "U";
              return Container(
                margin: const EdgeInsets.fromLTRB(10, 4, 10, 10),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: isDark ? kDarkBg : kCardBg,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: borderColor),
                ),
                child: Row(children: [
                  CircleAvatar(radius: 18, backgroundColor: kCyan,
                      child: Text(firstLetter, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14))),
                  const SizedBox(width: 10),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(displayName, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: textColor), overflow: TextOverflow.ellipsis),
                    Text(email, style: const TextStyle(fontSize: 11, color: kTextMuted), overflow: TextOverflow.ellipsis),
                  ])),
                  GestureDetector(
                    onTap: () async {
                      Navigator.pop(context);
                      await Navigator.push(context, MaterialPageRoute(builder: (_) => const SettingsScreen()));
                      _loadLanguage();
                    },
                    child: const Icon(Icons.settings, color: kCyan, size: 18),
                  ),
                ]),
              );
            }),
          ])),
        ),

        // ── BODY ────────────────────────────────────────────────
        body: SafeArea(
          child: Column(children: [

            // ── TOP BAR (website-style minimal) ────────────────
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
              decoration: BoxDecoration(
                color: bgColor,
                border: Border(bottom: BorderSide(color: borderColor, width: 0.8)),
              ),
              child: Row(children: [
                Builder(builder: (ctx) => IconButton(
                  icon: Icon(Icons.menu_rounded, color: textColor, size: 22),
                  onPressed: () => Scaffold.of(ctx).openDrawer(),
                )),

                // Title area
                Expanded(child: _isSearching
                    ? TextField(
                  controller: _searchController, autofocus: true,
                  style: TextStyle(color: textColor, fontSize: 15),
                  decoration: InputDecoration(
                    hintText: _t('searchHint'),
                    hintStyle: const TextStyle(color: kTextMuted),
                    border: InputBorder.none, contentPadding: EdgeInsets.zero,
                  ),
                  onChanged: (val) { setState(() => _searchQuery = val); _performSearch(val); },
                )
                    : Row(children: [
                  if (_isTemporary) ...[
                    const Icon(Icons.timer, color: Colors.orange, size: 16),
                    const SizedBox(width: 6),
                    Text(_t('temporaryChat'), style: const TextStyle(color: Colors.orange, fontSize: 15, fontWeight: FontWeight.w600)),
                  ] else ...[
                    const Text("Omega ", style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: kCyan)),
                    const Text("AI", style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: kCyan)),
                  ],
                ])),

                // Action icons
                Row(mainAxisSize: MainAxisSize.min, children: [
                  if (!_isSearching && messages.isNotEmpty)
                    IconButton(icon: const Icon(Icons.ios_share_rounded, color: kCyan, size: 20), onPressed: _showExportSheet),
                  IconButton(
                    icon: Icon(_isSearching ? Icons.close : Icons.search, color: kCyan, size: 20),
                    onPressed: () {
                      setState(() {
                        _isSearching = !_isSearching;
                        if (!_isSearching) { _searchController.clear(); _searchQuery = ""; _searchResults = []; }
                      });
                    },
                  ),
                  IconButton(
                    icon: Icon(_isTemporary ? Icons.timer : Icons.timer_outlined,
                        color: _isTemporary ? Colors.orange : kCyan, size: 20),
                    onPressed: _toggleTemporary,
                  ),
                  if (!_isSearching)
                    IconButton(icon: const Icon(Icons.add, color: kCyan, size: 22), onPressed: _startNewSession),
                ]),
              ]),
            ),

            // Temporary banner
            if (_isTemporary)
              Container(
                margin: const EdgeInsets.fromLTRB(12, 8, 12, 0),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.orange.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.orange.withOpacity(0.3)),
                ),
                child: Row(children: [
                  const Icon(Icons.timer, color: Colors.orange, size: 15),
                  const SizedBox(width: 8),
                  Text(_t('tempChatHint'), style: const TextStyle(color: Colors.orange, fontSize: 12, fontWeight: FontWeight.w500)),
                  const Spacer(),
                  GestureDetector(onTap: _toggleTemporary, child: const Icon(Icons.close, color: Colors.orange, size: 15)),
                ]),
              ),

            // Search result count
            if (_isSearching && _searchQuery.isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                child: Align(alignment: Alignment.centerLeft,
                    child: Text(
                      _searchResults.isEmpty ? _t('noResults')
                          : "${_searchResults.length} result${_searchResults.length > 1 ? 's' : ''} found",
                      style: const TextStyle(color: kTextSub, fontSize: 12),
                    )),
              ),

            // ── MESSAGES / WELCOME ─────────────────────────────
            Expanded(
              child: _isSearching && _searchQuery.isNotEmpty
                  ? (_searchResults.isEmpty
                  ? Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                const Icon(Icons.search_off, size: 52, color: kTextMuted),
                const SizedBox(height: 12),
                Text(_t('noMessages'), style: const TextStyle(color: kTextSub, fontSize: 16)),
                Text(_t('tryDifferent'), style: const TextStyle(color: kTextMuted, fontSize: 12)),
              ]))
                  : ListView.builder(
                padding: const EdgeInsets.all(12),
                itemCount: _searchResults.length,
                itemBuilder: (context, index) {
                  final result = _searchResults[index];
                  final isMe = result['isMe'] as bool;
                  return Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    decoration: BoxDecoration(color: cardColor, borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: borderColor),
                        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 4)]),
                    child: ListTile(
                      leading: CircleAvatar(radius: 17, backgroundColor: kCyan.withOpacity(0.12),
                          child: Icon(isMe ? Icons.person : Icons.smart_toy, size: 17, color: kCyan)),
                      title: Text(result['sessionTitle'], style: const TextStyle(fontSize: 11, color: kTextMuted)),
                      subtitle: Padding(padding: const EdgeInsets.only(top: 4),
                          child: _highlightText(result['text'], _searchQuery)),
                      onTap: () {
                        final session = sessions.firstWhere((s) => s['id'] == result['sessionId'], orElse: () => {});
                        if (session.isNotEmpty) {
                          _loadSessionFromSearch(session);
                        }
                      },
                    ),
                  );
                },
              ))

                  : messages.isEmpty
              // ── WELCOME SCREEN (exactly like website) ─────
                  ? SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(children: [
                  const SizedBox(height: 60),

                  // "Welcome to Omega AI"
                  Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                    Text("${_t('howCanIHelp')} ", style: TextStyle(
                        fontSize: 26, fontWeight: FontWeight.w700, color: textColor)),
                    const Text("Omega AI", style: TextStyle(
                        fontSize: 26, fontWeight: FontWeight.w700, color: kCyan)),
                  ]),
                  const SizedBox(height: 10),
                  Text(_t('subTitle'), textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 14, color: kTextSub, height: 1.5)),

                  const SizedBox(height: 44),

                  // 2×2 quick-action cards (exactly like website)
                  GridView.count(
                    crossAxisCount: 2,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    crossAxisSpacing: 14,
                    mainAxisSpacing: 14,
                    childAspectRatio: 2.4,
                    children: _quickCards.map((card) => GestureDetector(
                      onTap: () {
                        if (card['route'] == 'doc_analyzer') {
                          Navigator.push(context, MaterialPageRoute(
                              builder: (_) => const DocumentAnalyzerScreen()));
                        } else {
                          messageController.text = card['prompt'] as String;
                        }
                      },
                      child: Container(
                        decoration: BoxDecoration(
                          color: isDark ? kDarkCard : kCardBg,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: isDark ? kDarkBorder : kCardBorder),
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        child: Row(children: [
                          Container(
                            width: 32, height: 32,
                            decoration: BoxDecoration(
                              color: kCyan.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Icon(card['icon'] as IconData, color: kCyan, size: 17),
                          ),
                          const SizedBox(width: 10),
                          Flexible(child: Text(card['label'] as String,
                              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500,
                                  color: isDark ? Colors.white : kTextPrimary), maxLines: 2)),
                        ]),
                      ),
                    )).toList(),
                  ),
                  const SizedBox(height: 40),
                ]),
              )

              // ── CHAT MESSAGES ─────────────────────────
                  : ListView.builder(
                controller: _scrollController,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                itemCount: messages.length,
                itemBuilder: (context, index) =>
                    ChatBubble(message: messages[index], isNew: index == messages.length - 1),
              ),
            ),

            // ── INPUT BAR (website style) ──────────────────────
            if (!_isSearching) ...[
              // Image preview
              if (selectedImage != null)
                Container(
                  margin: const EdgeInsets.fromLTRB(12, 0, 12, 6),
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(color: cardColor, borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: borderColor)),
                  child: Row(children: [
                    ClipRRect(borderRadius: BorderRadius.circular(8),
                        child: Image.file(File(selectedImage!.path), width: 56, height: 56, fit: BoxFit.cover)),
                    const SizedBox(width: 10),
                    Text(_t('imageSelected'), style: TextStyle(color: textColor, fontSize: 13)),
                    const Spacer(),
                    IconButton(icon: const Icon(Icons.close, color: Colors.red, size: 18),
                        onPressed: () => setState(() => selectedImage = null)),
                  ]),
                ),

              // File preview
              if (selectedFile != null)
                Container(
                  margin: const EdgeInsets.fromLTRB(12, 0, 12, 6),
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(color: cardColor, borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: borderColor)),
                  child: Row(children: [
                    const Icon(Icons.insert_drive_file, color: kCyan, size: 36),
                    const SizedBox(width: 10),
                    Expanded(child: Text(selectedFile!.name, overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: textColor, fontSize: 13))),
                    IconButton(icon: const Icon(Icons.close, color: Colors.red, size: 18),
                        onPressed: () => setState(() => selectedFile = null)),
                  ]),
                ),

              // Input row — matches website exactly
              Container(
                margin: const EdgeInsets.fromLTRB(12, 4, 12, 14),
                decoration: BoxDecoration(
                  color: cardColor,
                  borderRadius: BorderRadius.circular(28),
                  border: Border.all(
                    color: _isTemporary
                        ? Colors.orange.withOpacity(0.5)
                        : (isDark ? kDarkBorder : kBorderLight),
                    width: 1.2,
                  ),
                  boxShadow: [BoxShadow(color: Colors.black.withOpacity(isDark ? 0.15 : 0.04), blurRadius: 8, offset: const Offset(0, 2))],
                ),
                child: Row(children: [
                  // + attach button (website uses "+" inside rounded square)
                  Padding(
                    padding: const EdgeInsets.only(left: 4),
                    child: Container(
                      width: 36, height: 36,
                      decoration: BoxDecoration(color: kCyan, borderRadius: BorderRadius.circular(10)),
                      child: IconButton(
                        padding: EdgeInsets.zero,
                        icon: const Icon(Icons.add, color: Colors.white, size: 20),
                        onPressed: _showAttachmentSheet,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),

                  // Text field
                  Expanded(child: TextField(
                    controller: messageController,
                    style: TextStyle(color: textColor, fontSize: 14),
                    maxLines: 4, minLines: 1,
                    decoration: InputDecoration(
                      hintText: _isListening ? _t('listening') : _t('askAnything'),
                      hintStyle: TextStyle(color: _isListening ? Colors.red : kTextMuted, fontSize: 14),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    onSubmitted: (_) => _sendMessage(),
                  )),

                  // Mic
                  IconButton(
                    icon: Icon(_isListening ? Icons.mic : Icons.mic_none,
                        color: _isListening ? Colors.red : kTextSub, size: 22),
                    onPressed: _startListening,
                  ),

                  // Send button (cyan filled circle — website style)
                  Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: GestureDetector(
                      onTap: _sendMessage,
                      child: Container(
                        width: 38, height: 38,
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(colors: [kCyanDark, kCyanLight]),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Icons.send_rounded, color: Colors.white, size: 18),
                      ),
                    ),
                  ),
                ]),
              ),
            ],
          ]),
        ),
      ),
    );
  }
}