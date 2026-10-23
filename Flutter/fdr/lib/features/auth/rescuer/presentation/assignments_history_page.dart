import 'package:fdr/features/auth/user/presentation/report_detail/report_detail_page.dart';
import 'package:fdr/services/api_service.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:fdr/features/auth/data/models/report/report_data.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

class AssignmentsHistoryPage extends StatelessWidget {
  final List<dynamic> reports;
  final VoidCallback? onRefresh;
  final Function(Map<String, dynamic> report)? onReportTap;

  const AssignmentsHistoryPage({
    super.key,
    required this.reports,
    this.onRefresh,
    this.onReportTap,
  });

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<int?>(
      future: _getCurrentUserId(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final currentUserId = snapshot.data;
        if (currentUserId == null) {
          return const Center(
            child: Text('Unable to load user data'),
          );
        }

        final resolvedReports = reports.where((report) {
          if (report is! Map) return false;
          
          final status = report['response_status']?.toString().toLowerCase();
          final assignedTo = report['assigned_to'] as int?;
          
          return (status == 'resolved' || status == 'completed') && 
                 assignedTo == currentUserId;
        }).toList();

        return RefreshIndicator(
          onRefresh: () async {
            onRefresh?.call();
          },
          child: resolvedReports.isEmpty
              ? const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.history, size: 64, color: Colors.grey),
                      SizedBox(height: 16),
                      Text(
                        'No Assignment History',
                        style: TextStyle(fontSize: 18, color: Colors.grey),
                      ),
                      SizedBox(height: 8),
                      Text(
                        'Your completed assignments will appear here.',
                        style: TextStyle(fontSize: 14, color: Colors.grey),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  itemCount: resolvedReports.length,
                  itemBuilder: (context, index) {
                    final report = resolvedReports[index];
                    return _buildHistoryCard(report, context);
                  },
                ),
        );
      },
    );
  }

  Future<int?> _getCurrentUserId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt('user_id');
  }

  Widget _buildHistoryCard(Map<String, dynamic> report, BuildContext context) {
    final reportId = _getReportId(report);
    final reportTitle = _getReportTitle(report);
    final status = _getReportStatus(report);
    final severity = _getReportSeverity(report);
    final description = _getReportDescription(report);
    final createdAt = _getReportCreatedAt(report);

    return Card(
      color: Colors.white,
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: ListTile(
        leading: const Icon(Icons.check_circle, color: Colors.green),
        title: Text('Report #$reportId'),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Status: ${status.toUpperCase()}'),
            Text('Severity: $severity'),
            if (reportTitle.isNotEmpty)
              Text(
                reportTitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            if (createdAt.isNotEmpty)
              Text(
                'Completed: ${_formatDate(createdAt)}',
                style: const TextStyle(fontSize: 12, color: Colors.grey),
              ),
          ],
        ),
        trailing: const Icon(Icons.arrow_forward_ios, size: 16),
        onTap: () {
          if (onReportTap != null) {
            onReportTap!(report);
          } else {
            _navigateToReportDetailsFallback(context, report);
          }
        },
      ),
    );
  }

  void _navigateToReportDetailsFallback(BuildContext context, Map<String, dynamic> report) async {
    try {
      final reportData = _convertToReportData(report);
      final location = await _getReportLocation(report);
      
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => ReportDetailScreen(
            report: reportData,
            severityColor: _getSeverityColor(reportData.severity),
            address: (locationId) async => null, 
            reportLocation: location,
          ),
        ),
      );
    } catch (e) {
      debugPrint('Error in fallback navigation: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error loading report details: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  String _getReportId(Map<dynamic, dynamic> report) {
    return (report['id'] ?? report['report_id'] ?? report['_id'] ?? 'N/A').toString();
  }
  String _getReportTitle(Map<dynamic, dynamic> report) {
    return (report['title'] ?? 'N/A').toString();
  }
  String _getReportStatus(Map<dynamic, dynamic> report) {
    return (report['response_status'] ?? report['status'] ?? 'Unknown').toString();
  }

  String _getReportSeverity(Map<dynamic, dynamic> report) {
    return (report['severity'] ?? report['level'] ?? 'LOW').toString();
  }

  String _getReportDescription(Map<dynamic, dynamic> report) {
    return (report['description'] ?? report['explanation'] ?? 'No description').toString();
  }

  String _getReportCreatedAt(Map<dynamic, dynamic> report) {
    return (report['created_at'] ?? report['created'] ?? report['timestamp'] ?? '').toString();
  }

  Future<LatLng?> _getReportLocation(Map<dynamic, dynamic> report) async {
    try {
      final apiService = ApiService();
      
      final latitude = _parseDouble(report['latitude']);
      final longitude = _parseDouble(report['longitude']);
      
      if (latitude != null && longitude != null) {
        return LatLng(latitude, longitude);
      }

      final locationId = _parseInt(report['location_id']);
      if (locationId != null) {
        final locationData = await apiService.getLocationById(locationId);
        
        if (locationData != null) {
          final lat = double.tryParse(locationData['latitude']?.toString() ?? '');
          final lng = double.tryParse(locationData['longitude']?.toString() ?? '');
          
          if (lat != null && lng != null) {
            return LatLng(lat, lng);
          }
        }
      }
      
      return null;
    } catch (e) {
      debugPrint('Error fetching report location: $e');
      return null;
    }
  }

  ReportData _convertToReportData(Map<dynamic, dynamic> report) {
    final reportId = _getReportId(report);

    return ReportData(
      reportId: reportId,
      title: report['title']?.toString(),
      description: report['description']?.toString(),
      explanation: report['explanation']?.toString(),
      severity: _parseSeverity(report['severity']),
      floodHeight: _parseFloodHeight(report['flood_height']),
      latitude: _parseDouble(report['latitude']),
      longitude: _parseDouble(report['longitude']),
      address: report['address']?.toString(),
      responseStatus: report['response_status']?.toString() ?? report['status']?.toString(),
      timestamp: _parseDateTime(report['created_at']),
      createdAt: _parseDateTime(report['created_at']),
      assignmentId: _parseAssignmentId(report),
      reportedBy: report['user_name']?.toString(),
      createdBy: report['created_by']?.toString(),
      userId: _parseInt(report['user_id']),
      locationId: _parseInt(report['location_id']),
      responseId: _parseInt(report['response_id']),
      assignedTo: _parseInt(report['rescuer_id'] ?? report['assigned_to']),
      phoneNumber: report['phone_number']?.toString() ?? report['user_phone_number']?.toString(),
    );
  }

  int? _parseInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is String) return int.tryParse(value);
    return null;
  }

  int? _parseAssignmentId(Map<dynamic, dynamic> report) {
    final value = report['assignment_id'] ?? report['assigned_to'] ?? report['rescuer_id'] ?? report['response_id'];
    return _parseInt(value);
  }

  FloodSeverity? _parseSeverity(dynamic severity) {
    if (severity == null) return null;
    final severityStr = severity.toString().toLowerCase();
    if (severityStr.contains('high')) return FloodSeverity.high;
    if (severityStr.contains('moderate')) return FloodSeverity.moderate;
    if (severityStr.contains('low')) return FloodSeverity.low;
    return null;
  }

  double? _parseFloodHeight(dynamic height) {
    if (height == null) return null;
    if (height is double) return height;
    if (height is int) return height.toDouble();
    if (height is String) return double.tryParse(height);
    return null;
  }

  double? _parseDouble(dynamic value) {
    if (value == null) return null;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) return double.tryParse(value);
    return null;
  }

  DateTime? _parseDateTime(dynamic dateTime) {
    if (dateTime == null) return null;
    if (dateTime is DateTime) return dateTime;
    if (dateTime is String) return DateTime.tryParse(dateTime);
    return null;
  }

  Color _getSeverityColor(FloodSeverity? severity) {
    switch (severity) {
      case FloodSeverity.high:
        return Colors.red;
      case FloodSeverity.moderate:
        return Colors.orange;
      case FloodSeverity.low:
        return Colors.green;
      default:
        return Colors.grey;
    }
  }

  String _formatDate(String dateString) {
    try {
      final date = DateTime.parse(dateString);
      return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
    } catch (e) {
      return dateString;
    }
  }
}