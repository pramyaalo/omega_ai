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
    final bgColor = isDark ? const Color(0xFF121212) : const Color(0xFFAACBE5);
    final cardColor = isDark ? const Color(0xFF1E1E1E) : Colors.white;
    final textColor = isDark ? Colors.white : Colors.black;
    final subTextColor = isDark ? Colors.white38 : Colors.black54;
    final labelColor = isDark ? Colors.white70 : Colors.black87;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle(
        statusBarColor: bgColor,
        statusBarIconBrightness:
        isDark ? Brightness.light : Brightness.dark,
        systemNavigationBarColor: bgColor,
      ),
      child: Scaffold(
        backgroundColor: bgColor,
        body: SafeArea(
          child: SingleChildScrollView( // ✅ Overflow fix
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
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

                    // ── LOGO ──────────────────────────────
                    Row(
                      children: [
                        Text("Ω",
                            style: TextStyle(
                                fontSize: 28,
                                fontWeight: FontWeight.bold,
                                color: textColor)),
                        const SizedBox(width: 6),
                        Text("OMEGA AI",
                            style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w600,
                                color: textColor)),
                      ],
                    ),

                    const Spacer(),

                    Text("Create your account",
                        style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.w900,
                            color: textColor)),
                    const SizedBox(height: 8),
                    Text(
                      "Get started with Omega AI in just a few steps",
                      style: TextStyle(fontSize: 14, color: subTextColor),
                    ),
                    const SizedBox(height: 24),

                    // Full Name
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
                    ),

                    const SizedBox(height: 16),

                    // Email
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
                    ),

                    const SizedBox(height: 16),

                    // Password
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
                      suffixIcon: IconButton(
                        icon: Icon(
                          isPasswordHidden
                              ? Icons.visibility_off
                              : Icons.visibility,
                          color: isDark ? Colors.white54 : Colors.grey,
                        ),
                        onPressed: () => setState(
                                () => isPasswordHidden = !isPasswordHidden),
                      ),
                    ),

                    const SizedBox(height: 24),

                    // Sign Up Button
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: loading
                          ? const Center(child: CircularProgressIndicator())
                          : ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF3F6F9C),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        onPressed: signup,
                        child: const Text("Sign Up",
                            style: TextStyle(
                                fontSize: 16,
                                color: Colors.white,
                                fontWeight: FontWeight.bold)),
                      ),
                    ),

                    const SizedBox(height: 16),

                    // Guest Button
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: Color(0xFF3F6F9C)),
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
                        child: const Text("Continue as Guest",
                            style: TextStyle(
                                fontSize: 16,
                                color: Color(0xFF3F6F9C),
                                fontWeight: FontWeight.bold)),
                      ),
                    ),

                    const SizedBox(height: 20),

                    // Already have account
                    Center(
                      child: RichText(
                        text: TextSpan(
                          style: TextStyle(color: textColor),
                          children: [
                            const TextSpan(text: "Already have an account? "),
                            TextSpan(
                              text: "Login",
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                decoration: TextDecoration.underline,
                                color: Color(0xFF4F7EA6),
                              ),
                              recognizer: TapGestureRecognizer()
                                ..onTap = () => Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                      builder: (_) =>
                                      const LoginScreen()),
                                ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    const Spacer(),

                    // ── FOOTER ───────────────────────────
                    Padding(
                      padding: const EdgeInsets.only(bottom: 10, top: 16),
                      child: Center(
                        child: Text(
                          "No credit card required. Privacy Policy",
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
    );
  }

  Widget _inputField({
    required TextEditingController controller,
    required Color cardColor,
    required Color textColor,
    required bool isDark,
    bool isPassword = false,
    Widget? suffixIcon,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: TextField(
        controller: controller,
        obscureText: isPassword ? isPasswordHidden : false,
        style: TextStyle(color: textColor),
        decoration: InputDecoration(
          hintStyle: TextStyle(
              color: isDark ? Colors.white38 : Colors.black54),
          border: InputBorder.none,
          suffixIcon: suffixIcon,
        ),
      ),
    );
  }
}