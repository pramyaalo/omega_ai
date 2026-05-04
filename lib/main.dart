import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'HomeScreen.dart';
import 'LoginScreen.dart';
import 'SignupScreen.dart';
import 'OnboardingScreen.dart';

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
  final onboardingDone = prefs.getBool('onboarding_done') ?? false;

  runApp(OmegaApp(isDark: isDark, onboardingDone: onboardingDone));
}

class OmegaApp extends StatefulWidget {
  final bool isDark;
  final bool onboardingDone;
  const OmegaApp({super.key, required this.isDark, required this.onboardingDone});

  static _OmegaAppState? of(BuildContext context) =>
      context.findAncestorStateOfType<_OmegaAppState>();

  @override
  State<OmegaApp> createState() => _OmegaAppState();
}

class _OmegaAppState extends State<OmegaApp> {
  late bool isDark;
  late bool onboardingDone;

  @override
  void initState() {
    super.initState();
    isDark = widget.isDark;
    onboardingDone = widget.onboardingDone;
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
        scaffoldBackgroundColor: const Color(0xFFEBF5FB),
        cardColor: Colors.white,
        colorSchemeSeed: const Color(0xFF1DA1D6),
        textTheme: const TextTheme(
          bodyMedium: TextStyle(color: Color(0xFF1A1A2E)),
          bodyLarge: TextStyle(color: Color(0xFF1A1A2E)),
        ),
        inputDecorationTheme: const InputDecorationTheme(
          fillColor: Colors.white,
        ),
        drawerTheme: const DrawerThemeData(
          backgroundColor: Color(0xFFF0F9FF),
        ),
        dividerColor: const Color(0xFFCDE8F8),
        iconTheme: const IconThemeData(color: Color(0xFF1DA1D6)),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF1DA1D6),
            foregroundColor: Colors.white,
          ),
        ),
      ),

      darkTheme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF0D1B2A),
        cardColor: const Color(0xFF1A2744),
        colorSchemeSeed: const Color(0xFF1DA1D6),
        textTheme: const TextTheme(
          bodyMedium: TextStyle(color: Colors.white),
          bodyLarge: TextStyle(color: Colors.white),
        ),
        inputDecorationTheme: InputDecorationTheme(
          fillColor: const Color(0xFF1A2744),
          hintStyle: const TextStyle(color: Colors.white38),
        ),
        drawerTheme: const DrawerThemeData(
          backgroundColor: Color(0xFF112035),
        ),
        dividerColor: Colors.white12,
        iconTheme: const IconThemeData(color: Color(0xFF1DA1D6)),
        listTileTheme: const ListTileThemeData(
          textColor: Colors.white,
          iconColor: Color(0xFF1DA1D6),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF1DA1D6),
            foregroundColor: Colors.white,
          ),
        ),
      ),

      home: onboardingDone ? const OmegaHome() : const OnboardingScreen(),
    );
  }
}

class OmegaHome extends StatelessWidget {
  const OmegaHome({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : const Color(0xFF1A1A2E);
    final subTextColor = isDark ? Colors.white38 : const Color(0xFF6B8CAE);

    // ✅ Gradient colors — web screenshot-மாதிரி exact
    final gradientTop = isDark
        ? const Color(0xFF0D1B2A)
        : const Color(0xFFEBF5FB); // light blue-white top
    final gradientBottom = isDark
        ? const Color(0xFF0A2540)
        : const Color(0xFFC5E3F5); // deeper blue bottom

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
        systemNavigationBarColor: gradientBottom,
      ),

      child: StreamBuilder<User?>(
        stream: FirebaseAuth.instance.authStateChanges(),
        builder: (context, snapshot) {

          if (snapshot.connectionState == ConnectionState.waiting) {
            return Scaffold(
              backgroundColor: gradientTop,
              body: const Center(
                child: CircularProgressIndicator(color: Color(0xFF1DA1D6)),
              ),
            );
          }

          if (snapshot.hasData && snapshot.data != null) {
            return HomeScreen(isGuest: false);
          }

          return Scaffold(
            backgroundColor: Colors.transparent,
            body: Container(
              width: double.infinity,
              height: double.infinity,
              // ✅ Web-மாதிரி top-to-bottom gradient
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [gradientTop, gradientBottom],
                  stops: const [0.0, 1.0],
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [

                  // ── WHITE NAVBAR (web-மாதிரி) ──────────────
                  Container(
                    width: double.infinity,
                    color: isDark ? const Color(0xFF0D1B2A) : Colors.white,
                    padding: EdgeInsets.only(
                      top: MediaQuery.of(context).padding.top + 8,
                      bottom: 12,
                      left: 20,
                      right: 20,
                    ),
                    child: Row(
                      children: [
                        // Cyan square icon
                        Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: const Color(0xFF1B9ED4),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Center(
                            child: Text(
                              "Ω",
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        // "Omega AI" cyan text
                        const Text(
                          "Omega AI",
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF1B9ED4),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // ── MAIN CONTENT ───────────────────────────
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 40),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [

                          // Advanced AI Model badge
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 14, vertical: 6),
                            decoration: BoxDecoration(
                              color: isDark
                                  ? const Color(0xFF1A2744)
                                  : Colors.white,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: const Color(0xFF1DA1D6).withOpacity(0.35),
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  width: 8,
                                  height: 8,
                                  decoration: const BoxDecoration(
                                    color: Color(0xFF1DA1D6),
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: 6),
                                const Text(
                                  "Advanced AI Model",
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: Color(0xFF1DA1D6),
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),

                          const SizedBox(height: 24),

                          // "Meet Omega AI" headline
                          RichText(
                            text: TextSpan(
                              children: [
                                TextSpan(
                                  text: "Meet ",
                                  style: TextStyle(
                                    fontSize: 36,
                                    fontWeight: FontWeight.w900,
                                    color: textColor,
                                  ),
                                ),
                                const TextSpan(
                                  text: "Omega AI",
                                  style: TextStyle(
                                    fontSize: 36,
                                    fontWeight: FontWeight.w900,
                                    color: Color(0xFF1DA1D6),
                                  ),
                                ),
                              ],
                            ),
                          ),

                          const SizedBox(height: 12),

                          Text(
                            "Your intelligent assistant for everything - from writing code to analyzing documents",
                            style: TextStyle(
                              fontSize: 15,
                              color: subTextColor,
                              height: 1.5,
                            ),
                          ),

                          SizedBox(height: MediaQuery.of(context).size.height * 0.06),

                          // ── Start with Omega AI button ──────
                          SizedBox(
                            width: double.infinity,
                            height: 52,
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF2B9ED4),
                                foregroundColor: Colors.white,
                                elevation: 0,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              onPressed: () => Navigator.pushReplacement(
                                context,
                                MaterialPageRoute(
                                    builder: (_) =>
                                    const HomeScreen(isGuest: true)),
                              ),
                              child: const Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    "Start with Omega AI",
                                    style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w600),
                                  ),
                                  SizedBox(width: 8),
                                  Icon(Icons.arrow_forward, size: 18),
                                ],
                              ),
                            ),
                          ),

                          SizedBox(height: MediaQuery.of(context).size.height * 0.02),

                          // ── Login button ────────────────────
                          SizedBox(
                            width: double.infinity,
                            height: 52,
                            child: OutlinedButton(
                              style: OutlinedButton.styleFrom(
                                foregroundColor: const Color(0xFF1DA1D6),
                                side: const BorderSide(
                                    color: Color(0xFF1DA1D6), width: 1.5),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              onPressed: () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                    builder: (_) => const LoginScreen()),
                              ),
                              child: const Text(
                                "Login",
                                style: TextStyle(
                                    fontSize: 16, fontWeight: FontWeight.w600),
                              ),
                            ),
                          ),

                          SizedBox(height: MediaQuery.of(context).size.height * 0.02),

                          // ── Create account button ───────────
                          SizedBox(
                            width: double.infinity,
                            height: 52,
                            child: TextButton(
                              onPressed: () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                    builder: (_) => const SignupScreen()),
                              ),
                              style: TextButton.styleFrom(
                                foregroundColor: subTextColor,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              child: Text(
                                "Create an account",
                                style: TextStyle(
                                    fontSize: 15, color: subTextColor),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // ── FOOTER ────────────────────────────────
                  Padding(
                    padding: const EdgeInsets.only(bottom: 24),
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