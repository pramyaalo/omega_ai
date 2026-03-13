import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'HomeScreen.dart';
import 'LoginScreen.dart';
import 'SignupScreen.dart';
import 'OnboardingScreen.dart'; // ✅

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  print("Background message: ${message.notification?.title}");
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();

  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

  await FirebaseMessaging.instance.requestPermission(
    alert: true,
    badge: true,
    sound: true,
  );

  final token = await FirebaseMessaging.instance.getToken();
  print("FCM Token: $token");

  FirebaseMessaging.onMessage.listen((RemoteMessage message) {
    print("Foreground message: ${message.notification?.title}");
  });

  final prefs = await SharedPreferences.getInstance();
  final isDark = prefs.getBool('dark_mode') ?? false;
  final onboardingDone = prefs.getBool('onboarding_done') ?? false; // ✅

  runApp(OmegaApp(isDark: isDark, onboardingDone: onboardingDone));
}

class OmegaApp extends StatefulWidget {
  final bool isDark;
  final bool onboardingDone; // ✅
  const OmegaApp({super.key, required this.isDark, required this.onboardingDone});

  static _OmegaAppState? of(BuildContext context) =>
      context.findAncestorStateOfType<_OmegaAppState>();

  @override
  State<OmegaApp> createState() => _OmegaAppState();
}

class _OmegaAppState extends State<OmegaApp> {
  late bool isDark;
  late bool onboardingDone; // ✅

  @override
  void initState() {
    super.initState();
    isDark = widget.isDark;
    onboardingDone = widget.onboardingDone; // ✅
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
        brightness: Brightness.light,
        scaffoldBackgroundColor: const Color(0xFFAACBE5),
        cardColor: Colors.white,
        colorSchemeSeed: const Color(0xFF4F7EA6),
        textTheme: const TextTheme(
          bodyMedium: TextStyle(color: Colors.black),
          bodyLarge: TextStyle(color: Colors.black),
        ),
        inputDecorationTheme: const InputDecorationTheme(
          fillColor: Colors.white,
        ),
        drawerTheme: const DrawerThemeData(
          backgroundColor: Color(0xFFEAF3FB),
        ),
      ),

      darkTheme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF121212),
        cardColor: const Color(0xFF1E1E1E),
        colorSchemeSeed: const Color(0xFF4F7EA6),
        textTheme: const TextTheme(
          bodyMedium: TextStyle(color: Colors.white),
          bodyLarge: TextStyle(color: Colors.white),
        ),
        inputDecorationTheme: InputDecorationTheme(
          fillColor: const Color(0xFF1E1E1E),
          hintStyle: const TextStyle(color: Colors.white38),
        ),
        drawerTheme: const DrawerThemeData(
          backgroundColor: Color(0xFF1A1A1A),
        ),
        dividerColor: Colors.white12,
        iconTheme: const IconThemeData(color: Colors.white),
        listTileTheme: const ListTileThemeData(
          textColor: Colors.white,
          iconColor: Color(0xFF4F7EA6),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF4F7EA6),
            foregroundColor: Colors.white,
          ),
        ),
      ),

      // ✅ Onboarding check — first install la OnboardingScreen, apram OmegaHome
      home: onboardingDone ? const OmegaHome() : const OnboardingScreen(),
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

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle(
        statusBarColor: bgColor,
        statusBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
        systemNavigationBarColor: bgColor,
      ),

      // ✅ Firebase auth state check
      child: StreamBuilder<User?>(
        stream: FirebaseAuth.instance.authStateChanges(),
        builder: (context, snapshot) {

          // Loading
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Scaffold(
              backgroundColor: bgColor,
              body: const Center(
                child: CircularProgressIndicator(color: Color(0xFF4F7EA6)),
              ),
            );
          }

          // ✅ Already logged in — direct HomeScreen
          if (snapshot.hasData && snapshot.data != null) {
            return HomeScreen(isGuest: false);
          }

          // Not logged in — show welcome screen
          return Scaffold(
            backgroundColor: bgColor,
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

                          // Get Started — Guest mode
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
                              onPressed: () => Navigator.pushReplacement(
                                context,
                                MaterialPageRoute(
                                    builder: (_) => const HomeScreen(isGuest: true)),
                              ),
                              child: const Text("Get started",
                                  style: TextStyle(fontSize: 16, color: Colors.white)),
                            ),
                          ),

                          SizedBox(height: MediaQuery.of(context).size.height * 0.02),

                          // Login button
                          SizedBox(
                            width: double.infinity,
                            height: 50,
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF4F7EA6),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              onPressed: () => Navigator.push(
                                context,
                                MaterialPageRoute(builder: (_) => const LoginScreen()),
                              ),
                              child: const Text("Login",
                                  style: TextStyle(fontSize: 16, color: Colors.white)),
                            ),
                          ),

                          SizedBox(height: MediaQuery.of(context).size.height * 0.02),

                          // Sign Up
                          SizedBox(
                            width: double.infinity,
                            height: 50,
                            child: TextButton(
                              onPressed: () => Navigator.push(
                                context,
                                MaterialPageRoute(builder: (_) => const SignupScreen()),
                              ),
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
        },
      ),
    );
  }
}