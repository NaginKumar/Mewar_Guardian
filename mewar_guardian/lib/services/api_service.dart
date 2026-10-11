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
  String connectionStatusDetail = "";
  String studentName = "";
  String mobileNumber = "";
  String enrollmentNumber = "";
  String studentEmail = "";
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
    studentEmail = prefs.getString('email') ?? '';
    role = prefs.getString('role') ?? 'Student';
    isLoggedIn = prefs.getBool('is_logged_in') ?? false;

    // Session is only active if verified credentials exist and is_logged_in flag is true
    if (studentName.isEmpty || enrollmentNumber.isEmpty) {
      isLoggedIn = false;
    }
    
    // Strictly enforce production HTTPS URL in release mode, and sanitize any stale LAN/local loopback
    if (kReleaseMode) {
      baseUrl = productionUrl;
      await prefs.setString('custom_base_url', productionUrl);
    } else {
      final savedUrl = prefs.getString('custom_base_url');
      if (savedUrl != null && savedUrl.isNotEmpty) {
        if (savedUrl.contains('127.0.0.1') || savedUrl.contains('localhost') || savedUrl.contains('10.0.2.2') || savedUrl.contains('10.168.') || savedUrl.contains('ngrok')) {
          baseUrl = productionUrl;
          await prefs.setString('custom_base_url', productionUrl);
        } else {
          baseUrl = savedUrl;
        }
      } else {
        baseUrl = productionUrl;
      }
    }
    notifyListeners();
  }

  String _parseErrorResponse(http.Response response, {String fallback = 'Request failed.'}) {
    try {
      final body = jsonDecode(response.body);
      if (body is Map && body['error'] != null && body['error'].toString().isNotEmpty) {
        return body['error'].toString();
      }
      if (body is Map && body['message'] != null && body['message'].toString().isNotEmpty) {
        return body['message'].toString();
      }
    } catch (_) {
      // Server returned non-JSON error page (e.g., Render 502 Bad Gateway / 503 Service Unavailable)
      if (response.statusCode >= 500) {
        return "Backend server is waking up or restarting (HTTP ${response.statusCode}). Please wait a few seconds and tap Retry.";
      }
    }
    return "$fallback (Status ${response.statusCode})";
  }

  String _classifyNetworkException(dynamic e) {
    final str = e.toString().toLowerCase();
    if (e is TimeoutException || str.contains('timeout')) {
      return "Backend server response timed out. The server is likely waking up from idle mode (Render cold start). Please tap Retry.";
    }
    if (str.contains('handshake') ||
        str.contains('certificate') ||
        str.contains('certpath') ||
        str.contains('trust anchor') ||
        str.contains('tlsexception') ||
        str.contains('ssl')) {
      return "Campus Wi-Fi portal (Mewar WIFI) is blocking secure connections. Please open your browser to log in to the Wi-Fi portal or switch to Mobile Data.";
    }
    if (str.contains('socketexception') || str.contains('failed host lookup') || str.contains('network is unreachable')) {
      return "Cannot reach campus safety server. Please verify your internet connection (Wi-Fi/Mobile Data) and tap Retry.";
    }
    if (str.contains('connection refused')) {
      return "Connection refused by server. The backend may be restarting, please tap Retry.";
    }
    if (str.contains('formatexception')) {
      return "Server returned an unexpected format. Campus safety service is restarting, please retry in a moment.";
    }
    return "Network error: ${e.toString().replaceAll('Exception:', '').trim()}";
  }

  Future<void> _persistStudent(String name, String mobile, String enrollment, String roleStr, {String? email}) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('name', name);
    await prefs.setString('mobile', mobile);
    await prefs.setString('enrollment', enrollment);
    if (email != null && email.isNotEmpty) {
      await prefs.setString('email', email);
      studentEmail = email;
    }
    await prefs.setString('role', roleStr);
    await prefs.setBool('is_logged_in', true);
    studentName = name;
    mobileNumber = mobile;
    enrollmentNumber = enrollment;
    role = roleStr;
    isLoggedIn = true;
    notifyListeners();
  }

  Future<Map<String, dynamic>> register(String name, String mobile, String enrollment, String password, {String? email}) async {
    final payload = <String, dynamic>{
      "name": name.trim(),
      "mobile": mobile.trim(),
      "enrollment": enrollment.trim().toUpperCase(),
      "password": password.trim(),
    };
    if (email != null && email.trim().isNotEmpty) {
      payload["email"] = email.trim();
    }

    // Attempt registration with 25s timeout and automatic single cold-start retry
    for (int attempt = 1; attempt <= 2; attempt++) {
      try {
        final response = await http.post(
          Uri.parse('$baseUrl/api/register'),
          headers: {'Content-Type': 'application/json', 'ngrok-skip-browser-warning': 'true'},
          body: jsonEncode(payload),
        ).timeout(const Duration(seconds: 25));

        if (response.statusCode == 201) {
          final body = jsonDecode(response.body);
          if (body['success'] == true) {
            final student = body['student'] ?? {};
            await _persistStudent(
              student['student_name'] ?? name,
              student['mobile_number'] ?? mobile,
              student['enrollment_number'] ?? enrollment.toUpperCase(),
              student['role'] ?? 'Student',
              email: student['email'] ?? email,
            );
            isConnected = true;
            notifyListeners();
            return {"success": true, "message": body['message'] ?? 'Registered successfully'};
          }
        }

        // Return exact server validation error (e.g. 400 Duplicate Account, Invalid MUR, etc.)
        final errorMsg = _parseErrorResponse(response, fallback: 'Registration failed. Please try again.');
        return {"success": false, "error": errorMsg};
      } catch (e) {
        if (attempt == 1 && (e is TimeoutException || e.toString().toLowerCase().contains('timeout'))) {
          // Cold start detected, try once more automatically
          continue;
        }
        return {"success": false, "error": _classifyNetworkException(e)};
      }
    }
    return {
      "success": false,
      "error": "Server is taking too long to respond. Render backend may still be waking up. Please tap Retry."
    };
  }

  Future<Map<String, dynamic>> login(String identifier, String password) async {
    for (int attempt = 1; attempt <= 2; attempt++) {
      try {
        final response = await http.post(
          Uri.parse('$baseUrl/api/login'),
          headers: {'Content-Type': 'application/json', 'ngrok-skip-browser-warning': 'true'},
          body: jsonEncode({
            "identifier": identifier.trim(),
            "password": password.trim(),
          }),
        ).timeout(const Duration(seconds: 25));

        if (response.statusCode == 200) {
          final body = jsonDecode(response.body);
          if (body['success'] == true) {
            final student = body['student'] ?? {};
            await _persistStudent(
              student['student_name'] ?? '',
              student['mobile_number'] ?? '',
              student['enrollment_number'] ?? identifier.toUpperCase(),
              student['role'] ?? 'Student',
              email: student['email'],
            );
            isConnected = true;
            notifyListeners();
            return {"success": true, "student": student};
          }
        }

        final errorMsg = _parseErrorResponse(response, fallback: 'Invalid credentials.');
        return {"success": false, "error": errorMsg};
      } catch (e) {
        if (attempt == 1 && (e is TimeoutException || e.toString().toLowerCase().contains('timeout'))) {
          continue;
        }
        return {"success": false, "error": _classifyNetworkException(e)};
      }
    }
    return {
      "success": false,
      "error": "Server response timed out. Please tap Retry."
    };
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
    await prefs.remove('email');
    await prefs.remove('role');
    await prefs.setBool('is_logged_in', false);

    studentName = "";
    mobileNumber = "";
    enrollmentNumber = "";
    studentEmail = "";
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
    studentEmail = "";
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
      ).timeout(const Duration(seconds: 15));

      final body = jsonDecode(response.body);
      if (response.statusCode == 200 && body['success'] == true) {
        await logout();
        return {"success": true, "message": body['message'] ?? 'Account deleted successfully.'};
      } else {
        return {"success": false, "error": body['error'] ?? 'Could not delete account.'};
      }
    } catch (e) {
      return {"success": false, "error": _classifyNetworkException(e)};
    }
  }

  Future<Map<String, dynamic>> forgotPassword(String enrollment, String email, {String? mobile}) async {
    try {
      final payload = <String, dynamic>{
        "enrollment": enrollment.trim().toUpperCase(),
        "email": email.trim(),
      };
      if (mobile != null && mobile.trim().isNotEmpty) {
        payload["mobile"] = mobile.trim();
      }

      final response = await http.post(
        Uri.parse('$baseUrl/api/auth/forgot-password'),
        headers: {'Content-Type': 'application/json', 'ngrok-skip-browser-warning': 'true'},
        body: jsonEncode(payload),
      ).timeout(const Duration(seconds: 25));

      if (response.statusCode == 200) {
        final body = jsonDecode(response.body);
        if (body['success'] == true) {
          return {
            "success": true,
            "message": body['message'] ?? 'Password reset verification code sent to registered email.',
            "dev_otp": body['dev_otp'],
          };
        }
      }
      return {"success": false, "error": _parseErrorResponse(response, fallback: 'Could not initiate password recovery.')};
    } catch (e) {
      return {"success": false, "error": _classifyNetworkException(e)};
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
      ).timeout(const Duration(seconds: 20));

      if (response.statusCode == 200) {
        final body = jsonDecode(response.body);
        if (body['success'] == true) {
          return {
            "success": true,
            "message": body['message'] ?? 'Verification successful.',
            "reset_token": body['reset_token'],
          };
        }
      }
      return {"success": false, "error": _parseErrorResponse(response, fallback: 'Invalid verification code.')};
    } catch (e) {
      return {"success": false, "error": _classifyNetworkException(e)};
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
      ).timeout(const Duration(seconds: 20));

      if (response.statusCode == 200) {
        final body = jsonDecode(response.body);
        if (body['success'] == true) {
          return {
            "success": true,
            "message": body['message'] ?? 'Password updated successfully.',
          };
        }
      }
      return {"success": false, "error": _parseErrorResponse(response, fallback: 'Failed to update password.')};
    } catch (e) {
      return {"success": false, "error": _classifyNetworkException(e)};
    }
  }

  Future<List<Map<String, dynamic>>> getMyEmergencies() async {
    try {
      final ident = enrollmentNumber.isNotEmpty ? enrollmentNumber : mobileNumber;
      if (ident.isEmpty) return [];
      final response = await http.get(
        Uri.parse('$baseUrl/api/my-emergencies?enrollment=$ident'),
        headers: {'ngrok-skip-browser-warning': 'true'},
      ).timeout(const Duration(seconds: 12));

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
      ).timeout(const Duration(seconds: 10));
    } catch (e) {
      if (kDebugMode) print('Failed to sync profile: $e');
    }

    notifyListeners();
  }

  Future<void> setBaseUrl(String newUrl) async {
    final clean = newUrl.trim().replaceAll(RegExp(r'/+$'), '');
    if (clean.isEmpty || clean.toLowerCase() == 'default') {
      baseUrl = productionUrl;
    } else if (kReleaseMode && (clean.contains('127.0.0.1') || clean.contains('localhost') || clean.contains('10.0.2.2') || clean.contains('10.168.'))) {
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
    final candidates = [
      '$baseUrl/health',
      '$baseUrl/api/health',
    ];

    dynamic lastError;
    for (final url in candidates) {
      try {
        final response = await http.get(
          Uri.parse(url),
          headers: {'ngrok-skip-browser-warning': 'true'},
        ).timeout(const Duration(seconds: 15));

        if (response.statusCode == 200) {
          isConnected = true;
          connectionStatusDetail = "Connected to Mewar Guardian Backend (${Uri.tryParse(baseUrl)?.host ?? baseUrl})";
          notifyListeners();
          return true;
        }
      } catch (e) {
        lastError = e;
      }
    }

    // If current baseUrl failed and it is not production, automatically fallback to productionUrl
    if (baseUrl != productionUrl) {
      for (final endpoint in ['/health', '/api/health']) {
        try {
          final r = await http.get(
            Uri.parse('$productionUrl$endpoint'),
            headers: {'ngrok-skip-browser-warning': 'true'},
          ).timeout(const Duration(seconds: 20));
          if (r.statusCode == 200) {
            baseUrl = productionUrl;
            isConnected = true;
            connectionStatusDetail = "Connected to Mewar Guardian Backend (mewar-guardian.onrender.com)";
            final prefs = await SharedPreferences.getInstance();
            await prefs.setString('custom_base_url', productionUrl);
            notifyListeners();
            return true;
          }
        } catch (e) {
          lastError = e;
        }
      }
    }

    isConnected = false;
    connectionStatusDetail = lastError != null
        ? _classifyNetworkException(lastError)
        : "Cannot reach campus safety backend.";
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
      final cleanUrl = baseUrl.endsWith('/') ? baseUrl.substring(0, baseUrl.length - 1) : baseUrl;
      final response = await http.get(
        Uri.parse('$cleanUrl/api/emergency/$emergencyId'),
        headers: {
          'Accept': 'application/json',
          'ngrok-skip-browser-warning': 'true',
        },
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
    } catch (e) {
      if (kDebugMode) print('getEmergencyById error: $e');
    }
    return null;
  }

  Future<Map<String, dynamic>> uploadImage(Uint8List bytes, String filename) async {
    try {
      final uri = Uri.parse('$baseUrl/api/upload');
      final request = http.MultipartRequest('POST', uri);
      request.headers['ngrok-skip-browser-warning'] = 'true';
      request.files.add(
        http.MultipartFile.fromBytes(
          'photo',
          bytes,
          filename: filename,
        ),
      );

      final streamedResponse = await request.send().timeout(const Duration(seconds: 15));
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200) {
        final body = jsonDecode(response.body);
        if (body is Map<String, dynamic> && body['success'] == true) {
          String photoUrl = body['photo_url'] ?? '';
          if (photoUrl.startsWith('/')) {
            photoUrl = '$baseUrl$photoUrl';
          }
          return {
            "success": true,
            "photo_url": photoUrl,
            "filename": body['filename'],
          };
        }
      }
      try {
        final body = jsonDecode(response.body);
        return {
          "success": false,
          "error": body['error'] ?? 'Upload failed (Status ${response.statusCode})',
        };
      } catch (_) {
        return {
          "success": false,
          "error": 'Upload failed with status ${response.statusCode}',
        };
      }
    } catch (e) {
      if (kDebugMode) print('uploadImage error: $e');
      return {
        "success": false,
        "error": "Failed to upload image. Please check network connection.",
      };
    }
  }

  Future<Map<String, dynamic>> uploadVideo(Uint8List bytes, String filename) async {
    try {
      // Server enforces 50MB max limit
      if (bytes.lengthInBytes > 50 * 1024 * 1024) {
        return {
          "success": false,
          "error": "Video exceeds 50MB limit (${(bytes.lengthInBytes / (1024 * 1024)).toStringAsFixed(1)}MB). Please select a shorter video.",
        };
      }

      final uri = Uri.parse('$baseUrl/api/upload');
      final request = http.MultipartRequest('POST', uri);
      request.headers['ngrok-skip-browser-warning'] = 'true';
      request.files.add(
        http.MultipartFile.fromBytes(
          'video',
          bytes,
          filename: filename,
        ),
      );

      final streamedResponse = await request.send().timeout(const Duration(seconds: 45));
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200) {
        final body = jsonDecode(response.body);
        if (body is Map<String, dynamic> && body['success'] == true) {
          String videoUrl = body['video_url'] ?? body['file_url'] ?? '';
          if (videoUrl.startsWith('/')) {
            videoUrl = '$baseUrl$videoUrl';
          }
          return {
            "success": true,
            "video_url": videoUrl,
            "filename": body['filename'],
          };
        }
      }
      try {
        final body = jsonDecode(response.body);
        return {
          "success": false,
          "error": body['error'] ?? 'Video upload failed (Status ${response.statusCode})',
        };
      } catch (_) {
        return {
          "success": false,
          "error": 'Video upload failed with status ${response.statusCode}',
        };
      }
    } catch (e) {
      if (kDebugMode) print('uploadVideo error: $e');
      return {
        "success": false,
        "error": "Failed to upload video. Please check your connection and retry.",
      };
    }
  }

  Future<Map<String, dynamic>?> chatWithAi(
    String message,
    List<Map<String, String>> history, {
    String? photoUrl,
    String? videoUrl,
  }) async {
    try {
      final payload = <String, dynamic>{
        "message": message,
        "history": history,
      };
      if (photoUrl != null && photoUrl.isNotEmpty) {
        payload["photo_url"] = photoUrl;
      }
      if (videoUrl != null && videoUrl.isNotEmpty) {
        payload["video_url"] = videoUrl;
      }

      final response = await http.post(
        Uri.parse('$baseUrl/api/chat'),
        headers: {
          'Content-Type': 'application/json',
          'ngrok-skip-browser-warning': 'true',
        },
        body: jsonEncode(payload),
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
