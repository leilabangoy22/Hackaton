import 'package:fdr/features/auth/data/models/report/report_data.dart';
import 'package:fdr/features/widgets/map_viewer.dart';
import 'package:fdr/features/widgets/real_time_map_viewer.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:fdr/services/api_service.dart';

class ReportDetailScreen extends StatefulWidget {
  final ReportData report;
  final Color severityColor;
  final Future<Map<String, dynamic>?> Function(int locationId) address;
  final VoidCallback? onAssignmentAccepted;
  final LatLng? reportLocation;
  const ReportDetailScreen({
    super.key,
    required this.report,
    required this.severityColor,
    required this.address,
    this.onAssignmentAccepted,
    required this.reportLocation,
  });

  @override
  State<ReportDetailScreen> createState() => _ReportDetailScreenState();
}

class _ReportDetailScreenState extends State<ReportDetailScreen> {
  final ApiService _apiService = ApiService();
  bool _isLoading = false;
  int? _currentUserId;
  String? _currentUserName;
  String? _userRole;

  @override
  void initState() {
    super.initState();
    _loadUserData();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _debugLocationApi();
    });
  }

  Future<void> _loadUserData() async {
    final prefs = await SharedPreferences.getInstance();
    final userId = prefs.getInt('user_id');
    final username = prefs.getString('user_name');
    final userRole = prefs.getString('user_role');
    setState(() {
      _currentUserId = userId;
      _currentUserName = username;
      _userRole = userRole;
    });
  }

  bool get _isRescuer {
    return _userRole?.toLowerCase().contains('rescuer') == true;
  }

  bool get _isUser {
    return _userRole?.toLowerCase().contains('user') == true;
  }

  bool get _isDispatcher {
    return _userRole?.toLowerCase().contains('dispatcher') == true;
  }

  ReportStatus? _parseReportStatus(dynamic status) {
    if (status == null) return null;

    final statusStr = status.toString().toLowerCase();

    if (statusStr.contains('pending')) return ReportStatus.pending;
    if (statusStr.contains('new')) return ReportStatus.newReport;
    if (statusStr.contains('assigned')) return ReportStatus.assigned;
    if (statusStr.contains('progress') || statusStr.contains('ongoing')) {
      return ReportStatus.inProgress;
    }
    if (statusStr.contains('resolved') || statusStr.contains('complete')) {
      return ReportStatus.resolved;
    }
    if (statusStr.contains('confirmed')) return ReportStatus.confirmed;

    return ReportStatus.pending;
  }

  String _getCleanStatusName(ReportStatus? status) {
    if (status == null) return 'N/A';

    final statusString = status.toString().split('.').last;

    switch (statusString) {
      case 'pending':
        return 'Pending';
      case 'newReport':
        return 'New Report';
      case 'assigned':
        return 'Assigned';
      case 'confirmed':
        return 'Confirmed';
      case 'inProgress':
        return 'In Progress';
      case 'ongoing':
        return 'Ongoing';
      case 'resolved':
        return 'Resolved';
      case 'complete':
        return 'Completed';
      case 'completed':
        return 'Completed';
      default:
        return statusString
            .splitMapJoin(
              RegExp(r'[A-Z]'),
              onMatch: (m) => ' ${m.group(0)}',
              onNonMatch: (n) =>
                  n.isEmpty ? '' : n[0].toUpperCase() + n.substring(1),
            )
            .trim();
    }
  }

  Future<void> _acceptAssignment() async {
    if (_isLoading) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final reportId = widget.report.reportId.toString();

      if (_currentUserId == null) {
        throw Exception('User ID not found');
      }

      final now = DateTime.now().toIso8601String();

      final updateData = {
        'report_id': int.tryParse(reportId),
        'response_status': 'confirmed',
        'assigned_to': _currentUserId,
        'user_id': widget.report.userId,
        "report_status": "confirmed",
        'dispatcher_id': widget.report.dispatcherId ?? 3,
        'location_id': widget.report.locationId ?? 0,
        'title': widget.report.title ?? 'Flood Report',
        'flood_height': widget.report.floodHeight ?? 0,
        'explanation':
            widget.report.explanation ??
            widget.report.description ??
            'No explanation provided',
        'created_by': widget.report.createdBy ?? _currentUserId,
        'created_at': widget.report.createdAt?.toIso8601String() ?? now,
        'updated_by': _currentUserName,
        'updated_at': now,

        'description': widget.report.description,
        'severity': widget.report.severity?.toString().split('.').last,
      };

      debugPrint('Updating report $reportId with data: $updateData');

      await _apiService.updateReport(reportId, updateData, _currentUserId!);

      widget.onAssignmentAccepted?.call();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Assignment accepted successfully!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      debugPrint('Error accepting assignment: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to accept assignment: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _completeAssignment() async {
    if (_isLoading) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final reportId = widget.report.reportId.toString();

      if (_currentUserId == null) {
        throw Exception('User ID not found');
      }

      final now = DateTime.now().toIso8601String();

      final updateData = {
        'report_id': int.tryParse(reportId),
        'response_status': 'resolved',
        'assigned_to': _currentUserId,
        'user_id': widget.report.userId,
        "report_status": "resolved",
        'dispatcher_id': widget.report.dispatcherId ?? 3,
        'location_id': widget.report.locationId ?? 0,
        'title': widget.report.title ?? 'Flood Report',
        'flood_height': widget.report.floodHeight ?? 0,
        'explanation':
            widget.report.explanation ??
            widget.report.description ??
            'No explanation provided',
        'created_by': widget.report.createdBy ?? _currentUserId,
        'created_at': widget.report.createdAt?.toIso8601String() ?? now,
        'updated_by': _currentUserName,
        'updated_at': now,

        'description': widget.report.description,
        'severity': widget.report.severity?.toString().split('.').last,
      };

      debugPrint('Completing report $reportId with data: $updateData');

      await _apiService.updateReport(reportId, updateData, _currentUserId!);

      widget.onAssignmentAccepted?.call();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Assignment completed successfully!'),
            backgroundColor: Colors.green,
          ),
        );
        
        Navigator.of(context).pop();
      }
    } catch (e) {
      debugPrint('Error completing assignment: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to complete assignment: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<LatLng?> _getReportLocation() async {
    if (widget.report.location != null) {
      return widget.report.location;
    } else if (widget.report.latitude != null &&
        widget.report.longitude != null) {
      return LatLng(widget.report.latitude!, widget.report.longitude!);
    } else if (widget.report.locationId != null) {
      debugPrint(
        'Fetching location from API using ID: ${widget.report.locationId}',
      );

      try {
        final locationData = await _apiService.getLocationById(
          widget.report.locationId!,
        );

        if (locationData != null) {
          debugPrint('Location API response: $locationData');

          final lat = double.tryParse(
            locationData['latitude']?.toString() ?? '',
          );
          final lng = double.tryParse(
            locationData['longitude']?.toString() ?? '',
          );

          if (lat != null && lng != null) {
            debugPrint(
              'Successfully extracted coordinates: Lat=$lat, Lng=$lng',
            );
            return LatLng(lat, lng);
          } else {
            debugPrint(
              'Invalid coordinates in API response: lat=$lat, lng=$lng',
            );
          }
        } else {
          debugPrint('No location data received from API');
        }
      } catch (e) {
        debugPrint('Error fetching location from API: $e');
      }
    }

    debugPrint('No location information available');
    return null;
  }

  Future<void> _debugLocationApi() async {
    if (widget.report.locationId != null) {
      debugPrint('=== DEBUG LOCATION API ===');
      debugPrint('Fetching location ID: ${widget.report.locationId}');

      final locationData = await _apiService.getLocationById(
        widget.report.locationId!,
      );
      debugPrint('Raw location API response: $locationData');

      if (locationData != null) {
        locationData.forEach((key, value) {
          debugPrint('Location[$key] = $value (type: ${value.runtimeType})');
        });
      }
      debugPrint('=== END DEBUG ===');
    }
  }

  @override
  Widget build(BuildContext context) {
    final status = _parseReportStatus(
      widget.report.status ?? widget.report.responseStatus,
    );
    final bool isOngoing =
        status == ReportStatus.inProgress ||
        status == ReportStatus.ongoing ||
        status == ReportStatus.confirmed;
    final bool isAssigned = status == ReportStatus.assigned;
    final String statusDisplay = _getCleanStatusName(status);

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: Text(
          widget.report.title ?? 'Report Details',
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: Colors.black87,
          ),
          overflow: TextOverflow.ellipsis,
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 20),
          onPressed: () => Navigator.of(context).pop(),
          color: Colors.black87,
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(color: Colors.grey[200], height: 1),
        ),
      ),
      body: FutureBuilder<LatLng?>(
        future: _getReportLocation(),
        builder: (context, snapshot) {
          final location = snapshot.data;

          return ReportDetailPageContent(
            report: widget.report,
            severityColor: widget.severityColor,
            statusDisplay: statusDisplay,
            parsedStatus: status,
            reportLocation: location,
            onCompleteAssignment: _isRescuer && isOngoing ? _completeAssignment : null,
            isLoading: _isLoading,
          );
        },
      ),
      bottomNavigationBar: _buildBottomNavigationBar(isOngoing, isAssigned),
    );
  }

  Widget? _buildBottomNavigationBar(bool isOngoing, bool isAssigned) {
    if (_isUser) {
      final isConfirmed =
          widget.report.responseStatus?.toLowerCase() == 'confirmed' ||
          widget.report.status == 'confirmed';

      if (isConfirmed) {
        return Container(
          decoration: BoxDecoration(
            color: Colors.white,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.08),
                blurRadius: 10,
                offset: const Offset(0, -2),
              ),
            ],
          ),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 20.0,
                vertical: 12.0,
              ),
              child: _buildLiveDispatchButton(),
            ),
          ),
        );
      }
      return null;
    }

    if (isOngoing || isAssigned) {
      return Container(
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.08),
              blurRadius: 10,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: 20.0,
              vertical: 12.0,
            ),
            child: isAssigned
                ? _buildAcceptAssignmentButton()
                : _buildLiveDispatchButton(),
          ),
        ),
      );
    }
    return null;
  }

  Widget _buildAcceptAssignmentButton() {
    return ElevatedButton.icon(
      onPressed: _isLoading ? null : _acceptAssignment,
      icon: _isLoading
          ? const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
              ),
            )
          : const Icon(Icons.check_circle, color: Colors.white, size: 22),
      label: Text(
        _isLoading ? 'Accepting...' : 'Accept Assignment',
        style: const TextStyle(
          fontSize: 16,
          color: Colors.white,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.3,
        ),
      ),
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.green,
        padding: const EdgeInsets.symmetric(vertical: 16),
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  Widget _buildLiveDispatchButton() {
    return ElevatedButton.icon(
      onPressed: _isLoading ? null : _handleLocationView,
      icon: _isLoading
          ? const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
              ),
            )
          : Icon(
              _isRescuer ? Icons.location_on : Icons.navigation,
              color: Colors.white,
              size: 22,
            ),
      label: Text(
        _isLoading
            ? 'Loading...'
            : _isRescuer
            ? 'View Report Location'
            : 'View Live Dispatch',
        style: const TextStyle(
          fontSize: 16,
          color: Colors.white,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.3,
        ),
      ),
      style: ElevatedButton.styleFrom(
        backgroundColor: _isLoading
            ? Colors.grey
            : Theme.of(context).primaryColor,
        padding: const EdgeInsets.symmetric(vertical: 16),
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  Future<void> _handleLocationView() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final location = await _getReportLocation();

      if (location != null) {
        _navigateToMapViewer(location);
      } else {
        _showLocationError('No location information available');
      }
    } catch (e) {
      debugPrint('Error handling location view: $e');
      _showLocationError('Failed to fetch location data: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _navigateToMapViewer(LatLng location) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => RealTimeMapViewer(
          initialLocation: location,
          reportId: widget.report.reportId?.toString(),
          rescuerId: _currentUserId?.toString(),
        ),
      ),
    );
  }

  void _showLocationError(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          behavior: SnackBarBehavior.floating,
          backgroundColor: Colors.red,
        ),
      );
    }
  }
}

class ReportDetailPageContent extends StatelessWidget {
  final ReportData report;
  final Color severityColor;
  final String statusDisplay;
  final ReportStatus? parsedStatus;
  final LatLng? reportLocation;
  final VoidCallback? onCompleteAssignment;
  final bool isLoading;

  const ReportDetailPageContent({
    super.key,
    required this.report,
    required this.severityColor,
    required this.statusDisplay,
    required this.parsedStatus,
    required this.reportLocation,
    this.onCompleteAssignment,
    this.isLoading = false,
  });

  String _getFormattedTime() {
    final DateTime? timestamp = report.timestamp ?? report.createdAt;
    if (timestamp == null) return 'N/A';

    final hour = timestamp.hour > 12 ? timestamp.hour - 12 : timestamp.hour;
    final period = timestamp.hour >= 12 ? 'PM' : 'AM';
    return '${hour == 0 ? 12 : hour}:${timestamp.minute.toString().padLeft(2, '0')} $period';
  }

  String _getFormattedDate() {
    final DateTime? timestamp = report.timestamp ?? report.createdAt;
    if (timestamp == null) return 'N/A';

    final months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    final month = months[timestamp.month - 1];
    return '$month ${timestamp.day}, ${timestamp.year}';
  }

  Color _getSeverityColor(FloodSeverity? severity) {
    if (severity == null) return Colors.grey;

    switch (severity) {
      case FloodSeverity.low:
        return Colors.green;
      case FloodSeverity.moderate:
        return Colors.orange;
      case FloodSeverity.high:
        return Colors.red;
    }
  }

  Color _getStatusColor(ReportStatus? status) {
    if (status == null) return Colors.grey;

    switch (status) {
      case ReportStatus.pending:
        return Colors.orange;
      case ReportStatus.newReport:
        return Colors.blue;
      case ReportStatus.assigned:
        return Colors.purple;
      case ReportStatus.confirmed:
        return Colors.blueAccent;
      case ReportStatus.inProgress:
        return Colors.deepOrange;
      case ReportStatus.ongoing:
        return Colors.deepOrange;
      case ReportStatus.resolved:
        return Colors.green;
      default:
        return Colors.grey;
    }
  }

  Widget _buildInfoCard(
    String label,
    String value,
    IconData icon, {
    Color? accentColor,
    Color? textColor,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: (accentColor ?? severityColor).withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 24, color: accentColor ?? severityColor),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: Colors.grey[600],
                    letterSpacing: 0.3,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: textColor ?? Colors.black87,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final timeString = _getFormattedTime();
    final dateString = _getFormattedDate();
    final statusColor = _getStatusColor(parsedStatus);

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. MAP VIEWER
          if (reportLocation != null) ...[
            Container(
              height: 280,
              decoration: BoxDecoration(
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: MapViewer(
                initialLocation: reportLocation!,
                disableSearch: true,
                disableLocationSelection: true,
                disableTapToPlace: true,
                mapScrollable: true,
                preventInteraction: false,
                reportMarkers: {
                  Marker(
                    markerId: MarkerId(report.reportId?.toString() ?? 'report'),
                    position: reportLocation!,
                    infoWindow: InfoWindow(
                      title: report.title ?? 'Report Location',
                      snippet: report.address ?? 'Flood Report',
                    ),
                    icon: BitmapDescriptor.defaultMarkerWithHue(
                      BitmapDescriptor.hueRed,
                    ),
                  ),
                },
                onLocationSelected: (LatLng loc, String? name) {},
                onMapCreated: (GoogleMapController controller) {
                  controller.animateCamera(
                    CameraUpdate.newLatLngZoom(reportLocation!, 15),
                  );
                },
                enableZoom: true,
                enablePan: true,
                enableRotation: false,
                enableTilt: true,
              ),
            ),
          ],

          // 2. CONTENT SECTION
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Status Badge
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: statusColor.withOpacity(0.3),
                      width: 1,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: statusColor,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        statusDisplay.toUpperCase(),
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: statusColor,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 20),

                // Report Title
                if (report.title != null) ...[
                  Text(
                    'Report Title',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: Colors.grey[800],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey[200]!),
                    ),
                    child: Text(
                      report.title!,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.black87,
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                ],

                // Time & Date Cards
                Row(
                  children: [
                    Expanded(
                      child: _buildInfoCard(
                        'Time',
                        timeString,
                        Icons.access_time_rounded,
                        accentColor: Colors.blue[700],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildInfoCard(
                        'Date',
                        dateString,
                        Icons.calendar_today_rounded,
                        accentColor: Colors.purple[700],
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 16),

                // Location Information
                if (report.address != null)
                  _buildInfoCard(
                    'Location',
                    report.address!,
                    Icons.place_rounded,
                    accentColor: Colors.green[700],
                  ),

                const SizedBox(height: 16),

                // Severity Card
                _buildInfoCard(
                  'Severity',
                  report.severity?.toString().split('.').last.toUpperCase() ??
                      'Low',
                  Icons.water_damage_rounded,
                  accentColor: _getSeverityColor(report.severity),
                  textColor: _getSeverityColor(report.severity),
                ),
                const SizedBox(height: 16),
                // Coordinates Card
                _buildInfoCard(
                  'Coordinates',
                  reportLocation != null
                      ? '${reportLocation!.latitude.toStringAsFixed(6)}, ${reportLocation!.longitude.toStringAsFixed(6)}'
                      : 'Location data unavailable',
                  Icons.location_on_rounded,
                  accentColor: Colors.red[700],
                ),

                // Flood Height
                if (report.floodHeight != null && report.floodHeight! > 0) ...[
                  const SizedBox(height: 16),
                  _buildInfoCard(
                    'Flood Height',
                    '${report.floodHeight} m',
                    Icons.water_damage_rounded,
                    accentColor: Colors.blue[600],
                  ),
                ],

                // Reporter Information
                if (report.reportedBy != null || report.createdBy != null) ...[
                  const SizedBox(height: 16),
                  _buildInfoCard(
                    'Reported By',
                    'You',
                    Icons.person_rounded,
                    accentColor: Colors.orange[700],
                  ),
                ],

                const SizedBox(height: 20),

                // Description Section
                if (report.description != null ||
                    report.explanation != null) ...[
                  Text(
                    'Description',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: Colors.grey[800],
                      letterSpacing: 0.2,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey[200]!),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.04),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Text(
                      report.description ??
                          report.explanation ??
                          'No detailed description provided.',
                      style: TextStyle(
                        fontSize: 15,
                        height: 1.6,
                        color: Colors.grey[800],
                        letterSpacing: 0.1,
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                ],

                if (onCompleteAssignment != null) ...[
                  Container(
                    width: double.infinity,
                    margin: const EdgeInsets.only(bottom: 20, top: 20),
                    child: ElevatedButton.icon(
                      onPressed: isLoading ? null : onCompleteAssignment,
                      icon: isLoading
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                              ),
                            )
                          : const Icon(Icons.task_alt, color: Colors.white, size: 22),
                      label: Text(
                        isLoading ? 'Completing...' : 'Complete Assignment',
                        style: const TextStyle(
                          fontSize: 16,
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.3,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green[700],
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        elevation: 2,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
                ],

                const SizedBox(height: 100),
              ],
            ),
          ),
        ],
      ),
    );
  }
}