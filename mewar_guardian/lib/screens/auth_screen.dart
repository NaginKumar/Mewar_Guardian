import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';
import 'home_screen.dart';
import 'report_screen.dart';
import 'forgot_password_screen.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  // Login controllers
  final _loginIdController = TextEditingController();
  final _loginPwdController = TextEditingController();
  bool _loginHidePassword = true;
  bool _isLoginLoading = false;
  String? _loginError;

  // Register controllers
  final _regNameController = TextEditingController();
  final _regMobileController = TextEditingController();
  final _regEnrollController = TextEditingController();
  final _regEmailController = TextEditingController();
  final _regPwdController = TextEditingController();
  final _regConfirmPwdController = TextEditingController();
  bool _regHidePassword = true;
  bool _isRegLoading = false;
  String? _regError;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _loginIdController.dispose();
    _loginPwdController.dispose();
    _regNameController.dispose();
    _regMobileController.dispose();
    _regEnrollController.dispose();
    _regEmailController.dispose();
    _regPwdController.dispose();
    _regConfirmPwdController.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    final ident = _loginIdController.text.trim();
    final pwd = _loginPwdController.text.trim();

    if (ident.isEmpty || pwd.isEmpty) {
      setState(() => _loginError = "Please enter enrollment number/mobile and password.");
      return;
    }

    setState(() {
      _isLoginLoading = true;
      _loginError = null;
    });

    final api = Provider.of<ApiService>(context, listen: false);
    final res = await api.login(ident, pwd);

    if (!mounted) return;
    setState(() => _isLoginLoading = false);

    if (res['success'] == true) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const HomeScreen()),
      );
    } else {
      setState(() => _loginError = res['error'] ?? "Login failed. Please check credentials.");
    }
  }

  Future<void> _handleRegister() async {
    final name = _regNameController.text.trim();
    final mobile = _regMobileController.text.trim();
    final enroll = _regEnrollController.text.trim().toUpperCase();
    final email = _regEmailController.text.trim().toLowerCase();
    final pwd = _regPwdController.text.trim();
    final confirmPwd = _regConfirmPwdController.text.trim();

    if (name.length < 2) {
      setState(() => _regError = "Full name must be at least 2 characters.");
      return;
    }
    if (mobile.length != 10 || !RegExp(r'^[0-9]+$').hasMatch(mobile)) {
      setState(() => _regError = "Enter a valid 10-digit mobile number.");
      return;
    }
    if (!enroll.startsWith("MUR") || enroll.length < 5) {
      setState(() => _regError = "Enrollment number must start with MUR (e.g., MUR2500001).");
      return;
    }
    final emailRegex = RegExp(r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$');
    if (email.isNotEmpty && !emailRegex.hasMatch(email)) {
      setState(() => _regError = "Enter a valid university email address (e.g., student@mewaruniversity.org).");
      return;
    }
    if (pwd.length < 4) {
      setState(() => _regError = "Password must be at least 4 characters.");
      return;
    }
    if (pwd != confirmPwd) {
      setState(() => _regError = "Passwords do not match.");
      return;
    }

    setState(() {
      _isRegLoading = true;
      _regError = null;
    });

    final api = Provider.of<ApiService>(context, listen: false);
    final res = await api.register(name, mobile, enroll, pwd, email: email.isNotEmpty ? email : null);

    if (!mounted) return;
    setState(() => _isRegLoading = false);

    if (res['success'] == true) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("✅ Registration successful! Welcome to Mewar Guardian."),
          backgroundColor: AppColors.forestGreen,
        ),
      );
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const HomeScreen()),
      );
    } else {
      setState(() => _regError = res['error'] ?? "Registration failed.");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.warmIvory,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 12),
              // Header & Logo
              Center(
                child: Column(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(18),
                      child: Image.asset(
                        'assets/logo.png',
                        width: 68,
                        height: 68,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Container(
                          width: 68,
                          height: 68,
                          decoration: BoxDecoration(
                            color: AppColors.forestGreen,
                            borderRadius: BorderRadius.circular(18),
                          ),
                          child: const Icon(Icons.shield, color: AppColors.safetyOrange, size: 38),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      "MEWAR GUARDIAN",
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.8,
                        color: AppColors.forestGreen,
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      "Campus Safety & Emergency Response",
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Emergency Bypass Banner
              GestureDetector(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const ReportScreen()),
                  );
                },
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.safetyOrange.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppColors.safetyOrange.withOpacity(0.5)),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.warning_amber_rounded, color: AppColors.safetyOrange, size: 24),
                      SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              "IMMEDIATE EMERGENCY SOS",
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w800,
                                color: AppColors.safetyOrange,
                              ),
                            ),
                            Text(
                              "In active crisis? Tap here to send SOS without signing in.",
                              style: TextStyle(fontSize: 11, color: AppColors.charcoal),
                            ),
                          ],
                        ),
                      ),
                      Icon(Icons.arrow_forward_ios, size: 14, color: AppColors.safetyOrange),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // Tab Bar
              Container(
                decoration: BoxDecoration(
                  color: AppColors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppColors.border),
                ),
                child: TabBar(
                  controller: _tabController,
                  indicator: BoxDecoration(
                    color: AppColors.forestGreen,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  labelColor: AppColors.warmIvory,
                  unselectedLabelColor: AppColors.textMuted,
                  labelStyle: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
                  unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                  tabs: const [
                    Tab(text: "Sign In"),
                    Tab(text: "Register Student"),
                  ],
                ),
              ),
              const SizedBox(height: 18),

              // Tab Content Card
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: AppColors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppColors.border),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.forestGreen.withOpacity(0.04),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: SizedBox(
                  height: 380,
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      _buildLoginTab(),
                      _buildRegisterTab(),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLoginTab() {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            "Student Login",
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: AppColors.forestGreen,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            "Sign in with your university enrollment number or mobile.",
            style: TextStyle(fontSize: 12, color: AppColors.textMuted),
          ),
          const SizedBox(height: 16),
          if (_loginError != null) ...[
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.criticalRed.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.criticalRed.withOpacity(0.3)),
              ),
              child: Text(
                _loginError!,
                style: const TextStyle(color: AppColors.criticalRed, fontSize: 12, fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(height: 12),
          ],
          TextField(
            controller: _loginIdController,
            decoration: const InputDecoration(
              labelText: 'Enrollment Number / Mobile',
              hintText: 'e.g., MUR2500001 or 9000000001',
              prefixIcon: Icon(Icons.badge_outlined, color: AppColors.forestGreen),
            ),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _loginPwdController,
            obscureText: _loginHidePassword,
            decoration: InputDecoration(
              labelText: 'Password',
              prefixIcon: const Icon(Icons.lock_outline, color: AppColors.forestGreen),
              suffixIcon: IconButton(
                icon: Icon(
                  _loginHidePassword ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                  color: AppColors.textMuted,
                ),
                onPressed: () => setState(() => _loginHidePassword = !_loginHidePassword),
              ),
            ),
          ),
          const SizedBox(height: 6),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const ForgotPasswordScreen()),
                );
              },
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 2),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: const Text(
                "Forgot Password?",
                style: TextStyle(
                  color: AppColors.forestGreen,
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 48,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.forestGreen,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: _isLoginLoading ? null : _handleLogin,
              child: _isLoginLoading
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(color: AppColors.white, strokeWidth: 2),
                    )
                  : const Text(
                      "Sign In",
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: AppColors.white),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRegisterTab() {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            "New Student Registration",
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: AppColors.forestGreen,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            "Enter your university verified details to register.",
            style: TextStyle(fontSize: 12, color: AppColors.textMuted),
          ),
          const SizedBox(height: 12),
          if (_regError != null) ...[
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.criticalRed.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.criticalRed.withOpacity(0.3)),
              ),
              child: Text(
                _regError!,
                style: const TextStyle(color: AppColors.criticalRed, fontSize: 12, fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(height: 10),
          ],
          TextField(
            controller: _regNameController,
            decoration: const InputDecoration(
              labelText: 'Full Name',
              hintText: 'e.g., Aarav Sharma',
              prefixIcon: Icon(Icons.person_outline, color: AppColors.forestGreen),
            ),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _regMobileController,
            keyboardType: TextInputType.phone,
            decoration: const InputDecoration(
              labelText: 'Mobile Number',
              hintText: '10-digit number (e.g., 9000000001)',
              prefixIcon: Icon(Icons.phone_android, color: AppColors.forestGreen),
            ),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _regEnrollController,
            decoration: const InputDecoration(
              labelText: 'Enrollment Number',
              hintText: 'e.g., MUR2500001',
              prefixIcon: Icon(Icons.school_outlined, color: AppColors.forestGreen),
            ),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _regEmailController,
            keyboardType: TextInputType.emailAddress,
            decoration: const InputDecoration(
              labelText: 'University Email Address',
              hintText: 'e.g., student@mewaruniversity.org (For password recovery)',
              prefixIcon: Icon(Icons.email_outlined, color: AppColors.forestGreen),
            ),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _regPwdController,
            obscureText: _regHidePassword,
            decoration: InputDecoration(
              labelText: 'Password',
              prefixIcon: const Icon(Icons.lock_outline, color: AppColors.forestGreen),
              suffixIcon: IconButton(
                icon: Icon(
                  _regHidePassword ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                  color: AppColors.textMuted,
                ),
                onPressed: () => setState(() => _regHidePassword = !_regHidePassword),
              ),
            ),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _regConfirmPwdController,
            obscureText: _regHidePassword,
            decoration: const InputDecoration(
              labelText: 'Confirm Password',
              prefixIcon: Icon(Icons.lock_reset, color: AppColors.forestGreen),
            ),
          ),
          const SizedBox(height: 18),
          SizedBox(
            height: 48,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.forestGreen,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: _isRegLoading ? null : _handleRegister,
              child: _isRegLoading
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(color: AppColors.white, strokeWidth: 2),
                    )
                  : const Text(
                      "Register Account",
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: AppColors.white),
                    ),
            ),
          ),
          const SizedBox(height: 12),
        ],
      ),
    );
  }
}
