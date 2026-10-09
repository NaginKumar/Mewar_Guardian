import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import '../config/campus_locations_data.dart';
import '../models/campus_location.dart';

class ApiService extends ChangeNotifier {
  // Production URL (Deployed on Render)
  static const String productionUrl  = "https://mewar-guardian.onrender.com";

  // Development URLs
  static const String defaultLocalUrl = "http://127.0.0.1:5000";
  static const String defaultLanUrl   = "http://10.168.143.130:5000";
  static const String defaultNgrokUrl = "https://upturned-wispy-comply.ngrok-free.dev";

  String baseUrl = productionUrl;
  bool isConnected = false;
  String studentName = "";
  String mobileNumber = "";
  String enrollmentNumber = "";
  String role = "Student";
  bool isLoggedIn = false;

  List<CampusLocation> _cachedLocations = CampusLocationsData.allLocations;
  List<CampusLocation> get cachedLocations => _cachedLocations;

  ApiService() {
    _init();
  }

  Future<void> _init() async {
    await loadProfile();
    await checkBackendHealth();
    await syncOfflineEmergencies();
  }

  Future<void> loadProfile() async {
    final prefs = await SharedPreferences.getInstance();
    studentName = prefs.getString('name') ?? '';
    mobileNumber = prefs.getString('mobile') ?? '';
    enrollmentNumber = prefs.getString('enrollment') ?? '';
    role = prefs.getString('role') ?? 'Student';
    isLoggedIn = prefs.getBool('is_logged_in') ?? false;

    // Session is only active if verified credentials exist and is_logged_in flag is true
    if (studentName.isEmpty || enrollmentNumber.isEmpty) {
      isLoggedIn = false;
    }
    
    // Load custom baseUrl if saved (strictly enforce production in release builds)
    final savedUrl = prefs.getString('custom_base_url');
    if (savedUrl != null && savedUrl.isNotEmpty) {
      if (kReleaseMode && (savedUrl.contains('127.0.0.1') || savedUrl.contains('localhost') || savedUrl.contains('10.0.2.2'))) {
        baseUrl = productionUrl;
        await prefs.setString('custom_base_url', productionUrl);
      } else {
        baseUrl = savedUrl;
      }
    } else {
      baseUrl = productionUrl;
    }
    notifyListeners();
  }

  Future<void> _persistStudent(String name, String mobile, String enrollment, String roleStr) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('name', name);
    await prefs.setString('mobile', mobile);
    await prefs.setString('enrollment', enrollment);
    await prefs.setString('role', roleStr);
    await prefs.setBool('is_logged_in', true);
    studentName = name;
    mobileNumber = mobile;
    enrollmentNumber = enrollment;
    role = roleStr;
    isLoggedIn = true;
    notifyListeners();
  }

  Future<Map<String, dynamic>> register(String name, String mobile, String enrollment, String password) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/api/register'),
        headers: {'Content-Type': 'application/json', 'ngrok-skip-browser-warning': 'true'},
        body: jsonEncode({
          "name": name.trim(),
          "mobile": mobile.trim(),
          "enrollment": enrollment.trim().toUpperCase(),
          "password": password.trim(),
        }),
      ).timeout(const Duration(seconds: 8));

      final body = jsonDecode(response.body);
      if (response.statusCode == 201 && body['success'] == true) {
        final student = body['student'] ?? {};
        await _persistStudent(
          student['student_name'] ?? name,
          student['mobile_number'] ?? mobile,
          student['enrollment_number'] ?? enrollment.toUpperCase(),
          student['role'] ?? 'Student',
        );
        return {"success": true, "message": body['message'] ?? 'Registered successfully'};
      } else {
        return {"success": false, "error": body['error'] ?? 'Registration failed. Please try again.'};
      }
    } catch (e) {
      return {"success": false, "error": "Connection unavailable. Please verify backend connection."};
    }
  }

  Future<Map<String, dynamic>> login(String identifier, String password) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/api/login'),
        headers: {'Content-Type': 'application/json', 'ngrok-skip-browser-warning': 'true'},
        body: jsonEncode({
          "identifier": identifier.trim(),
          "password": password.trim(),
        }),
      ).timeout(const Duration(seconds: 8));

      final body = jsonDecode(response.body);
      if (response.statusCode == 200 && body['success'] == true) {
        final student = body['student'] ?? {};
        await _persistStudent(
          student['student_name'] ?? '',
          student['mobile_number'] ?? '',
          student['enrollment_number'] ?? identifier.toUpperCase(),
          student['role'] ?? 'Student',
        );
        return {"success": true, "student": student};
      } else {
        return {"success": false, "error": body['error'] ?? 'Invalid credentials.'};
      }
    } catch (e) {
      return {"success": false, "error": "Connection unavailable. Please verify backend connection."};
    }
  }

  Future<void> logout() async {
    try {
      await http.post(
        Uri.parse('$baseUrl/api/logout'),
        headers: {'Content-Type': 'application/json', 'ngrok-skip-browser-warning': 'true'},
      ).timeout(const Duration(seconds: 3));
    } catch (_) {}

    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('name');
    await prefs.remove('mobile');
    await prefs.remove('enrollment');
    await prefs.remove('role');
    await prefs.setBool('is_logged_in', false);

    studentName = "";
    mobileNumber = "";
    enrollmentNumber = "";
    role = "Student";
    isLoggedIn = false;
    notifyListeners();
  }

  Future<void> clearLocalData() async {
    final prefs = await SharedPreferences.getInstance();
    final customUrl = prefs.getString('custom_base_url');
    await prefs.clear();
    if (customUrl != null) {
      await prefs.setString('custom_base_url', customUrl);
    }
    studentName = "";
    mobileNumber = "";
    enrollmentNumber = "";
    role = "Student";
    isLoggedIn = false;
    notifyListeners();
  }

  Future<Map<String, dynamic>> deleteAccount(String password) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/api/account/delete'),
        headers: {'Content-Type': 'application/json', 'ngrok-skip-browser-warning': 'true'},
        body: jsonEncode({
          "enrollment": enrollmentNumber,
          "password": password.trim(),
        }),
      ).timeout(const Duration(seconds: 8));

      final body = jsonDecode(response.body);
      if (response.statusCode == 200 && body['success'] == true) {
        await logout();
        return {"success": true, "message": body['message'] ?? 'Account deleted successfully.'};
      } else {
        return {"success": false, "error": body['error'] ?? 'Could not delete account.'};
      }
    } catch (e) {
      return {"success": false, "error": "Connection unavailable. Please retry."};
    }
  }

  Future<Map<String, dynamic>> forgotPassword(String enrollment, String mobile) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/api/auth/forgot-password'),
        headers: {'Content-Type': 'application/json', 'ngrok-skip-browser-warning': 'true'},
        body: jsonEncode({
          "enrollment": enrollment.trim().toUpperCase(),
          "mobile": mobile.trim(),
        }),
      ).timeout(const Duration(seconds: 8));

      final body = jsonDecode(response.body);
      if (response.statusCode == 200 && body['success'] == true) {
        return {
          "success": true,
          "message": body['message'] ?? 'OTP sent to registered mobile.',
          "dev_otp": body['dev_otp'],
        };
      } else {
        return {
          "success": false,
          "error": body['error'] ?? 'Could not initiate password recovery.',
        };
      }
    } catch (e) {
      return {"success": false, "error": "Connection unavailable. Please verify connection and retry."};
    }
  }

  Future<Map<String, dynamic>> verifyResetOtp(String enrollment, String otp) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/api/auth/verify-reset-otp'),
        headers: {'Content-Type': 'application/json', 'ngrok-skip-browser-warning': 'true'},
        body: jsonEncode({
          "enrollment": enrollment.trim().toUpperCase(),
          "otp": otp.trim(),
        }),
      ).timeout(const Duration(seconds: 8));

      final body = jsonDecode(response.body);
      if (response.statusCode == 200 && body['success'] == true) {
        return {
          "success": true,
          "message": body['message'] ?? 'Verification successful.',
          "reset_token": body['reset_token'],
        };
      } else {
        return {
          "success": false,
          "error": body['error'] ?? 'Invalid verification code.',
        };
      }
    } catch (e) {
      return {"success": false, "error": "Connection unavailable. Please retry."};
    }
  }

  Future<Map<String, dynamic>> resetPassword(String enrollment, String resetToken, String newPassword) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/api/auth/reset-password'),
        headers: {'Content-Type': 'application/json', 'ngrok-skip-browser-warning': 'true'},
        body: jsonEncode({
          "enrollment": enrollment.trim().toUpperCase(),
          "reset_token": resetToken.trim(),
          "new_password": newPassword.trim(),
        }),
      ).timeout(const Duration(seconds: 8));

      final body = jsonDecode(response.body);
      if (response.statusCode == 200 && body['success'] == true) {
        return {
          "success": true,
          "message": body['message'] ?? 'Password updated successfully.',
        };
      } else {
        return {
          "success": false,
          "error": body['error'] ?? 'Failed to update password.',
        };
      }
    } catch (e) {
      return {"success": false, "error": "Connection unavailable. Please retry."};
    }
  }

  Future<List<Map<String, dynamic>>> getMyEmergencies() async {
    try {
      final ident = enrollmentNumber.isNotEmpty ? enrollmentNumber : mobileNumber;
      if (ident.isEmpty) return [];
      final response = await http.get(
        Uri.parse('$baseUrl/api/my-emergencies?enrollment=$ident'),
        headers: {'ngrok-skip-browser-warning': 'true'},
      ).timeout(const Duration(seconds: 6));

      if (response.statusCode == 200) {
        final body = jsonDecode(response.body);
        if (body is Map && body['emergencies'] is List) {
          return List<Map<String, dynamic>>.from(body['emergencies']);
        }
      }
    } catch (e) {
      if (kDebugMode) print('getMyEmergencies error: $e');
    }
    return [];
  }

  Future<void> saveProfile(String name, String mobile, String enrollment) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('name', name);
    await prefs.setString('mobile', mobile);
    await prefs.setString('enrollment', enrollment);
    studentName = name;
    mobileNumber = mobile;
    enrollmentNumber = enrollment;

    // Sync with backend database
    try {
      await http.post(
        Uri.parse('$baseUrl/api/profile'),
        headers: {'Content-Type': 'application/json', 'ngrok-skip-browser-warning': 'true'},
        body: jsonEncode({
          "name": name,
          "mobile": mobile,
          "enrollment": enrollment,
        }),
      ).timeout(const Duration(seconds: 4));
    } catch (e) {
      if (kDebugMode) print('Failed to sync profile: $e');
    }

    notifyListeners();
  }

  Future<void> setBaseUrl(String newUrl) async {
    final clean = newUrl.trim().replaceAll(RegExp(r'/+$'), '');
    if (clean.isEmpty || clean.toLowerCase() == 'default') {
      baseUrl = productionUrl;
    } else if (kReleaseMode && (clean.contains('127.0.0.1') || clean.contains('localhost') || clean.contains('10.0.2.2'))) {
      baseUrl = productionUrl;
    } else {
      baseUrl = clean;
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('custom_base_url', baseUrl);
    await checkBackendHealth();
    notifyListeners();
  }

  Future<bool> checkBackendHealth() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/api/health'),
        headers: {'ngrok-skip-browser-warning': 'true'},
      ).timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        isConnected = true;
        notifyListeners();
        return true;
      }
    } catch (_) {}

    // Only probe local LAN in debug mode if explicitly targeting local dev
    if (!kReleaseMode && baseUrl == defaultLocalUrl) {
      try {
        final r = await http.get(
          Uri.parse('$defaultLanUrl/api/health'),
          headers: {'ngrok-skip-browser-warning': 'true'},
        ).timeout(const Duration(seconds: 2));
        if (r.statusCode == 200) {
          baseUrl = defaultLanUrl;
          isConnected = true;
          notifyListeners();
          return true;
        }
      } catch (_) {}
    }

    isConnected = false;
    notifyListeners();
    return false;
  }

  /// Get campus locations with immediate bundled fallback.
  /// NEVER returns empty or gets stuck on loading.
  Future<List<CampusLocation>> getLocations() async {
    // Return bundled fallback baseline if empty
    if (_cachedLocations.isEmpty) {
      _cachedLocations = CampusLocationsData.allLocations;
    }

    try {
      final response = await http.get(
        Uri.parse('$baseUrl/api/locations'),
        headers: {'ngrok-skip-browser-warning': 'true'},
      ).timeout(const Duration(seconds: 4));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data != null && data['locations'] is List) {
          final list = (data['locations'] as List)
              .map((item) => CampusLocation.fromJson(item))
              .toList();
          if (list.isNotEmpty) {
            _cachedLocations = list;
            isConnected = true;
            notifyListeners();
            return _cachedLocations;
          }
        }
      }
    } catch (e) {
      if (kDebugMode) print('Locations fetch remote fallback: $e');
    }

    // Always return the valid 33 locations
    return _cachedLocations;
  }

  bool _isSubmittingEmergency = false;

  /// Submits an emergency report with idempotency, validation, and offline queue.
  Future<Map<String, dynamic>> submitEmergency(Map<String, dynamic> data) async {
    if (_isSubmittingEmergency) {
      return {
        "error": "Emergency transmission already in progress. Please wait a moment.",
        "error_type": "in_progress",
      };
    }
    _isSubmittingEmergency = true;

    try {
      // Enrich with authenticated student identity and idempotency key
      data['student_name'] = data['student_name'] ?? studentName;
      data['mobile_number'] = data['mobile_number'] ?? mobileNumber;
      data['enrollment_number'] = data['enrollment_number'] ?? enrollmentNumber;
      data['timestamp'] = DateTime.now().toIso8601String();
      data['client_request_id'] = "${DateTime.now().millisecondsSinceEpoch}_${studentName.hashCode}";

      // Check device connectivity
      try {
        final connectivityResult = await (Connectivity().checkConnectivity());
        if (connectivityResult.contains(ConnectivityResult.none) && !connectivityResult.any((r) => r != ConnectivityResult.none)) {
          return await _queueOffline(data, "Device is offline. Report stored locally in emergency queue.");
        }
      } catch (_) {}

      try {
        final response = await http.post(
          Uri.parse('$baseUrl/api/emergency'),
          headers: {
            'Content-Type': 'application/json',
            'ngrok-skip-browser-warning': 'true',
          },
          body: jsonEncode(data),
        ).timeout(const Duration(seconds: 12));

        isConnected = true;

        if (response.statusCode == 200 || response.statusCode == 201) {
          final body = jsonDecode(response.body);
          if (body is Map<String, dynamic> && (body['success'] == true || body.containsKey('emergency_id'))) {
            // Trigger background sync of any previously queued reports
            unawaited(syncOfflineEmergencies());
            return body;
          }
        }

        try {
          final body = jsonDecode(response.body);
          if (body is Map && body.containsKey('error')) {
            return {
              "error": body['error'] ?? "Server error occurred.",
              "error_type": "server_rejected",
            };
          }
        } catch (_) {}

        return {
          "error": "Server returned status code ${response.statusCode}.",
          "error_type": "server_error",
        };
      } catch (e) {
        if (kDebugMode) print('submitEmergency network exception: $e');
        isConnected = false;
        return await _queueOffline(data, "Cannot reach safety server ($baseUrl). Report saved locally in offline queue.");
      }
    } finally {
      _isSubmittingEmergency = false;
    }
  }

  Future<Map<String, dynamic>> _queueOffline(Map<String, dynamic> data, String reason) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      List<String> offlineQueue = prefs.getStringList('offline_emergencies') ?? [];
      offlineQueue.add(jsonEncode(data));
      await prefs.setStringList('offline_emergencies', offlineQueue);
      return {
        "offline": true,
        "message": reason,
        "queued_count": offlineQueue.length,
      };
    } catch (e) {
      return {
        "error": "Failed to queue emergency offline: $e",
        "error_type": "local_storage_error",
      };
    }
  }

  Future<void> syncOfflineEmergencies() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      List<String> offlineQueue = prefs.getStringList('offline_emergencies') ?? [];
      if (offlineQueue.isEmpty) return;

      List<String> remainingQueue = [];
      for (String dataStr in offlineQueue) {
        try {
          final response = await http.post(
            Uri.parse('$baseUrl/api/emergency'),
            headers: {'Content-Type': 'application/json', 'ngrok-skip-browser-warning': 'true'},
            body: dataStr,
          ).timeout(const Duration(seconds: 6));

          if (response.statusCode != 200 && response.statusCode != 201) {
            remainingQueue.add(dataStr);
          }
        } catch (_) {
          remainingQueue.add(dataStr);
        }
      }
      await prefs.setStringList('offline_emergencies', remainingQueue);
      if (remainingQueue.length != offlineQueue.length) {
        notifyListeners();
      }
    } catch (_) {}
  }

  Future<Map<String, dynamic>?> getEmergencyById(int emergencyId) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/api/emergency/$emergencyId'),
        headers: {'ngrok-skip-browser-warning': 'true'},
      ).timeout(const Duration(seconds: 6));

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
    } catch (e) {
      if (kDebugMode) print('getEmergencyById error: $e');
    }
    return null;
  }

  Future<Map<String, dynamic>?> chatWithAi(String message, List<Map<String, String>> history) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/api/chat'),
        headers: {
          'Content-Type': 'application/json',
          'ngrok-skip-browser-warning': 'true',
        },
        body: jsonEncode({"message": message, "history": history}),
      ).timeout(const Duration(seconds: 12));

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
    } catch (e) {
      if (kDebugMode) print('chatWithAi error: $e');
    }
    return null;
  }
}
