import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ProfileEditScreen extends StatefulWidget {
  const ProfileEditScreen({super.key});

  @override
  State<ProfileEditScreen> createState() => _ProfileEditScreenState();
}

class _ProfileEditScreenState extends State<ProfileEditScreen> {
  final _nameController = TextEditingController();
  bool _isLoading = false;
  String _errorMsg = "";

  @override
  void initState() {
    super.initState();
    final user = FirebaseAuth.instance.currentUser;
    _nameController.text = user?.displayName ?? user?.email?.split('@')[0] ?? "";
  }

  Future<void> _saveProfile() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      setState(() => _errorMsg = "Name cannot be empty!");
      return;
    }
    setState(() { _isLoading = true; _errorMsg = ""; });
    try {
      await FirebaseAuth.instance.currentUser?.updateDisplayName(name);
      await FirebaseAuth.instance.currentUser?.reload();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Profile updated! ✅"), backgroundColor: Color(0xFF2B9348)),
        );
        Navigator.pop(context, true); // ✅ true — settings refresh aagum
      }
    } catch (e) {
      setState(() { _errorMsg = "Update failed: $e"; _isLoading = false; });
    }
  }

  Future<void> _changePassword() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user?.email == null) return;
    setState(() => _isLoading = true);
    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(email: user!.email!);
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Password reset email sent to ${user.email} 📧"), backgroundColor: const Color(0xFF4F7EA6)),
        );
      }
    } catch (e) {
      setState(() { _errorMsg = "Error: $e"; _isLoading = false; });
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? const Color(0xFF121212) : const Color(0xFFAACBE5);
    final cardColor = isDark ? const Color(0xFF1E1E1E) : Colors.white;
    final textColor = isDark ? Colors.white : Colors.black;
    final subTextColor = isDark ? Colors.white54 : Colors.black54;

    final user = FirebaseAuth.instance.currentUser;
    final displayName = user?.displayName ?? user?.email?.split('@')[0] ?? "User";
    final email = user?.email ?? "";
    final firstLetter = displayName.isNotEmpty ? displayName[0].toUpperCase() : "U";

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle(
        statusBarColor: bgColor,
        statusBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
        systemNavigationBarColor: bgColor,
      ),
      child: Scaffold(
        backgroundColor: bgColor,
        appBar: AppBar(
          backgroundColor: bgColor,
          elevation: 0,
          leading: IconButton(
            icon: Icon(Icons.arrow_back, color: textColor),
            onPressed: () => Navigator.pop(context),
          ),
          title: Text("Edit Profile", style: TextStyle(color: textColor, fontWeight: FontWeight.bold)),
          actions: [
            _isLoading
                ? const Padding(
              padding: EdgeInsets.all(12),
              child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF4F7EA6))),
            )
                : TextButton(
              onPressed: _saveProfile,
              child: const Text("Save", style: TextStyle(color: Color(0xFF4F7EA6), fontWeight: FontWeight.bold, fontSize: 16)),
            ),
          ],
        ),
        body: ListView(
          padding: const EdgeInsets.all(20),
          children: [

            // ── AVATAR ──────────────────────────────
            Center(
              child: Stack(
                children: [
                  CircleAvatar(
                    radius: 50,
                    backgroundColor: const Color(0xFF4F7EA6),
                    child: Text(firstLetter,
                        style: const TextStyle(color: Colors.white, fontSize: 40, fontWeight: FontWeight.bold)),
                  ),
                  // ✅ Edit icon overlay
                  Positioned(
                    bottom: 0, right: 0,
                    child: Container(
                      width: 32, height: 32,
                      decoration: BoxDecoration(
                        color: const Color(0xFF4F7EA6),
                        shape: BoxShape.circle,
                        border: Border.all(color: bgColor, width: 2),
                      ),
                      child: const Icon(Icons.edit, color: Colors.white, size: 16),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 8),

            // Email
            Center(
              child: Text(email, style: TextStyle(color: subTextColor, fontSize: 13)),
            ),

            const SizedBox(height: 28),

            // ── NAME FIELD ───────────────────────────
            Text("Display Name", style: TextStyle(color: subTextColor, fontSize: 12, fontWeight: FontWeight.w600, letterSpacing: 0.5)),
            const SizedBox(height: 8),
            Container(
              decoration: BoxDecoration(color: cardColor, borderRadius: BorderRadius.circular(14)),
              child: TextField(
                controller: _nameController,
                style: TextStyle(color: textColor, fontSize: 16),
                decoration: InputDecoration(
                  prefixIcon: const Icon(Icons.person_outline, color: Color(0xFF4F7EA6)),
                  hintText: "Enter your name",
                  hintStyle: TextStyle(color: subTextColor),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                ),
              ),
            ),

            // ✅ Error message
            if (_errorMsg.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 8, left: 4),
                child: Text(_errorMsg, style: const TextStyle(color: Colors.red, fontSize: 12)),
              ),

            const SizedBox(height: 24),

            // ── EMAIL (read only) ────────────────────
            Text("Email Address", style: TextStyle(color: subTextColor, fontSize: 12, fontWeight: FontWeight.w600, letterSpacing: 0.5)),
            const SizedBox(height: 8),
            Container(
              decoration: BoxDecoration(color: cardColor.withOpacity(0.6), borderRadius: BorderRadius.circular(14)),
              child: ListTile(
                leading: const Icon(Icons.email_outlined, color: Color(0xFF4F7EA6)),
                title: Text(email, style: TextStyle(color: subTextColor, fontSize: 14)),
                trailing: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFF4F7EA6).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text("Verified", style: TextStyle(color: Color(0xFF4F7EA6), fontSize: 11, fontWeight: FontWeight.w600)),
                ),
              ),
            ),

            const SizedBox(height: 24),

            // ── ACCOUNT SECTION ──────────────────────
            Text("Account", style: TextStyle(color: subTextColor, fontSize: 12, fontWeight: FontWeight.w600, letterSpacing: 0.5)),
            const SizedBox(height: 8),

            // Change Password
            Container(
              decoration: BoxDecoration(color: cardColor, borderRadius: BorderRadius.circular(14)),
              child: ListTile(
                leading: const Icon(Icons.lock_outline, color: Color(0xFF4F7EA6)),
                title: Text("Change Password", style: TextStyle(color: textColor)),
                subtitle: Text("Send reset link to email", style: TextStyle(color: subTextColor, fontSize: 12)),
                trailing: const Icon(Icons.chevron_right, color: Colors.grey),
                onTap: _isLoading ? null : _changePassword,
              ),
            ),

            const SizedBox(height: 12),

            // Account Info
            Container(
              decoration: BoxDecoration(color: cardColor, borderRadius: BorderRadius.circular(14)),
              child: ListTile(
                leading: const Icon(Icons.verified_user_outlined, color: Color(0xFF2B9348)),
                title: Text("Account Type", style: TextStyle(color: textColor)),
                trailing: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFF2B9348).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Text("Free Plan", style: TextStyle(color: Color(0xFF2B9348), fontSize: 12, fontWeight: FontWeight.w600)),
                ),
              ),
            ),

            const SizedBox(height: 12),

            // Member Since
            Container(
              decoration: BoxDecoration(color: cardColor, borderRadius: BorderRadius.circular(14)),
              child: ListTile(
                leading: const Icon(Icons.calendar_today_outlined, color: Color(0xFF533483)),
                title: Text("Member Since", style: TextStyle(color: textColor)),
                trailing: Text(
                  user?.metadata.creationTime != null
                      ? "${user!.metadata.creationTime!.day}/${user.metadata.creationTime!.month}/${user.metadata.creationTime!.year}"
                      : "N/A",
                  style: const TextStyle(color: Colors.grey, fontSize: 13),
                ),
              ),
            ),

            const SizedBox(height: 32),

            // ── SAVE BUTTON ──────────────────────────
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF4F7EA6),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  elevation: 0,
                ),
                onPressed: _isLoading ? null : _saveProfile,
                child: _isLoading
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Text("Save Changes", style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Colors.white)),
              ),
            ),

            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }
}