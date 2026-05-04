import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'main.dart';
import 'ProfileEditScreen.dart';

class SettingsScreen extends StatefulWidget {
  final bool isGuest;
  const SettingsScreen({super.key, this.isGuest = false});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  // ── Cyan theme (matches NewChatScreen) ──
  static const kCyan        = Color(0xFF1BA8D4);
  static const kCyanDark    = Color(0xFF1890B8);
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
  static const kDarkSub     = Color(0xFF8899AA);

  bool darkMode = false;
  bool notifications = true;
  String selectedLanguage = "English";
  String selectedModel = "Llama 3.1 8B";

  int totalMessages = 0;
  int totalChats = 0;
  int totalWords = 0;
  int totalAIReplies = 0;

  @override
  void initState() {
    super.initState();
    _loadSettings();
    _loadUsageStats();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      darkMode = prefs.getBool('dark_mode') ?? false;
      notifications = prefs.getBool('notifications') ?? true;
      selectedLanguage = prefs.getString('selected_language') ?? 'English';
      selectedModel = prefs.getString('selected_model') ?? 'Llama 3.1 8B';
    });
  }

  Future<void> _loadUsageStats() async {
    final prefs = await SharedPreferences.getInstance();
    final user = FirebaseAuth.instance.currentUser;
    final sessionKey = 'sessions_${user?.uid ?? 'guest'}';
    final saved = prefs.getString(sessionKey);
    int msgs = 0, chats = 0, words = 0, aiReplies = 0;
    if (saved != null) {
      final List sessions = jsonDecode(saved);
      chats = sessions.length;
      for (final session in sessions) {
        final messages = session['messages'] as List? ?? [];
        msgs += messages.length;
        for (final msg in messages) {
          final text = (msg['text'] ?? '').toString();
          words += text.split(' ').where((w) => w.isNotEmpty).length;
          if (msg['isMe'] == false) aiReplies++;
        }
      }
    }
    setState(() {
      totalMessages = msgs; totalChats = chats;
      totalWords = words; totalAIReplies = aiReplies;
    });
  }

  Future<void> _showLogoutDialog() async {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: isDark ? kDarkCard : kBgWhite,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(widget.isGuest ? "Exit Guest Mode?" : "Log Out?",
            style: TextStyle(color: isDark ? Colors.white : kTextPrimary, fontWeight: FontWeight.bold)),
        content: Text(
          widget.isGuest ? "Are you sure you want to exit guest mode?" : "Are you sure you want to log out?",
          style: TextStyle(color: isDark ? kDarkSub : kTextSub),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false),
              child: const Text("No", style: TextStyle(color: kCyan, fontWeight: FontWeight.w600))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
            onPressed: () => Navigator.pop(context, true),
            child: const Text("Yes", style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      if (!widget.isGuest) await FirebaseAuth.instance.signOut();
      Navigator.of(context).pushNamedAndRemoveUntil('/', (route) => false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor     = isDark ? kDarkBg    : kBgWhite;
    final cardColor   = isDark ? kDarkCard  : kBgWhite;
    final textColor   = isDark ? Colors.white : kTextPrimary;
    final subColor    = isDark ? kDarkSub   : kTextSub;
    final borderColor = isDark ? kDarkBorder : kBorderLight;

    final user = FirebaseAuth.instance.currentUser;
    final displayName = widget.isGuest ? "Guest User"
        : (user?.displayName ?? user?.email?.split('@')[0] ?? "User");
    final email = widget.isGuest ? "guest@omega.ai" : (user?.email ?? "guest@omega.ai");
    final firstLetter = displayName.isNotEmpty ? displayName[0].toUpperCase() : "G";

    final List<Map<String, String>> models = [
      {"name": "Llama 3.1 8B",    "desc": "Fast & efficient",          "icon": "⚡", "tag": "Fast"},
      {"name": "Llama 3.3 70B",   "desc": "Smart & powerful",          "icon": "🧠", "tag": "Smart"},
      {"name": "DeepSeek R1 70B", "desc": "Best for math & reasoning", "icon": "🔬", "tag": "Reasoning"},
      {"name": "Gemma 2 9B",      "desc": "Balanced & creative",       "icon": "🎯", "tag": "Balanced"},
      {"name": "Mixtral 8x7B",    "desc": "Long documents & context",  "icon": "📚", "tag": "Long Context"},
    ];

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
        systemNavigationBarColor: bgColor,
      ),
      child: Scaffold(
        backgroundColor: bgColor,
        appBar: AppBar(
          backgroundColor: bgColor,
          elevation: 0,
          surfaceTintColor: Colors.transparent,
          leading: IconButton(
            icon: Icon(Icons.arrow_back_ios_new_rounded, color: textColor, size: 20),
            onPressed: () => Navigator.pop(context),
          ),
          title: Row(children: [
            Container(width: 28, height: 28,
                decoration: BoxDecoration(color: kCyan, borderRadius: BorderRadius.circular(7)),
                child: const Center(child: Text("Ω", style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold)))),
            const SizedBox(width: 8),
            Text("Settings", style: TextStyle(color: textColor, fontWeight: FontWeight.bold, fontSize: 18)),
          ]),
          bottom: PreferredSize(preferredSize: const Size.fromHeight(1),
              child: Divider(height: 1, color: borderColor)),
        ),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [

            // ── PROFILE CARD ──
            GestureDetector(
              onTap: () async {
                if (!widget.isGuest) {
                  final updated = await Navigator.push(context, MaterialPageRoute(builder: (_) => const ProfileEditScreen()));
                  if (updated == true) setState(() {});
                }
              },
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: isDark ? kDarkCard : kCardBg,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: isDark ? kDarkBorder : kCardBorder),
                ),
                child: Row(children: [
                  CircleAvatar(radius: 28, backgroundColor: kCyan,
                      child: Text(firstLetter, style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold))),
                  const SizedBox(width: 14),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(displayName, style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: textColor)),
                    Text(email, style: const TextStyle(color: kTextMuted, fontSize: 12), overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(color: kCyan.withOpacity(0.1), borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: kCyan.withOpacity(0.3))),
                      child: Text(widget.isGuest ? "Guest" : "Free Plan",
                          style: const TextStyle(color: kCyan, fontSize: 11, fontWeight: FontWeight.w600)),
                    ),
                  ])),
                  if (!widget.isGuest) const Icon(Icons.chevron_right, color: kTextMuted),
                ]),
              ),
            ),

            const SizedBox(height: 20),

            // ── USAGE STATS ──
            _sectionTitle("Usage Stats", subColor),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: cardColor, borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: borderColor)),
              child: Column(children: [
                Row(children: [
                  Expanded(child: _statCard(icon: Icons.chat_bubble_outline, label: "Total Chats", value: totalChats.toString(), color: kCyan, isDark: isDark)),
                  const SizedBox(width: 12),
                  Expanded(child: _statCard(icon: Icons.message_outlined, label: "Messages", value: totalMessages.toString(), color: const Color(0xFF2B9348), isDark: isDark)),
                ]),
                const SizedBox(height: 12),
                Row(children: [
                  Expanded(child: _statCard(icon: Icons.smart_toy_outlined, label: "AI Replies", value: totalAIReplies.toString(), color: const Color(0xFF533483), isDark: isDark)),
                  const SizedBox(width: 12),
                  Expanded(child: _statCard(icon: Icons.text_fields, label: "Total Words",
                      value: totalWords > 999 ? '${(totalWords / 1000).toStringAsFixed(1)}k' : totalWords.toString(),
                      color: const Color(0xFFB5451B), isDark: isDark)),
                ]),
                const SizedBox(height: 14),
                Container(
                  width: double.infinity, padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(color: kCyan.withOpacity(0.08), borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: kCyan.withOpacity(0.2))),
                  child: Row(children: [
                    const Icon(Icons.token, color: kCyan, size: 20),
                    const SizedBox(width: 10),
                    Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text("~${(totalWords * 1.3).toInt()} tokens used",
                          style: const TextStyle(color: kCyan, fontWeight: FontWeight.bold, fontSize: 14)),
                      Text("Estimated based on word count", style: TextStyle(color: subColor, fontSize: 11)),
                    ]),
                  ]),
                ),
              ]),
            ),

            const SizedBox(height: 20),

            // ── GENERAL ──
            _sectionTitle("General", subColor),
            _tile(
              icon: Icons.language_rounded, title: "Language",
              cardColor: cardColor, textColor: textColor, borderColor: borderColor,
              trailing: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(color: kCyan.withOpacity(0.1), borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: kCyan.withOpacity(0.3))),
                child: Text(selectedLanguage, style: const TextStyle(color: kCyan, fontSize: 12, fontWeight: FontWeight.w600)),
              ),
              onTap: () {
                showDialog(
                  context: context,
                  builder: (_) => SimpleDialog(
                    backgroundColor: cardColor,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    title: Text("Select Language", style: TextStyle(color: textColor, fontWeight: FontWeight.bold)),
                    children: ["English", "Tamil", "Hindi", "Spanish"].map((lang) {
                      final isSelected = lang == selectedLanguage;
                      return SimpleDialogOption(
                        onPressed: () async {
                          setState(() => selectedLanguage = lang);
                          final prefs = await SharedPreferences.getInstance();
                          await prefs.setString('selected_language', lang);
                          Navigator.pop(context); // Close dialog
                          Navigator.pop(context); // Close settings → _loadLanguage() auto call
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          child: Row(children: [
                            Icon(Icons.language_rounded, color: isSelected ? kCyan : kTextMuted, size: 18),
                            const SizedBox(width: 10),
                            Text(lang, style: TextStyle(color: isSelected ? kCyan : textColor,
                                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal)),
                            const Spacer(),
                            if (isSelected) const Icon(Icons.check_circle, color: kCyan, size: 18),
                          ]),
                        ),
                      );
                    }).toList(),
                  ),
                );
              },
            ),
            _tile(
              icon: Icons.dark_mode_rounded, title: "Dark Mode",
              cardColor: cardColor, textColor: textColor, borderColor: borderColor,
              trailing: Switch(value: darkMode, activeColor: kCyan,
                  onChanged: (val) { setState(() => darkMode = val); OmegaApp.of(context)?.toggleDark(val); }),
              onTap: () { setState(() => darkMode = !darkMode); OmegaApp.of(context)?.toggleDark(darkMode); },
            ),
            _tile(
              icon: Icons.notifications_rounded, title: "Notifications",
              cardColor: cardColor, textColor: textColor, borderColor: borderColor,
              trailing: Switch(value: notifications, activeColor: kCyan,
                  onChanged: (val) async {
                    setState(() => notifications = val);
                    final prefs = await SharedPreferences.getInstance();
                    await prefs.setBool('notifications', val);
                    if (val) {
                      await FirebaseMessaging.instance.requestPermission();
                      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Notifications enabled ✅")));
                    } else {
                      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Notifications disabled 🔕")));
                    }
                  }),
              onTap: () async {
                final newVal = !notifications;
                setState(() => notifications = newVal);
                final prefs = await SharedPreferences.getInstance();
                await prefs.setBool('notifications', newVal);
              },
            ),

            const SizedBox(height: 20),

            // ── AI SETTINGS ──
            _sectionTitle("AI Settings", subColor),
            Container(
              margin: const EdgeInsets.only(bottom: 8),
              decoration: BoxDecoration(color: cardColor, borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: borderColor)),
              child: ListTile(
                leading: Container(width: 36, height: 36,
                    decoration: BoxDecoration(color: kCyan.withOpacity(0.1), borderRadius: BorderRadius.circular(9)),
                    child: const Icon(Icons.memory_rounded, color: kCyan, size: 20)),
                title: Text("AI Model", style: TextStyle(color: textColor, fontWeight: FontWeight.w500)),
                trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(color: kCyan.withOpacity(0.1), borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: kCyan.withOpacity(0.3))),
                    child: Text(selectedModel, style: const TextStyle(color: kCyan, fontSize: 11, fontWeight: FontWeight.w600)),
                  ),
                  const SizedBox(width: 4),
                  const Icon(Icons.expand_more_rounded, color: kTextMuted),
                ]),
                onTap: () {
                  showModalBottomSheet(
                    context: context, backgroundColor: Colors.transparent,
                    builder: (_) => Container(
                      padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
                      decoration: BoxDecoration(color: cardColor, borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                          border: Border(top: BorderSide(color: borderColor))),
                      child: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
                        Container(width: 40, height: 4, margin: const EdgeInsets.only(bottom: 16),
                            decoration: BoxDecoration(color: borderColor, borderRadius: BorderRadius.circular(2))),
                        Text("Select AI Model", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: textColor)),
                        const SizedBox(height: 4),
                        Text("All models are free via Groq", style: TextStyle(fontSize: 12, color: subColor)),
                        const SizedBox(height: 16),
                        ...models.map((m) {
                          final isSelected = selectedModel == m["name"];
                          return GestureDetector(
                            onTap: () async {
                              setState(() => selectedModel = m["name"]!);
                              final prefs = await SharedPreferences.getInstance();
                              await prefs.setString('selected_model', m["name"]!);
                              Navigator.pop(context);
                              if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                                content: Row(children: [
                                  Text(m["icon"]!, style: const TextStyle(fontSize: 16)),
                                  const SizedBox(width: 8),
                                  Text("${m["name"]} selected"),
                                ]),
                                backgroundColor: kCyan, behavior: SnackBarBehavior.floating,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                duration: const Duration(seconds: 2),
                              ));
                            },
                            child: Container(
                              margin: const EdgeInsets.only(bottom: 10),
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                              decoration: BoxDecoration(
                                color: isSelected ? kCyan.withOpacity(0.08) : Colors.transparent,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: isSelected ? kCyan : borderColor, width: isSelected ? 1.5 : 1),
                              ),
                              child: Row(children: [
                                Text(m["icon"]!, style: const TextStyle(fontSize: 22)),
                                const SizedBox(width: 12),
                                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                  Text(m["name"]!, style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14,
                                      color: isSelected ? kCyan : textColor)),
                                  Text(m["desc"]!, style: TextStyle(fontSize: 11, color: subColor)),
                                ])),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: isSelected ? kCyan.withOpacity(0.12) : borderColor.withOpacity(0.5),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(m["tag"]!, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600,
                                      color: isSelected ? kCyan : subColor)),
                                ),
                                if (isSelected) ...[
                                  const SizedBox(width: 8),
                                  const Icon(Icons.check_circle_rounded, color: kCyan, size: 20),
                                ],
                              ]),
                            ),
                          );
                        }).toList(),
                      ])),
                    ),
                  );
                },
              ),
            ),

            _tile(
              icon: Icons.delete_sweep_rounded, title: "Clear All Chats",
              cardColor: cardColor, textColor: textColor, borderColor: borderColor,
              trailing: const Icon(Icons.chevron_right_rounded, color: kTextMuted),
              onTap: () {
                showDialog(context: context, builder: (_) => AlertDialog(
                  backgroundColor: cardColor,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  title: Text("Clear All Chats", style: TextStyle(color: textColor, fontWeight: FontWeight.bold)),
                  content: Text("Are you sure? This cannot be undone.", style: TextStyle(color: subColor)),
                  actions: [
                    TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel", style: TextStyle(color: kCyan))),
                    TextButton(
                      onPressed: () async {
                        final prefs = await SharedPreferences.getInstance();
                        final user = FirebaseAuth.instance.currentUser;
                        final sessionKey = 'sessions_${user?.uid ?? 'guest'}';
                        await prefs.remove(sessionKey);
                        Navigator.pop(context);
                        _loadUsageStats();
                        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("All chats cleared!")));
                      },
                      child: const Text("Clear", style: TextStyle(color: Colors.red)),
                    ),
                  ],
                ));
              },
            ),

            const SizedBox(height: 20),

            // ── ABOUT ──
            _sectionTitle("About", subColor),
            _tile(icon: Icons.info_outline_rounded, title: "App Version", cardColor: cardColor, textColor: textColor, borderColor: borderColor,
                trailing: Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(color: kCyan.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                    child: const Text("1.0.0", style: TextStyle(color: kCyan, fontSize: 12, fontWeight: FontWeight.w600))),
                onTap: () {}),
            _tile(icon: Icons.privacy_tip_outlined, title: "Privacy Policy", cardColor: cardColor, textColor: textColor, borderColor: borderColor,
                trailing: const Icon(Icons.chevron_right_rounded, color: kTextMuted), onTap: () {}),
            _tile(icon: Icons.star_outline_rounded, title: "Rate App", cardColor: cardColor, textColor: textColor, borderColor: borderColor,
                trailing: const Icon(Icons.chevron_right_rounded, color: kTextMuted), onTap: () {}),

            const SizedBox(height: 20),

            // ── LOGOUT ──
            Container(
              decoration: BoxDecoration(color: cardColor, borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.red.withOpacity(0.2))),
              child: ListTile(
                leading: Container(width: 36, height: 36,
                    decoration: BoxDecoration(color: Colors.red.withOpacity(0.1), borderRadius: BorderRadius.circular(9)),
                    child: Icon(widget.isGuest ? Icons.exit_to_app : Icons.logout_rounded, color: Colors.red, size: 20)),
                title: Text(widget.isGuest ? "Exit Guest Mode" : "Log Out",
                    style: const TextStyle(color: Colors.red, fontWeight: FontWeight.w600)),
                onTap: _showLogoutDialog,
              ),
            ),

            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }

  Widget _sectionTitle(String title, Color color) {
    return Padding(
      padding: const EdgeInsets.only(left: 2, bottom: 8),
      child: Text(title.toUpperCase(), style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: color, letterSpacing: 1.0)),
    );
  }

  Widget _tile({
    required IconData icon, required String title,
    required Widget trailing, required Color cardColor,
    required Color textColor, required Color borderColor,
    required VoidCallback onTap,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(color: cardColor, borderRadius: BorderRadius.circular(12),
          border: Border.all(color: borderColor)),
      child: ListTile(
        leading: Container(width: 36, height: 36,
            decoration: BoxDecoration(color: kCyan.withOpacity(0.1), borderRadius: BorderRadius.circular(9)),
            child: Icon(icon, color: kCyan, size: 20)),
        title: Text(title, style: TextStyle(color: textColor, fontWeight: FontWeight.w500)),
        trailing: trailing,
        onTap: onTap,
      ),
    );
  }

  Widget _statCard({required IconData icon, required String label, required String value, required Color color, required bool isDark}) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: color.withOpacity(0.08), borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.2))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(height: 8),
        Text(value, style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: color)),
        const SizedBox(height: 2),
        Text(label, style: TextStyle(fontSize: 11, color: isDark ? kDarkSub : kTextSub)),
      ]),
    );
  }
}