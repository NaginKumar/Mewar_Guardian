import '../models/campus_location.dart';

/// Canonical dataset of all 33 Mewar University campus locations
/// Matches config/locations.py exactly. Used as offline fallback so
/// manual location selection NEVER gets stuck on "Loading campus locations...".
class CampusLocationsData {
  static const List<CampusLocation> allLocations = [
    // Verified / Mapped
    CampusLocation(
      name: "main building",
      lat: 25.032150,
      lon: 74.636160,
      category: "University",
      verified: true,
    ),
    CampusLocation(
      name: "Sanga Hostel",
      lat: 25.034470,
      lon: 74.635760,
      category: "Hostel",
      verified: true,
    ),
    CampusLocation(
      name: "Kumbha Hostel",
      lat: 25.033710,
      lon: 74.636120,
      category: "Hostel",
      verified: true,
    ),
    CampusLocation(
      name: "Main Campus Reference",
      lat: 25.033000,
      lon: 74.635912,
      category: "Reference",
      verified: true,
    ),

    // Hostels
    CampusLocation(
      name: "International Hostel",
      lat: 25.03410,
      lon: 74.63495,
      category: "Hostel",
      verified: false,
    ),
    CampusLocation(
      name: "Pratap Hostel",
      lat: 25.03340,
      lon: 74.63665,
      category: "Hostel",
      verified: false,
    ),
    CampusLocation(
      name: "Meera Hostel",
      lat: 25.03400,
      lon: 74.63530,
      category: "Hostel",
      verified: false,
    ),
    CampusLocation(
      name: "Panna Hostel",
      lat: 25.03435,
      lon: 74.63510,
      category: "Hostel",
      verified: false,
    ),

    // Facilities & Medical
    CampusLocation(
      name: "Guest House",
      lat: 25.03210,
      lon: 74.63660,
      category: "Facility",
      verified: false,
    ),
    CampusLocation(
      name: "Hospital",
      lat: 25.03340,
      lon: 74.63620,
      category: "Medical",
      verified: false,
    ),

    // Academic Blocks
    CampusLocation(
      name: "Engineering Block",
      lat: 25.03180,
      lon: 74.63575,
      category: "Academic",
      verified: false,
    ),
    CampusLocation(
      name: "Law & Education Building",
      lat: 25.03145,
      lon: 74.63540,
      category: "Academic",
      verified: false,
    ),
    CampusLocation(
      name: "Science Block",
      lat: 25.03155,
      lon: 74.63655,
      category: "Academic",
      verified: false,
    ),
    CampusLocation(
      name: "Humanities Block",
      lat: 25.03120,
      lon: 74.63620,
      category: "Academic",
      verified: false,
    ),
    CampusLocation(
      name: "Vocational Studies",
      lat: 25.03095,
      lon: 74.63585,
      category: "Academic",
      verified: false,
    ),
    CampusLocation(
      name: "Mass Communication",
      lat: 25.03075,
      lon: 74.63550,
      category: "Academic",
      verified: false,
    ),
    CampusLocation(
      name: "IT Block",
      lat: 25.03100,
      lon: 74.63665,
      category: "Academic",
      verified: false,
    ),
    CampusLocation(
      name: "Library / Computer Science",
      lat: 25.03170,
      lon: 74.63685,
      category: "Academic",
      verified: false,
    ),

    // Food & Dining
    CampusLocation(
      name: "Mess / Dining",
      lat: 25.03300,
      lon: 74.63675,
      category: "Food",
      verified: false,
    ),
    CampusLocation(
      name: "International Mess + Gym",
      lat: 25.03355,
      lon: 74.63700,
      category: "Food",
      verified: false,
    ),
    CampusLocation(
      name: "Canteen",
      lat: 25.03310,
      lon: 74.63520,
      category: "Food",
      verified: false,
    ),

    // Commercial & Facilities
    CampusLocation(
      name: "Bank & ATM",
      lat: 25.03275,
      lon: 74.63595,
      category: "Facility",
      verified: false,
    ),
    CampusLocation(
      name: "Shopping Complex",
      lat: 25.03305,
      lon: 74.63535,
      category: "Shopping",
      verified: false,
    ),
    CampusLocation(
      name: "Guard Room",
      lat: 25.03320,
      lon: 74.63545,
      category: "Security",
      verified: false,
    ),
    CampusLocation(
      name: "Parking",
      lat: 25.03255,
      lon: 74.63555,
      category: "Parking",
      verified: false,
    ),
    CampusLocation(
      name: "Temple",
      lat: 25.03380,
      lon: 74.63560,
      category: "Religious",
      verified: false,
    ),
    CampusLocation(
      name: "Auditorium",
      lat: 25.03035,
      lon: 74.63615,
      category: "Facility",
      verified: false,
    ),
    CampusLocation(
      name: "STP",
      lat: 25.02990,
      lon: 74.63680,
      category: "Utility",
      verified: false,
    ),
    CampusLocation(
      name: "Main Gate",
      lat: 25.03270,
      lon: 74.63490,
      category: "Entry",
      verified: false,
    ),

    // Sports
    CampusLocation(
      name: "Football Ground",
      lat: 25.03425,
      lon: 74.63725,
      category: "Sports",
      verified: false,
    ),
    CampusLocation(
      name: "Cricket Practice Pitch",
      lat: 25.03460,
      lon: 74.63700,
      category: "Sports",
      verified: false,
    ),
    CampusLocation(
      name: "Basketball Court",
      lat: 25.03440,
      lon: 74.63660,
      category: "Sports",
      verified: false,
    ),
    CampusLocation(
      name: "Volleyball Court",
      lat: 25.03470,
      lon: 74.63645,
      category: "Sports",
      verified: false,
    ),
  ];

  static List<String> get categories {
    final set = allLocations.map((l) => l.category).toSet().toList();
    set.sort();
    return ['All', ...set];
  }

  static CampusLocation? findByName(String name) {
    try {
      return allLocations.firstWhere(
        (l) => l.name.toLowerCase().trim() == name.toLowerCase().trim(),
      );
    } catch (_) {
      return null;
    }
  }

  static List<CampusLocation> search(String query, {String? category}) {
    final q = query.toLowerCase().trim();
    return allLocations.where((loc) {
      final matchesQuery = q.isEmpty ||
          loc.name.toLowerCase().contains(q) ||
          loc.category.toLowerCase().contains(q);
      final matchesCat = category == null || category == 'All' || loc.category == category;
      return matchesQuery && matchesCat;
    }).toList();
  }
}
