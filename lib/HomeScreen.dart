import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'NewCHatScreen.dart';
import 'SettingsScreen.dart';
import 'main.dart';

class HomeScreen extends StatefulWidget {
  final bool isGuest;
  const HomeScreen({super.key, this.isGuest = false});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  final TextEditingController chatController = TextEditingController();
  late bool isGuest;

  @override
  void initState() {
    super.initState();
    isGuest = widget.isGuest;
  }

  @override
  void dispose() {
    chatController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? const Color(0xFF121212) : const Color(0xFFAACBE5);
    final cardColor = isDark ? const Color(0xFF1E1E1E) : Colors.white;
    final textColor = isDark ? Colors.white : Colors.black;
    final subTextColor = isDark ? Colors.white38 : Colors.black54;

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: bgColor,
      drawer: _buildDrawer(context, isDark, cardColor, textColor, subTextColor),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Column(
            children: [

              // ── TOP BAR ──────────────────────────
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Text("Ω",
                          style: TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                            color: textColor,
                          )),
                      const SizedBox(width: 6),
                      Text("OMEGA AI",
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w600,
                            color: textColor,
                          )),
                    ],
                  ),
                  IconButton(
                    icon: Icon(Icons.menu, size: 28, color: textColor),
                    onPressed: () => _scaffoldKey.currentState?.openDrawer(),
                  ),
                ],
              ),

              // ── CENTER CONTENT ────────────────────
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [

                    Padding(
                      padding: const EdgeInsets.only(left: 20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text("Ready when you are.",
                              style: TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.w600,
                                color: textColor,
                              )),
                          const SizedBox(height: 8),
                          Text(
                            "Start a conversation and let Omega follow.",
                            style: TextStyle(
                              fontSize: 14,
                              color: subTextColor,
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 30),

                    // ── FEATURE CARDS ──────────────────
                    Wrap(
                      spacing: 14,
                      runSpacing: 14,
                      alignment: WrapAlignment.center,
                      children: [
                        _FeatureCard(
                          icon: Icons.lightbulb_outline,
                          title: "Ideas",
                          subtitle: "Brainstorm",
                          cardColor: cardColor,
                          textColor: textColor,
                          onTap: () => Navigator.push(context,
                              MaterialPageRoute(builder: (_) => const NewChatScreen(
                                initialMessage: "Help me brainstorm ideas for: ",
                              ))),
                        ),
                        _FeatureCard(
                          icon: Icons.edit,
                          title: "Writing",
                          subtitle: "Create content",
                          cardColor: cardColor,
                          textColor: textColor,
                          onTap: () => Navigator.push(context,
                              MaterialPageRoute(builder: (_) => const NewChatScreen(
                                initialMessage: "Help me write: ",
                              ))),
                        ),
                        _FeatureCard(
                          icon: Icons.code,
                          title: "Code",
                          subtitle: "Build apps",
                          cardColor: cardColor,
                          textColor: textColor,
                          onTap: () => Navigator.push(context,
                              MaterialPageRoute(builder: (_) => const NewChatScreen(
                                initialMessage: "Write code for: ",
                              ))),
                        ),
                        _FeatureCard(
                          icon: Icons.bar_chart,
                          title: "Analyze",
                          subtitle: "Get insights",
                          cardColor: cardColor,
                          textColor: textColor,
                          onTap: () => Navigator.push(context,
                              MaterialPageRoute(builder: (_) => const NewChatScreen(
                                initialMessage: "Analyze this for me: ",
                              ))),
                        ),
                      ],
                    ),

                    const SizedBox(height: 40),

                    // ── NEW CHAT BUTTON ────────────────
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF4F7EA6),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        onPressed: () => Navigator.push(context,
                            MaterialPageRoute(
                                builder: (_) => const NewChatScreen())),
                        child: const Text("New Chat",
                            style: TextStyle(
                              fontSize: 16,
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                            )),
                      ),
                    ),
                  ],
                ),
              ),

              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Text(
                  "Nothing to configure. Just begin.",
                  style: TextStyle(fontSize: 12, color: subTextColor),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── DRAWER ───────────────────────────────────
  Drawer _buildDrawer(BuildContext context, bool isDark, Color cardColor,
      Color textColor, Color subTextColor) {
    final user = FirebaseAuth.instance.currentUser;
    final displayName = isGuest
        ? "Guest User"
        : (user?.displayName ?? user?.email?.split('@')[0] ?? "User");
    final email = isGuest ? "guest@omega.ai" : (user?.email ?? "");
    final firstLetter = displayName.isNotEmpty
        ? displayName[0].toUpperCase()
        : "G";
    final drawerBg = isDark ? const Color(0xFF1A1A1A) : const Color(0xFFEAF3FB);

    return Drawer(
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
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1,
                  )),
            ),

            // New Chat Button
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
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed: () {
                    Navigator.pop(context);
                    Navigator.push(context,
                        MaterialPageRoute(
                            builder: (_) => const NewChatScreen()));
                  },
                ),
              ),
            ),

            const SizedBox(height: 16),

            // History Title
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text("Recent Chats",
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                      color: subTextColor,
                      letterSpacing: 0.5,
                    )),
              ),
            ),

            const SizedBox(height: 8),

            // History List
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                children: [
                  _HistoryTile(
                    title: "Landing page ideas",
                    subtitle: "UI layout",
                    icon: Icons.lightbulb_outline,
                    textColor: textColor,
                  ),
                  _HistoryTile(
                    title: "Trading strategies",
                    subtitle: "Market analysis",
                    icon: Icons.trending_up,
                    textColor: textColor,
                  ),
                ],
              ),
            ),

            const Divider(height: 1),

            // Settings
            ListTile(
              leading: Icon(Icons.settings_outlined, color: subTextColor),
              title: Text("Settings",
                  style: TextStyle(
                      fontWeight: FontWeight.w500, color: textColor)),
              trailing: Icon(Icons.chevron_right, color: subTextColor),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(context,
                    MaterialPageRoute(
                        builder: (_) => const SettingsScreen()));
              },
            ),

            // Profile Card
            Container(
              margin: const EdgeInsets.fromLTRB(8, 0, 8, 8),
              decoration: BoxDecoration(
                color: cardColor,
                borderRadius: BorderRadius.circular(14),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: ListTile(
                leading: CircleAvatar(
                  radius: 20,
                  backgroundColor: const Color(0xFF4F7EA6),
                  child: Text(firstLetter,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      )),
                ),
                title: Text(displayName,
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                      color: textColor,
                    ),
                    overflow: TextOverflow.ellipsis),
                subtitle: Text(email,
                    style:
                    const TextStyle(fontSize: 11, color: Colors.grey),
                    overflow: TextOverflow.ellipsis),
                trailing: Icon(Icons.logout,
                    color: Colors.red, size: 20),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(context,
                      MaterialPageRoute(
                          builder: (_) => const SettingsScreen()));
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── FEATURE CARD ─────────────────────────────
class _FeatureCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color cardColor;
  final Color textColor;
  final VoidCallback? onTap;

  const _FeatureCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.cardColor,
    required this.textColor,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 150,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: const Color(0xFF4F7EA6), size: 28),
            const SizedBox(height: 10),
            Text(title,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                  color: textColor,
                )),
            const SizedBox(height: 4),
            Text(subtitle,
                style: const TextStyle(
                  fontSize: 12,
                  color: Colors.grey,
                )),
          ],
        ),
      ),
    );
  }
}

// ── HISTORY TILE ─────────────────────────────
class _HistoryTile extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color textColor;

  const _HistoryTile({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.textColor,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon, color: const Color(0xFF4F7EA6)),
      title: Text(title, style: TextStyle(color: textColor)),
      subtitle: Text(subtitle,
          style: const TextStyle(color: Colors.grey)),
    );
  }
}