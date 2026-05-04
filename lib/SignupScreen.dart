import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/services.dart';
import 'HomeScreen.dart';
import 'LoginScreen.dart';

class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  final TextEditingController nameController = TextEditingController();
  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();

  bool isPasswordHidden = true;
  bool loading = false;

  Future<void> signup() async {
    setState(() => loading = true);
    try {
      await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: emailController.text.trim(),
        password: passwordController.text.trim(),
      );
      await FirebaseAuth.instance.currentUser?.updateDisplayName(
        nameController.text.trim(),
      );
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Signup successful ✅")),
      );
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const HomeScreen()),
      );
    } on FirebaseAuthException catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message ?? "Signup failed ❌")),
      );
    }
    setState(() => loading = false);
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
          // ✅ main.dart-மாதிரி gradient bg
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
                        "Create your account",
                        style: TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.w900,
                          color: textColor,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        "Get started with Omega AI in just a few steps",
                        style: TextStyle(fontSize: 14, color: subTextColor),
                      ),
                      const SizedBox(height: 28),

                      // ── Full Name ────────────────────────────────
                      Text("Full name",
                          style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              color: labelColor)),
                      const SizedBox(height: 6),
                      _inputField(
                        controller: nameController,
                        cardColor: cardColor,
                        textColor: textColor,
                        isDark: isDark,
                        hint: "Enter your full name",
                      ),

                      const SizedBox(height: 16),

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
                        isPassword: true,
                        cardColor: cardColor,
                        textColor: textColor,
                        isDark: isDark,
                        hint: "Create a password",
                        suffixIcon: IconButton(
                          icon: Icon(
                            isPasswordHidden
                                ? Icons.visibility_off
                                : Icons.visibility,
                            color: isDark ? Colors.white54 : const Color(0xFF6B8CAE),
                          ),
                          onPressed: () =>
                              setState(() => isPasswordHidden = !isPasswordHidden),
                        ),
                      ),

                      const SizedBox(height: 28),

                      // ── Sign Up Button (gradient — main.dart-மாதிரி) ──
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
                            onPressed: signup,
                            child: const Text(
                              "Sign Up",
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
                                builder: (_) => const HomeScreen(isGuest: true)),
                          ),
                          child: const Text(
                            "Continue as Guest",
                            style: TextStyle(
                                fontSize: 16, fontWeight: FontWeight.w600),
                          ),
                        ),
                      ),

                      const SizedBox(height: 20),

                      // ── Already have account ─────────────────────
                      Center(
                        child: RichText(
                          text: TextSpan(
                            style: TextStyle(
                                color: subTextColor, fontSize: 14),
                            children: [
                              const TextSpan(text: "Already have an account? "),
                              TextSpan(
                                text: "Login",
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  decoration: TextDecoration.underline,
                                  color: Color(0xFF1B9ED4),
                                ),
                                recognizer: TapGestureRecognizer()
                                  ..onTap = () => Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                        builder: (_) => const LoginScreen()),
                                  ),
                              ),
                            ],
                          ),
                        ),
                      ),

                      const Spacer(),

                      // ── FOOTER ───────────────────────────────────
                      Padding(
                        padding: const EdgeInsets.only(bottom: 10, top: 16),
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
        obscureText: isPassword ? isPasswordHidden : false,
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