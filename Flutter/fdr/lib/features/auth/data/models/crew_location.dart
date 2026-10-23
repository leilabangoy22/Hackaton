import 'dart:math';

import 'package:google_maps_flutter/google_maps_flutter.dart';

class CrewLocation {
  final String id;
  final String name;
  final double latitude;
  final double longitude;
  final bool hasAssignment;
  final bool isTracking;

  CrewLocation({
    required this.id,
    required this.name,
    required this.latitude,
    required this.longitude,
    required this.hasAssignment,
    required this.isTracking,
  });

  CrewLocation.fromLatLng({
    required this.id,
    required this.name,
    required LatLng location,
    required this.hasAssignment,
    required this.isTracking,
  }) : latitude = location.latitude,
       longitude = location.longitude;

  factory CrewLocation.fromJson(Map<String, dynamic> json) {
    return CrewLocation(
      id: json['crew_id']?.toString() ?? '',
      name: json['crew_name']?.toString() ?? 'Unknown Crew',
      latitude: (json['latitude'] as num?)?.toDouble() ?? 0.0,
      longitude: (json['longitude'] as num?)?.toDouble() ?? 0.0,

      hasAssignment: json['has_assignment'] is bool
          ? json['has_assignment'] as bool
          : (json['has_assignment'] is String
                ? json['has_assignment'].toString().toLowerCase() == 'true'
                : (json['has_assignment'] as int? ?? 0) == 1),

      isTracking: json['is_tracking'] is bool
          ? json['is_tracking'] as bool
          : (json['is_tracking'] is String
                ? json['is_tracking'].toString().toLowerCase() == 'true'
                : (json['is_tracking'] as int? ?? 0) == 1),
    );
  }

  CrewLocation copyWith({
    String? id,
    String? name,
    double? latitude,
    double? longitude,
    bool? hasAssignment,
    bool? isTracking,
  }) {
    return CrewLocation(
      id: id ?? this.id,
      name: name ?? this.name,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      hasAssignment: hasAssignment ?? this.hasAssignment,
      isTracking: isTracking ?? this.isTracking,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'crew_id': id,
      'crew_name': name,
      'latitude': latitude,
      'longitude': longitude,
      'has_assignment': hasAssignment,
      'is_tracking': isTracking,
    };
  }

  LatLng get location => LatLng(latitude, longitude);

  /// Calculates distance to another location in kilometers using Haversine formula.
  double distanceTo(double targetLat, double targetLng) {
    const double earthRadius = 6371; // Earth's radius in kilometers

    double dLat = _toRadians(targetLat - latitude);
    double dLng = _toRadians(targetLng - longitude);

    double a =
        sin(dLat / 2) * sin(dLat / 2) +
        cos(_toRadians(latitude)) *
            cos(_toRadians(targetLat)) *
            sin(dLng / 2) *
            sin(dLng / 2);

    double c = 2 * atan2(sqrt(a), sqrt(1 - a));

    return earthRadius * c;
  }

  double _toRadians(double degrees) {
    return degrees * (3.141592653589793 / 180.0);
  }

  String get status {
    if (!hasAssignment) return 'Available';
    if (isTracking) return 'On Active Mission';
    return 'Assigned (Inactive)';
  }

  int get statusColor {
    if (!hasAssignment) return 0xFF4CAF50;
    if (isTracking) return 0xFF2196F3;
    return 0xFFFF9800;
  }

  @override
  String toString() {
    return 'CrewLocation(id: $id, name: $name, location: ($latitude, $longitude), hasAssignment: $hasAssignment, isTracking: $isTracking)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is CrewLocation &&
        other.id == id &&
        other.name == name &&
        other.latitude == latitude &&
        other.longitude == longitude &&
        other.hasAssignment == hasAssignment &&
        other.isTracking == isTracking;
  }

  @override
  int get hashCode =>
      id.hashCode ^
      name.hashCode ^
      latitude.hashCode ^
      longitude.hashCode ^
      hasAssignment.hashCode ^
      isTracking.hashCode;
}
