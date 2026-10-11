import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  int _currentStep = 0; // 0: Enter Details, 1: Verify OTP, 2: New Password, 3: Success

  // Step 1 Controllers
  final _enrollController = TextEditingController();
  final _mobileController = TextEditingController();

  // Step 2 Controller & Timer
  final _otpController = TextEditingController();
  Timer? _resendTimer;
  int _resendCountdown = 60;
  bool _canResend = false;
  String? _devOtpNotice;

  // Step 3 Controllers
  final _newPwdController = TextEditingController();
  final _confirmPwdController = TextEditingController();
  bool _hideNewPassword = true;
  bool _hideConfirmPassword = true;

  // State
  String _resetToken = "";
  bool _isLoading = false;
  String? _errorMessage;
  String? _infoMessage;

  @override
  void dispose() {
    _resendTimer?.cancel();
    _enrollController.dispose();
    _mobileController.dispose();
    _otpController.dispose();
    _newPwdController.dispose();
    _confirmPwdController.dispose();
    super.dispose();
  }

  void _startResendTimer() {
    _resendTimer?.cancel();
    setState(() {
      _resendCountdown = 60;
      _canResend = false;
    });
    _resendTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_resendCountdown > 1) {
        if (mounted) setState(() => _resendCountdown--);
      } else {
        timer.cancel();
        if (mounted) setState(() => _canResend = true);
      }
    });
  }

  // --- STEP 1: REQUEST OTP ---
  Future<void> _handleRequestOtp() async {
    final enroll = _enrollController.text.trim().toUpperCase();
    final mobile = _mobileController.text.trim();

    if (enroll.isEmpty || !enroll.startsWith("MUR")) {
      setState(() => _errorMessage = "Please enter a valid university enrollment number (e.g., MUR2500001).");
      return;
    }
    if (mobile.length != 10 || !RegExp(r'^[0-9]+$').hasMatch(mobile)) {
      setState(() => _errorMessage = "Please enter a valid 10-digit registered mobile number.");
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _infoMessage = null;
    });

    final api = Provider.of<ApiService>(context, listen: false);
    final res = await api.forgotPassword(enroll, mobile);

    if (!mounted) return;
    setState(() => _isLoading = false);

    if (res['success'] == true) {
      _startResendTimer();
      setState(() {
        _currentStep = 1;
        _infoMessage = res['message'] ?? "If the account exists, an OTP has been sent.";
        if (res['dev_otp'] != null) {
          _devOtpNotice = "Dev OTP: ${res['dev_otp']}";
        }
      });
    } else {
      setState(() => _errorMessage = res['error'] ?? "Failed to request verification code.");
    }
  }

  // --- RESEND OTP ---
  Future<void> _handleResendOtp() async {
    if (!_canResend || _isLoading) return;
    final enroll = _enrollController.text.trim().toUpperCase();
    final mobile = _mobileController.text.trim();

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final api = Provider.of<ApiService>(context, listen: false);
    final res = await api.forgotPassword(enroll, mobile);

    if (!mounted) return;
    setState(() => _isLoading = false);

    if (res['success'] == true) {
      _startResendTimer();
      setState(() {
        _infoMessage = "A new verification code has been dispatched.";
        if (res['dev_otp'] != null) {
          _devOtpNotice = "Dev OTP: ${res['dev_otp']}";
        }
      });
    } else {
      setState(() => _errorMessage = res['error'] ?? "Failed to resend code.");
    }
  }

  // --- STEP 2: VERIFY OTP ---
  Future<void> _handleVerifyOtp() async {
    final enroll = _enrollController.text.trim().toUpperCase();
    final otp = _otpController.text.trim();

    if (otp.length != 6 || !RegExp(r'^[0-9]+$').hasMatch(otp)) {
      setState(() => _errorMessage = "Please enter the 6-digit code received on your mobile.");
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final api = Provider.of<ApiService>(context, listen: false);
    final res = await api.verifyResetOtp(enroll, otp);

    if (!mounted) return;
    setState(() => _isLoading = false);

    if (res['success'] == true && res['reset_token'] != null) {
      setState(() {
        _resetToken = res['reset_token'];
        _currentStep = 2;
        _errorMessage = null;
        _infoMessage = null;
      });
    } else {
      setState(() => _errorMessage = res['error'] ?? "Incorrect or expired verification code.");
    }
  }

  // --- STEP 3: RESET PASSWORD ---
  Future<void> _handleResetPassword() async {
    final enroll = _enrollController.text.trim().toUpperCase();
    final newPwd = _newPwdController.text.trim();
    final confirmPwd = _confirmPwdController.text.trim();

    if (newPwd.length < 4) {
      setState(() => _errorMessage = "Password must be at least 4 characters.");
      return;
    }
    if (newPwd != confirmPwd) {
      setState(() => _errorMessage = "Passwords do not match.");
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final api = Provider.of<ApiService>(context, listen: false);
    final res = await api.resetPassword(enroll, _resetToken, newPwd);

    if (!mounted) return;
    setState(() => _isLoading = false);

    if (res['success'] == true) {
      setState(() => _currentStep = 3);
    } else {
      setState(() => _errorMessage = res['error'] ?? "Failed to update password.");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.warmIvory,
      appBar: AppBar(
        title: const Text('Password Recovery'),
        backgroundColor: AppColors.forestGreen,
        foregroundColor: AppColors.warmIvory,
        elevation: 0,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Step Progress Tracker
              if (_currentStep < 3) _buildStepProgress(),
              const SizedBox(height: 24),

              // Alert / Info Banners
              if (_errorMessage != null) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.criticalRed.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.criticalRed.withOpacity(0.3)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.error_outline, color: AppColors.criticalRed, size: 20),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          _errorMessage!,
                          style: const TextStyle(color: AppColors.criticalRed, fontSize: 13, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],

              if (_infoMessage != null && _errorMessage == null) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.forestGreen.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.forestGreen.withOpacity(0.3)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.info_outline, color: AppColors.forestGreen, size: 20),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          _infoMessage!,
                          style: const TextStyle(color: AppColors.forestGreen, fontSize: 13, fontWeight: FontWeight.w600),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],

              // Card Body based on current step
              Container(
                padding: const EdgeInsets.all(22),
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
                child: _buildCurrentStepContent(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStepProgress() {
    final steps = ["Identity", "Verify OTP", "New Password"];
    return Row(
      children: List.generate(steps.length, (idx) {
        final isActive = idx <= _currentStep;
        final isCurrent = idx == _currentStep;
        return Expanded(
          child: Row(
            children: [
              Expanded(
                child: Column(
                  children: [
                    Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: isCurrent
                            ? AppColors.safetyOrange
                            : isActive
                                ? AppColors.forestGreen
                                : AppColors.border,
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: isActive && !isCurrent
                            ? const Icon(Icons.check, size: 16, color: Colors.white)
                            : Text(
                                "${idx + 1}",
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                ),
                              ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      steps[idx],
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: isCurrent ? FontWeight.w800 : FontWeight.w600,
                        color: isCurrent ? AppColors.safetyOrange : AppColors.charcoal,
                      ),
                    ),
                  ],
                ),
              ),
              if (idx < steps.length - 1)
                Container(
                  width: 24,
                  height: 2,
                  color: idx < _currentStep ? AppColors.forestGreen : AppColors.border,
                ),
            ],
          ),
        );
      }),
    );
  }

  Widget _buildCurrentStepContent() {
    switch (_currentStep) {
      case 0:
        return _buildStep1Identity();
      case 1:
        return _buildStep2Otp();
      case 2:
        return _buildStep3NewPassword();
      case 3:
        return _buildStep4Success();
      default:
        return const SizedBox.shrink();
    }
  }

  // --- STEP 1 UI ---
  Widget _buildStep1Identity() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          "Identify Your Account",
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.forestGreen),
        ),
        const SizedBox(height: 6),
        const Text(
          "Enter your university enrollment number and registered 10-digit mobile number.",
          style: TextStyle(fontSize: 13, color: AppColors.textMuted, height: 1.35),
        ),
        const SizedBox(height: 20),
        TextField(
          controller: _enrollController,
          decoration: const InputDecoration(
            labelText: 'Enrollment Number',
            hintText: 'e.g., MUR2500001',
            prefixIcon: Icon(Icons.badge_outlined, color: AppColors.forestGreen),
          ),
        ),
        const SizedBox(height: 14),
        TextField(
          controller: _mobileController,
          keyboardType: TextInputType.phone,
          decoration: const InputDecoration(
            labelText: 'Registered Mobile Number',
            hintText: '10-digit mobile (e.g., 9000000001)',
            prefixIcon: Icon(Icons.phone_android, color: AppColors.forestGreen),
          ),
        ),
        const SizedBox(height: 24),
        SizedBox(
          height: 50,
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.forestGreen,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
            onPressed: _isLoading ? null : _handleRequestOtp,
            child: _isLoading
                ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                : const Text("Send Verification OTP", style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: Colors.white)),
          ),
        ),
      ],
    );
  }

  // --- STEP 2 UI ---
  Widget _buildStep2Otp() {
    final rawMob = _mobileController.text.trim();
    final maskedMob = rawMob.length >= 10 ? "${rawMob.substring(0, 2)}••••••${rawMob.substring(rawMob.length - 2)}" : rawMob;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          "Enter Verification Code",
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.forestGreen),
        ),
        const SizedBox(height: 6),
        Text(
          "A 6-digit OTP has been sent to your registered mobile $maskedMob. Valid for 5 minutes.",
          style: const TextStyle(fontSize: 13, color: AppColors.textMuted, height: 1.35),
        ),
        if (_devOtpNotice != null) ...[
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: AppColors.mutedSage.withOpacity(0.5),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              _devOtpNotice!,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.forestGreen),
            ),
          ),
        ],
        const SizedBox(height: 20),
        TextField(
          controller: _otpController,
          keyboardType: TextInputType.number,
          textAlign: TextAlign.center,
          maxLength: 6,
          style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900, letterSpacing: 8, color: AppColors.forestGreen),
          decoration: const InputDecoration(
            labelText: '6-Digit OTP',
            hintText: '000000',
            counterText: '',
            prefixIcon: Icon(Icons.lock_clock, color: AppColors.forestGreen),
          ),
        ),
        const SizedBox(height: 20),
        SizedBox(
          height: 50,
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.forestGreen,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
            onPressed: _isLoading ? null : _handleVerifyOtp,
            child: _isLoading
                ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                : const Text("Verify OTP Code", style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: Colors.white)),
          ),
        ),
        const SizedBox(height: 16),
        Center(
          child: _canResend
              ? TextButton.icon(
                  icon: const Icon(Icons.refresh, size: 18, color: AppColors.safetyOrange),
                  label: const Text("Resend Code", style: TextStyle(color: AppColors.safetyOrange, fontWeight: FontWeight.w800)),
                  onPressed: _isLoading ? null : _handleResendOtp,
                )
              : Text(
                  "Resend code in $_resendCountdown seconds",
                  style: const TextStyle(fontSize: 12, color: AppColors.textMuted, fontWeight: FontWeight.w600),
                ),
        ),
      ],
    );
  }

  // --- STEP 3 UI ---
  Widget _buildStep3NewPassword() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          "Set New Password",
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.forestGreen),
        ),
        const SizedBox(height: 6),
        const Text(
          "Choose a secure new password for your Mewar Guardian account.",
          style: TextStyle(fontSize: 13, color: AppColors.textMuted, height: 1.35),
        ),
        const SizedBox(height: 20),
        TextField(
          controller: _newPwdController,
          obscureText: _hideNewPassword,
          decoration: InputDecoration(
            labelText: 'New Password',
            hintText: 'Minimum 4 characters',
            prefixIcon: const Icon(Icons.lock_outline, color: AppColors.forestGreen),
            suffixIcon: IconButton(
              icon: Icon(_hideNewPassword ? Icons.visibility_off_outlined : Icons.visibility_outlined, color: AppColors.textMuted),
              onPressed: () => setState(() => _hideNewPassword = !_hideNewPassword),
            ),
          ),
        ),
        const SizedBox(height: 14),
        TextField(
          controller: _confirmPwdController,
          obscureText: _hideConfirmPassword,
          decoration: InputDecoration(
            labelText: 'Confirm New Password',
            prefixIcon: const Icon(Icons.lock_reset, color: AppColors.forestGreen),
            suffixIcon: IconButton(
              icon: Icon(_hideConfirmPassword ? Icons.visibility_off_outlined : Icons.visibility_outlined, color: AppColors.textMuted),
              onPressed: () => setState(() => _hideConfirmPassword = !_hideConfirmPassword),
            ),
          ),
        ),
        const SizedBox(height: 24),
        SizedBox(
          height: 50,
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.forestGreen,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
            onPressed: _isLoading ? null : _handleResetPassword,
            child: _isLoading
                ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                : const Text("Save & Update Password", style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: Colors.white)),
          ),
        ),
      ],
    );
  }

  // --- STEP 4 SUCCESS UI ---
  Widget _buildStep4Success() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(
          width: 72,
          height: 72,
          decoration: BoxDecoration(
            color: AppColors.mutedSage.withOpacity(0.5),
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.check_circle_outline, color: AppColors.forestGreen, size: 48),
        ),
        const SizedBox(height: 18),
        const Text(
          "Password Reset Complete!",
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: AppColors.forestGreen),
        ),
        const SizedBox(height: 10),
        const Text(
          "Your password has been securely updated in the campus safety database. Please sign in with your new password.",
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 13, color: AppColors.charcoal, height: 1.4),
        ),
        const SizedBox(height: 24),
        SizedBox(
          width: double.infinity,
          height: 48,
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.forestGreen,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
            onPressed: () => Navigator.pop(context),
            child: const Text("Back to Sign In", style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: Colors.white)),
          ),
        ),
      ],
    );
  }
}
