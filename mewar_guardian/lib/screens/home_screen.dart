import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';
import 'report_screen.dart';
import 'map_screen.dart';
import 'ai_chat_screen.dart';
import 'safety_info_screen.dart';
import 'profile_screen.dart';
import 'my_emergencies_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<ApiService>(context, listen: false).checkBackendHealth();
    });
  }

  @override
  Widget build(BuildContext context) {
    final api = Provider.of<ApiService>(context);

    return Scaffold(
      backgroundColor: AppColors.warmIvory,
      appBar: AppBar(
        backgroundColor: AppColors.forestGreen,
        elevation: 0,
        titleSpacing: 16,
        title: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: AppColors.deepGreen,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.mutedSage.withOpacity(0.4)),
              ),
              child: const Icon(Icons.shield, color: AppColors.safetyOrange, size: 22),
            ),
            const SizedBox(width: 10),
            const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'MEWAR GUARDIAN',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.8,
                    color: AppColors.warmIvory,
                  ),
                ),
                Text(
                  'Campus Safety & Emergency Response',
                  style: TextStyle(fontSize: 10, color: AppColors.mutedSage),
                ),
              ],
            ),
          ],
        ),
        actions: [
          // Backend connectivity pill
          Container(
            margin: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: api.isConnected ? AppColors.deepGreen : AppColors.criticalRed.withOpacity(0.2),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: api.isConnected ? AppColors.mutedSage : AppColors.criticalRed,
                width: 1,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 7,
                  height: 7,
                  decoration: BoxDecoration(
                    color: api.isConnected ? const Color(0xFF4ADE80) : AppColors.criticalRed,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  api.isConnected ? 'LIVE' : 'OFFLINE',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: api.isConnected ? AppColors.warmIvory : AppColors.criticalRed,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.account_circle_outlined, color: AppColors.warmIvory, size: 26),
            onPressed: () {
              Navigator.push(context, MaterialPageRoute(builder: (_) => const ProfileScreen()));
            },
          ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
          children: [
            // Student Welcome & Location Banner
            _buildWelcomeCard(api),
            const SizedBox(height: 18),

            // PRIMARY EMERGENCY ACTION: SAFETY ORANGE SOS BUTTON
            _buildPrimarySosButton(context),
            const SizedBox(height: 20),

            // QUICK EMERGENCY CATEGORIES
            _buildSectionHeader("QUICK EMERGENCY REPORT"),
            const SizedBox(height: 10),
            _buildQuickCategoryGrid(context),
            const SizedBox(height: 20),

            // CAMPUS SAFETY SERVICES (Map, AI Assistant, Guidelines)
            _buildSectionHeader("CAMPUS SAFETY SERVICES"),
            const SizedBox(height: 10),
            _buildServicesGrid(context),
            const SizedBox(height: 20),

            // 24/7 HELPLINE FOOTER CARD
            _buildHotlineCard(),
          ],
        ),
      ),
    );
  }

  Widget _buildWelcomeCard(ApiService api) {
    final maskedPhone = api.mobileNumber.length >= 10
        ? "${api.mobileNumber.substring(0, 2)}••••••${api.mobileNumber.substring(api.mobileNumber.length - 2)}"
        : "";

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: AppColors.forestGreen.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  api.studentName.isNotEmpty ? api.studentName : 'Mewar University Student',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: AppColors.charcoal,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  api.enrollmentNumber.isNotEmpty
                      ? "Enrollment: ${api.enrollmentNumber}"
                      : "Campus Visitor / Guest",
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.forestGreen),
                ),
                if (maskedPhone.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    "Verified Mobile: $maskedPhone",
                    style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
                  ),
                ],
                const SizedBox(height: 6),
                const Row(
                  children: [
                    Icon(Icons.location_on, color: AppColors.forestGreen, size: 14),
                    SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        "Mewar University Main Campus",
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.charcoal),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: AppColors.mutedSage,
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Column(
              children: [
                Icon(Icons.shield_outlined, color: AppColors.forestGreen, size: 22),
                SizedBox(height: 2),
                Text("SECURED", style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: AppColors.forestGreen)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPrimarySosButton(BuildContext context) {
    return GestureDetector(
      onTap: () {
        Navigator.push(context, MaterialPageRoute(builder: (_) => const ReportScreen()));
      },
      child: Container(
        height: 140,
        decoration: BoxDecoration(
          color: AppColors.safetyOrange,
          borderRadius: BorderRadius.circular(22),
          boxShadow: [
            BoxShadow(
              color: AppColors.safetyOrange.withOpacity(0.38),
              blurRadius: 18,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Stack(
          children: [
            Positioned(
              right: -15,
              bottom: -15,
              child: Icon(
                Icons.warning_amber_rounded,
                size: 140,
                color: Colors.white.withOpacity(0.15),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(22.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppColors.white.withOpacity(0.2),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.emergency_share, color: AppColors.white, size: 28),
                      ),
                      const SizedBox(width: 14),
                      const Expanded(
                        child: Text(
                          "REPORT EMERGENCY (SOS)",
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0.8,
                            color: AppColors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    "Tap to immediately alert Mewar Campus Security with your campus building or GPS location.",
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.white,
                      height: 1.35,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickCategoryGrid(BuildContext context) {
    final quickItems = [
      {'title': 'Medical Aid', 'icon': Icons.medical_services, 'color': AppColors.criticalRed, 'cat': 'Medical Emergency'},
      {'title': 'Fire Alert', 'icon': Icons.local_fire_department, 'color': AppColors.safetyOrange, 'cat': 'Fire'},
      {'title': 'Campus Security', 'icon': Icons.security, 'color': AppColors.forestGreen, 'cat': 'Security Issue'},
      {'title': 'Accident', 'icon': Icons.car_crash, 'color': AppColors.safetyOrange, 'cat': 'Accident'},
      {'title': 'Threat Alert', 'icon': Icons.warning_rounded, 'color': AppColors.criticalRed, 'cat': 'Threat'},
      {'title': 'Harassment', 'icon': Icons.shield, 'color': AppColors.deepGreen, 'cat': 'Harassment'},
      {'title': 'Other Issue', 'icon': Icons.emergency, 'color': AppColors.charcoal, 'cat': 'Other'},
    ];

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: quickItems.map((item) {
        final double itemWidth = (MediaQuery.of(context).size.width - 32 - 16) / 3.05;
        return SizedBox(
          width: itemWidth,
          child: InkWell(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => ReportScreen(initialCategory: item['cat'] as String),
                ),
              );
            },
            borderRadius: BorderRadius.circular(14),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 6),
              decoration: BoxDecoration(
                color: AppColors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.border),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.forestGreen.withOpacity(0.02),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: (item['color'] as Color).withOpacity(0.12),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(item['icon'] as IconData, color: item['color'] as Color, size: 20),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    item['title'] as String,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: AppColors.charcoal,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildServicesGrid(BuildContext context) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _buildServiceTile(
                title: "Campus Map & Directory",
                subtitle: "33 verified locations",
                icon: Icons.map,
                iconColor: AppColors.forestGreen,
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const CampusMapScreen())),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildServiceTile(
                title: "Rakshak AI Assistant",
                subtitle: "Safety guidance 24/7",
                icon: Icons.smart_toy_outlined,
                iconColor: AppColors.safetyOrange,
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AiChatScreen())),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildServiceTile(
                title: "My Submitted Reports",
                subtitle: "Live status & history",
                icon: Icons.history_rounded,
                iconColor: AppColors.forestGreen,
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const MyEmergenciesScreen())),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildServiceTile(
                title: "Safety Protocols",
                subtitle: "Guidelines & contacts",
                icon: Icons.menu_book,
                iconColor: AppColors.safetyOrange,
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SafetyInfoScreen())),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildServiceTile({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color iconColor,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: iconColor.withOpacity(0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: iconColor, size: 24),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: AppColors.charcoal,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHotlineCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.deepGreen,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.white.withOpacity(0.12),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.phone_in_talk, color: AppColors.safetyOrange, size: 24),
          ),
          const SizedBox(width: 14),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "24/7 Campus Security Hotline",
                  style: TextStyle(color: AppColors.warmIvory, fontWeight: FontWeight.w800, fontSize: 13),
                ),
                SizedBox(height: 2),
                Text(
                  "Direct line: +91 1477-229900 (Mewar Security)",
                  style: TextStyle(color: AppColors.mutedSage, fontSize: 11),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w800,
        letterSpacing: 1.1,
        color: AppColors.forestGreen,
      ),
    );
  }
}
