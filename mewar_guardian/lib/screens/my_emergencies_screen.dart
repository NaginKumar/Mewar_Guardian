import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';
import 'tracking_screen.dart';

class MyEmergenciesScreen extends StatefulWidget {
  const MyEmergenciesScreen({super.key});

  @override
  State<MyEmergenciesScreen> createState() => _MyEmergenciesScreenState();
}

class _MyEmergenciesScreenState extends State<MyEmergenciesScreen> {
  bool _isLoading = true;
  List<Map<String, dynamic>> _reports = [];

  @override
  void initState() {
    super.initState();
    _fetchEmergencies();
  }

  Future<void> _fetchEmergencies() async {
    setState(() => _isLoading = true);
    final api = Provider.of<ApiService>(context, listen: false);
    final data = await api.getMyEmergencies();
    if (mounted) {
      setState(() {
        _reports = data;
        _isLoading = false;
      });
    }
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'pending':
        return AppColors.safetyOrange;
      case 'dispatched':
        return const Color(0xFF2563EB); // Royal Blue
      case 'on the way':
        return AppColors.deepGreen;
      case 'arrived':
        return AppColors.forestGreen;
      case 'resolved':
        return const Color(0xFF16A34A); // Success Green
      default:
        return AppColors.charcoal;
    }
  }

  IconData _getTypeIcon(String type) {
    final t = type.toLowerCase();
    if (t.contains('medical')) return Icons.medical_services;
    if (t.contains('fire')) return Icons.local_fire_department;
    if (t.contains('security')) return Icons.security;
    if (t.contains('accident')) return Icons.car_crash;
    if (t.contains('threat')) return Icons.warning_amber_rounded;
    if (t.contains('harass')) return Icons.shield;
    return Icons.emergency;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.warmIvory,
      appBar: AppBar(
        title: const Text('My Emergency Reports'),
        backgroundColor: AppColors.forestGreen,
        foregroundColor: AppColors.warmIvory,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _fetchEmergencies,
            tooltip: 'Refresh reports',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.forestGreen),
            )
          : RefreshIndicator(
              onRefresh: _fetchEmergencies,
              color: AppColors.forestGreen,
              child: _reports.isEmpty
                  ? ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      children: [
                        SizedBox(height: MediaQuery.of(context).size.height * 0.25),
                        Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Container(
                                width: 72,
                                height: 72,
                                decoration: BoxDecoration(
                                  color: AppColors.mutedSage.withOpacity(0.4),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.shield_outlined,
                                  size: 38,
                                  color: AppColors.forestGreen,
                                ),
                              ),
                              const SizedBox(height: 16),
                              const Text(
                                "No Emergency Reports",
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.forestGreen,
                                ),
                              ),
                              const SizedBox(height: 8),
                              const Padding(
                                padding: EdgeInsets.symmetric(horizontal: 40),
                                child: Text(
                                  "You have not submitted any emergency alerts. If you face any danger or medical crisis, use the SOS button.",
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: AppColors.textMuted,
                                    height: 1.4,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: _reports.length,
                      itemBuilder: (ctx, idx) {
                        final item = _reports[idx];
                        final status = (item['status'] ?? 'Pending').toString();
                        final statusColor = _getStatusColor(status);
                        final type = (item['emergency_type'] ?? 'Emergency').toString();
                        final loc = (item['location'] ?? 'Campus').toString();
                        final timeStr = (item['time'] ?? '').toString();
                        final id = item['id'];

                        return Card(
                          margin: const EdgeInsets.only(bottom: 14),
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                            side: const BorderSide(color: AppColors.border),
                          ),
                          color: AppColors.white,
                          child: InkWell(
                            borderRadius: BorderRadius.circular(16),
                            onTap: () {
                              if (id != null) {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => TrackingScreen(
                                      emergencyId: id is int ? id : int.tryParse(id.toString()) ?? 1,
                                      initialData: item,
                                    ),
                                  ),
                                );
                              }
                            },
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(8),
                                        decoration: BoxDecoration(
                                          color: statusColor.withOpacity(0.12),
                                          shape: BoxShape.circle,
                                        ),
                                        child: Icon(
                                          _getTypeIcon(type),
                                          size: 20,
                                          color: statusColor,
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              "Incident #${id ?? idx + 1} • $type",
                                              style: const TextStyle(
                                                fontSize: 15,
                                                fontWeight: FontWeight.w800,
                                                color: AppColors.charcoal,
                                              ),
                                            ),
                                            if (timeStr.isNotEmpty)
                                              Text(
                                                timeStr,
                                                style: const TextStyle(
                                                  fontSize: 11,
                                                  color: AppColors.textMuted,
                                                ),
                                              ),
                                          ],
                                        ),
                                      ),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: statusColor.withOpacity(0.12),
                                          borderRadius: BorderRadius.circular(12),
                                          border: Border.all(color: statusColor.withOpacity(0.4)),
                                        ),
                                        child: Text(
                                          status.toUpperCase(),
                                          style: TextStyle(
                                            fontSize: 10,
                                            fontWeight: FontWeight.w800,
                                            color: statusColor,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 12),
                                  Row(
                                    children: [
                                      const Icon(Icons.location_on_outlined, size: 16, color: AppColors.forestGreen),
                                      const SizedBox(width: 6),
                                      Expanded(
                                        child: Text(
                                          loc,
                                          style: const TextStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w600,
                                            color: AppColors.forestGreen,
                                          ),
                                        ),
                                      ),
                                      const Icon(Icons.chevron_right, color: AppColors.textMuted),
                                    ],
                                  ),
                                  if (item['responder'] != null && item['responder'].toString().isNotEmpty) ...[
                                    const SizedBox(height: 8),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                      decoration: BoxDecoration(
                                        color: AppColors.warmIvory,
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Row(
                                        children: [
                                          const Icon(Icons.shield, size: 14, color: AppColors.forestGreen),
                                          const SizedBox(width: 6),
                                          Text(
                                            "Assigned: ${item['responder']}",
                                            style: const TextStyle(
                                              fontSize: 12,
                                              fontWeight: FontWeight.w600,
                                              color: AppColors.charcoal,
                                            ),
                                          ),
                                          if (item['estimated_minutes'] != null) ...[
                                            const Spacer(),
                                            Text(
                                              "ETA ~${item['estimated_minutes']} min",
                                              style: const TextStyle(
                                                fontSize: 11,
                                                fontWeight: FontWeight.bold,
                                                color: AppColors.safetyOrange,
                                              ),
                                            ),
                                          ],
                                        ],
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
            ),
    );
  }
}
