import 'dart:convert';
import 'dart:developer' as developer;
import 'package:fdr/app_routes.dart';
import 'package:fdr/features/auth/user/presentation/report_detail/report_detail_page.dart';
import 'package:fdr/services/api_service.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:fdr/features/auth/data/models/report/report_data.dart';
import 'assignments_history_page.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

class AssignmentsPage extends StatefulWidget {
  const AssignmentsPage({super.key});

  @override
  State<AssignmentsPage> createState() => _AssignmentsPageState();
}

class _AssignmentsPageState extends State<AssignmentsPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  int? _currentUserId;
  bool _isLoading = true;
  List<dynamic> _rescuerReports = [];
  final ApiService _apiService = ApiService();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadUserDataAndReports();
    _refreshReports();
  }

  void _log(String message) {
    developer.log(message, name: 'AssignmentsPage');
    debugPrint('[AssignmentsPage] $message');
    print('[AssignmentsPage] $message');
  }

  Future<void> _loadUserDataAndReports() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final userRole = prefs.getString('user_role');
      final userId = prefs.getInt('user_id');

      _log('User Role: $userRole');
      _log('User ID: $userId');

      setState(() {
        _currentUserId = userId;
      });

      if (userRole == 'rescuer' && userId != null) {
        await _loadRescuerReports();
      } else {
        _log('Not loading reports - User role: $userRole, User ID: $userId');
      }
    } catch (e) {
      _log('ERROR loading user data: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _loadRescuerReports() async {
    try {
      final reportsResponse = await _apiService.getAllReports(limit: 100);

      List<dynamic> allReports = [];
      if (reportsResponse is Map && reportsResponse.containsKey('data')) {
        allReports = reportsResponse['data'] as List;
      } else if (reportsResponse is List) {
        allReports = reportsResponse;
      } else {
        allReports = reportsResponse ?? [];
      }

      final filteredReports = allReports.where((report) {
        if (report is! Map) return false;

        final assignmentId = _getAssignmentId(report);
        final reportId = report['id'] ?? report['report_id'] ?? report['_id'];
        final status = report['response_status'] ?? report['status'];

        _log(
          'Checking Report $reportId - assignment_id: $assignmentId (type: ${assignmentId.runtimeType}), current user: $_currentUserId (type: ${_currentUserId.runtimeType}), status: $status',
        );

        final assignmentIdStr = assignmentId?.toString();
        final currentUserIdStr = _currentUserId?.toString();

        final matches = assignmentIdStr == currentUserIdStr;
        _log('Match result for Report $reportId: $matches');

        return matches;
      }).toList();

      setState(() {
        _rescuerReports = filteredReports;
      });
    } catch (e, stackTrace) {
      _log('ERROR loading rescuer reports: $e');
      _log('Stack trace: $stackTrace');

      setState(() {
        _rescuerReports = [];
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to load assignments: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    }
  }

  dynamic _getAssignmentId(Map<dynamic, dynamic> report) {
    return report['assignment_id'] ??
        report['assigned_to'] ??
        report['rescuer_id'] ??
        report['response_id'] ??
        report['user_id'] ??
        report['assigned_user_id'];
  }

  Future<void> _refreshReports() async {
    if (_currentUserId != null) {
      _log('Refreshing reports...');
      setState(() {
        _isLoading = true;
      });
      await _loadRescuerReports();
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<LatLng?> _getReportLocation(Map<dynamic, dynamic> report) async {
    try {
      final latitude = _parseDouble(report['latitude']);
      final longitude = _parseDouble(report['longitude']);

      if (latitude != null && longitude != null) {
        return LatLng(latitude, longitude);
      }

      final locationId = _parseInt(report['location_id']);
      if (locationId != null) {
        _log('Fetching location from API using ID: $locationId');

        final locationData = await _apiService.getLocationById(locationId);

        if (locationData != null) {
          _log('Location API response: $locationData');

          final lat = double.tryParse(
            locationData['latitude']?.toString() ?? '',
          );
          final lng = double.tryParse(
            locationData['longitude']?.toString() ?? '',
          );

          if (lat != null && lng != null) {
            _log('Successfully extracted coordinates: Lat=$lat, Lng=$lng');
            return LatLng(lat, lng);
          } else {
            _log('Invalid coordinates in API response: lat=$lat, lng=$lng');
          }
        } else {
          _log('No location data received from API');
        }
      }

      _log('No location information available for report');
      return null;
    } catch (e) {
      _log('Error fetching report location: $e');
      return null;
    }
  }

  ReportData _convertToReportData(Map<dynamic, dynamic> report) {
    final reportId = _getReportId(report);

    _log('Report ID: $reportId');

    try {
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
        responseStatus:
            report['response_status']?.toString() ??
            report['status']?.toString(),
        timestamp: _parseDateTime(report['created_at']),
        createdAt: _parseDateTime(report['created_at']),
        assignmentId: _parseAssignmentId(report),
        reportedBy: report['user_name']?.toString(),
        createdBy: report['created_by']?.toString(),
        userId: _parseInt(report['user_id']),
        locationId: _parseInt(report['location_id']),
        responseId: _parseInt(report['response_id']),
        assignedTo: _parseInt(report['rescuer_id'] ?? report['assigned_to']),
        phoneNumber:
            report['phone_number']?.toString() ??
            report['user_phone_number']?.toString(),
      );
    } catch (e, stackTrace) {
      _log('ERROR in ReportData creation: $e');
      _log('Stack trace: $stackTrace');
      _log('Report data causing error: ${report.toString()}');
      rethrow;
    }
  }

  int? _parseInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is String) return int.tryParse(value);
    return null;
  }

  int? _parseAssignmentId(Map<dynamic, dynamic> report) {
    final value =
        report['assignment_id'] ??
        report['assigned_to'] ??
        report['rescuer_id'] ??
        report['response_id'];
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

  void _navigateToReportDetails(Map<dynamic, dynamic> report) async {
    try {
      _log('Navigating to report details for report: ${report['id']}');
      final reportData = _convertToReportData(report);

      final location = await _getReportLocation(report);
      _log('Fetched location for navigation: $location');

      if (mounted) {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => ReportDetailScreen(
              report: reportData,
              severityColor: _getSeverityColorFromFloodSeverity(
                reportData.severity,
              ),
              address: (locationId) async {
                return null;
              },
              reportLocation: location,
            ),
          ),
        );
      }
    } catch (e, stackTrace) {
      _log('ERROR navigating to report details: $e');
      _log('Stack trace: $stackTrace');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Error loading report details'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _navigateToReportDetailsWrapper(Map<dynamic, dynamic> report) async {
    try {
      _log('Navigating to report details for report: ${report['id']}');
      final reportData = _convertToReportData(report);

      final location = await _getReportLocation(report);
      _log('Fetched location for navigation: $location');

      if (mounted) {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => ReportDetailScreen(
              report: reportData,
              severityColor: _getSeverityColorFromFloodSeverity(
                reportData.severity,
              ),
              address: (locationId) async {
                return null;
              },
              reportLocation: location,
            ),
          ),
        );
      }
    } catch (e, stackTrace) {
      _log('ERROR navigating to report details: $e');
      _log('Stack trace: $stackTrace');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Error loading report details'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Color _getSeverityColorFromFloodSeverity(FloodSeverity? severity) {
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

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        title: const Text('Assignments'),
        centerTitle: true,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.blue.shade700,
          labelColor: Colors.blue.shade700,
          unselectedLabelColor: Colors.grey,
          tabs: const [
            Tab(text: 'Assignments'),
            Tab(text: 'History'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildAssignmentsTab(),
          AssignmentsHistoryPage(
            reports: _rescuerReports,
            onRefresh: _refreshReports,
            onReportTap: _navigateToReportDetailsWrapper,
          ),
        ],
      ),
      floatingActionButton: _currentUserId != null
          ? FloatingActionButton(
              onPressed: _refreshReports,
              child: const Icon(Icons.refresh),
            )
          : null,
    );
  }

  Widget _buildAssignmentsTab() {
    if (_isLoading) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Loading assignments...'),
          ],
        ),
      );
    }

    if (_currentUserId == null) {
      return _buildErrorState(
        'Unable to load user data. Please check if you are logged in as a rescuer.',
      );
    }

    if (_rescuerReports.isEmpty) {
      return _buildNoAssignmentsState();
    }

    final activeAssignments = _rescuerReports.where((report) {
      final status = _getReportStatus(report);
      return status != 'completed' &&
          status != 'cancelled' &&
          status != 'resolved';
    }).toList();

    return RefreshIndicator(
      onRefresh: _refreshReports,
      child: Column(
        children: [
          _buildHeaderInfo(activeAssignments.length),
          Expanded(
            child: activeAssignments.isEmpty
                ? _buildNoActiveAssignmentsState()
                : ListView.builder(
                    itemCount: activeAssignments.length,
                    itemBuilder: (context, index) {
                      final report = activeAssignments[index];
                      return _buildAssignmentCard(report);
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeaderInfo(int activeCount) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      color: Colors.blue.shade50,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Rescuer ID: $_currentUserId',
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.blue,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Total Assignments: ${_rescuerReports.length}',
            style: const TextStyle(fontSize: 14, color: Colors.black54),
          ),
          Text(
            'Active Assignments: $activeCount',
            style: const TextStyle(fontSize: 14, color: Colors.black54),
          ),
          const SizedBox(height: 4),
        ],
      ),
    );
  }

  Widget _buildNoAssignmentsState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.assignment, size: 64, color: Colors.grey),
          const SizedBox(height: 16),
          const Text(
            'No Assignments Found',
            style: TextStyle(fontSize: 18, color: Colors.grey),
          ),
          const SizedBox(height: 8),
          Text(
            'No reports found where assignment_id = $_currentUserId\n\n'
            'This could mean:\n'
            '• No reports are assigned to you yet\n'
            '• The assignment field has a different name\n'
            '• All assigned reports are completed/cancelled\n\n'
            'Check the console/logs for detailed debug info',
            style: const TextStyle(fontSize: 14, color: Colors.grey),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: _refreshReports,
            child: const Text('Refresh'),
          ),
        ],
      ),
    );
  }

  Widget _buildNoActiveAssignmentsState() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.check_circle, size: 64, color: Colors.green),
          SizedBox(height: 16),
          Text(
            'No Active Assignments',
            style: TextStyle(fontSize: 18, color: Colors.green),
          ),
          SizedBox(height: 8),
          Text(
            'All your assignments are completed or cancelled.',
            style: TextStyle(fontSize: 14, color: Colors.grey),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState(String message) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, size: 64, color: Colors.grey),
          const SizedBox(height: 16),
          const Text(
            'Unable to load assignments',
            style: TextStyle(fontSize: 18, color: Colors.black54),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32.0),
            child: Text(
              message,
              style: const TextStyle(fontSize: 14, color: Colors.grey),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAssignmentCard(Map<dynamic, dynamic> report) {
    final reportId = _getReportId(report);
    final status = _getReportStatus(report);
    final severity = _getReportSeverity(report).toUpperCase();
    final description = _getReportDescription(report);
    final createdAt = _getReportCreatedAt(report);
    final assignmentId = _getAssignmentId(report);

    Color statusColor = Colors.grey;
    if (status == 'assigned') statusColor = Colors.orange;
    if (status == 'confirmed') statusColor = Colors.blue;
    if (status == 'in_progress') statusColor = Colors.green;
    if (status == 'completed') statusColor = Colors.green;
    if (status == 'cancelled') statusColor = Colors.red;
    if (status == 'resolved') statusColor = Colors.green;

    return Card(
      color: Colors.white,
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: InkWell(
        onTap: () => _navigateToReportDetails(report),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Report #$reportId',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: statusColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: statusColor),
                    ),
                    child: Text(
                      status.replaceAll('_', ' ').toUpperCase(),
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: statusColor,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 2),

              Container(
                padding: const EdgeInsets.only(bottom: 8),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.white),
                ),
                child: Text(
                  'Assigned to: You',
                  style: const TextStyle(fontSize: 12, color: Colors.black54),
                ),
              ),
              Column(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    // decoration: BoxDecoration(
                    //   color: _getSeverityColorFromString(
                    //     severity,
                    //   ).withOpacity(0.1),
                    //   borderRadius: BorderRadius.circular(8),
                    //   border: Border.all(
                    //     color: _getSeverityColorFromString(severity),
                    //   ),
                    // ),
                    child: Text(
                      'Severity: $severity',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: _getSeverityColorFromString(severity),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                description,
                style: const TextStyle(fontSize: 14, color: Colors.black54),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              if (createdAt.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  'Created: ${_formatDate(createdAt)}',
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  String _getReportId(Map<dynamic, dynamic> report) {
    return (report['id'] ?? report['report_id'] ?? report['_id'] ?? 'N/A')
        .toString();
  }

  String _getReportStatus(Map<dynamic, dynamic> report) {
    return (report['response_status'] ?? report['status'] ?? 'Unknown')
        .toString();
  }

  String _getReportSeverity(Map<dynamic, dynamic> report) {
    return (report['severity'] ?? report['level'] ?? 'LOW').toString();
  }

  String _getReportDescription(Map<dynamic, dynamic> report) {
    return (report['explanation'] ?? 'No description').toString();
  }

  String _getReportCreatedAt(Map<dynamic, dynamic> report) {
    return (report['created_at'] ??
            report['created'] ??
            report['timestamp'] ??
            '')
        .toString();
  }

  Color _getSeverityColorFromString(String severity) {
    switch (severity.toLowerCase()) {
      case 'high':
        return Colors.red;
      case 'medium':
      case 'moderate':
        return Colors.orange;
      case 'low':
        return Colors.yellow;
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
