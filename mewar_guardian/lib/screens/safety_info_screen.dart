import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class SafetyInfoScreen extends StatelessWidget {
  const SafetyInfoScreen({super.key});

  Widget _buildSafetyCard(String title, IconData icon, Color iconColor, List<String> points) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: iconColor.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: iconColor, size: 22),
              ),
              const SizedBox(width: 12),
              Text(
                title,
                style: const TextStyle(color: AppColors.charcoal, fontWeight: FontWeight.w800, fontSize: 16),
              ),
            ],
          ),
          const SizedBox(height: 14),
          ...points.map((p) => Padding(
            padding: const EdgeInsets.only(bottom: 8.0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text("• ", style: TextStyle(color: AppColors.forestGreen, fontSize: 16, fontWeight: FontWeight.bold)),
                Expanded(child: Text(p, style: const TextStyle(color: AppColors.charcoal, fontSize: 13, height: 1.3))),
              ],
            ),
          )),
        ],
      ),
    );
  }

  Widget _buildContactCard(String title, String value, {bool isPhone = false}) {
    return Container(
      width: 160,
      margin: const EdgeInsets.only(right: 12, bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(color: AppColors.textMuted, fontSize: 10, fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              color: isPhone ? AppColors.forestGreen : AppColors.charcoal,
              fontWeight: FontWeight.w800,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.warmIvory,
      appBar: AppBar(
        title: const Text('Campus Safety Protocols'),
        backgroundColor: AppColors.forestGreen,
        foregroundColor: AppColors.warmIvory,
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _buildSafetyCard("Medical Emergencies", Icons.medical_services, AppColors.criticalRed, [
              "Stay calm and call for help or tap SOS immediately.",
              "Do not move the injured person unless there is imminent environmental danger.",
              "Check breathing and responsiveness.",
              "Mewar Campus Health Center: Next to Main Administrative Building.",
            ]),

            _buildSafetyCard("Fire Safety & Evacuation", Icons.local_fire_department, AppColors.safetyOrange, [
              "Evacuate immediately via designated staircases; NEVER use elevators.",
              "Close doors behind you to contain fire and smoke spread.",
              "Use Mewar Guardian to transmit the exact building and floor location.",
              "Assemble at primary campus assembly grounds.",
            ]),

            _buildSafetyCard("Security Threats & Harassment", Icons.security, AppColors.forestGreen, [
              "Move toward populated, well-lit campus zones or security checkpoints.",
              "Report suspicious activity immediately via the SOS portal.",
              "Campus Security Guard Room is stationed at the Main Gate 24/7.",
              "Strict anti-harassment policy is enforced campus-wide.",
            ]),

            const SizedBox(height: 12),
            const Text(
              "EMERGENCY CONTACTS",
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, letterSpacing: 0.8, color: AppColors.forestGreen),
            ),
            const SizedBox(height: 12),
            Wrap(
              children: [
                _buildContactCard("CAMPUS SECURITY", "+91 1477 229900", isPhone: true),
                _buildContactCard("CAMPUS HOSPITAL", "Health Center", isPhone: false),
                _buildContactCard("POLICE CONTROL", "112", isPhone: true),
                _buildContactCard("AMBULANCE", "108", isPhone: true),
                _buildContactCard("FIRE BRIGADE", "101", isPhone: true),
                _buildContactCard("WOMEN HELPLINE", "1090", isPhone: true),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
