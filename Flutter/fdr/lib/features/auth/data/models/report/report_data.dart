import 'package:flutter/foundation.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

enum ReportStatus {
  pending,
  complete,
  newReport,
  inProgress,
  resolved,
  ongoing,
  completed,
  assigned,
  confirmed,
}

enum ResponseStatus {
  pending,
  inProgress,
  resolved,
  ongoing,
  completed,
  assigned,
  confirmed,
}

enum FloodSeverity { low, moderate, high }

class ReportData {
  final String reportId;
  final int? locationId;
  final int? userId;
  final String? title;
  final double? floodHeight;
  final String? explanation;
  final String? responseStatus;
  final int? responseId;
  final String? createdBy;
  final DateTime? createdAt;
  final String? updatedBy;
  final DateTime? updatedAt;
final int? dispatcherId;
  final String? description;
  final String? address;
  final LatLng? location;
  final FloodSeverity? severity;
  final DateTime? timestamp;
  final String? reporterId;
  final ReportStatus? status;
  final double? latitude;
  final double? longitude;
  final int? assignmentId;
  final String? reportedBy;
  final String? phoneNumber;
  final int? assignedTo;

  ReportData({
    required this.reportId,
    this.locationId,
    this.userId,
    this.title,
    this.floodHeight,
    this.explanation,
    this.responseStatus,
    this.responseId,
    this.createdBy,
    this.createdAt,
    this.updatedBy,
    this.updatedAt,
    this.description,
    this.address,
    this.location,
    this.severity,
    this.timestamp,
    this.reporterId,
    this.status,
    this.latitude,
    this.longitude,
    this.assignmentId,
    this.reportedBy,
    this.phoneNumber,
    this.assignedTo,
    this.dispatcherId,
  });

  factory ReportData.fromJson(Map<String, dynamic> json) {
    if (kDebugMode) {
      print('Parsing ReportData from API: $json');
    }

    final data = json['data'] ?? json;

    String parseReportId(dynamic id) {
      if (id == null) return '0';
      if (id is int) return id.toString();
      if (id is String) return id;
      return '0';
    }

    double? parseDouble(dynamic value) {
      if (value == null) return null;
      if (value is double) return value;
      if (value is int) return value.toDouble();
      if (value is String) return double.tryParse(value);
      return null;
    }

    DateTime? parseDateTime(dynamic value) {
      if (value == null) return null;
      try {
        return DateTime.parse(value.toString());
      } catch (_) {
        return null;
      }
    }

    FloodSeverity? deriveSeverity(dynamic height) {
      final h = parseDouble(height) ?? 0;
      if (h < 0.3) return FloodSeverity.low;
      if (h < 0.7) return FloodSeverity.moderate;
      return FloodSeverity.high;
    }

    ReportStatus deriveStatus(String? responseStatus) {
      if (responseStatus == null) return ReportStatus.newReport;
      final s = responseStatus.toLowerCase();
      if (s.contains('pending') || s.contains('new'))
        return ReportStatus.pending;
      if (s.contains('assigned') || s.contains('confirmed'))
        return ReportStatus.assigned;
      if (s.contains('in_progress') || s.contains('ongoing'))
        return ReportStatus.inProgress;
      if (s.contains('resolved') || s.contains('complete'))
        return ReportStatus.resolved;
      return ReportStatus.newReport;
    }

    final createdAt = parseDateTime(data['created_at']);
    final updatedAt = parseDateTime(data['updated_at']);
    final floodHeight = parseDouble(data['flood_height']);
    final responseStatus = data['response_status']?.toString();

    return ReportData(
      reportId: parseReportId(data['report_id']),
      locationId: data['location_id'] as int?,
      userId: data['user_id'] as int?,
      title: data['title']?.toString() ?? 'Flood Report',
      floodHeight: floodHeight,
      explanation: data['explanation']?.toString(),
      responseStatus: responseStatus,
      responseId: data['response_id'] as int?,
      createdBy: data['created_by']?.toString(),
      createdAt: createdAt,
      updatedBy: data['updated_by']?.toString(),
      updatedAt: updatedAt,
      description: data['explanation']?.toString() ?? 'No details available',
      latitude: null,
      longitude: null,
      address: null,
      severity: deriveSeverity(floodHeight),
      status: deriveStatus(responseStatus),
      timestamp: createdAt ?? DateTime.now(),
      reporterId: data['user_id']?.toString() ?? data['created_by']?.toString(),
      assignedTo: data['rescuer_id'] as int?,
      assignmentId: data['response_id'] as int?,
      reportedBy: data['user_id']?.toString() ?? data['created_by']?.toString(),
      phoneNumber: data['user_phone_number']?.toString() ?? 'N/A',
      dispatcherId: data['dispatcher_id'] as int?,
    );
  }

  ReportData copyWith({
    String? reportId,
    int? locationId,
    int? userId,
    int? dispatcherId,
    String? title,
    double? floodHeight,
    String? explanation,
    String? responseStatus,
    int? responseId,
    String? createdBy,
    DateTime? createdAt,
    String? updatedBy,
    DateTime? updatedAt,
    String? description,
    String? address,
    double? latitude,
    double? longitude,
    LatLng? location,
    FloodSeverity? severity,
    ReportStatus? status,
    DateTime? timestamp,
    String? reporterId,
    int? assignmentId,
    String? reportedBy,
    String? phoneNumber,
  }) {
    return ReportData(
      reportId: reportId ?? this.reportId,
      locationId: locationId ?? this.locationId,
      userId: userId ?? this.userId,
      title: title ?? this.title,
      floodHeight: floodHeight ?? this.floodHeight,
      explanation: explanation ?? this.explanation,
      responseStatus: responseStatus ?? this.responseStatus,
      responseId: responseId ?? this.responseId,
      createdBy: createdBy ?? this.createdBy,
      createdAt: createdAt ?? this.createdAt,
      updatedBy: updatedBy ?? this.updatedBy,
      updatedAt: updatedAt ?? this.updatedAt,
      description: description ?? this.description,
      address: address ?? this.address,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      location: location ?? this.location,
      severity: severity ?? this.severity,
      status: status ?? this.status,
      timestamp: timestamp ?? this.timestamp,
      reporterId: reporterId ?? this.reporterId,
      assignmentId: assignmentId ?? this.assignmentId,
      reportedBy: reportedBy ?? this.reportedBy,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      dispatcherId: dispatcherId ?? this.dispatcherId,
    );
  }

  LatLng? get locationLatLng {
    if (latitude != null && longitude != null)
      return LatLng(latitude!, longitude!);
    return null;
  }

  get reportStatus => null;

  // get dispatcher_id => dispatcher_id ?? this.dispatcher_id;

  Map<String, dynamic> toJson() {
    return {
      'report_id': int.tryParse(reportId) ?? 0,
      'location_id': locationId ?? 0,
      'user_id': userId ?? 0,
      'title': title ?? '',
      'flood_height': floodHeight ?? 0,
      'explanation': explanation ?? '',
      'response_status': responseStatus ?? 'pending',
      'response_id': responseId,
      'created_by': createdBy ?? '',
      'created_at': createdAt?.toIso8601String(),
      'updated_by': updatedBy ?? '',
      'updated_at': updatedAt?.toIso8601String(),
      'user_phone_number': phoneNumber ?? 'N/A',
    };
  }

  @override
  String toString() {
    return 'ReportData(reportId: $reportId, title: $title, floodHeight: $floodHeight, status: $responseStatus, createdAt: $createdAt)';
  }
}
