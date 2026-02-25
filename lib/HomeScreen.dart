import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'NewCHatScreen.dart';

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
    isGuest = widget.isGuest; // ✅ SAFE
  }

  @override
  void dispose() {
    chatController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: const Color(0xFFAACBE5),
      drawer: _buildDrawer(context),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Column(
            children: [

              /// 🔹 TOP BAR
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: const [
                      Text(
                        "Ω",
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(width: 6),
                      Text(
                        "OMEGA AI",
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  IconButton(
                    icon: const Icon(Icons.menu, size: 28),
                    onPressed: () {
                      _scaffoldKey.currentState?.openDrawer();
                    },
                  ),
                ],
              ),

              /// 🔹 CENTER CONTENT
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [

                    Padding(
                      padding: const EdgeInsets.only(left: 20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: const [
                          Text(
                            "Ready when you are.",
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          SizedBox(height: 8),
                          Text(
                            "Start a conversation and let Omega follow.",
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.black54,
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 30),

                    Wrap(
                      spacing: 14,
                      runSpacing: 14,
                      alignment: WrapAlignment.center,
                       children: [_FeatureCard(
                         icon: Icons.lightbulb_outline,
                         title: "Ideas",
                         subtitle: "Brainstorm",
                         onTap: () {
                           Navigator.push(
                             context,
                             MaterialPageRoute(
                               builder: (_) => const NewChatScreen(
                                 initialMessage: "Help me brainstorm ideas for: ",
                               ),
                             ),
                           );
                         },
                       ),
                         _FeatureCard(
                           icon: Icons.edit,
                           title: "Writing",
                           subtitle: "Create content",
                           onTap: () {
                             Navigator.push(
                               context,
                               MaterialPageRoute(
                                 builder: (_) => const NewChatScreen(
                                   initialMessage: "Help me write: ",
                                 ),
                               ),
                             );
                           },
                         ),
                         _FeatureCard(
                           icon: Icons.code,
                           title: "Code",
                           subtitle: "Build apps",
                           onTap: () {
                             Navigator.push(
                               context,
                               MaterialPageRoute(
                                 builder: (_) => const NewChatScreen(
                                   initialMessage: "Write code for: ",
                                 ),
                               ),
                             );
                           },
                         ),
                         _FeatureCard(
                           icon: Icons.bar_chart,
                           title: "Analyze",
                           subtitle: "Get insights",
                           onTap: () {
                             Navigator.push(
                               context,
                               MaterialPageRoute(
                                 builder: (_) => const NewChatScreen(
                                   initialMessage: "Analyze this for me: ",
                                 ),
                               ),
                             );
                           },
                         ),],
                    ),

                    const SizedBox(height: 40),

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
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const NewChatScreen(),
                            ),
                          );
                        },
                        child: const Text(
                          "New Chat",
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const Padding(
                padding: EdgeInsets.only(bottom: 10),
                child: Text(
                  "Nothing to configure. Just begin.",
                  style: TextStyle(fontSize: 12, color: Colors.black54),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 🔹 DRAWER
  Drawer _buildDrawer(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return Drawer(
      child: SafeArea(
        child: Column(
          children: [

            /// 🔹 USER INFO
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  const CircleAvatar(
                    radius: 22,
                    child: Icon(Icons.person),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isGuest ? "Guest User" : "OMEGA",
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      Text(
                        isGuest ? "guest@omega.ai" : (user?.email ?? ""),
                        style: const TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            /// 🔹 NEW CHAT
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const NewChatScreen(),
                      ),
                    );
                  },
                  child: const Text("New Chat"),
                ),
              ),
            ),

            const SizedBox(height: 20),

            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  "History",
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.grey,
                  ),
                ),
              ),
            ),

            const SizedBox(height: 8),

            Expanded(
              child: ListView(
                children: const [
                  _HistoryTile(
                    title: "Landing page ideas",
                    subtitle: "UI layout",
                    icon: Icons.lightbulb_outline,
                  ),
                  _HistoryTile(
                    title: "Trading strategies",
                    subtitle: "Market analysis",
                    icon: Icons.trending_up,
                  ),
                ],
              ),
            ),

            const Divider(),

            ListTile(
              leading: const Icon(Icons.settings),
              title: const Text("Settings"),
              onTap: () {},
            ),

            ListTile(
              leading: const Icon(Icons.logout, color: Colors.red),
              title: const Text("Logout",
                  style: TextStyle(color: Colors.red)),
              onTap: () async {
                if (!isGuest) {
                  await FirebaseAuth.instance.signOut();
                }
                Navigator.pop(context);
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _FeatureCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback? onTap; // ✅ This line irukka check pannu

  const _FeatureCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.onTap, // ✅ This line irukka check pannu
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap, // ✅ This line irukka check pannu
      child: Container(
        width: 150,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
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
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
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
/// 🔹 HISTORY TILE
class _HistoryTile extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;

  const _HistoryTile({
    required this.title,
    required this.subtitle,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon, color: Colors.blueGrey),
      title: Text(title),
      subtitle: Text(subtitle),
    );
  }

}
