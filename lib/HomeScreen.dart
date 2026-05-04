import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'Costestimatorscreen.dart';
import 'NewCHatScreen.dart';
import 'SettingsScreen.dart';
import 'TemplateGeneratorScreen.dart';
import 'RoomDesignerScreen.dart';
import 'Videoaiscreen.dart';
import 'Wallmeasurementscreen.dart';

class HomeScreen extends StatefulWidget {
  final bool isGuest;
  const HomeScreen({super.key, this.isGuest = false});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with TickerProviderStateMixin {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  late bool isGuest;
  late AnimationController _fadeController;
  late Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    isGuest = widget.isGuest;
    _fadeController = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 600));
    _fadeAnim =
        CurvedAnimation(parent: _fadeController, curve: Curves.easeOut);
    _fadeController.forward();
  }

  @override
  void dispose() {
    _fadeController.dispose();
    super.dispose();
  }

  void _comingSoon(String feature) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final card = isDark ? const Color(0xFF1A2744) : Colors.white;
    final textColor = isDark ? Colors.white : const Color(0xFF1A1A2E);
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        padding: const EdgeInsets.all(28),
        decoration: BoxDecoration(
            color: card,
            borderRadius:
            const BorderRadius.vertical(top: Radius.circular(24))),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                  color: Colors.grey.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(2))),
          const SizedBox(height: 20),
          const Text("🚧", style: TextStyle(fontSize: 48)),
          const SizedBox(height: 12),
          Text("$feature — Coming Soon!",
              style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: textColor)),
          const SizedBox(height: 8),
          const Text("This feature is under development.\nStay tuned for updates! 🚀",
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey, fontSize: 13)),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                  colors: [Color(0xFF2B6CB8), Color(0xFF2BB5E8)],
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.transparent,
                  shadowColor: Colors.transparent,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
                child: const Text("Got it!",
                    style: TextStyle(fontWeight: FontWeight.w600)),
              ),
            ),
          ),
        ]),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // ✅ main.dart-மாதிரி exact colors
    final gradientTop    = isDark ? const Color(0xFF0D1B2A) : const Color(0xFFEBF5FB);
    final gradientBottom = isDark ? const Color(0xFF0A2540) : const Color(0xFFC5E3F5);
    final cardColor      = isDark ? const Color(0xFF1A2744) : Colors.white;
    final textColor      = isDark ? Colors.white : const Color(0xFF1A1A2E);
    final subTextColor   = isDark ? Colors.white38 : const Color(0xFF6B8CAE);

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
        systemNavigationBarColor: gradientBottom,
      ),
      child: Scaffold(
        key: _scaffoldKey,
        backgroundColor: Colors.transparent,
        body: Container(
          width: double.infinity,
          height: double.infinity,
          // ✅ Gradient bg
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [gradientTop, gradientBottom],
            ),
          ),
          child: SafeArea(
            child: FadeTransition(
              opacity: _fadeAnim,
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [

                      // ── TOP BAR ─────────────────────────────────
                      Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(children: [
                              // ✅ Cyan square icon
                              Container(
                                width: 36,
                                height: 36,
                                decoration: BoxDecoration(
                                  color: const Color(0xFF1B9ED4),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Center(
                                  child: Text("Ω",
                                      style: TextStyle(
                                          fontSize: 20,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.white)),
                                ),
                              ),
                              const SizedBox(width: 8),
                              // ✅ "Omega AI" cyan
                              const Text("Omega AI",
                                  style: TextStyle(
                                      fontSize: 20,
                                      fontWeight: FontWeight.w600,
                                      color: Color(0xFF1B9ED4))),
                            ]),
                            IconButton(
                              icon: Icon(Icons.settings_outlined, color: textColor),
                              onPressed: () => Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                      builder: (_) => const SettingsScreen())),
                            ),
                          ]),

                      const SizedBox(height: 16),

                      // ── GREETING ────────────────────────────────
                      Builder(builder: (context) {
                        final user = FirebaseAuth.instance.currentUser;
                        final name = user?.displayName ??
                            user?.email?.split('@')[0] ??
                            'there';
                        return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text("Hello, $name 👋",
                                  style: TextStyle(
                                      fontSize: 22,
                                      fontWeight: FontWeight.bold,
                                      color: textColor)),
                              const SizedBox(height: 4),
                              Text("What would you like to do today?",
                                  style:
                                  TextStyle(fontSize: 13, color: subTextColor)),
                            ]);
                      }),

                      const SizedBox(height: 20),

                      // ── NEW CHAT BANNER ──────────────────────────
                      GestureDetector(
                        onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (_) => const NewChatScreen())),
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 20, vertical: 16),
                          decoration: BoxDecoration(
                            // ✅ Updated gradient — matches button style
                            gradient: const LinearGradient(
                              colors: [Color(0xFF2B6CB8), Color(0xFF2BB5E8)],
                              begin: Alignment.centerLeft,
                              end: Alignment.centerRight,
                            ),
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: [
                              BoxShadow(
                                  color: const Color(0xFF1B9ED4).withOpacity(0.35),
                                  blurRadius: 12,
                                  offset: const Offset(0, 4))
                            ],
                          ),
                          child: Row(children: [
                            Container(
                              width: 44,
                              height: 44,
                              decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.15),
                                  shape: BoxShape.circle),
                              child: const Center(
                                  child: Text("Ω",
                                      style: TextStyle(
                                          fontSize: 22,
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold))),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                                child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Text("Start New Chat",
                                          style: TextStyle(
                                              fontSize: 16,
                                              fontWeight: FontWeight.bold,
                                              color: Colors.white)),
                                      Text("Ask anything to Omega AI",
                                          style: TextStyle(
                                              fontSize: 12,
                                              color: Colors.white.withOpacity(0.75))),
                                    ])),
                            const Icon(Icons.arrow_forward_ios_rounded,
                                color: Colors.white, size: 18),
                          ]),
                        ),
                      ),

                      const SizedBox(height: 24),

                      // ── FEATURES ────────────────────────────────
                      Text("Features",
                          style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              color: textColor)),
                      const SizedBox(height: 12),

                      // Row 1
                      Row(children: [
                        Expanded(
                            child: _bigFeatureCard(
                              emoji: '💬',
                              title: 'AI Chat',
                              subtitle: 'Ask anything',
                              color: const Color(0xFF1B9ED4),
                              cardColor: cardColor,
                              textColor: textColor,
                              onTap: () => Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                      builder: (_) => const NewChatScreen())),
                            )),
                        const SizedBox(width: 12),
                        Expanded(
                            child: _bigFeatureCard(
                              emoji: '📝',
                              title: 'Templates',
                              subtitle: 'Generate docs',
                              color: const Color(0xFF1A73E8),
                              cardColor: cardColor,
                              textColor: textColor,
                              onTap: () => Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                      builder: (_) =>
                                      const TemplateGeneratorScreen())),
                            )),
                      ]),

                      const SizedBox(height: 12),

                      // Row 2
                      Row(children: [
                        Expanded(
                            child: _bigFeatureCard(
                              emoji: '🏠',
                              title: 'Room Design',
                              subtitle: 'Interior AI',
                              color: const Color(0xFF2B9348),
                              cardColor: cardColor,
                              textColor: textColor,
                              onTap: () => Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                      builder: (_) => const RoomDesignerScreen())),
                            )),
                        const SizedBox(width: 12),
                        Expanded(
                            child: _bigFeatureCard(
                              emoji: '🎬',
                              title: 'Video AI',
                              subtitle: 'Describe & create',
                              color: const Color(0xFFE94560),
                              cardColor: cardColor,
                              textColor: textColor,
                              onTap: () => Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                      builder: (_) => const VideoAiScreen())),
                            )),
                      ]),

                      const SizedBox(height: 12),

                      // Row 3
                      Row(children: [
                        Expanded(
                            child: _bigFeatureCard(
                              emoji: '📏',
                              title: 'Wall Measure',
                              subtitle: 'Upload & detect',
                              color: const Color(0xFFFF6D00),
                              cardColor: cardColor,
                              textColor: textColor,
                              onTap: () => Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                      builder: (_) => const WallMeasurementScreen())),
                            )),
                        const SizedBox(width: 12),
                        Expanded(
                            child: _bigFeatureCard(
                              emoji: '💰',
                              title: 'Cost Estimator',
                              subtitle: 'Calculate budget',
                              color: const Color(0xFF9C27B0),
                              cardColor: cardColor,
                              textColor: textColor,
                              onTap: () => Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                      builder: (_) => const CostEstimatorScreen())),
                            )),
                      ]),

                      const SizedBox(height: 24),

                      // ── QUICK ACTIONS ────────────────────────────
                      Text("Quick Actions",
                          style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              color: textColor)),
                      const SizedBox(height: 12),

                      Row(children: [
                        Expanded(
                            child: _quickActionCard(Icons.lightbulb_outline,
                                'Ideas', 'Help me brainstorm ideas for: ', cardColor, textColor, subTextColor, context)),
                        const SizedBox(width: 10),
                        Expanded(
                            child: _quickActionCard(Icons.edit_rounded, 'Writing',
                                'Help me write: ', cardColor, textColor, subTextColor, context)),
                      ]),
                      const SizedBox(height: 10),
                      Row(children: [
                        Expanded(
                            child: _quickActionCard(Icons.code_rounded, 'Code',
                                'Write code for: ', cardColor, textColor, subTextColor, context)),
                        const SizedBox(width: 10),
                        Expanded(
                            child: _quickActionCard(Icons.bar_chart_rounded,
                                'Analyze', 'Analyze this for me: ', cardColor, textColor, subTextColor, context)),
                      ]),

                      const SizedBox(height: 20),

                      Center(
                          child: Text("Nothing to configure. Just begin.",
                              style:
                              TextStyle(fontSize: 12, color: subTextColor))),
                    ]),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _bigFeatureCard({
    required String emoji,
    required String title,
    required String subtitle,
    required Color color,
    required Color cardColor,
    required Color textColor,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: const Color(0xFF1DA1D6).withOpacity(0.08),
          ),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withOpacity(0.04),
                blurRadius: 8,
                offset: const Offset(0, 2))
          ],
        ),
        child: Row(children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
                color: color.withOpacity(0.12),
                borderRadius: BorderRadius.circular(12)),
            child: Center(
                child: Text(emoji, style: const TextStyle(fontSize: 20))),
          ),
          const SizedBox(width: 10),
          Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                            color: textColor),
                        overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 2),
                    Text(subtitle,
                        style: const TextStyle(fontSize: 10, color: Colors.grey),
                        overflow: TextOverflow.ellipsis),
                  ])),
        ]),
      ),
    );
  }

  Widget _quickActionCard(IconData icon, String label, String msg,
      Color cardColor, Color textColor, Color subColor, BuildContext context) {
    return GestureDetector(
      onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
              builder: (_) => NewChatScreen(initialMessage: msg))),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: const Color(0xFF1DA1D6).withOpacity(0.08),
          ),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withOpacity(0.04), blurRadius: 6)
          ],
        ),
        child: Row(children: [
          Icon(icon, color: const Color(0xFF1B9ED4), size: 20),
          const SizedBox(width: 8),
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(label,
                style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                    color: textColor)),
            Text('Tap to start',
                style: TextStyle(fontSize: 10, color: subColor)),
          ]),
        ]),
      ),
    );
  }
}