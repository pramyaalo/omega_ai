import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/services.dart';

import 'HomeScreen.dart';
import 'ResetPasswordScreen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();

  bool isPasswordHidden = true;
  bool loading = false;

  @override
  void dispose() {
    emailController.dispose();
    passwordController.dispose();
    super.dispose();
  }

  Future<void> login() async {
    setState(() => loading = true);
    try {
      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: emailController.text.trim(),
        password: passwordController.text.trim(),
      );
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const HomeScreen()),
      );
    } on FirebaseAuthException catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message ?? "Login failed")),
      );
    }
    setState(() => loading = false);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // ✅ main.dart + SignupScreen-மாதிரி exact same colors
    final gradientTop    = isDark ? const Color(0xFF0D1B2A) : const Color(0xFFEBF5FB);
    final gradientBottom = isDark ? const Color(0xFF0A2540) : const Color(0xFFC5E3F5);
    final cardColor      = isDark ? const Color(0xFF1A2744) : Colors.white;
    final textColor      = isDark ? Colors.white : const Color(0xFF1A1A2E);
    final subTextColor   = isDark ? Colors.white38 : const Color(0xFF6B8CAE);
    final labelColor     = isDark ? Colors.white70 : const Color(0xFF1A1A2E);

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
        systemNavigationBarColor: gradientBottom,
      ),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: Container(
          width: double.infinity,
          height: double.infinity,
          // ✅ Gradient bg — main.dart-மாதிரி exact
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [gradientTop, gradientBottom],
            ),
          ),
          child: SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight: MediaQuery.of(context).size.height -
                      MediaQuery.of(context).padding.top -
                      MediaQuery.of(context).padding.bottom,
                ),
                child: IntrinsicHeight(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [

                      // ── LOGO (main.dart-மாதிரி exact) ──────────
                      Row(
                        children: [
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

                      const Spacer(),

                      // ── HEADING ─────────────────────────────────
                      Text(
                        "Welcome back",
                        style: TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.w900,
                          color: textColor,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        "Login to continue working with Omega AI",
                        style: TextStyle(fontSize: 14, color: subTextColor),
                      ),
                      const SizedBox(height: 28),

                      // ── Email ────────────────────────────────────
                      Text("Email",
                          style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              color: labelColor)),
                      const SizedBox(height: 6),
                      _inputField(
                        controller: emailController,
                        cardColor: cardColor,
                        textColor: textColor,
                        isDark: isDark,
                        hint: "Enter your email",
                        keyboardType: TextInputType.emailAddress,
                      ),

                      const SizedBox(height: 16),

                      // ── Password ─────────────────────────────────
                      Text("Password",
                          style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              color: labelColor)),
                      const SizedBox(height: 6),
                      _inputField(
                        controller: passwordController,
                        isPassword: isPasswordHidden,
                        cardColor: cardColor,
                        textColor: textColor,
                        isDark: isDark,
                        hint: "Enter your password",
                        suffixIcon: IconButton(
                          icon: Icon(
                            isPasswordHidden
                                ? Icons.visibility_off
                                : Icons.visibility,
                            color: isDark
                                ? Colors.white54
                                : const Color(0xFF6B8CAE),
                          ),
                          onPressed: () => setState(
                                  () => isPasswordHidden = !isPasswordHidden),
                        ),
                      ),

                      // ── Forgot Password ──────────────────────────
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton(
                          onPressed: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (_) => const ResetPasswordScreen()),
                          ),
                          child: const Text(
                            "Forgot password?",
                            style: TextStyle(
                                fontSize: 13, color: Color(0xFF1B9ED4)),
                          ),
                        ),
                      ),

                      const SizedBox(height: 4),

                      // ── Login Button (gradient) ───────────────────
                      SizedBox(
                        width: double.infinity,
                        height: 52,
                        child: loading
                            ? const Center(
                            child: CircularProgressIndicator(
                                color: Color(0xFF1DA1D6)))
                            : DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              begin: Alignment.centerLeft,
                              end: Alignment.centerRight,
                              colors: [
                                Color(0xFF2B6CB8), // left dark blue
                                Color(0xFF2BB5E8), // right cyan
                              ],
                            ),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.transparent,
                              shadowColor: Colors.transparent,
                              foregroundColor: Colors.white,
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            onPressed: login,
                            child: const Text(
                              "Login",
                              style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600),
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(height: 14),

                      // ── Continue as Guest (outlined) ─────────────
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
                          onPressed: () => Navigator.pushReplacement(
                            context,
                            MaterialPageRoute(
                                builder: (_) =>
                                const HomeScreen(isGuest: true)),
                          ),
                          child: const Text(
                            "Continue as Guest",
                            style: TextStyle(
                                fontSize: 16, fontWeight: FontWeight.w600),
                          ),
                        ),
                      ),

                      const Spacer(),

                      // ── FOOTER ───────────────────────────────────
                      Padding(
                        padding: const EdgeInsets.only(bottom: 10, top: 16),
                        child: Center(
                          child: Text(
                            "By signing up you accept to our Terms & Privacy Policy",
                            textAlign: TextAlign.center,
                            style:
                            TextStyle(fontSize: 12, color: subTextColor),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _inputField({
    required TextEditingController controller,
    required Color cardColor,
    required Color textColor,
    required bool isDark,
    bool isPassword = false,
    Widget? suffixIcon,
    String? hint,
    TextInputType? keyboardType,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: const Color(0xFF1DA1D6).withOpacity(0.2),
        ),
      ),
      child: TextField(
        controller: controller,
        obscureText: isPassword,
        keyboardType: keyboardType,
        style: TextStyle(color: textColor),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: TextStyle(
              color: isDark ? Colors.white38 : const Color(0xFF6B8CAE)),
          border: InputBorder.none,
          suffixIcon: suffixIcon,
        ),
      ),
    );
  }
}