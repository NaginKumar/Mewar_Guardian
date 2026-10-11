import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
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
  final List<Map<String, dynamic>> _messages = [];
  bool _isTyping = false;
  bool _isUploadingPhoto = false;
  final ScrollController _scrollCtrl = ScrollController();
  final ImagePicker _picker = ImagePicker();

  Uint8List? _selectedImageBytes;
  String? _selectedImageName;

  @override
  void initState() {
    super.initState();
    _messages.add({
      "role": "assistant",
      "content": "Namaste! Main Mewar Guardian AI hoon 🛡️\nMewar University campus safety ke baare mein kuch poochna hai? Ya koi emergency hai? Mujhe batao, main turant help karunga!",
      "photo_url": null,
    });
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final XFile? file = await _picker.pickImage(
        source: source,
        maxWidth: 1600,
        maxHeight: 1600,
        imageQuality: 85,
      );
      if (file != null) {
        final bytes = await file.readAsBytes();
        setState(() {
          _selectedImageBytes = bytes;
          _selectedImageName = file.name;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Could not access image: $e"),
            backgroundColor: AppColors.criticalRed,
          ),
        );
      }
    }
  }

  void _showImageSourcePicker() {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(color: AppColors.border, borderRadius: BorderRadius.circular(2)),
              ),
              const SizedBox(height: 16),
              const Text(
                "Attach Incident Photo",
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppColors.forestGreen),
              ),
              const SizedBox(height: 6),
              const Text(
                "Photos are stored securely for campus safety verification.",
                style: TextStyle(fontSize: 12, color: AppColors.textMuted),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(color: AppColors.mutedSage.withOpacity(0.4), shape: BoxShape.circle),
                  child: const Icon(Icons.photo_camera_rounded, color: AppColors.forestGreen),
                ),
                title: const Text("Take Photo with Camera", style: TextStyle(fontWeight: FontWeight.w700)),
                subtitle: const Text("Capture live incident scene", style: TextStyle(fontSize: 12)),
                onTap: () {
                  Navigator.pop(ctx);
                  _pickImage(ImageSource.camera);
                },
              ),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(color: AppColors.mutedSage.withOpacity(0.4), shape: BoxShape.circle),
                  child: const Icon(Icons.photo_library_rounded, color: AppColors.forestGreen),
                ),
                title: const Text("Choose from Gallery", style: TextStyle(fontWeight: FontWeight.w700)),
                subtitle: const Text("Select image from your device", style: TextStyle(fontSize: 12)),
                onTap: () {
                  Navigator.pop(ctx);
                  _pickImage(ImageSource.gallery);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _removeSelectedImage() {
    setState(() {
      _selectedImageBytes = null;
      _selectedImageName = null;
    });
  }

  void _sendMessage() async {
    final text = _msgController.text.trim();
    if ((text.isEmpty && _selectedImageBytes == null) || _isTyping || _isUploadingPhoto) return;

    final imageBytesToSend = _selectedImageBytes;
    final imageNameToSend = _selectedImageName ?? 'incident_photo.jpg';

    // Clear draft state
    _msgController.clear();
    setState(() {
      _selectedImageBytes = null;
      _selectedImageName = null;
      _isTyping = true;
    });

    final api = Provider.of<ApiService>(context, listen: false);
    String? uploadedUrl;

    if (imageBytesToSend != null) {
      setState(() => _isUploadingPhoto = true);
      final uploadRes = await api.uploadImage(imageBytesToSend, imageNameToSend);
      setState(() => _isUploadingPhoto = false);

      if (uploadRes['success'] == true) {
        uploadedUrl = uploadRes['photo_url'];
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(uploadRes['error'] ?? "Failed to upload image."),
              backgroundColor: AppColors.criticalRed,
            ),
          );
        }
      }
    }

    setState(() {
      _messages.add({
        "role": "user",
        "content": text.isNotEmpty ? text : (uploadedUrl != null ? "📸 Attached incident photo" : ""),
        "photo_url": uploadedUrl,
        "photo_bytes": imageBytesToSend,
      });
    });
    _scrollToBottom();

    final history = _messages.take(_messages.length - 1)
        .map((m) => {"role": m["role"]!.toString(), "content": m["content"]!.toString()})
        .toList();

    final response = await api.chatWithAi(
      text.isNotEmpty ? text : "I have attached an incident photo.",
      history,
      photoUrl: uploadedUrl,
    );

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
      _messages.add({
        "role": "assistant",
        "content": reply,
        "photo_url": null,
      });
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
                  final photoBytes = msg["photo_bytes"] as Uint8List?;
                  final photoUrl = msg["photo_url"] as String?;

                  return Align(
                    alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(12),
                      constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.82),
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
                      child: Column(
                        crossAxisAlignment: isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                        children: [
                          // Photo preview if attached
                          if (photoBytes != null || (photoUrl != null && photoUrl.isNotEmpty)) ...[
                            ClipRRect(
                              borderRadius: BorderRadius.circular(10),
                              child: photoBytes != null
                                  ? Image.memory(
                                      photoBytes,
                                      width: 220,
                                      height: 160,
                                      fit: BoxFit.cover,
                                    )
                                  : Image.network(
                                      photoUrl!,
                                      width: 220,
                                      height: 160,
                                      fit: BoxFit.cover,
                                      errorBuilder: (_, __, ___) => const Icon(Icons.broken_image, size: 40),
                                    ),
                            ),
                            const SizedBox(height: 8),
                          ],
                          if (msg["content"] != null && (msg["content"] as String).isNotEmpty)
                            Text(
                              msg["content"] ?? "",
                              style: TextStyle(
                                color: isUser ? AppColors.white : AppColors.charcoal,
                                fontSize: 14,
                                height: 1.35,
                              ),
                            ),
                        ],
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
                    Text("Mewar Guardian AI is analyzing...", style: TextStyle(fontSize: 12, color: AppColors.textMuted)),
                  ],
                ),
              ),

            // Image Preview Bar if an image is selected
            if (_selectedImageBytes != null)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                color: AppColors.white,
                child: Row(
                  children: [
                    Stack(
                      clipBehavior: Clip.none,
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.memory(
                            _selectedImageBytes!,
                            width: 54,
                            height: 54,
                            fit: BoxFit.cover,
                          ),
                        ),
                        Positioned(
                          top: -6,
                          right: -6,
                          child: GestureDetector(
                            onTap: _removeSelectedImage,
                            child: Container(
                              padding: const EdgeInsets.all(2),
                              decoration: const BoxDecoration(
                                color: AppColors.criticalRed,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.close, size: 14, color: Colors.white),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _selectedImageName ?? "Incident Photo",
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.charcoal),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const Text(
                            "Ready to upload with your query",
                            style: TextStyle(fontSize: 11, color: AppColors.textMuted),
                          ),
                        ],
                      ),
                    ),
                    TextButton(
                      onPressed: _showImageSourcePicker,
                      child: const Text("Replace", style: TextStyle(fontSize: 12, color: AppColors.forestGreen, fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
              ),

            // Input Bar
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              color: AppColors.white,
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.camera_alt_outlined, color: AppColors.forestGreen),
                    tooltip: "Attach Photo",
                    onPressed: _showImageSourcePicker,
                  ),
                  Expanded(
                    child: TextField(
                      controller: _msgController,
                      decoration: InputDecoration(
                        hintText: _selectedImageBytes != null
                            ? "Add description (optional)..."
                            : "Ask anything about campus safety...",
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: const BorderSide(color: AppColors.border)),
                      ),
                      onSubmitted: (_) => _sendMessage(),
                    ),
                  ),
                  const SizedBox(width: 6),
                  IconButton(
                    icon: _isUploadingPhoto
                        ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.forestGreen))
                        : const Icon(Icons.send_rounded, color: AppColors.forestGreen),
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
