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
              child: IntrinsicHeight( // ✅ Full height maintain
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

                    const Spacer(), // ✅ Center content push

                    Text("Welcome back",
                        style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w600,
                            color: textColor)),
                    const SizedBox(height: 8),
                    Text(
                      "Login to continue working with Omega AI",
                      style: TextStyle(fontSize: 14, color: subTextColor),
                    ),
                    const SizedBox(height: 24),

                    // Email
                    Text("Email", style: TextStyle(color: labelColor)),
                    const SizedBox(height: 6),
                    _inputField(
                      controller: emailController,
                      cardColor: cardColor,
                      textColor: textColor,
                    ),

                    const SizedBox(height: 16),

                    // Password
                    Text("Password", style: TextStyle(color: labelColor)),
                    const SizedBox(height: 6),
                    _inputField(
                      controller: passwordController,
                      isPassword: isPasswordHidden,
                      cardColor: cardColor,
                      textColor: textColor,
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

                    // Forgot Password
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
                              fontSize: 13, color: Color(0xFF4F7EA6)),
                        ),
                      ),
                    ),

                    const SizedBox(height: 10),

                    // Login Button
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
                        onPressed: login,
                        child: const Text("Login",
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
                              builder: (_) => const HomeScreen(isGuest: true)),
                        ),
                        child: const Text("Continue as Guest",
                            style: TextStyle(
                                fontSize: 16,
                                color: Color(0xFF3F6F9C),
                                fontWeight: FontWeight.bold)),
                      ),
                    ),

                    const Spacer(), // ✅ Footer push down

                    // ── FOOTER ───────────────────────────
                    Padding(
                      padding: const EdgeInsets.only(bottom: 10, top: 16),
                      child: Center(
                        child: Text(
                          "By signing up you accept to our Terms & Privacy Policy",
                          textAlign: TextAlign.center,
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
    );
  }
}

// ── INPUT FIELD ──────────────────────────────
Widget _inputField({
  required TextEditingController controller,
  required Color cardColor,
  required Color textColor,
  bool isPassword = false,
  Widget? suffixIcon,
}) {
  return TextField(
    controller: controller,
    obscureText: isPassword,
    style: TextStyle(color: textColor),
    decoration: InputDecoration(
      filled: true,
      fillColor: cardColor,
      suffixIcon: suffixIcon,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
    ),
  );
}