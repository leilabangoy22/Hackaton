class RescuerLocation {
  final double latitudeRescuer;
  final double longitudeRescuer;
  final double latitudeReport;
  final double longitudeReport;
  final double distance;
  final String timeArrival;

  RescuerLocation({
    required this.latitudeRescuer,
    required this.longitudeRescuer,
    required this.latitudeReport,
    required this.longitudeReport,
    required this.distance,
    required this.timeArrival,
  });

  factory RescuerLocation.fromJson(Map<String, dynamic> json) {
    return RescuerLocation(
      latitudeRescuer: (json['latitude_rescuer'] is String)
          ? double.tryParse(json['latitude_rescuer']) ?? 0.0
          : (json['latitude_rescuer'] as num?)?.toDouble() ?? 0.0,
      longitudeRescuer: (json['longitude_rescuer'] is String)
          ? double.tryParse(json['longitude_rescuer']) ?? 0.0
          : (json['longitude_rescuer'] as num?)?.toDouble() ?? 0.0,
      latitudeReport: (json['latitude_report'] is String)
          ? double.tryParse(json['latitude_report']) ?? 0.0
          : (json['latitude_report'] as num?)?.toDouble() ?? 0.0,
      longitudeReport: (json['longitude_report'] is String)
          ? double.tryParse(json['longitude_report']) ?? 0.0
          : (json['longitude_report'] as num?)?.toDouble() ?? 0.0,
      distance: (json['distance'] as num?)?.toDouble() ?? 0.0,
      timeArrival: json['time_arrival']?.toString() ?? '',
    );
  }
}
