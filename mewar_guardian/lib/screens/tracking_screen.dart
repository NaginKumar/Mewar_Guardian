import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';

class TrackingScreen extends StatefulWidget {
  final int emergencyId;
  final Map<String, dynamic> initialData;

  const TrackingScreen({
    super.key,
    required this.emergencyId,
    required this.initialData,
  });

  @override
  State<TrackingScreen> createState() => _TrackingScreenState();
}

class _TrackingScreenState extends State<TrackingScreen> {
  Map<String, dynamic>? _data;
  bool _isLoading = false;
  bool _isStale = false;
  Timer? _pollTimer;

  final List<String> _stages = [
    'Pending',
    'Dispatched',
    'On the Way',
    'Arrived',
    'Resolved',
  ];

  @override
  void initState() {
    super.initState();
    _data = Map.from(widget.initialData);
    // 3-second rapid polling ensures real-time live synchronization with command center
    _pollTimer = Timer.periodic(const Duration(seconds: 3), (_) => _refreshStatus());
    WidgetsBinding.instance.addPostFrameCallback((_) => _refreshStatus());
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }

  Future<void> _refreshStatus() async {
    if (!mounted) return;
    try {
      final api = Provider.of<ApiService>(context, listen: false);
      final update = await api.getEmergencyById(widget.emergencyId);
      if (mounted) {
        if (update != null && update.isNotEmpty) {
          final oldStatus = _data?['status']?.toString() ?? widget.initialData['status']?.toString() ?? 'Pending';
          final newStatus = update['status']?.toString() ?? oldStatus;

          if (_currentStageIndex(newStatus) > _currentStageIndex(oldStatus) && mounted) {
            final stageName = _stages[_currentStageIndex(newStatus)];
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Row(
                  children: [
                    const Icon(Icons.shield_sharp, color: Colors.white, size: 20),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        "Live Update: Security status is now $stageName!",
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
                backgroundColor: AppColors.forestGreen,
                duration: const Duration(seconds: 4),
                behavior: SnackBarBehavior.floating,
              ),
            );
          }

          setState(() {
            _data = {
              ...widget.initialData,
              ...update,
              if ((update['student_name'] == null || update['student_name'].toString().isEmpty) && widget.initialData['student_name'] != null)
                'student_name': widget.initialData['student_name'],
              if ((update['mobile_number'] == null || update['mobile_number'].toString().isEmpty) && widget.initialData['mobile_number'] != null)
                'mobile_number': widget.initialData['mobile_number'],
              if ((update['emergency_type'] == null || update['emergency_type'] == 'Confidential Report') && widget.initialData['emergency_type'] != null)
                'emergency_type': widget.initialData['emergency_type'],
              if ((update['description'] == null || update['description'].toString().contains('Details hidden')) && widget.initialData['description'] != null)
                'description': widget.initialData['description'],
            };
            _isStale = false;
          });
        } else {
          setState(() => _isStale = true);
        }
      }
    } catch (_) {
      if (mounted) setState(() => _isStale = true);
    }
  }

  int _currentStageIndex(String? rawStatus) {
    if (rawStatus == null || rawStatus.trim().isEmpty) return 0;
    final s = rawStatus.trim().toLowerCase().replaceAll(RegExp(r'[\s_\-]+'), ' ');
    if (s.contains('resolve') || s.contains('close') || s.contains('complete')) return 4;
    if (s.contains('arrive') || s.contains('reach')) return 3;
    if (s.contains('way') || s.contains('route') || s.contains('transit') || s.contains('progress')) return 2;
    if (s.contains('dispatch') || s.contains('assigned') || s.contains('accept')) return 1;
    return 0; // Default to Pending
  }

  Color _getStatusColor(String? status) {
    final idx = _currentStageIndex(status);
    switch (idx) {
      case 1: return const Color(0xFF2563EB); // Dispatched (Blue)
      case 2: return AppColors.safetyOrange; // On the Way (Orange)
      case 3: return const Color(0xFF0D9488); // Arrived (Teal)
      case 4: return const Color(0xFF16A34A); // Resolved (Green)
      default: return const Color(0xFFD97706); // Pending (Amber)
    }
  }

  @override
  Widget build(BuildContext context) {
    final d = _data ?? widget.initialData;
    final status = d['status']?.toString() ?? 'Pending';
    final stageIdx = _currentStageIndex(status);
    final emergencyType = d['emergency_type']?.toString() ?? 'Emergency';
    final location = d['location']?.toString() ?? 'Campus Reference';
    final priority = d['priority']?.toString() ?? 'HIGH';
    final responder = d['responder']?.toString() ?? 'Campus Security Team';
    final estMinutes = d['estimated_minutes'];
    final recommendation = d['recommendation']?.toString() ?? '';
    final timeStr = d['time']?.toString() ?? '';

    return Scaffold(
      backgroundColor: AppColors.warmIvory,
      appBar: AppBar(
        title: Text('Emergency Incident #${widget.emergencyId}'),
        backgroundColor: AppColors.forestGreen,
        foregroundColor: AppColors.warmIvory,
        actions: [
          _isLoading
              ? const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16.0),
                  child: SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.warmIvory),
                  ),
                )
              : IconButton(
                  icon: const Icon(Icons.refresh),
                  onPressed: () {
                    setState(() => _isLoading = true);
                    _refreshStatus().then((_) {
                      if (mounted) setState(() => _isLoading = false);
                    });
                  },
                ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Stale indicator if connection lost
            if (_isStale)
              Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.safetyOrange.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppColors.safetyOrange),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.wifi_off, size: 16, color: AppColors.safetyOrange),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        "Showing last known status. Reconnecting to security dispatch...",
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.charcoal),
                      ),
                    ),
                  ],
                ),
              ),

            // INCIDENT OVERVIEW CARD
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: AppColors.white,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: AppColors.border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppColors.forestGreen,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          "INCIDENT #${widget.emergencyId}",
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.warmIvory),
                        ),
                      ),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: _getStatusColor(status),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              _stages[stageIdx].toUpperCase(),
                              style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: Colors.white),
                            ),
                          ),
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: priority == 'CRITICAL'
                                  ? AppColors.criticalRed
                                  : AppColors.safetyOrange,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              priority.toUpperCase(),
                              style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: Colors.white),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Text(
                    emergencyType,
                    style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: AppColors.charcoal),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      const Icon(Icons.location_on, size: 16, color: AppColors.forestGreen),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          location,
                          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.charcoal),
                        ),
                      ),
                    ],
                  ),
                  if (timeStr.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text("Reported at: $timeStr", style: const TextStyle(fontSize: 12, color: AppColors.textMuted)),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 16),

            // RESPONSE LIFECYCLE TIMELINE
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: AppColors.white,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: AppColors.border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    "RESPONSE PROGRESS",
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, letterSpacing: 0.8, color: AppColors.forestGreen),
                  ),
                  const SizedBox(height: 16),
                  ..._stages.asMap().entries.map((entry) {
                    final idx = entry.key;
                    final stageName = entry.value;
                    final isCompleted = idx <= stageIdx;
                    final isCurrent = idx == stageIdx;
                    final isLast = idx == _stages.length - 1;

                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Column(
                          children: [
                            Container(
                              width: 24,
                              height: 24,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: isCompleted ? AppColors.forestGreen : AppColors.warmIvory,
                                border: Border.all(
                                  color: isCompleted ? AppColors.forestGreen : AppColors.border,
                                  width: 2,
                                ),
                              ),
                              child: isCompleted
                                  ? const Icon(Icons.check, size: 14, color: AppColors.white)
                                  : null,
                            ),
                            if (!isLast)
                              Container(
                                width: 2,
                                height: 32,
                                color: idx < stageIdx ? AppColors.forestGreen : AppColors.border,
                              ),
                          ],
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.only(top: 2.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  stageName,
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: isCurrent ? FontWeight.w900 : (isCompleted ? FontWeight.w700 : FontWeight.w500),
                                    color: isCurrent ? AppColors.forestGreen : (isCompleted ? AppColors.charcoal : AppColors.textMuted),
                                  ),
                                ),
                                if (isCurrent)
                                  Text(
                                    _getStageDescription(stageName),
                                    style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
                                  ),
                                const SizedBox(height: 16),
                              ],
                            ),
                          ),
                        ),
                      ],
                    );
                  }),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // ASSIGNED RESPONDER & ETA CARD
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: AppColors.white,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: AppColors.border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    "ASSIGNED RESPONDER TEAM",
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, letterSpacing: 0.8, color: AppColors.forestGreen),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: AppColors.mutedSage,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Icons.shield, color: AppColors.forestGreen, size: 24),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              responder,
                              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: AppColors.charcoal),
                            ),
                            if (estMinutes != null && estMinutes > 0)
                              Text(
                                "Estimated Arrival: ~$estMinutes minutes",
                                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.safetyOrange),
                              )
                            else
                              const Text(
                                "Dispatch status: Active response",
                                style: TextStyle(fontSize: 12, color: AppColors.textMuted),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            // SINGLE COMBINED EVIDENCE MEDIA CARD (PHASE 3)
            const SizedBox(height: 16),
            Builder(
              builder: (context) {
                final photoUrl = _data?['photo_url']?.toString();
                final videoUrl = _data?['video_url']?.toString();
                final hasPhoto = photoUrl != null && photoUrl.isNotEmpty;
                final hasVideo = videoUrl != null && videoUrl.isNotEmpty;

                return Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.white,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.perm_media_outlined, color: AppColors.forestGreen, size: 18),
                          const SizedBox(width: 8),
                          const Text(
                            "EVIDENCE MEDIA (PHOTOS & VIDEOS)",
                            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: AppColors.forestGreen),
                          ),
                          const Spacer(),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppColors.warmIvory,
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: AppColors.border),
                            ),
                            child: Text(
                              (hasPhoto && hasVideo) ? "2 items" : ((hasPhoto || hasVideo) ? "1 item" : "No media"),
                              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.textMuted),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      if (!hasPhoto && !hasVideo) ...[
                        // Clean empty state inside the same card
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
                          decoration: BoxDecoration(
                            color: AppColors.warmIvory.withOpacity(0.5),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: AppColors.border),
                          ),
                          child: const Column(
                            children: [
                              Icon(Icons.photo_outlined, size: 30, color: AppColors.textMuted),
                              SizedBox(height: 6),
                              Text(
                                "No photo or video evidence was attached to this alert.",
                                style: TextStyle(fontSize: 12, color: AppColors.textMuted),
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
                        ),
                      ] else ...[
                        // Photos and videos displayed together inside the card
                        if (hasPhoto) ...[
                          ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: Image.network(
                              photoUrl,
                              width: double.infinity,
                              height: 180,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => const Text("Attached photo uploaded to safety records.", style: TextStyle(fontSize: 12, color: AppColors.textMuted)),
                            ),
                          ),
                        ],
                        if (hasPhoto && hasVideo) const SizedBox(height: 12),
                        if (hasVideo) ...[
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: AppColors.safetyOrange.withOpacity(0.08),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: AppColors.safetyOrange.withOpacity(0.3)),
                            ),
                            child: const Row(
                              children: [
                                Icon(Icons.play_circle_fill_rounded, color: AppColors.safetyOrange, size: 34),
                                SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        "Incident Video Transmitted",
                                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.charcoal),
                                      ),
                                      SizedBox(height: 2),
                                      Text(
                                        "Stored in secure safety media storage for command center",
                                        style: TextStyle(fontSize: 11, color: AppColors.textMuted),
                                      ),
                                    ],
                                  ),
                                ),
                                Icon(Icons.check_circle, color: AppColors.successGreen, size: 20),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ],
                  ),
                );
              },
            ),

            if (recommendation.isNotEmpty) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.mutedSage.withOpacity(0.5),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.forestGreen.withOpacity(0.3)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.lightbulb_outline, color: AppColors.forestGreen, size: 18),
                        SizedBox(width: 6),
                        Text(
                          "SAFETY GUIDANCE",
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: AppColors.forestGreen),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      recommendation,
                      style: const TextStyle(fontSize: 13, color: AppColors.charcoal, height: 1.35),
                    ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 24),
            // DIRECT CALL SECURITY BUTTON
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.forestGreen,
                  foregroundColor: AppColors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                icon: const Icon(Icons.phone_in_talk, size: 20),
                label: const Text(
                  "CALL CAMPUS SECURITY DIRECTLY",
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                ),
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('📞 Calling Campus Security Dispatch: 01477-229900'),
                      backgroundColor: AppColors.forestGreen,
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _getStageDescription(String stage) {
    switch (stage) {
      case 'Pending': return 'Received by command center. Assigning response unit.';
      case 'Dispatched': return 'Emergency response team has been dispatched.';
      case 'On the Way': return 'Team is en route to the reported campus location.';
      case 'Arrived': return 'Responders have arrived at the scene.';
      case 'Resolved': return 'Situation resolved and campus safety restored.';
      default: return '';
    }
  }
}
