import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'HomeScreen.dart';
import 'SignupScreen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  final prefs = await SharedPreferences.getInstance();
  final isDark = prefs.getBool('dark_mode') ?? false;
  runApp(OmegaApp(isDark: isDark));
}

class OmegaApp extends StatefulWidget {
  final bool isDark;
  const OmegaApp({super.key, required this.isDark});

  static _OmegaAppState? of(BuildContext context) =>
      context.findAncestorStateOfType<_OmegaAppState>();

  @override
  State<OmegaApp> createState() => _OmegaAppState();
}

class _OmegaAppState extends State<OmegaApp> {
  late bool isDark;

  @override
  void initState() {
    super.initState();
    isDark = widget.isDark;
  }

  void toggleDark(bool val) async {
    setState(() => isDark = val);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('dark_mode', val);
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      themeMode: isDark ? ThemeMode.dark : ThemeMode.light,
      theme: ThemeData(
        colorSchemeSeed: const Color(0xFF4F7EA6),
        brightness: Brightness.light,
      ),
      darkTheme: ThemeData(
        colorSchemeSeed: const Color(0xFF4F7EA6),
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF121212),
        cardColor: const Color(0xFF1E1E1E),
        drawerTheme: const DrawerThemeData(
          backgroundColor: Color(0xFF1E1E1E),
        ),
      ),
      home: const OmegaHome(),
    );
  }
}

class OmegaHome extends StatelessWidget {
  const OmegaHome({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? const Color(0xFF121212) : const Color(0xFFAACBE5);
    final textColor = isDark ? Colors.white : Colors.black;
    final subTextColor = isDark ? Colors.white38 : Colors.black38;

    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        color: bgColor,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 40),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [

            // ── LOGO ──────────────────────────────
            Padding(
              padding: const EdgeInsets.only(top: 40, left: 20),
              child: Row(
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
            ),

            // ── CENTER CONTENT ────────────────────
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text("Think smarter.",
                        style: TextStyle(
                          fontSize: 25,
                          color: textColor,
                          fontWeight: FontWeight.w900,
                        )),
                    const SizedBox(height: 4),
                    Text("Work faster.",
                        style: TextStyle(
                          fontSize: 25,
                          color: textColor,
                          fontWeight: FontWeight.w900,
                        )),
                    const SizedBox(height: 16),
                    Text(
                      "Collaborate, analyze and build faster - all in one intelligent AI workspace.",
                      style: TextStyle(fontSize: 14, color: subTextColor),
                    ),

                    SizedBox(height: MediaQuery.of(context).size.height * 0.06),

                    // Get Started
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF3F6F9C),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        onPressed: () {
                          Navigator.pushReplacement(
                            context,
                            MaterialPageRoute(
                              builder: (context) =>
                              const HomeScreen(isGuest: true),
                            ),
                          );
                        },
                        child: const Text("Get started",
                            style:
                            TextStyle(fontSize: 16, color: Colors.white)),
                      ),
                    ),

                    SizedBox(height: MediaQuery.of(context).size.height * 0.03),

                    // Sign Up
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: TextButton(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const SignupScreen(),
                            ),
                          );
                        },
                        style: TextButton.styleFrom(
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                            side: const BorderSide(
                              color: Color(0xFF3F6F9C),
                              width: 1.5,
                            ),
                          ),
                        ),
                        child: const Text("Sign Up",
                            style: TextStyle(
                              fontSize: 15,
                              color: Color(0xFF3F6F9C),
                            )),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // ── FOOTER ───────────────────────────
            Padding(
              padding: const EdgeInsets.only(bottom: 20),
              child: Center(
                child: Text(
                  "No credit card required. Privacy Policy",
                  style: TextStyle(fontSize: 12, color: subTextColor),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}