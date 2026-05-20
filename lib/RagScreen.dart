// rag_screen.dart
// flutter pub add http file_picker path_provider

import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:http/http.dart' as http;

// ─── Config ──────────────────────────────────────────────────────────────────
const String kBaseUrl = 'http://192.168.1.8:8000/api/rag'; // ✅ சரியான IP
// const String kBaseUrl = 'http://localhost:8000/api/rag'; // iOS simulator
// const String kBaseUrl = 'https://yourserver.com/api/rag'; // Production

// ─── Models ──────────────────────────────────────────────────────────────────

class RagDocument {
  final String id;
  final String name;
  final int    chunkCount;
  RagDocument({required this.id, required this.name, required this.chunkCount});
  factory RagDocument.fromJson(Map<String, dynamic> j) =>
      RagDocument(id: j['id'], name: j['name'], chunkCount: j['chunk_count']);
}

class ChatMessage {
  final String  text;
  final bool    isUser;
  final List<String> sources;
  final DateTime time;
  ChatMessage({
    required this.text,
    required this.isUser,
    this.sources = const [],
    DateTime? time,
  }) : time = time ?? DateTime.now();
}

// ─── RAG Service ─────────────────────────────────────────────────────────────

class RagService {
  final String sessionId;
  RagService({required this.sessionId});

  Future<List<RagDocument>> uploadFiles(List<PlatformFile> files) async {
    final uri = Uri.parse('$kBaseUrl/upload/');
    final req = http.MultipartRequest('POST', uri)
      ..fields['session_id'] = sessionId;

    for (final file in files) {
      if (file.path == null) continue;
      req.files.add(await http.MultipartFile.fromPath('files', file.path!,
          filename: file.name));
    }

    final streamed = await req.send();
    final body     = await streamed.stream.bytesToString();
    final json     = jsonDecode(body);

    if (streamed.statusCode != 200) {
      throw Exception(json['error'] ?? 'Upload failed');
    }

    return (json['uploaded'] as List)
        .map((e) => RagDocument.fromJson(e))
        .toList();
  }

  Future<Map<String, dynamic>> query(String question) async {
    final res = await http.post(
      Uri.parse('$kBaseUrl/query/'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'session_id': sessionId, 'question': question}),
    );
    final json = jsonDecode(res.body);
    if (res.statusCode != 200) throw Exception(json['error'] ?? 'Query failed');
    return json;
  }

  Future<List<RagDocument>> listDocuments() async {
    final res = await http.get(
        Uri.parse('$kBaseUrl/documents/?session_id=$sessionId'));
    final json = jsonDecode(res.body);
    return (json['documents'] as List)
        .map((e) => RagDocument.fromJson(e))
        .toList();
  }

  Future<void> deleteDocument(String docId) async {
    await http.delete(
        Uri.parse('$kBaseUrl/documents/$docId/?session_id=$sessionId'));
  }
}

// ─── Screen ──────────────────────────────────────────────────────────────────

class RagScreen extends StatefulWidget {
  const RagScreen({super.key});
  @override
  State<RagScreen> createState() => _RagScreenState();
}

class _RagScreenState extends State<RagScreen> {
  late final RagService _service;
  final _queryController  = TextEditingController();
  final _scrollController = ScrollController();
  final List<RagDocument>  _docs     = [];
  final List<ChatMessage>  _messages = [];
  bool _uploading = false;
  bool _thinking  = false;

  @override
  void initState() {
    super.initState();
    _service = RagService(sessionId: 'user_${DateTime.now().millisecondsSinceEpoch}');
  }

  // ── Upload ────────────────────────────────────────────────────────────────

  Future<void> _pickAndUpload() async {
    final result = await FilePicker.platform.pickFiles(
      allowMultiple: true,
      type: FileType.custom,
      allowedExtensions: ['txt', 'md', 'pdf', 'docx'],
    );
    if (result == null || result.files.isEmpty) return;

    setState(() => _uploading = true);
    try {
      final uploaded = await _service.uploadFiles(result.files);
      setState(() {
        for (final doc in uploaded) {
          _docs.removeWhere((d) => d.name == doc.name);
          _docs.add(doc);
        }
      });
      _showSnack('${uploaded.length} document(s) uploaded ✓');
    } catch (e) {
      // ✅ இதை சேருங்கள் — exact error காட்டும்
      print('UPLOAD ERROR: $e');
      _showSnack('Upload failed: $e', isError: true);
    } finally {
      setState(() => _uploading = false);
    }
  }

  Future<void> _deleteDoc(RagDocument doc) async {
    await _service.deleteDocument(doc.id);
    setState(() => _docs.remove(doc));
  }

  // ── Query ─────────────────────────────────────────────────────────────────

  Future<void> _sendQuery() async {
    final q = _queryController.text.trim();
    if (q.isEmpty || _thinking) return;
    if (_docs.isEmpty) {
      _showSnack('Please upload a document first', isError: true);
      return;
    }

    setState(() {
      _messages.add(ChatMessage(text: q, isUser: true));
      _thinking = true;
      _queryController.clear();
    });
    _scrollToBottom();

    try {
      final result  = await _service.query(q);
      final answer  = result['answer'] as String;
      final sources = (result['sources'] as List)
          .map((s) => s['doc_name'] as String)
          .toSet()
          .toList();

      setState(() => _messages.add(
          ChatMessage(text: answer, isUser: false, sources: sources)));
    } catch (e) {
      setState(() => _messages.add(
          ChatMessage(text: 'Error: $e', isUser: false)));
    } finally {
      setState(() => _thinking = false);
      _scrollToBottom();
    }
  }

  void _scrollToBottom() {
    Future.delayed(const Duration(milliseconds: 100), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _showSnack(String msg, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: isError ? Colors.red.shade700 : Colors.green.shade700,
      behavior: SnackBarBehavior.floating,
    ));
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        title: const Text('RAG Assistant',
            style: TextStyle(fontWeight: FontWeight.w600)),
        backgroundColor: const Color(0xFF1A73E8),
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.upload_file),
            tooltip: 'Upload document',
            onPressed: _uploading ? null : _pickAndUpload,
          ),
        ],
      ),
      body: Column(
        children: [
          // ── Document chips bar ──────────────────────────────────────────
          if (_docs.isNotEmpty)
            Container(
              color: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: SizedBox(
                height: 36,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: _docs.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 6),
                  itemBuilder: (_, i) {
                    final doc = _docs[i];
                    return Chip(
                      avatar: const Icon(Icons.description, size: 14),
                      label: Text(doc.name,
                          style: const TextStyle(fontSize: 12)),
                      deleteIcon:
                      const Icon(Icons.close, size: 14),
                      onDeleted: () => _deleteDoc(doc),
                      backgroundColor:
                      const Color(0xFFE8F0FE),
                      padding: EdgeInsets.zero,
                      materialTapTargetSize:
                      MaterialTapTargetSize.shrinkWrap,
                    );
                  },
                ),
              ),
            ),

          // ── Upload loading indicator ────────────────────────────────────
          if (_uploading) const LinearProgressIndicator(),

          // ── Chat messages ───────────────────────────────────────────────
          Expanded(
            child: _messages.isEmpty
                ? _buildEmptyState()
                : ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.all(16),
              itemCount: _messages.length + (_thinking ? 1 : 0),
              itemBuilder: (_, i) {
                if (i == _messages.length) return _buildThinkingBubble();
                return _buildMessageBubble(_messages[i]);
              },
            ),
          ),

          // ── Input bar ───────────────────────────────────────────────────
          _buildInputBar(),
        ],
      ),
    );
  }

  Widget _buildEmptyState() => Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.chat_bubble_outline,
            size: 64, color: Colors.grey.shade300),
        const SizedBox(height: 16),
        Text('Upload a document & ask anything',
            style: TextStyle(
                color: Colors.grey.shade500, fontSize: 15)),
      ],
    ),
  );

  Widget _buildMessageBubble(ChatMessage msg) {
    final isUser = msg.isUser;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisAlignment:
        isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isUser)
            const CircleAvatar(
              radius: 16,
              backgroundColor: Color(0xFF1A73E8),
              child: Icon(Icons.smart_toy, size: 16, color: Colors.white),
            ),
          const SizedBox(width: 8),
          Flexible(
            child: Column(
              crossAxisAlignment: isUser
                  ? CrossAxisAlignment.end
                  : CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: isUser
                        ? const Color(0xFF1A73E8)
                        : Colors.white,
                    borderRadius: BorderRadius.only(
                      topLeft:     const Radius.circular(16),
                      topRight:    const Radius.circular(16),
                      bottomLeft:  Radius.circular(isUser ? 16 : 4),
                      bottomRight: Radius.circular(isUser ? 4  : 16),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Text(
                    msg.text,
                    style: TextStyle(
                      color: isUser ? Colors.white : Colors.black87,
                      fontSize: 14,
                      height: 1.5,
                    ),
                  ),
                ),
                if (msg.sources.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Wrap(
                    spacing: 4,
                    children: msg.sources
                        .map((s) => Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: const Color(0xFFE8F0FE),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.source,
                              size: 11,
                              color: Color(0xFF1A73E8)),
                          const SizedBox(width: 3),
                          Text(s,
                              style: const TextStyle(
                                  fontSize: 11,
                                  color: Color(0xFF1A73E8))),
                        ],
                      ),
                    ))
                        .toList(),
                  ),
                ],
                const SizedBox(height: 2),
                Text(
                  '${msg.time.hour.toString().padLeft(2, '0')}:${msg.time.minute.toString().padLeft(2, '0')}',
                  style: TextStyle(
                      fontSize: 10, color: Colors.grey.shade400),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          if (isUser)
            const CircleAvatar(
              radius: 16,
              backgroundColor: Color(0xFFE8F0FE),
              child: Icon(Icons.person, size: 16, color: Color(0xFF1A73E8)),
            ),
        ],
      ),
    );
  }

  Widget _buildThinkingBubble() => Row(
    children: [
      const CircleAvatar(
        radius: 16,
        backgroundColor: Color(0xFF1A73E8),
        child: Icon(Icons.smart_toy, size: 16, color: Colors.white),
      ),
      const SizedBox(width: 8),
      Container(
        padding:
        const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 4,
                offset: const Offset(0, 2)),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(3, (i) => _Dot(delay: i * 200)),
        ),
      ),
    ],
  );

  Widget _buildInputBar() => Container(
    color: Colors.white,
    padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
    child: Row(
      children: [
        Expanded(
          child: TextField(
            controller: _queryController,
            maxLines: null,
            textInputAction: TextInputAction.send,
            onSubmitted: (_) => _sendQuery(),
            decoration: InputDecoration(
              hintText: 'Ask about your documents...',
              hintStyle:
              TextStyle(color: Colors.grey.shade400, fontSize: 14),
              filled: true,
              fillColor: const Color(0xFFF5F5F5),
              contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16, vertical: 10),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(24),
                borderSide: BorderSide.none,
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          child: FloatingActionButton.small(
            onPressed: _thinking ? null : _sendQuery,
            backgroundColor: const Color(0xFF1A73E8),
            elevation: 0,
            child: Icon(
              _thinking ? Icons.hourglass_top : Icons.send,
              size: 18,
              color: Colors.white,
            ),
          ),
        ),
      ],
    ),
  );
}

// ─── Typing animation dot ─────────────────────────────────────────────────────

class _Dot extends StatefulWidget {
  final int delay;
  const _Dot({required this.delay});
  @override
  State<_Dot> createState() => _DotState();
}

class _DotState extends State<_Dot> with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double>   _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 600))
      ..repeat(reverse: true);
    _anim = Tween<double>(begin: 0, end: -6).animate(CurvedAnimation(
        parent: _ctrl, curve: Curves.easeInOut));
    Future.delayed(Duration(milliseconds: widget.delay), () {
      if (mounted) _ctrl.forward();
    });
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _anim,
    builder: (_, __) => Transform.translate(
      offset: Offset(0, _anim.value),
      child: Container(
        width: 7, height: 7,
        margin: const EdgeInsets.symmetric(horizontal: 2),
        decoration: const BoxDecoration(
            color: Color(0xFF1A73E8), shape: BoxShape.circle),
      ),
    ),
  );
}

// ─── Usage in your app ────────────────────────────────────────────────────────
//
// Navigator.push(context,
//   MaterialPageRoute(builder: (_) => const RagScreen()));
//
// OR add to your routes:
// '/rag': (context) => const RagScreen(),