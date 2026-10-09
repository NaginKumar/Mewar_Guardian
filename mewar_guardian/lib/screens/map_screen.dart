import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import '../config/campus_locations_data.dart';
import '../models/campus_location.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';
import 'report_screen.dart';

class CampusMapScreen extends StatefulWidget {
  const CampusMapScreen({super.key});

  @override
  State<CampusMapScreen> createState() => _CampusMapScreenState();
}

class _CampusMapScreenState extends State<CampusMapScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final MapController _mapController = MapController();
  final LatLng _campusCenter = const LatLng(25.033000, 74.635912); // Mewar Campus Reference

  List<CampusLocation> _locations = CampusLocationsData.allLocations;
  String _searchQuery = "";
  String _selectedCategory = "All";

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadLocations();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadLocations() async {
    final api = Provider.of<ApiService>(context, listen: false);
    final locs = await api.getLocations();
    if (mounted && locs.isNotEmpty) {
      setState(() {
        _locations = locs;
      });
    }
  }

  Color _getCategoryColor(String category) {
    switch (category.toLowerCase()) {
      case 'academic': return AppColors.forestGreen;
      case 'hostel': return AppColors.safetyOrange;
      case 'medical': return AppColors.criticalRed;
      case 'security': return AppColors.deepGreen;
      case 'food': return const Color(0xFFD97706);
      case 'sports': return const Color(0xFF059669);
      default: return AppColors.charcoal;
    }
  }

  IconData _getCategoryIcon(String category) {
    switch (category.toLowerCase()) {
      case 'academic': return Icons.school;
      case 'hostel': return Icons.hotel;
      case 'medical': return Icons.medical_services;
      case 'security': return Icons.security;
      case 'food': return Icons.restaurant;
      case 'sports': return Icons.sports_soccer;
      default: return Icons.location_on;
    }
  }

  Future<void> _recenterToGps() async {
    try {
      final pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 5),
      );
      _mapController.move(LatLng(pos.latitude, pos.longitude), 17.5);
    } catch (_) {
      _mapController.move(_campusCenter, 17.0);
    }
  }

  void _showLocationModal(CampusLocation loc) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(22))),
      builder: (ctx) {
        return Padding(
          padding: const EdgeInsets.all(22.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: _getCategoryColor(loc.category).withOpacity(0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(_getCategoryIcon(loc.category), color: _getCategoryColor(loc.category), size: 26),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          loc.name,
                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.charcoal),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          "${loc.category} • ${loc.verified ? 'Verified Campus Location' : 'Campus Building'}",
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: loc.verified ? AppColors.successGreen : AppColors.textMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.warmIvory,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.border),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.pin_drop, size: 18, color: AppColors.forestGreen),
                    const SizedBox(width: 8),
                    Text(
                      "GPS: ${loc.lat.toStringAsFixed(5)}° N, ${loc.lon.toStringAsFixed(5)}° E",
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.charcoal),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.safetyOrange,
                    foregroundColor: AppColors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  icon: const Icon(Icons.warning_amber_rounded, size: 20),
                  label: const Text(
                    "REPORT EMERGENCY AT THIS LOCATION",
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800),
                  ),
                  onPressed: () {
                    Navigator.pop(ctx);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => ReportScreen(initialLocation: loc.name),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final filteredLocations = _locations.where((loc) {
      final q = _searchQuery.toLowerCase().trim();
      final matchesQuery = q.isEmpty ||
          loc.name.toLowerCase().contains(q) ||
          loc.category.toLowerCase().contains(q);
      final matchesCat = _selectedCategory == 'All' || loc.category == _selectedCategory;
      return matchesQuery && matchesCat;
    }).toList();

    return Scaffold(
      backgroundColor: AppColors.warmIvory,
      appBar: AppBar(
        title: const Text('Campus Map & Directory'),
        backgroundColor: AppColors.forestGreen,
        foregroundColor: AppColors.warmIvory,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppColors.safetyOrange,
          indicatorWeight: 3,
          labelColor: AppColors.warmIvory,
          unselectedLabelColor: AppColors.mutedSage,
          labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
          tabs: const [
            Tab(icon: Icon(Icons.map, size: 20), text: "Map View"),
            Tab(icon: Icon(Icons.format_list_bulleted, size: 20), text: "Directory List"),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // TAB 1: INTERACTIVE MAP VIEW
          _buildMapView(filteredLocations),

          // TAB 2: INDEPENDENT DIRECTORY LIST VIEW (100% OFFLINE SAFE)
          _buildDirectoryListView(filteredLocations),
        ],
      ),
    );
  }

  Widget _buildMapView(List<CampusLocation> filtered) {
    return Stack(
      children: [
        FlutterMap(
          mapController: _mapController,
          options: MapOptions(
            initialCenter: _campusCenter,
            initialZoom: 16.8,
            maxZoom: 19.0,
            minZoom: 14.0,
          ),
          children: [
            TileLayer(
              urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
              userAgentPackageName: 'com.mewarguardian.app',
            ),
            MarkerLayer(
              markers: filtered.map((loc) {
                return Marker(
                  point: LatLng(loc.lat, loc.lon),
                  width: 38,
                  height: 38,
                  child: GestureDetector(
                    onTap: () => _showLocationModal(loc),
                    child: Container(
                      decoration: BoxDecoration(
                        color: _getCategoryColor(loc.category),
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 2),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.25),
                            blurRadius: 6,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: Icon(_getCategoryIcon(loc.category), color: Colors.white, size: 18),
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
        ),

        // Search pill on top of map
        Positioned(
          top: 12,
          left: 16,
          right: 16,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.white.withOpacity(0.95),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.border),
              boxShadow: [
                BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 10, offset: const Offset(0, 4)),
              ],
            ),
            child: Row(
              children: [
                const Icon(Icons.search, color: AppColors.forestGreen, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    onChanged: (val) => setState(() => _searchQuery = val),
                    decoration: const InputDecoration(
                      hintText: "Search buildings or hostels on map...",
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      isDense: true,
                      contentPadding: EdgeInsets.symmetric(vertical: 10),
                    ),
                  ),
                ),
                if (_searchQuery.isNotEmpty)
                  GestureDetector(
                    onTap: () => setState(() => _searchQuery = ""),
                    child: const Icon(Icons.close, size: 18, color: AppColors.textMuted),
                  ),
              ],
            ),
          ),
        ),

        // FAB to Recenter to Campus
        Positioned(
          bottom: 20,
          right: 16,
          child: FloatingActionButton(
            backgroundColor: AppColors.forestGreen,
            foregroundColor: AppColors.warmIvory,
            elevation: 4,
            onPressed: _recenterToGps,
            child: const Icon(Icons.my_location),
          ),
        ),
      ],
    );
  }

  Widget _buildDirectoryListView(List<CampusLocation> filtered) {
    return Column(
      children: [
        // Search & Category Filters
        Container(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
          color: AppColors.white,
          child: Column(
            children: [
              TextField(
                onChanged: (val) => setState(() => _searchQuery = val),
                decoration: InputDecoration(
                  hintText: "Search 33 campus locations...",
                  prefixIcon: const Icon(Icons.search, color: AppColors.forestGreen),
                  filled: true,
                  fillColor: AppColors.warmIvory,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                ),
              ),
              const SizedBox(height: 10),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: CampusLocationsData.categories.map((cat) {
                    final isSel = _selectedCategory == cat;
                    return Padding(
                      padding: const EdgeInsets.only(right: 6.0),
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
                        onSelected: (_) => setState(() => _selectedCategory = cat),
                      ),
                    );
                  }).toList(),
                ),
              ),
            ],
          ),
        ),
        const Divider(height: 1, color: AppColors.border),

        // List
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: filtered.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (context, idx) {
              final loc = filtered[idx];
              return InkWell(
                onTap: () => _showLocationModal(loc),
                borderRadius: BorderRadius.circular(14),
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppColors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: _getCategoryColor(loc.category).withOpacity(0.12),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(_getCategoryIcon(loc.category), color: _getCategoryColor(loc.category), size: 22),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              loc.name,
                              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: AppColors.charcoal),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              "${loc.category} • ${loc.lat.toStringAsFixed(4)}° N, ${loc.lon.toStringAsFixed(4)}° E",
                              style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
                            ),
                          ],
                        ),
                      ),
                      const Icon(Icons.arrow_forward_ios, size: 14, color: AppColors.textMuted),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
