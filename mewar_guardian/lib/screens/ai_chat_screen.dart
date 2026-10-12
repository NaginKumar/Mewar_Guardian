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
  Uint8List? _selectedVideoBytes;
  String? _selectedVideoName;
  bool _isUploadingMedia = false;

  @override
  void initState() {
    super.initState();
    _messages.add({
      "role": "assistant",
      "content": "Namaste! Main Mewar Guardian AI hoon 🛡️\nMewar University campus safety ke baare mein kuch poochna hai? Ya koi emergency hai? Mujhe batao, main turant help karunga!",
      "photo_url": null,
      "video_url": null,
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
          _selectedVideoBytes = null;
          _selectedVideoName = null;
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

  Future<void> _pickVideo(ImageSource source) async {
    try {
      final XFile? file = await _picker.pickVideo(
        source: source,
        maxDuration: const Duration(minutes: 3),
      );
      if (file != null) {
        final bytes = await file.readAsBytes();
        if (bytes.lengthInBytes > 50 * 1024 * 1024) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text("Selected video exceeds 50MB limit."),
                backgroundColor: AppColors.criticalRed,
              ),
            );
          }
          return;
        }
        setState(() {
          _selectedVideoBytes = bytes;
          _selectedVideoName = file.name;
          _selectedImageBytes = null;
          _selectedImageName = null;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Could not access video: $e"),
            backgroundColor: AppColors.criticalRed,
          ),
        );
      }
    }
  }

  void _showAttachmentPicker() {
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
                "Attach Incident Evidence",
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppColors.forestGreen),
              ),
              const SizedBox(height: 6),
              const Text(
                "Upload photos or videos (up to 50MB) for AI safety analysis and security records.",
                style: TextStyle(fontSize: 12, color: AppColors.textMuted),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 18),
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
                title: const Text("Choose Photo from Gallery", style: TextStyle(fontWeight: FontWeight.w700)),
                subtitle: const Text("Select image from device", style: TextStyle(fontSize: 12)),
                onTap: () {
                  Navigator.pop(ctx);
                  _pickImage(ImageSource.gallery);
                },
              ),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(color: AppColors.safetyOrange.withOpacity(0.12), shape: BoxShape.circle),
                  child: const Icon(Icons.videocam_rounded, color: AppColors.safetyOrange),
                ),
                title: const Text("Record Video with Camera", style: TextStyle(fontWeight: FontWeight.w700)),
                subtitle: const Text("Live video footage (up to 3 min)", style: TextStyle(fontSize: 12)),
                onTap: () {
                  Navigator.pop(ctx);
                  _pickVideo(ImageSource.camera);
                },
              ),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(color: AppColors.safetyOrange.withOpacity(0.12), shape: BoxShape.circle),
                  child: const Icon(Icons.video_library_rounded, color: AppColors.safetyOrange),
                ),
                title: const Text("Choose Video from Gallery", style: TextStyle(fontWeight: FontWeight.w700)),
                subtitle: const Text("Select video file (max 50MB)", style: TextStyle(fontSize: 12)),
                onTap: () {
                  Navigator.pop(ctx);
                  _pickVideo(ImageSource.gallery);
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

  void _removeSelectedVideo() {
    setState(() {
      _selectedVideoBytes = null;
      _selectedVideoName = null;
    });
  }

  void _sendMessage() async {
    final text = _msgController.text.trim();
    if ((text.isEmpty && _selectedImageBytes == null && _selectedVideoBytes == null) || _isTyping || _isUploadingMedia) return;

    final imageBytesToSend = _selectedImageBytes;
    final imageNameToSend = _selectedImageName ?? 'incident_photo.jpg';
    final videoBytesToSend = _selectedVideoBytes;
    final videoNameToSend = _selectedVideoName ?? 'incident_video.mp4';

    // Clear draft state
    _msgController.clear();
    setState(() {
      _selectedImageBytes = null;
      _selectedImageName = null;
      _selectedVideoBytes = null;
      _selectedVideoName = null;
      _isTyping = true;
    });

    final api = Provider.of<ApiService>(context, listen: false);
    String? uploadedPhotoUrl;
    String? uploadedVideoUrl;

    if (imageBytesToSend != null) {
      setState(() => _isUploadingMedia = true);
      final uploadRes = await api.uploadImage(imageBytesToSend, imageNameToSend);
      setState(() => _isUploadingMedia = false);

      if (uploadRes['success'] == true) {
        uploadedPhotoUrl = uploadRes['photo_url'];
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(uploadRes['error'] ?? "Failed to upload image."),
            backgroundColor: AppColors.criticalRed,
          ),
        );
      }
    }

    if (videoBytesToSend != null) {
      setState(() => _isUploadingMedia = true);
      final uploadRes = await api.uploadVideo(videoBytesToSend, videoNameToSend);
      setState(() => _isUploadingMedia = false);

      if (uploadRes['success'] == true) {
        uploadedVideoUrl = uploadRes['video_url'];
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(uploadRes['error'] ?? "Failed to upload video."),
            backgroundColor: AppColors.criticalRed,
          ),
        );
      }
    }

    String displayContent = text;
    if (displayContent.isEmpty) {
      if (uploadedVideoUrl != null) {
        displayContent = "🎥 Attached incident video footage";
      } else if (uploadedPhotoUrl != null) {
        displayContent = "📸 Attached incident photo";
      }
    }

    setState(() {
      _messages.add({
        "role": "user",
        "content": displayContent,
        "photo_url": uploadedPhotoUrl,
        "photo_bytes": imageBytesToSend,
        "video_url": uploadedVideoUrl,
        "video_name": videoNameToSend,
      });
    });
    _scrollToBottom();

    final history = _messages.take(_messages.length - 1)
        .map((m) => {"role": m["role"]!.toString(), "content": m["content"]!.toString()})
        .toList();

    final response = await api.chatWithAi(
      text.isNotEmpty ? text : (uploadedVideoUrl != null ? "I have attached an incident video." : "I have attached an incident photo."),
      history,
      photoUrl: uploadedPhotoUrl,
      videoUrl: uploadedVideoUrl,
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
        "video_url": null,
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
                          // Video preview badge if attached
                          if (msg["video_url"] != null) ...[
                            Container(
                              margin: const EdgeInsets.only(bottom: 8),
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                              decoration: BoxDecoration(
                                color: isUser ? Colors.white.withOpacity(0.18) : AppColors.safetyOrange.withOpacity(0.12),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: isUser ? Colors.white24 : AppColors.safetyOrange.withOpacity(0.3)),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.videocam_rounded, size: 20, color: isUser ? Colors.white : AppColors.safetyOrange),
                                  const SizedBox(width: 8),
                                  Text(
                                    msg["video_name"]?.toString() ?? "Incident Video Transmitted",
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                      color: isUser ? Colors.white : AppColors.charcoal,
                                    ),
                                  ),
                                ],
                              ),
                            ),
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

            // Combined Evidence Media Preview Bar (Photos & Videos)
            if (_selectedImageBytes != null || _selectedVideoBytes != null)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: const BoxDecoration(
                  color: AppColors.white,
                  border: Border(bottom: BorderSide(color: AppColors.borderLight)),
                ),
                child: Row(
                  children: [
                    if (_selectedImageBytes != null) ...[
                      Stack(
                        clipBehavior: Clip.none,
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Image.memory(
                              _selectedImageBytes!,
                              width: 50,
                              height: 50,
                              fit: BoxFit.cover,
                            ),
                          ),
                          Positioned(
                            top: -4,
                            right: -4,
                            child: GestureDetector(
                              onTap: _removeSelectedImage,
                              child: Container(
                                padding: const EdgeInsets.all(2),
                                decoration: const BoxDecoration(
                                  color: AppColors.criticalRed,
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(Icons.close, size: 12, color: Colors.white),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(width: 8),
                    ],
                    if (_selectedVideoBytes != null) ...[
                      Stack(
                        clipBehavior: Clip.none,
                        children: [
                          Container(
                            width: 50,
                            height: 50,
                            decoration: BoxDecoration(
                              color: AppColors.safetyOrange.withOpacity(0.12),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: AppColors.safetyOrange.withOpacity(0.3)),
                            ),
                            child: const Center(
                              child: Icon(Icons.play_circle_fill_rounded, color: AppColors.safetyOrange, size: 26),
                            ),
                          ),
                          Positioned(
                            top: -4,
                            right: -4,
                            child: GestureDetector(
                              onTap: _removeSelectedVideo,
                              child: Container(
                                padding: const EdgeInsets.all(2),
                                decoration: const BoxDecoration(
                                  color: AppColors.criticalRed,
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(Icons.close, size: 12, color: Colors.white),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(width: 8),
                    ],
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            (_selectedImageBytes != null && _selectedVideoBytes != null)
                                ? "Photo & Video attached"
                                : (_selectedImageBytes != null ? (_selectedImageName ?? "Incident Photo") : (_selectedVideoName ?? "Incident Video")),
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.charcoal),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            (_selectedImageBytes != null && _selectedVideoBytes != null)
                                ? "Both files ready for AI analysis"
                                : (_selectedImageBytes != null
                                    ? "Photo ready for AI analysis"
                                    : "${(_selectedVideoBytes!.lengthInBytes / (1024 * 1024)).toStringAsFixed(1)} MB • Video ready to upload"),
                            style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
                          ),
                        ],
                      ),
                    ),
                    TextButton(
                      onPressed: _showAttachmentPicker,
                      child: const Text("Change", style: TextStyle(fontSize: 12, color: AppColors.forestGreen, fontWeight: FontWeight.bold)),
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
                    icon: const Icon(Icons.add_photo_alternate_outlined, color: AppColors.forestGreen),
                    tooltip: "Attach Photo / Video",
                    onPressed: _showAttachmentPicker,
                  ),
                  Expanded(
                    child: TextField(
                      controller: _msgController,
                      decoration: InputDecoration(
                        hintText: (_selectedImageBytes != null || _selectedVideoBytes != null)
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
                    icon: _isUploadingMedia
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
