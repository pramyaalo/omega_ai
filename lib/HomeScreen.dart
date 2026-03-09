import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle(
        statusBarColor: bgColor, // ✅ App color same
        statusBarIconBrightness:
        isDark ? Brightness.light : Brightness.dark, // ✅ Icons visible
        systemNavigationBarColor: bgColor,
      ),
      child: Scaffold(
        key: _scaffoldKey,
        backgroundColor: bgColor,
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
      ),
    );
  }

  // ── DRAWER ───────────────────────────────────

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