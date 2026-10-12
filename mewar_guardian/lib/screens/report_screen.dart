import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:geolocator/geolocator.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import '../config/campus_locations_data.dart';
import '../models/campus_location.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';
import 'tracking_screen.dart';

class ReportScreen extends StatefulWidget {
  final String? initialLocation;
  final String? initialCategory;
  const ReportScreen({super.key, this.initialLocation, this.initialCategory});

  @override
  State<ReportScreen> createState() => _ReportScreenState();
}

class _ReportScreenState extends State<ReportScreen> {
  final _nameController = TextEditingController();
  final _mobileController = TextEditingController();
  final _enrollController = TextEditingController();
  final _descController = TextEditingController();

  // --- SMART AUTO-VOICE SPEECH-TO-TEXT STATE ---
  final stt.SpeechToText _speech = stt.SpeechToText();
  bool _speechInitialized = false;
  bool _isListening = false;
  bool _speechAvailable = false;
  String _currentInterimWords = '';
  String? _speechError;
  List<stt.LocaleName> _deviceLocales = [];

  // --- PHOTO & VIDEO EVIDENCE STATE ---
  final ImagePicker _picker = ImagePicker();
  Uint8List? _selectedPhotoBytes;
  String? _selectedPhotoName;
  Uint8List? _selectedVideoBytes;
  String? _selectedVideoName;
  int _selectedVideoSizeBytes = 0;

  String _selectedCategory = 'Let AI Decide';
  CampusLocation _selectedLocation = CampusLocationsData.allLocations.firstWhere(
    (l) => l.name == "main building",
    orElse: () => CampusLocationsData.allLocations.first,
  );

  List<CampusLocation> _allLocations = CampusLocationsData.allLocations;
  Position? _gpsPosition;
  bool _isGpsActive = false;
  String _gpsStatus = "GPS not acquired";
  bool _isLoading = false;

  String _selectedSeverity = 'HIGH';
  final List<Map<String, dynamic>> _severities = [
    {'level': 'CRITICAL', 'label': 'Critical', 'sub': 'Life Threat', 'color': AppColors.criticalRed},
    {'level': 'HIGH', 'label': 'High', 'sub': 'Urgent Dispatch', 'color': AppColors.safetyOrange},
    {'level': 'MEDIUM', 'label': 'Medium', 'sub': 'Assistance Needed', 'color': const Color(0xFFD97706)},
    {'level': 'LOW', 'label': 'Low', 'sub': 'Advisory / Low', 'color': AppColors.forestGreen},
  ];

  final List<Map<String, dynamic>> _categories = [
    {'name': 'Let AI Decide', 'icon': Icons.auto_awesome, 'color': AppColors.forestGreen},
    {'name': 'Medical Emergency', 'icon': Icons.medical_services, 'color': AppColors.criticalRed},
    {'name': 'Fire', 'icon': Icons.local_fire_department, 'color': AppColors.safetyOrange},
    {'name': 'Accident', 'icon': Icons.car_crash, 'color': AppColors.safetyOrange},
    {'name': 'Security Threat', 'icon': Icons.security, 'color': AppColors.forestGreen},
    {'name': 'Harassment', 'icon': Icons.shield, 'color': AppColors.deepGreen},
    {'name': 'Other', 'icon': Icons.emergency, 'color': AppColors.charcoal},
  ];

  @override
  void initState() {
    super.initState();
    final api = Provider.of<ApiService>(context, listen: false);
    _nameController.text = api.studentName;
    _mobileController.text = api.mobileNumber;
    _enrollController.text = api.enrollmentNumber;

    // Handle Quick Emergency preselection
    if (widget.initialCategory != null && widget.initialCategory!.isNotEmpty) {
      final reqCat = widget.initialCategory!.trim().toLowerCase();
      for (final cat in _categories) {
        final catName = cat['name'].toString().toLowerCase();
        if (catName == reqCat ||
            (reqCat.contains('medical') && catName.contains('medical')) ||
            (reqCat.contains('fire') && catName.contains('fire')) ||
            (reqCat.contains('security') && catName.contains('security')) ||
            (reqCat.contains('accident') && catName.contains('accident')) ||
            (reqCat.contains('threat') && catName.contains('threat')) ||
            (reqCat.contains('harass') && catName.contains('harass')) ||
            (reqCat.contains('other') && catName.contains('other'))) {
          _selectedCategory = cat['name'] as String;
          break;
        }
      }
    }

    if (widget.initialLocation != null) {
      final found = CampusLocationsData.findByName(widget.initialLocation!);
      if (found != null) {
        _selectedLocation = found;
      }
    }
    _loadLocations();
  }

  Future<void> _loadLocations() async {
    final api = Provider.of<ApiService>(context, listen: false);
    final locs = await api.getLocations();
    if (mounted && locs.isNotEmpty) {
      setState(() {
        _allLocations = locs;
      });
    }
  }

  @override
  void dispose() {
    _speech.stop();
    _speech.cancel();
    _nameController.dispose();
    _mobileController.dispose();
    _enrollController.dispose();
    _descController.dispose();
    super.dispose();
  }

  // --- MULTILINGUAL VOICE SPEECH-TO-TEXT LOGIC ---
  Future<void> _initSpeech() async {
    if (_speechInitialized) return;
    try {
      final available = await _speech.initialize(
        onError: (err) {
          if (mounted) {
            setState(() {
              _isListening = false;
              if (err.errorMsg == "error_no_match") {
                _speechError = "No speech detected. Please speak closer to the microphone.";
              } else if (err.errorMsg.contains("permission")) {
                _speechError = "Microphone permission is required to transcribe speech. Please enable it in Settings.";
              } else {
                _speechError = "Voice error: ${err.errorMsg}";
              }
            });
          }
        },
        onStatus: (status) {
          if (mounted) {
            if (status == 'done' || status == 'notListening') {
              if (_isListening) {
                if (_currentInterimWords.trim().isNotEmpty) {
                  _commitVoiceText(_currentInterimWords);
                }
                setState(() {
                  _isListening = false;
                  _currentInterimWords = '';
                });
              }
            }
          }
        },
      );
      if (mounted) {
        setState(() {
          _speechInitialized = true;
          _speechAvailable = available;
        });
        if (available) {
          try {
            final locs = await _speech.locales();
            if (mounted) setState(() => _deviceLocales = locs);
          } catch (_) {}
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _speechInitialized = false;
          _speechAvailable = false;
          _speechError = "Unable to initialize speech recognition: $e";
        });
      }
    }
  }

  Future<void> _startListening() async {
    if (_isListening) return;

    setState(() {
      _speechError = null;
      _currentInterimWords = '';
    });

    if (!_speechInitialized) {
      await _initSpeech();
    }

    if (!_speechAvailable) {
      setState(() {
        _speechError = "Microphone permission is required or speech recognition service is not available on this device.";
      });
      return;
    }

    // Automatic Language Detection Strategy:
    // Uses best Indian locale candidate (Hindi / English / Hinglish) or system speech recognizer
    String? targetLocale;
    if (_deviceLocales.isNotEmpty) {
      for (final l in _deviceLocales) {
        final id = l.localeId.toLowerCase();
        if (id.contains('hi_in') || id.contains('hi-in')) {
          targetLocale = l.localeId;
          break;
        }
      }
      if (targetLocale == null) {
        for (final l in _deviceLocales) {
          final id = l.localeId.toLowerCase();
          if (id.contains('en_in') || id.contains('en-in')) {
            targetLocale = l.localeId;
            break;
          }
        }
      }
    }

    setState(() {
      _isListening = true;
    });

    try {
      await _speech.listen(
        onResult: (result) {
          if (mounted) {
            setState(() {
              _currentInterimWords = result.recognizedWords;
            });
            if (result.finalResult) {
              _commitVoiceText(result.recognizedWords);
              setState(() {
                _currentInterimWords = '';
                _isListening = false;
              });
            }
          }
        },
        listenOptions: stt.SpeechListenOptions(
          localeId: targetLocale,
          listenMode: stt.ListenMode.dictation,
          cancelOnError: true,
          partialResults: true,
          autoPunctuation: true,
        ),
      );
    } catch (e) {
      if (mounted) {
        setState(() {
          _isListening = false;
          _speechError = "Voice listening error: $e";
        });
      }
    }
  }

  void _commitVoiceText(String words) {
    final text = words.trim();
    if (text.isEmpty) return;
    final current = _descController.text.trim();
    if (current.isEmpty) {
      _descController.text = text;
    } else {
      if (!current.endsWith(text)) {
        _descController.text = "$current $text";
      }
    }
    _descController.selection = TextSelection.fromPosition(
      TextPosition(offset: _descController.text.length),
    );
    setState(() {});
  }

  Future<void> _stopListening() async {
    if (!_isListening) return;
    await _speech.stop();
    if (_currentInterimWords.trim().isNotEmpty) {
      _commitVoiceText(_currentInterimWords);
    }
    if (mounted) {
      setState(() {
        _isListening = false;
        _currentInterimWords = '';
      });
    }
  }

  Future<void> _cancelListening() async {
    if (!_isListening) return;
    await _speech.cancel();
    if (mounted) {
      setState(() {
        _isListening = false;
        _currentInterimWords = '';
        _speechError = null;
      });
    }
  }

  Future<void> _retryListening() async {
    await _cancelListening();
    await _startListening();
  }

  void _confirmClearDescription() {
    if (_descController.text.trim().isEmpty) return;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Clear Emergency Description?"),
        content: const Text("Are you sure you want to clear your current description text?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.criticalRed),
            onPressed: () {
              _descController.clear();
              Navigator.pop(ctx);
              setState(() {});
            },
            child: const Text("Clear", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  // --- EVIDENCE MEDIA HELPERS (PHOTOS & VIDEOS COMBINED) ---
  Future<void> _pickPhoto(ImageSource source) async {
    try {
      final XFile? file = await _picker.pickImage(
        source: source,
        maxWidth: 1920,
        maxHeight: 1080,
        imageQuality: 85,
      );
      if (file != null) {
        final bytes = await file.readAsBytes();
        if (bytes.lengthInBytes > 10 * 1024 * 1024) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text("Selected photo exceeds 10MB limit. Please choose a smaller photo."),
                backgroundColor: AppColors.criticalRed,
              ),
            );
          }
          return;
        }
        setState(() {
          _selectedPhotoBytes = bytes;
          _selectedPhotoName = file.name;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Could not access photo: $e"),
            backgroundColor: AppColors.criticalRed,
          ),
        );
      }
    }
  }

  void _removeSelectedPhoto() {
    setState(() {
      _selectedPhotoBytes = null;
      _selectedPhotoName = null;
    });
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
                content: Text("Selected video exceeds 50MB limit. Please select a shorter clip."),
                backgroundColor: AppColors.criticalRed,
              ),
            );
          }
          return;
        }
        setState(() {
          _selectedVideoBytes = bytes;
          _selectedVideoName = file.name;
          _selectedVideoSizeBytes = bytes.lengthInBytes;
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

  void _removeSelectedVideo() {
    setState(() {
      _selectedVideoBytes = null;
      _selectedVideoName = null;
      _selectedVideoSizeBytes = 0;
    });
  }

  void _showUnifiedMediaPicker() {
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
                "Attach Evidence Media",
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppColors.forestGreen),
              ),
              const SizedBox(height: 6),
              const Text(
                "Photos (max 10MB) or Videos (max 50MB) will be securely transmitted to Campus Security responders.",
                style: TextStyle(fontSize: 12, color: AppColors.textMuted),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(color: AppColors.mutedSage.withOpacity(0.4), shape: BoxShape.circle),
                  child: const Icon(Icons.camera_alt, color: AppColors.forestGreen),
                ),
                title: const Text("Take Photo with Camera", style: TextStyle(fontWeight: FontWeight.w700)),
                subtitle: const Text("Capture live incident image", style: TextStyle(fontSize: 12)),
                onTap: () {
                  Navigator.pop(ctx);
                  _pickPhoto(ImageSource.camera);
                },
              ),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(color: AppColors.mutedSage.withOpacity(0.4), shape: BoxShape.circle),
                  child: const Icon(Icons.photo_library_rounded, color: AppColors.forestGreen),
                ),
                title: const Text("Choose Photo from Gallery", style: TextStyle(fontWeight: FontWeight.w700)),
                subtitle: const Text("Select image from device (max 10MB)", style: TextStyle(fontSize: 12)),
                onTap: () {
                  Navigator.pop(ctx);
                  _pickPhoto(ImageSource.gallery);
                },
              ),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(color: AppColors.safetyOrange.withOpacity(0.15), shape: BoxShape.circle),
                  child: const Icon(Icons.videocam_rounded, color: AppColors.safetyOrange),
                ),
                title: const Text("Record Video with Camera", style: TextStyle(fontWeight: FontWeight.w700)),
                subtitle: const Text("Record live video (up to 3 min)", style: TextStyle(fontSize: 12)),
                onTap: () {
                  Navigator.pop(ctx);
                  _pickVideo(ImageSource.camera);
                },
              ),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(color: AppColors.safetyOrange.withOpacity(0.15), shape: BoxShape.circle),
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

  // --- MANUAL LOCATION SELECTOR MODAL ---
  void _openManualLocationSelector() {
    String searchQuery = "";
    String selectedCat = "All";

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            final filtered = _allLocations.where((loc) {
              final q = searchQuery.toLowerCase().trim();
              final matchesQuery = q.isEmpty ||
                  loc.name.toLowerCase().contains(q) ||
                  loc.category.toLowerCase().contains(q);
              final matchesCat = selectedCat == 'All' || loc.category == selectedCat;
              return matchesQuery && matchesCat;
            }).toList();

            return Container(
              height: MediaQuery.of(context).size.height * 0.82,
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: AppColors.border,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        "Select Campus Location",
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: AppColors.forestGreen,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, color: AppColors.textMuted),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  // Search field
                  TextField(
                    onChanged: (val) {
                      setModalState(() => searchQuery = val);
                    },
                    decoration: InputDecoration(
                      hintText: "Search building, hostel, block...",
                      prefixIcon: const Icon(Icons.search, color: AppColors.forestGreen),
                      filled: true,
                      fillColor: AppColors.warmIvory,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: AppColors.border),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  // Category chips
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: CampusLocationsData.categories.map((cat) {
                        final isSel = selectedCat == cat;
                        return Padding(
                          padding: const EdgeInsets.only(right: 8.0),
                          child: ChoiceChip(
                            label: Text(cat),
                            selected: isSel,
                            selectedColor: AppColors.forestGreen,
                            backgroundColor: AppColors.warmIvory,
                            labelStyle: TextStyle(
                              color: isSel ? AppColors.white : AppColors.charcoal,
                              fontWeight: isSel ? FontWeight.w700 : FontWeight.w500,
                              fontSize: 12,
                            ),
                            onSelected: (_) {
                              setModalState(() => selectedCat = cat);
                            },
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    "Showing ${filtered.length} locations",
                    style: const TextStyle(fontSize: 12, color: AppColors.textMuted, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 8),
                  Expanded(
                    child: ListView.separated(
                      itemCount: filtered.length,
                      separatorBuilder: (_, __) => const Divider(height: 1, color: AppColors.borderLight),
                      itemBuilder: (context, idx) {
                        final item = filtered[idx];
                        final isChosen = _selectedLocation.name == item.name;
                        return ListTile(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          leading: Container(
                            width: 38,
                            height: 38,
                            decoration: BoxDecoration(
                              color: isChosen ? AppColors.forestGreen : AppColors.mutedSage,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Icon(
                              _getCategoryIcon(item.category),
                              color: isChosen ? AppColors.white : AppColors.forestGreen,
                              size: 20,
                            ),
                          ),
                          title: Text(
                            item.name,
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: isChosen ? FontWeight.w800 : FontWeight.w600,
                              color: AppColors.charcoal,
                            ),
                          ),
                          subtitle: Text(
                            "${item.category} • ${item.lat.toStringAsFixed(4)}° N, ${item.lon.toStringAsFixed(4)}° E",
                            style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
                          ),
                          trailing: isChosen
                              ? const Icon(Icons.check_circle, color: AppColors.forestGreen, size: 22)
                              : const Icon(Icons.chevron_right, color: AppColors.border),
                          onTap: () {
                            setState(() {
                              _selectedLocation = item;
                            });
                            Navigator.pop(context);
                          },
                        );
                      },
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  IconData _getCategoryIcon(String category) {
    switch (category.toLowerCase()) {
      case 'hostel': return Icons.hotel;
      case 'academic': return Icons.school;
      case 'medical': return Icons.medical_services;
      case 'food': return Icons.restaurant;
      case 'sports': return Icons.sports_soccer;
      case 'security': return Icons.security;
      case 'facility': return Icons.business;
      case 'entry': return Icons.door_sliding;
      default: return Icons.location_on;
    }
  }

  // --- GPS ACQUISITION ---
  Future<void> _detectGpsLocation() async {
    setState(() {
      _isGpsActive = true;
      _gpsStatus = "Detecting GPS...";
    });

    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        setState(() {
          _isGpsActive = false;
          _gpsStatus = "GPS disabled in settings";
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('📍 Device GPS is off. Please enable Location in Phone Settings.'),
              backgroundColor: AppColors.charcoal,
            ),
          );
        }
        await Geolocator.openLocationSettings();
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.deniedForever) {
        setState(() {
          _isGpsActive = false;
          _gpsStatus = "Permission denied permanently";
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('📍 Location permission is permanently denied. You can still select your campus location manually.'),
              backgroundColor: AppColors.charcoal,
            ),
          );
        }
        return;
      }

      if (permission == LocationPermission.denied) {
        setState(() {
          _isGpsActive = false;
          _gpsStatus = "Permission denied";
        });
        return;
      }

      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 8),
      );

      if (mounted) {
        setState(() {
          _gpsPosition = position;
          _isGpsActive = false;
          _gpsStatus = "Acquired: ${position.latitude.toStringAsFixed(4)}° N, ${position.longitude.toStringAsFixed(4)}° E (±${position.accuracy.toStringAsFixed(0)}m)";
        });
      }
    } on TimeoutException {
      try {
        final last = await Geolocator.getLastKnownPosition();
        if (last != null && mounted) {
          setState(() {
            _gpsPosition = last;
            _isGpsActive = false;
            _gpsStatus = "Last known: ${last.latitude.toStringAsFixed(4)}° N, ${last.longitude.toStringAsFixed(4)}° E";
          });
          return;
        }
      } catch (_) {}
      setState(() {
        _isGpsActive = false;
        _gpsStatus = "GPS timed out. Use manual selection.";
      });
    } catch (e) {
      setState(() {
        _isGpsActive = false;
        _gpsStatus = "GPS unavailable. Use manual selection.";
      });
    }
  }

  Color _getSeverityColor(String severity) {
    switch (severity.toUpperCase()) {
      case 'CRITICAL':
        return AppColors.criticalRed;
      case 'HIGH':
        return AppColors.safetyOrange;
      case 'MEDIUM':
        return const Color(0xFFD97706);
      case 'LOW':
        return AppColors.forestGreen;
      default:
        return AppColors.safetyOrange;
    }
  }

  // --- ACCIDENTAL TAP PROTECTION & CONFIRMATION ---
  void _confirmAndSubmitEmergency() {
    _stopListening();
    final desc = _descController.text.trim();
    if (desc.isEmpty && _selectedCategory == 'Let AI Decide') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('⚠️ Please provide a brief description or select an emergency category.'),
          backgroundColor: AppColors.criticalRed,
        ),
      );
      return;
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: AppColors.safetyOrange, size: 28),
            SizedBox(width: 10),
            Expanded(
              child: Text(
                "Confirm Emergency SOS",
                style: TextStyle(fontWeight: FontWeight.w800, color: AppColors.forestGreen, fontSize: 18),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Are you sure you want to trigger an immediate emergency alert?",
              style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.charcoal, fontSize: 14),
            ),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.warmIvory,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("Category: $_selectedCategory", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.forestGreen)),
                  const SizedBox(height: 3),
                  Text("Severity: $_selectedSeverity", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: _getSeverityColor(_selectedSeverity))),
                  const SizedBox(height: 3),
                  Text("Location: ${_selectedLocation.name}", style: const TextStyle(fontSize: 12, color: AppColors.charcoal)),
                  if (_selectedPhotoBytes != null || _selectedVideoBytes != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      "Media: ${[if (_selectedPhotoBytes != null) 'Photo', if (_selectedVideoBytes != null) 'Video'].join(' + ')} attached",
                      style: const TextStyle(fontSize: 11, color: AppColors.forestGreen, fontWeight: FontWeight.w600),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              "Campus Security responders will be dispatched immediately. Tap Dispatch to proceed.",
              style: TextStyle(fontSize: 12, color: AppColors.textMuted),
            ),
          ],
        ),
        actions: [
          OutlinedButton(
            onPressed: () => Navigator.pop(ctx),
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: AppColors.border),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text("Cancel", style: TextStyle(color: AppColors.charcoal)),
          ),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.safetyOrange,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            icon: const Icon(Icons.emergency_share, color: Colors.white, size: 18),
            label: const Text("Dispatch SOS Now", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            onPressed: () {
              Navigator.pop(ctx);
              _submitEmergency();
            },
          ),
        ],
      ),
    );
  }

  // --- SOS SUBMISSION ---
  void _submitEmergency() async {
    _stopListening();
    final desc = _descController.text.trim();
    if (desc.isEmpty && _selectedCategory == 'Let AI Decide') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('⚠️ Please provide a brief description or select an emergency category.'),
          backgroundColor: AppColors.criticalRed,
        ),
      );
      return;
    }

    final api = Provider.of<ApiService>(context, listen: false);
    final name = _nameController.text.trim().isNotEmpty ? _nameController.text.trim() : api.studentName;
    final mobile = _mobileController.text.trim().isNotEmpty ? _mobileController.text.trim() : api.mobileNumber;
    final enroll = _enrollController.text.trim().toUpperCase().isNotEmpty ? _enrollController.text.trim().toUpperCase() : api.enrollmentNumber;

    setState(() => _isLoading = true);

    // Save profile updates to memory/prefs
    api.saveProfile(name, mobile, enroll);

    String? photoUrl;
    if (_selectedPhotoBytes != null) {
      try {
        final uploadRes = await api.uploadImage(_selectedPhotoBytes!, _selectedPhotoName ?? 'incident_evidence.jpg');
        if (uploadRes['success'] == true) {
          photoUrl = uploadRes['photo_url'];
        }
      } catch (e) {
        // Continue emergency transmission even if image upload encountered an error
      }
    }

    String? videoUrl;
    if (_selectedVideoBytes != null) {
      try {
        final uploadRes = await api.uploadVideo(_selectedVideoBytes!, _selectedVideoName ?? 'incident_evidence.mp4');
        if (uploadRes['success'] == true) {
          videoUrl = uploadRes['video_url'];
        }
      } catch (e) {
        // Continue emergency transmission even if video upload encountered an error
      }
    }

    final Map<String, dynamic> payload = {
      "student_name": name,
      "mobile_number": mobile,
      "enrollment_number": enroll,
      "emergency_type": _selectedCategory == 'Let AI Decide' ? "" : _selectedCategory,
      "priority": _selectedSeverity,
      "description": desc,
      "location": _selectedLocation.name,
    };

    if (photoUrl != null && photoUrl.isNotEmpty) {
      payload["photo_url"] = photoUrl;
    }
    if (videoUrl != null && videoUrl.isNotEmpty) {
      payload["video_url"] = videoUrl;
    }

    if (_gpsPosition != null) {
      payload["student_lat"] = _gpsPosition!.latitude;
      payload["student_lon"] = _gpsPosition!.longitude;
      payload["location_accuracy"] = _gpsPosition!.accuracy;
    }

    final result = await api.submitEmergency(payload);
    setState(() => _isLoading = false);

    if (!mounted) return;

    // Check 1: Server Confirmed Success
    if (result.containsKey('emergency_id') && (result['success'] == true || result['emergency_id'] != null)) {
      final int eid = result['emergency_id'];
      final Map<String, dynamic> trackingData = {
        'id': eid,
        'emergency_type': result['emergency_type'] ?? _selectedCategory,
        'status': 'Pending',
        'location': result['location'] ?? _selectedLocation.name,
        'responder': result['responder'] ?? 'Campus Security Team',
        'estimated_minutes': result['estimated_minutes'] ?? 3,
        'priority': result['priority'] ?? 'HIGH',
        'student_name': name,
        'mobile_number': mobile,
        'description': desc,
        'photo_url': photoUrl ?? result['photo_url'],
        'video_url': videoUrl ?? result['video_url'],
        'time': DateTime.now().toString().split('.').first,
        'recommendation': result['recommendation'] ?? '',
      };

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => TrackingScreen(emergencyId: eid, initialData: trackingData),
        ),
      );
      return;
    }

    // Check 2: Saved Offline
    if (result['offline'] == true) {
      _showOfflineNoticeDialog(result['message'] ?? 'Report queued offline.');
      return;
    }

    // Check 3: Clear Specific Error
    final errorMsg = result['error'] ?? 'Emergency submission could not be completed. Please call campus security directly.';
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.white,
        title: const Row(
          children: [
            Icon(Icons.error_outline, color: AppColors.criticalRed),
            SizedBox(width: 8),
            Text("Submission Alert", style: TextStyle(color: AppColors.forestGreen, fontWeight: FontWeight.bold)),
          ],
        ),
        content: Text(errorMsg, style: const TextStyle(color: AppColors.charcoal)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("Close", style: TextStyle(color: AppColors.textMuted)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.safetyOrange),
            onPressed: () {
              Navigator.pop(ctx);
              _submitEmergency();
            },
            child: const Text("Retry SOS", style: TextStyle(color: AppColors.white)),
          ),
        ],
      ),
    );
  }

  void _showOfflineNoticeDialog(String message) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.cloud_off, color: AppColors.safetyOrange, size: 28),
            SizedBox(width: 10),
            Text("Saved Offline", style: TextStyle(fontWeight: FontWeight.w800, color: AppColors.forestGreen)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              message,
              style: const TextStyle(color: AppColors.charcoal, fontSize: 14, height: 1.4),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.warmIvory,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.border),
              ),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("IMMEDIATE ASSISTANCE:", style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.textMuted)),
                  SizedBox(height: 4),
                  Text("Call Campus Security: 01477-229900", style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.forestGreen)),
                  Text("Police Control: 112 | Ambulance: 108", style: TextStyle(fontSize: 12, color: AppColors.charcoal)),
                ],
              ),
            ),
          ],
        ),
        actions: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.forestGreen),
            onPressed: () {
              Navigator.pop(ctx);
              Navigator.pop(context);
            },
            child: const Text("OK, Understood", style: TextStyle(color: AppColors.white)),
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
        title: const Text('Report Campus Emergency'),
        backgroundColor: AppColors.forestGreen,
        foregroundColor: AppColors.warmIvory,
      ),
      body: _isLoading
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(color: AppColors.safetyOrange),
                  SizedBox(height: 16),
                  Text(
                    "Transmitting SOS to Campus Security...",
                    style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.forestGreen),
                  ),
                ],
              ),
            )
          : SafeArea(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
                children: [
                  // 1. SELECT EMERGENCY CATEGORY
                  _buildSectionHeader("1. EMERGENCY CATEGORY"),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: _categories.map((cat) {
                        final isSel = _selectedCategory == cat['name'];
                        final Color c = cat['color'] as Color;
                        return ChoiceChip(
                          avatar: Icon(
                            cat['icon'] as IconData,
                            size: 18,
                            color: isSel ? AppColors.white : c,
                          ),
                          label: Text(cat['name']),
                          selected: isSel,
                          selectedColor: c,
                          backgroundColor: AppColors.warmIvory,
                          labelStyle: TextStyle(
                            color: isSel ? AppColors.white : AppColors.charcoal,
                            fontWeight: isSel ? FontWeight.w800 : FontWeight.w600,
                            fontSize: 13,
                          ),
                          onSelected: (_) {
                            setState(() => _selectedCategory = cat['name']);
                          },
                        );
                      }).toList(),
                    ),
                  ),
                  if (_selectedCategory == 'Harassment') ...[
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.forestGreen.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.forestGreen.withOpacity(0.3)),
                      ),
                      child: const Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(Icons.shield_outlined, color: AppColors.forestGreen, size: 20),
                          SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  "Confidential Harassment Protection",
                                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: AppColors.forestGreen),
                                ),
                                SizedBox(height: 3),
                                Text(
                                  "Harassment reports and uploaded evidence are encrypted and restricted solely to authorized female safety officers & anti-harassment panel.",
                                  style: TextStyle(fontSize: 11, color: AppColors.charcoal, height: 1.3),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 20),

                  // 2. SEVERITY / URGENCY LEVEL
                  _buildSectionHeader("2. SEVERITY LEVEL"),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Row(
                      children: _severities.map((sev) {
                        final isSel = _selectedSeverity == sev['level'];
                        final Color c = sev['color'] as Color;
                        return Expanded(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 4.0),
                            child: InkWell(
                              borderRadius: BorderRadius.circular(10),
                              onTap: () => setState(() => _selectedSeverity = sev['level'] as String),
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 200),
                                padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
                                decoration: BoxDecoration(
                                  color: isSel ? c : AppColors.warmIvory,
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                    color: isSel ? c : AppColors.border,
                                    width: isSel ? 2 : 1,
                                  ),
                                ),
                                child: Column(
                                  children: [
                                    Text(
                                      sev['label'] as String,
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w800,
                                        color: isSel ? AppColors.white : AppColors.charcoal,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      sev['sub'] as String,
                                      style: TextStyle(
                                        fontSize: 9,
                                        color: isSel ? AppColors.white.withOpacity(0.9) : AppColors.textMuted,
                                      ),
                                      textAlign: TextAlign.center,
                                      maxLines: 1,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // 3. CAMPUS LOCATION SELECTION
                  _buildSectionHeader("3. CAMPUS LOCATION"),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Currently selected building card
                        Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: AppColors.mutedSage.withOpacity(0.4),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: AppColors.forestGreen.withOpacity(0.3)),
                          ),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: AppColors.forestGreen,
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Icon(
                                  _getCategoryIcon(_selectedLocation.category),
                                  color: AppColors.white,
                                  size: 22,
                                ),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text("Selected Location", style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.textMuted)),
                                    const SizedBox(height: 2),
                                    Text(
                                      _selectedLocation.name,
                                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppColors.charcoal),
                                    ),
                                    Text(
                                      "Category: ${_selectedLocation.category}",
                                      style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
                                    ),
                                  ],
                                ),
                              ),
                              OutlinedButton(
                                onPressed: _openManualLocationSelector,
                                style: OutlinedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                  side: const BorderSide(color: AppColors.forestGreen),
                                ),
                                child: const Text("Change", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Action 1: Select Campus Location Manually
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.forestGreen,
                              foregroundColor: AppColors.white,
                              padding: const EdgeInsets.symmetric(vertical: 13),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            icon: const Icon(Icons.list_alt, size: 20),
                            label: const Text(
                              "Select Campus Location Manually",
                              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                            ),
                            onPressed: _openManualLocationSelector,
                          ),
                        ),
                        const SizedBox(height: 10),

                        // Action 2: Detect via GPS
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              side: const BorderSide(color: AppColors.border, width: 1.5),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            icon: _isGpsActive
                                ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.forestGreen))
                                : const Icon(Icons.my_location, size: 18, color: AppColors.charcoal),
                            label: Text(
                              _gpsPosition != null ? "GPS Acquired (Tap to refresh)" : "Detect Location via GPS",
                              style: const TextStyle(fontWeight: FontWeight.w600, color: AppColors.charcoal, fontSize: 13),
                            ),
                            onPressed: _isGpsActive ? null : _detectGpsLocation,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          "📍 GPS Status: $_gpsStatus",
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                            color: _gpsPosition != null ? AppColors.successGreen : AppColors.textMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // 3. EMERGENCY DETAILS WITH MULTILINGUAL VOICE INPUT
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _buildSectionHeader("4. EMERGENCY DETAILS"),
                      if (_descController.text.trim().isNotEmpty)
                        TextButton.icon(
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            minimumSize: Size.zero,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                          icon: const Icon(Icons.clear, size: 14, color: AppColors.criticalRed),
                          label: const Text(
                            "Clear Text",
                            style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.criticalRed),
                          ),
                          onPressed: _confirmClearDescription,
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: _isListening ? AppColors.safetyOrange : AppColors.border,
                        width: _isListening ? 2 : 1,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Voice Controls Bar
                        _buildVoiceControlsSection(),
                        const SizedBox(height: 14),

                        // Editable Text Field
                        TextField(
                          controller: _descController,
                          maxLines: 4,
                          onChanged: (_) => setState(() {}),
                          decoration: InputDecoration(
                            labelText: "Emergency Description",
                            labelStyle: const TextStyle(color: AppColors.forestGreen, fontWeight: FontWeight.w600),
                            hintText: "Speak using the microphone above, or type details here (e.g., Medical distress in Room 204, fire in lab...)",
                            hintStyle: const TextStyle(color: AppColors.textMuted, fontSize: 13),
                            fillColor: AppColors.warmIvory.withOpacity(0.5),
                            filled: true,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(color: AppColors.border),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(color: AppColors.border),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(color: AppColors.forestGreen, width: 1.5),
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Row(
                          children: [
                            Icon(Icons.check_circle_outline, size: 14, color: AppColors.forestGreen),
                            SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                "Voice transcript is editable. You can review, correct, or add text before submitting.",
                                style: TextStyle(fontSize: 11, color: AppColors.textMuted),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // 5. COMBINED EVIDENCE MEDIA (PHOTOS & VIDEOS IN ONE SINGLE CARD)
                  _buildSectionHeader("5. EVIDENCE MEDIA (PHOTOS & VIDEOS)"),
                  const SizedBox(height: 8),
                  _buildCombinedMediaSection(),
                  const SizedBox(height: 20),

                  // 6. STUDENT INFORMATION
                  _buildSectionHeader("6. STUDENT INFORMATION"),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Column(
                      children: [
                        TextField(
                          controller: _nameController,
                          decoration: const InputDecoration(
                            labelText: "Full Name",
                            prefixIcon: Icon(Icons.person, color: AppColors.forestGreen, size: 20),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: _mobileController,
                                keyboardType: TextInputType.phone,
                                decoration: const InputDecoration(
                                  labelText: "Mobile Number",
                                  prefixIcon: Icon(Icons.phone, color: AppColors.forestGreen, size: 20),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: TextField(
                                controller: _enrollController,
                                decoration: const InputDecoration(
                                  labelText: "Enrollment ID",
                                  prefixIcon: Icon(Icons.badge, color: AppColors.forestGreen, size: 20),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 28),

                  // 5. PROMINENT SAFETY ORANGE SOS BUTTON WITH ACCIDENTAL TAP CONFIRMATION
                  SizedBox(
                    width: double.infinity,
                    height: 58,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.safetyOrange,
                        elevation: 4,
                        shadowColor: AppColors.safetyOrange.withOpacity(0.5),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                      icon: const Icon(Icons.warning_amber_rounded, size: 28, color: AppColors.white),
                      label: const Text(
                        "SUBMIT EMERGENCY (SOS)",
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1.2,
                          color: AppColors.white,
                        ),
                      ),
                      onPressed: _confirmAndSubmitEmergency,
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Center(
                    child: Text(
                      "Mewar University Emergency Response Team will be dispatched immediately.",
                      style: TextStyle(fontSize: 12, color: AppColors.textMuted),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildVoiceControlsSection() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _isListening ? AppColors.safetyOrange.withOpacity(0.08) : AppColors.warmIvory,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: _isListening ? AppColors.safetyOrange.withOpacity(0.5) : AppColors.border,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Smart Auto Voice Detection Banner
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: AppColors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppColors.border),
            ),
            child: const Row(
              children: [
                Icon(Icons.auto_awesome, size: 16, color: AppColors.forestGreen),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    "Smart Voice • Auto-Detects Hindi, English & Hinglish",
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.forestGreen),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 10),

          // Idle State vs Listening State
          if (!_isListening) ...[
            SizedBox(
              height: 46,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.forestGreen,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  elevation: 1,
                ),
                icon: const Icon(Icons.mic, size: 20, color: Colors.white),
                label: const Text(
                  "Describe by Voice (Tap to Speak)",
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: Colors.white),
                ),
                onPressed: _startListening,
              ),
            ),
          ] else ...[
            // Listening State Panel
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.safetyOrange.withOpacity(0.5)),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppColors.safetyOrange.withOpacity(0.2),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.mic, color: AppColors.safetyOrange, size: 22),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  width: 8,
                                  height: 8,
                                  decoration: const BoxDecoration(color: AppColors.criticalRed, shape: BoxShape.circle),
                                ),
                                const SizedBox(width: 6),
                                const Text(
                                  "LISTENING...",
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w900,
                                    color: AppColors.safetyOrange,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 2),
                            const Text(
                              "Speak naturally in Hindi, English, or Hinglish",
                              style: TextStyle(fontSize: 11, color: AppColors.textMuted),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),

                  // Live Interim Transcription Bubble
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(
                      color: AppColors.warmIvory.withOpacity(0.6),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Text(
                      _currentInterimWords.isNotEmpty ? _currentInterimWords : "Waiting for speech... Speak clearly.",
                      style: TextStyle(
                        fontSize: 13,
                        fontStyle: _currentInterimWords.isEmpty ? FontStyle.italic : FontStyle.normal,
                        color: _currentInterimWords.isNotEmpty ? AppColors.charcoal : AppColors.textMuted,
                        fontWeight: _currentInterimWords.isNotEmpty ? FontWeight.w700 : FontWeight.normal,
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),

                  // Interactive Controls: Stop & Keep, Retry, Cancel
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.forestGreen,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                          icon: const Icon(Icons.check, size: 16, color: Colors.white),
                          label: const Text("Done & Keep", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white)),
                          onPressed: _stopListening,
                        ),
                      ),
                      const SizedBox(width: 6),
                      OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.safetyOrange,
                          side: const BorderSide(color: AppColors.safetyOrange),
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        icon: const Icon(Icons.refresh, size: 16),
                        label: const Text("Retry", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                        onPressed: _retryListening,
                      ),
                      const SizedBox(width: 6),
                      OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.textMuted,
                          side: const BorderSide(color: AppColors.border),
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        onPressed: _cancelListening,
                        child: const Text("Cancel", style: TextStyle(fontSize: 12)),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],

          // Error / Permission Alert Banner
          if (_speechError != null) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.criticalRed.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.criticalRed.withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.error_outline, size: 18, color: AppColors.criticalRed),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _speechError!,
                      style: const TextStyle(fontSize: 11, color: AppColors.criticalRed, fontWeight: FontWeight.w600),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, size: 16, color: AppColors.criticalRed),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    onPressed: () => setState(() => _speechError = null),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildCombinedMediaSection() {
    final bool hasPhoto = _selectedPhotoBytes != null;
    final bool hasVideo = _selectedVideoBytes != null;
    final bool hasMedia = hasPhoto || hasVideo;

    return Container(
      padding: const EdgeInsets.all(16),
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
              const Icon(Icons.perm_media_rounded, size: 20, color: AppColors.forestGreen),
              const SizedBox(width: 8),
              const Text(
                "Evidence Media (Photos & Videos)",
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: AppColors.forestGreen),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.warmIvory,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.border),
                ),
                child: Text(
                  hasMedia ? (hasPhoto && hasVideo ? "2 items" : "1 item") : "Optional",
                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.textMuted),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          const Text(
            "Attach photos or videos of the scene. Media is securely uploaded and shared directly with the responding security unit.",
            style: TextStyle(fontSize: 12, color: AppColors.textMuted),
          ),
          const SizedBox(height: 14),

          // Clean empty state inside the same card when no attachments
          if (!hasMedia) ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
              decoration: BoxDecoration(
                color: AppColors.warmIvory.withOpacity(0.5),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.border, style: BorderStyle.solid),
              ),
              child: Column(
                children: [
                  Icon(Icons.cloud_upload_outlined, size: 40, color: AppColors.forestGreen.withOpacity(0.6)),
                  const SizedBox(height: 8),
                  const Text(
                    "No Evidence Media Attached",
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.charcoal),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    "Add photo (max 10MB) or video (max 50MB)",
                    style: TextStyle(fontSize: 11, color: AppColors.textMuted),
                  ),
                  const SizedBox(height: 14),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.forestGreen,
                      foregroundColor: AppColors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 11),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    icon: const Icon(Icons.add_photo_alternate_rounded, size: 18),
                    label: const Text("Add Media (Photo / Video)", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                    onPressed: _showUnifiedMediaPicker,
                  ),
                ],
              ),
            ),
          ] else ...[
            // Thumbnail Gallery inside the same card
            Column(
              children: [
                if (hasPhoto) ...[
                  Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppColors.warmIvory.withOpacity(0.6),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.forestGreen.withOpacity(0.3)),
                    ),
                    child: Row(
                      children: [
                        Stack(
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: Image.memory(
                                _selectedPhotoBytes!,
                                width: 68,
                                height: 68,
                                fit: BoxFit.cover,
                              ),
                            ),
                            Positioned(
                              top: 2,
                              left: 2,
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                                decoration: BoxDecoration(
                                  color: AppColors.forestGreen.withOpacity(0.85),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: const Row(
                                  children: [
                                    Icon(Icons.photo_camera, size: 10, color: AppColors.white),
                                    SizedBox(width: 2),
                                    Text("Photo", style: TextStyle(fontSize: 9, color: AppColors.white, fontWeight: FontWeight.bold)),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _selectedPhotoName ?? "Incident Photo",
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.charcoal),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: AppColors.white,
                                      borderRadius: BorderRadius.circular(4),
                                      border: Border.all(color: AppColors.border),
                                    ),
                                    child: Text(
                                      "${(_selectedPhotoBytes!.lengthInBytes / (1024 * 1024)).toStringAsFixed(1)} MB",
                                      style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppColors.charcoal),
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  const Text(
                                    "Ready to upload",
                                    style: TextStyle(fontSize: 11, color: AppColors.successGreen, fontWeight: FontWeight.w600),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete_outline, color: AppColors.criticalRed, size: 22),
                          tooltip: "Remove Photo",
                          onPressed: _removeSelectedPhoto,
                        ),
                      ],
                    ),
                  ),
                ],

                if (hasVideo) ...[
                  Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppColors.safetyOrange.withOpacity(0.06),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.safetyOrange.withOpacity(0.3)),
                    ),
                    child: Row(
                      children: [
                        Stack(
                          alignment: Alignment.center,
                          children: [
                            Container(
                              width: 68,
                              height: 68,
                              decoration: BoxDecoration(
                                color: Colors.black87,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Icon(Icons.play_circle_fill_rounded, color: AppColors.safetyOrange, size: 34),
                            ),
                            Positioned(
                              top: 2,
                              left: 2,
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                                decoration: BoxDecoration(
                                  color: AppColors.safetyOrange.withOpacity(0.9),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: const Row(
                                  children: [
                                    Icon(Icons.videocam, size: 10, color: AppColors.white),
                                    SizedBox(width: 2),
                                    Text("Video", style: TextStyle(fontSize: 9, color: AppColors.white, fontWeight: FontWeight.bold)),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _selectedVideoName ?? "Incident Video",
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.charcoal),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: AppColors.white,
                                      borderRadius: BorderRadius.circular(4),
                                      border: Border.all(color: AppColors.border),
                                    ),
                                    child: Text(
                                      "${(_selectedVideoSizeBytes / (1024 * 1024)).toStringAsFixed(1)} MB",
                                      style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppColors.charcoal),
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  const Text(
                                    "Ready to stream",
                                    style: TextStyle(fontSize: 11, color: AppColors.successGreen, fontWeight: FontWeight.w600),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete_outline, color: AppColors.criticalRed, size: 22),
                          tooltip: "Remove Video",
                          onPressed: _removeSelectedVideo,
                        ),
                      ],
                    ),
                  ),
                ],

                // Action to add more if one type is still missing
                if (!hasPhoto || !hasVideo) ...[
                  const SizedBox(height: 4),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: AppColors.forestGreen),
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      icon: const Icon(Icons.add, size: 16, color: AppColors.forestGreen),
                      label: Text(
                        !hasPhoto ? "Add Photo Evidence" : "Add Video Footage",
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.forestGreen),
                      ),
                      onPressed: _showUnifiedMediaPicker,
                    ),
                  ),
                ],
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w800,
        letterSpacing: 1.0,
        color: AppColors.forestGreen,
      ),
    );
  }
}
