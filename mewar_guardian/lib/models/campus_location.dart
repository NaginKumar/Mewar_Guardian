class CampusLocation {
  final String name;
  final double lat;
  final double lon;
  final String category;
  final bool verified;

  const CampusLocation({
    required this.name,
    required this.lat,
    required this.lon,
    required this.category,
    this.verified = false,
  });

  factory CampusLocation.fromJson(Map<String, dynamic> json) {
    return CampusLocation(
      name: json['name']?.toString() ?? 'Unknown Location',
      lat: (json['lat'] as num?)?.toDouble() ?? 25.033000,
      lon: (json['lon'] as num?)?.toDouble() ?? 74.635912,
      category: json['category']?.toString() ?? 'General',
      verified: json['verified'] == true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'lat': lat,
      'lon': lon,
      'category': category,
      'verified': verified,
    };
  }
}
