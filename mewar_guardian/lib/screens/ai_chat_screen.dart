import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';
import 'report_screen.dart';

class AiChatScreen extends StatefulWidget {
  const AiChatScreen({super.key});
  @override
  State<AiChatScreen> createState() => _AiChatScreenState();
}

class _AiChatScreenState extends State<AiChatScreen> {
  final _msgController = TextEditingController();
  final List<Map<String, String>> _messages = [];
  bool _isTyping = false;
  final ScrollController _scrollCtrl = ScrollController();

  @override
  void initState() {
    super.initState();
    _messages.add({
      "role": "assistant",
      "content": "Namaste! Main Mewar Guardian AI hoon 🛡️\nMewar University campus safety ke baare mein kuch poochna hai? Ya koi emergency hai? Mujhe batao, main turant help karunga!\n\n(Developed by Nagin Daksh for campus safety)"
    });
  }

  void _sendMessage() async {
    final text = _msgController.text.trim();
    if (text.isEmpty || _isTyping) return;

    setState(() {
      _messages.add({"role": "user", "content": text});
      _isTyping = true;
    });
    _msgController.clear();
    _scrollToBottom();

    final api = Provider.of<ApiService>(context, listen: false);
    final history = _messages.take(_messages.length - 1)
        .map((m) => {"role": m["role"]!, "content": m["content"]!})
        .toList();

    final response = await api.chatWithAi(text, history);

    if (!mounted) return;

    String reply = "Sorry, main abhi server se connect nahi kar paa raha hoon. In case of emergency, please direct SOS button use karein.";
    bool isEmergency = false;
    bool askSos = false;

    if (response != null) {
      reply = response['message']?.toString() ?? reply;
      isEmergency = response['is_emergency'] == true;
      askSos = response['ask_sos'] == true;
    }

    setState(() {
      _isTyping = false;
      _messages.add({"role": "assistant", "content": reply});
    });
    _scrollToBottom();

    if ((isEmergency || askSos) && mounted) {
      await Future.delayed(const Duration(milliseconds: 300));
      _showSosPrompt(response);
    }
  }

  void _showSosPrompt(Map<String, dynamic>? response) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        decoration: const BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40, height: 4,
              decoration: BoxDecoration(color: AppColors.border, borderRadius: BorderRadius.circular(4)),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.safetyOrange.withOpacity(0.12),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.warning_amber_rounded, color: AppColors.safetyOrange, size: 36),
            ),
            const SizedBox(height: 12),
            const Text(
              "Emergency Situation Detected",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.charcoal),
            ),
            const SizedBox(height: 6),
            Text(
              response?['emergency_type'] != null
                  ? "Category: ${response!['emergency_type']}"
                  : "Would you like to transmit an immediate SOS report?",
              style: const TextStyle(fontSize: 13, color: AppColors.textMuted),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.safetyOrange,
                  foregroundColor: AppColors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                icon: const Icon(Icons.emergency_share, size: 22),
                label: const Text("TRANSMIT SOS REPORT NOW", style: TextStyle(fontWeight: FontWeight.w900)),
                onPressed: () {
                  Navigator.pop(context);
                  Navigator.push(context, MaterialPageRoute(builder: (_) => const ReportScreen()));
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _scrollToBottom() {
    Future.delayed(const Duration(milliseconds: 100), () {
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.animateTo(
          _scrollCtrl.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.warmIvory,
      appBar: AppBar(
        title: const Row(
          children: [
            Icon(Icons.smart_toy_outlined, color: AppColors.safetyOrange, size: 22),
            SizedBox(width: 8),
            Text("Mewar Guardian AI Chat"),
          ],
        ),
        backgroundColor: AppColors.forestGreen,
        foregroundColor: AppColors.warmIvory,
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView.builder(
                controller: _scrollCtrl,
                padding: const EdgeInsets.all(16),
                itemCount: _messages.length,
                itemBuilder: (context, idx) {
                  final msg = _messages[idx];
                  final isUser = msg["role"] == "user";
                  return Align(
                    alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.78),
                      decoration: BoxDecoration(
                        color: isUser ? AppColors.forestGreen : AppColors.white,
                        borderRadius: BorderRadius.only(
                          topLeft: const Radius.circular(16),
                          topRight: const Radius.circular(16),
                          bottomLeft: Radius.circular(isUser ? 16 : 4),
                          bottomRight: Radius.circular(isUser ? 4 : 16),
                        ),
                        border: isUser ? null : Border.all(color: AppColors.border),
                        boxShadow: [
                          BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 6, offset: const Offset(0, 2)),
                        ],
                      ),
                      child: Text(
                        msg["content"] ?? "",
                        style: TextStyle(
                          color: isUser ? AppColors.white : AppColors.charcoal,
                          fontSize: 14,
                          height: 1.35,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            if (_isTyping)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.forestGreen)),
                    SizedBox(width: 8),
                    Text("Rakshak AI is analyzing...", style: TextStyle(fontSize: 12, color: AppColors.textMuted)),
                  ],
                ),
              ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              color: AppColors.white,
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _msgController,
                      decoration: InputDecoration(
                        hintText: "Ask anything about campus safety...",
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: const BorderSide(color: AppColors.border)),
                      ),
                      onSubmitted: (_) => _sendMessage(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: const Icon(Icons.send_rounded, color: AppColors.forestGreen),
                    onPressed: _sendMessage,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
