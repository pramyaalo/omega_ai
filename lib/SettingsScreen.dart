import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'main.dart';

class SettingsScreen extends StatefulWidget {
  final bool isGuest;
  const SettingsScreen({super.key, this.isGuest = false});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool darkMode = false;
  bool notifications = true;
  String selectedLanguage = "English";

  // ✅ Usage Stats
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
    });
  }

  // ✅ Usage Stats calculate pannuvom
  Future<void> _loadUsageStats() async {
    final prefs = await SharedPreferences.getInstance();
    final user = FirebaseAuth.instance.currentUser;
    final sessionKey = 'sessions_${user?.uid ?? 'guest'}';
    final saved = prefs.getString(sessionKey);

    int msgs = 0;
    int chats = 0;
    int words = 0;
    int aiReplies = 0;

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
      totalMessages = msgs;
      totalChats = chats;
      totalWords = words;
      totalAIReplies = aiReplies;
    });
  }

  Future<void> _showLogoutDialog() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: Theme.of(context).brightness == Brightness.dark
            ? const Color(0xFF1E1E1E)
            : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          widget.isGuest ? "Exit Guest Mode?" : "Log Out?",
          style: TextStyle(
            color: Theme.of(context).brightness == Brightness.dark
                ? Colors.white
                : Colors.black,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Text(
          widget.isGuest
              ? "Are you sure you want to exit guest mode?"
              : "Are you sure you want to log out?",
          style: TextStyle(
            color: Theme.of(context).brightness == Brightness.dark
                ? Colors.white54
                : Colors.black54,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("No",
                style: TextStyle(color: Color(0xFF4F7EA6), fontWeight: FontWeight.w600)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text("Yes",
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
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
    final bgColor = isDark ? const Color(0xFF121212) : const Color(0xFFAACBE5);
    final cardColor = isDark ? const Color(0xFF1E1E1E) : Colors.white;
    final textColor = isDark ? Colors.white : Colors.black;
    final subTextColor = isDark ? Colors.white38 : Colors.black54;

    final user = FirebaseAuth.instance.currentUser;
    final displayName = widget.isGuest
        ? "Guest User"
        : (user?.displayName ?? user?.email?.split('@')[0] ?? "User");
    final email = widget.isGuest ? "guest@omega.ai" : (user?.email ?? "guest@omega.ai");
    final firstLetter = displayName.isNotEmpty ? displayName[0].toUpperCase() : "G";

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle(
        statusBarColor: bgColor,
        statusBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
        systemNavigationBarColor: bgColor,
      ),
      child: Scaffold(
        backgroundColor: bgColor,
        appBar: AppBar(
          backgroundColor: bgColor,
          elevation: 0,
          leading: IconButton(
            icon: Icon(Icons.arrow_back, color: textColor),
            onPressed: () => Navigator.pop(context),
          ),
          title: Text("Settings",
              style: TextStyle(color: textColor, fontWeight: FontWeight.bold)),
        ),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [

            // ── PROFILE CARD ─────────────────────────
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: cardColor,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 30,
                    backgroundColor: const Color(0xFF4F7EA6),
                    child: Text(firstLetter,
                        style: const TextStyle(
                            color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(displayName,
                            style: TextStyle(
                                fontSize: 18, fontWeight: FontWeight.bold, color: textColor)),
                        Text(email,
                            style: const TextStyle(color: Colors.grey, fontSize: 12),
                            overflow: TextOverflow.ellipsis),
                        const SizedBox(height: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFF4F7EA6).withOpacity(0.1),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            widget.isGuest ? "Guest" : "Free Plan",
                            style: const TextStyle(
                                color: Color(0xFF4F7EA6),
                                fontSize: 11,
                                fontWeight: FontWeight.w600),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // ✅ USAGE STATS SECTION
            _sectionTitle("Usage Stats", subTextColor),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: cardColor,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                children: [
                  // ✅ Top row — Total Chats + Total Messages
                  Row(
                    children: [
                      Expanded(
                        child: _statCard(
                          icon: Icons.chat_bubble_outline,
                          label: "Total Chats",
                          value: totalChats.toString(),
                          color: const Color(0xFF4F7EA6),
                          isDark: isDark,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _statCard(
                          icon: Icons.message_outlined,
                          label: "Messages",
                          value: totalMessages.toString(),
                          color: const Color(0xFF2B9348),
                          isDark: isDark,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  // ✅ Bottom row — AI Replies + Words
                  Row(
                    children: [
                      Expanded(
                        child: _statCard(
                          icon: Icons.smart_toy_outlined,
                          label: "AI Replies",
                          value: totalAIReplies.toString(),
                          color: const Color(0xFF533483),
                          isDark: isDark,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _statCard(
                          icon: Icons.text_fields,
                          label: "Total Words",
                          value: totalWords > 999
                              ? '${(totalWords / 1000).toStringAsFixed(1)}k'
                              : totalWords.toString(),
                          color: const Color(0xFFB5451B),
                          isDark: isDark,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  // ✅ Tokens estimate (words * 1.3 approx)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFF4F7EA6).withOpacity(0.08),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFF4F7EA6).withOpacity(0.2)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.token, color: Color(0xFF4F7EA6), size: 20),
                        const SizedBox(width: 10),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              "~${(totalWords * 1.3).toInt()} tokens used",
                              style: const TextStyle(
                                  color: Color(0xFF4F7EA6),
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14),
                            ),
                            Text(
                              "Estimated based on word count",
                              style: TextStyle(color: subTextColor, fontSize: 11),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // ── GENERAL ──────────────────────────────
            _sectionTitle("General", subTextColor),
            _settingsTile(
              icon: Icons.language,
              title: "Language",
              cardColor: cardColor,
              textColor: textColor,
              trailing: Text(selectedLanguage, style: const TextStyle(color: Colors.grey)),
              onTap: () {
                showDialog(
                  context: context,
                  builder: (_) => SimpleDialog(
                    backgroundColor: cardColor,
                    title: Text("Select Language", style: TextStyle(color: textColor)),
                    children: ["English", "Tamil", "Hindi", "Spanish"]
                        .map((lang) => SimpleDialogOption(
                      child: Text(lang, style: TextStyle(color: textColor)),
                      onPressed: () async {
                        setState(() => selectedLanguage = lang);
                        final prefs = await SharedPreferences.getInstance();
                        await prefs.setString('selected_language', lang); // ✅ Save
                        Navigator.pop(context);
                      },
                    ))
                        .toList(),
                  ),
                );
              },
            ),
            _settingsTile(
              icon: Icons.dark_mode,
              title: "Dark Mode",
              cardColor: cardColor,
              textColor: textColor,
              trailing: Switch(
                value: darkMode,
                activeColor: const Color(0xFF4F7EA6),
                onChanged: (val) {
                  setState(() => darkMode = val);
                  OmegaApp.of(context)?.toggleDark(val);
                },
              ),
              onTap: () {
                setState(() => darkMode = !darkMode);
                OmegaApp.of(context)?.toggleDark(darkMode);
              },
            ),
            _settingsTile(
              icon: Icons.notifications,
              title: "Notifications",
              cardColor: cardColor,
              textColor: textColor,
              trailing: Switch(
                value: notifications,
                activeColor: const Color(0xFF4F7EA6),
                onChanged: (val) async {
                  setState(() => notifications = val);
                  final prefs = await SharedPreferences.getInstance();
                  await prefs.setBool('notifications', val);
                  if (val) {
                    await FirebaseMessaging.instance.requestPermission();
                    final token = await FirebaseMessaging.instance.getToken();
                    print("FCM Token: $token");
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text("Notifications enabled ✅")),
                    );
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text("Notifications disabled 🔕")),
                    );
                  }
                },
              ),
              onTap: () async {
                final newVal = !notifications;
                setState(() => notifications = newVal);
                final prefs = await SharedPreferences.getInstance();
                await prefs.setBool('notifications', newVal);
              },
            ),

            const SizedBox(height: 20),

            // ── AI SETTINGS ──────────────────────────
            _sectionTitle("AI Settings", subTextColor),
            _settingsTile(
              icon: Icons.memory,
              title: "AI Model",
              cardColor: cardColor,
              textColor: textColor,
              trailing: const Text("Llama 3.1", style: TextStyle(color: Colors.grey)),
              onTap: () {},
            ),
            _settingsTile(
              icon: Icons.history,
              title: "Clear All Chats",
              cardColor: cardColor,
              textColor: textColor,
              trailing: const Icon(Icons.chevron_right, color: Colors.grey),
              onTap: () {
                showDialog(
                  context: context,
                  builder: (_) => AlertDialog(
                    backgroundColor: cardColor,
                    title: Text("Clear All Chats", style: TextStyle(color: textColor)),
                    content: Text("Are you sure? This cannot be undone.",
                        style: TextStyle(color: subTextColor)),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text("Cancel"),
                      ),
                      TextButton(
                        onPressed: () async {
                          final prefs = await SharedPreferences.getInstance();
                          final user = FirebaseAuth.instance.currentUser;
                          final sessionKey = 'sessions_${user?.uid ?? 'guest'}';
                          await prefs.remove(sessionKey);
                          Navigator.pop(context);
                          // ✅ Stats refresh pannuvom
                          _loadUsageStats();
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text("All chats cleared!")),
                          );
                        },
                        child: const Text("Clear", style: TextStyle(color: Colors.red)),
                      ),
                    ],
                  ),
                );
              },
            ),

            const SizedBox(height: 20),

            // ── ABOUT ────────────────────────────────
            _sectionTitle("About", subTextColor),
            _settingsTile(
              icon: Icons.info_outline,
              title: "App Version",
              cardColor: cardColor,
              textColor: textColor,
              trailing: const Text("1.0.0", style: TextStyle(color: Colors.grey)),
              onTap: () {},
            ),
            _settingsTile(
              icon: Icons.privacy_tip_outlined,
              title: "Privacy Policy",
              cardColor: cardColor,
              textColor: textColor,
              trailing: const Icon(Icons.chevron_right, color: Colors.grey),
              onTap: () {},
            ),
            _settingsTile(
              icon: Icons.star_outline,
              title: "Rate App",
              cardColor: cardColor,
              textColor: textColor,
              trailing: const Icon(Icons.chevron_right, color: Colors.grey),
              onTap: () {},
            ),

            const SizedBox(height: 20),

            // ── LOGOUT ───────────────────────────────
            Container(
              decoration: BoxDecoration(
                color: cardColor,
                borderRadius: BorderRadius.circular(12),
              ),
              child: ListTile(
                leading: Icon(
                  widget.isGuest ? Icons.exit_to_app : Icons.logout,
                  color: Colors.red,
                ),
                title: Text(
                  widget.isGuest ? "Exit Guest Mode" : "Log Out",
                  style: const TextStyle(color: Colors.red, fontWeight: FontWeight.w600),
                ),
                onTap: _showLogoutDialog,
              ),
            ),

            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }

  // ✅ Stat Card Widget
  Widget _statCard({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
    required bool isDark,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: isDark ? Colors.white54 : Colors.black54,
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionTitle(String title, Color color) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Text(title,
          style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: color,
              letterSpacing: 0.5)),
    );
  }

  Widget _settingsTile({
    required IconData icon,
    required String title,
    required Widget trailing,
    required Color cardColor,
    required Color textColor,
    required VoidCallback onTap,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: ListTile(
        leading: Icon(icon, color: const Color(0xFF4F7EA6)),
        title: Text(title, style: TextStyle(color: textColor)),
        trailing: trailing,
        onTap: onTap,
      ),
    );
  }
}