import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';
import 'auth_screen.dart';
import 'home_screen.dart';
import 'my_emergencies_screen.dart';
import 'safety_info_screen.dart';

class ProfileScreen extends StatefulWidget {
  final bool isFirstTime;
  const ProfileScreen({super.key, this.isFirstTime = false});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _nameController = TextEditingController();
  final _mobileController = TextEditingController();
  final _enrollController = TextEditingController();
  final _devUrlController = TextEditingController();

  bool _isLoading = false;
  int _devTapCount = 0;

  @override
  void initState() {
    super.initState();
    final api = Provider.of<ApiService>(context, listen: false);
    _nameController.text = api.studentName;
    _mobileController.text = api.mobileNumber;
    _enrollController.text = api.enrollmentNumber;
    _devUrlController.text = api.baseUrl;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _mobileController.dispose();
    _enrollController.dispose();
    _devUrlController.dispose();
    super.dispose();
  }

  void _saveProfile() async {
    final name = _nameController.text.trim();
    final mobile = _mobileController.text.trim();
    final enroll = _enrollController.text.trim().toUpperCase();

    if (name.isEmpty || mobile.isEmpty || enroll.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('All profile fields are required.'),
          backgroundColor: AppColors.criticalRed,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);
    final api = Provider.of<ApiService>(context, listen: false);
    await api.saveProfile(name, mobile, enroll);
    setState(() => _isLoading = false);

    if (widget.isFirstTime && mounted) {
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const HomeScreen()));
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('✅ Student profile saved and synced!'),
          backgroundColor: AppColors.forestGreen,
        ),
      );
    }
  }

  void _confirmLogout() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.white,
        title: const Text("Sign Out", style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.forestGreen)),
        content: const Text(
          "Are you sure you want to sign out? Your local session on this device will be cleared.",
          style: TextStyle(color: AppColors.charcoal),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("Cancel", style: TextStyle(color: AppColors.textMuted)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.forestGreen),
            onPressed: () async {
              Navigator.pop(ctx);
              final api = Provider.of<ApiService>(context, listen: false);
              await api.logout();
              if (mounted) {
                Navigator.pushAndRemoveUntil(
                  context,
                  MaterialPageRoute(builder: (_) => const AuthScreen()),
                  (route) => false,
                );
              }
            },
            child: const Text("Sign Out", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _confirmClearLocalData() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.white,
        title: const Text("Clear Local App Data", style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.forestGreen)),
        content: const Text(
          "This will reset all locally stored session data and cached drafts on this device.\n\nNote: University emergency records and security audit logs on the campus server will remain securely preserved according to safety policy.",
          style: TextStyle(color: AppColors.charcoal, height: 1.35),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("Cancel", style: TextStyle(color: AppColors.textMuted)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.criticalRed),
            onPressed: () async {
              Navigator.pop(ctx);
              final api = Provider.of<ApiService>(context, listen: false);
              await api.clearLocalData();
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text("Local app data cleared."),
                    backgroundColor: AppColors.forestGreen,
                  ),
                );
                Navigator.pushAndRemoveUntil(
                  context,
                  MaterialPageRoute(builder: (_) => const AuthScreen()),
                  (route) => false,
                );
              }
            },
            child: const Text("Clear Data", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _showDeleteAccountDialog() {
    final pwdController = TextEditingController();
    String? errorText;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) => AlertDialog(
          backgroundColor: AppColors.white,
          title: const Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: AppColors.criticalRed),
              SizedBox(width: 8),
              Text("Delete Account", style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.criticalRed)),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                "This action permanently deletes your student profile from the database. Please enter your password to confirm:",
                style: TextStyle(color: AppColors.charcoal, fontSize: 13),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: pwdController,
                obscureText: true,
                decoration: InputDecoration(
                  labelText: 'Confirm Password',
                  errorText: errorText,
                  prefixIcon: const Icon(Icons.lock_outline, color: AppColors.forestGreen),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text("Cancel", style: TextStyle(color: AppColors.textMuted)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.criticalRed),
              onPressed: () async {
                final pwd = pwdController.text.trim();
                if (pwd.isEmpty) {
                  setModalState(() => errorText = "Password is required");
                  return;
                }
                final api = Provider.of<ApiService>(context, listen: false);
                final res = await api.deleteAccount(pwd);
                if (!mounted) return;
                if (res['success'] == true) {
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text("Account deleted successfully."),
                      backgroundColor: AppColors.forestGreen,
                    ),
                  );
                  Navigator.pushAndRemoveUntil(
                    context,
                    MaterialPageRoute(builder: (_) => const AuthScreen()),
                    (route) => false,
                  );
                } else {
                  setModalState(() => errorText = res['error'] ?? "Failed to delete account");
                }
              },
              child: const Text("Confirm Deletion", style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  void _onVersionTap() {
    _devTapCount++;
    if (_devTapCount >= 7) {
      _devTapCount = 0;
      _openDeveloperDiagnosticDialog();
    }
  }

  void _openDeveloperDiagnosticDialog() {
    final api = Provider.of<ApiService>(context, listen: false);
    _devUrlController.text = api.baseUrl;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.white,
        title: const Row(
          children: [
            Icon(Icons.developer_mode, color: AppColors.forestGreen),
            SizedBox(width: 8),
            Text("Diagnostics (Admin/Dev)", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.forestGreen)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Protected diagnostic mode for network configuration testing.",
              style: TextStyle(fontSize: 12, color: AppColors.textMuted),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _devUrlController,
              decoration: const InputDecoration(
                labelText: 'Target Backend URL',
                prefixIcon: Icon(Icons.link, color: AppColors.forestGreen),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("Close"),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.forestGreen),
            onPressed: () async {
              await api.setBaseUrl(_devUrlController.text.trim());
              final ok = await api.checkBackendHealth();
              if (!mounted) return;
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(ok ? "Diagnostics: Connected successfully." : "Diagnostics: Connection unavailable."),
                  backgroundColor: ok ? AppColors.forestGreen : AppColors.criticalRed,
                ),
              );
            },
            child: const Text("Apply & Probe", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final api = Provider.of<ApiService>(context);

    final maskedPhone = api.mobileNumber.length >= 10
        ? "${api.mobileNumber.substring(0, 2)}••••••${api.mobileNumber.substring(api.mobileNumber.length - 2)}"
        : api.mobileNumber;

    return Scaffold(
      backgroundColor: AppColors.warmIvory,
      appBar: AppBar(
        title: const Text('Student Profile & Settings'),
        backgroundColor: AppColors.forestGreen,
        foregroundColor: AppColors.warmIvory,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 18.0, vertical: 20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Avatar & Badge
              Container(
                width: 84,
                height: 84,
                decoration: BoxDecoration(
                  color: AppColors.forestGreen,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.forestGreen.withOpacity(0.2),
                      blurRadius: 15,
                      offset: const Offset(0, 5),
                    ),
                  ],
                ),
                child: const Icon(Icons.person, size: 48, color: AppColors.warmIvory),
              ),
              const SizedBox(height: 12),
              Text(
                api.studentName.isNotEmpty ? api.studentName : 'Student Profile',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  color: AppColors.charcoal,
                ),
              ),
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.mutedSage,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  api.isLoggedIn ? "VERIFIED STUDENT" : "CAMPUS USER",
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: AppColors.forestGreen,
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // CARD 1: STUDENT DETAILS & EDIT
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: AppColors.white,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: AppColors.border),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.forestGreen.withOpacity(0.03),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          "STUDENT IDENTITY",
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: AppColors.forestGreen),
                        ),
                        Icon(Icons.verified_user, color: AppColors.forestGreen, size: 18),
                      ],
                    ),
                    const SizedBox(height: 14),
                    TextField(
                      controller: _nameController,
                      decoration: const InputDecoration(
                        labelText: 'Full Name',
                        prefixIcon: Icon(Icons.person_outline, color: AppColors.forestGreen),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _mobileController,
                      keyboardType: TextInputType.phone,
                      decoration: InputDecoration(
                        labelText: 'Mobile Number',
                        helperText: maskedPhone.isNotEmpty ? "Registered: $maskedPhone" : null,
                        prefixIcon: const Icon(Icons.phone_android, color: AppColors.forestGreen),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _enrollController,
                      decoration: const InputDecoration(
                        labelText: 'Enrollment Number (e.g., MUR2500001)',
                        prefixIcon: Icon(Icons.badge_outlined, color: AppColors.forestGreen),
                      ),
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      height: 46,
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _saveProfile,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.forestGreen,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        child: _isLoading
                            ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                            : const Text('Update Profile', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white)),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // CARD 2: QUICK STUDENT ACTIONS
              Container(
                decoration: BoxDecoration(
                  color: AppColors.white,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: AppColors.border),
                ),
                child: Column(
                  children: [
                    ListTile(
                      leading: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(color: AppColors.mutedSage.withOpacity(0.5), shape: BoxShape.circle),
                        child: const Icon(Icons.history_rounded, color: AppColors.forestGreen, size: 20),
                      ),
                      title: const Text("My Emergency Reports", style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                      subtitle: const Text("View past submitted alerts and live responder status", style: TextStyle(fontSize: 12)),
                      trailing: const Icon(Icons.chevron_right, color: AppColors.textMuted),
                      onTap: () {
                        Navigator.push(context, MaterialPageRoute(builder: (_) => const MyEmergenciesScreen()));
                      },
                    ),
                    const Divider(height: 1, indent: 60),
                    ListTile(
                      leading: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(color: AppColors.safetyOrange.withOpacity(0.12), shape: BoxShape.circle),
                        child: const Icon(Icons.menu_book, color: AppColors.safetyOrange, size: 20),
                      ),
                      title: const Text("Safety Protocols & Guidelines", style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                      subtitle: const Text("Campus security helpline and emergency procedures", style: TextStyle(fontSize: 12)),
                      trailing: const Icon(Icons.chevron_right, color: AppColors.textMuted),
                      onTap: () {
                        Navigator.push(context, MaterialPageRoute(builder: (_) => const SafetyInfoScreen()));
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // CARD 3: PRIVACY & SESSION MANAGEMENT
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
                      "PRIVACY & ACCOUNT SETTINGS",
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: AppColors.forestGreen),
                    ),
                    const SizedBox(height: 14),
                    // Sign Out Button
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size.fromHeight(44),
                        side: const BorderSide(color: AppColors.forestGreen),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      icon: const Icon(Icons.logout, size: 18, color: AppColors.forestGreen),
                      label: const Text("Sign Out of Account", style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.forestGreen)),
                      onPressed: _confirmLogout,
                    ),
                    const SizedBox(height: 10),
                    // Clear Local Data Button
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size.fromHeight(44),
                        side: const BorderSide(color: AppColors.border),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      icon: const Icon(Icons.cleaning_services_outlined, size: 18, color: AppColors.charcoal),
                      label: const Text("Clear Local Device Session", style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.charcoal)),
                      onPressed: _confirmClearLocalData,
                    ),
                    const SizedBox(height: 10),
                    // Account Deletion
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size.fromHeight(44),
                        side: BorderSide(color: AppColors.criticalRed.withOpacity(0.5)),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      icon: const Icon(Icons.delete_outline, size: 18, color: AppColors.criticalRed),
                      label: const Text("Delete Account & Profile", style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.criticalRed)),
                      onPressed: _showDeleteAccountDialog,
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      "Policy Notice: Clearing local data resets your login session on this phone. Authentic safety incident records remain archived on university servers per campus safety governance.",
                      style: TextStyle(fontSize: 11, color: AppColors.textMuted, height: 1.3),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Clean System Status & Version
              GestureDetector(
                onTap: _onVersionTap,
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: api.isConnected ? const Color(0xFF4ADE80) : AppColors.criticalRed,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          api.isConnected ? "Campus Network Connected" : "Connection Unavailable",
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: api.isConnected ? AppColors.forestGreen : AppColors.criticalRed,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      "Mewar Guardian v2.1.0 • Mohanlal Sukhadia University / Mewar",
                      style: TextStyle(fontSize: 11, color: AppColors.textMuted),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}
