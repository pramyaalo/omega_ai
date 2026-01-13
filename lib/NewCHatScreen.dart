import 'package:flutter/material.dart';

class NewCHatScreen extends StatefulWidget {
  const NewCHatScreen({super.key});

  @override
  State<NewCHatScreen> createState() => _OmegaHomeScreenState();
}

class _OmegaHomeScreenState extends State<NewCHatScreen> {
  final TextEditingController messageController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFAACBE5),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(
            children: [

              /// 🔹 TOP LOGO
              Row(
                children: const [
                  Text(
                    "Ω",
                    style: TextStyle(
                      fontSize: 26,
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

              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [

                    /// 🔹 White Card
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 20,
                      ),
                      margin: const EdgeInsets.symmetric(horizontal: 20),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: const [
                          Text(
                            "Omega AI",
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w600,
                            ),
                          ),

                          SizedBox(height: 10),

                          Text(
                            "Your intelligent workspace — ask questions, plan tasks, or explore ideas.",
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.black54,
                              height: 1.9, // 👈 line spacing
                            ),
                          ),

                        ],
                      ),
                    ),

                    const SizedBox(height: 17),

                    /// 🔹 Outside text (below white bg)
                    const Text(
                      "Capture a thought to begin",
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.black45,
                      ),
                    ),
                  ],
                ),
              ),



              /// 🔹 MESSAGE INPUT BAR
              Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(25),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 8,
                    ),
                  ],
                ),
                child: Row(
                  children: [

                    /// ➕ ICON
                    const Icon(
                      Icons.add,
                      color: Colors.black54,
                    ),

                    const SizedBox(width: 8),

                    /// TEXT FIELD
                    Expanded(
                      child: TextField(
                        controller: messageController,
                        decoration: const InputDecoration(
                          hintText: "Ask Anything...",
                          border: InputBorder.none,
                        ),
                      ),
                    ),

                    const SizedBox(width: 8),

                    /// SEND BUTTON
                    Container(
                      height: 40,
                      width: 40,
                      decoration: const BoxDecoration(
                        color:  Colors.teal,
                        shape: BoxShape.circle,
                      ),
                      child: IconButton(
                        icon: const Icon(
                          Icons.send,
                          color: Colors.white,
                          size: 18,
                        ),
                        onPressed: () {
                          // SEND ACTION
                          print(messageController.text);
                          messageController.clear();
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
