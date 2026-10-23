import 'dart:math' as math;
import 'package:fdr/app_routes.dart';
import 'package:fdr/features/widgets/assigned_report_item.dart';
import 'package:fdr/features/widgets/map_viewer.dart';
import 'package:fdr/features/widgets/resolved_report_item.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:fdr/services/api_service.dart';
import 'package:fdr/features/auth/data/models/report/report_data.dart';
import 'package:shared_preferences/shared_preferences.dart';

class DispatcherDashboard extends StatefulWidget {
  const DispatcherDashboard({super.key});
  static const routeName = '/dispatcher_dashboard';

  @override
  State<DispatcherDashboard> createState() => _DispatcherDashboardState();
}

class _DispatcherDashboardState extends State<DispatcherDashboard> {
  final GlobalKey<ScaffoldMessengerState> _scaffoldMessengerKey =
      GlobalKey<ScaffoldMessengerState>();
  final ApiService _apiService = ApiService();
  List<ReportData> _pendingReports = [];
  List<ReportData> _assignedReports = [];
  List<ReportData> _resolvedReports = [];
  List<Map<String, dynamic>> _availableRescuers = [];
  bool _isLoading = true;
  String? _error;
  bool _usingMockData = false;
  String _userName = '';

  // Map state
  GoogleMapController? _mapController;
  Set<Marker> _reportMarkers = {};
  List<LatLng> _validMarkerLocations = [];
  Map<String, LatLng> _locationCache = {};

  List<int> _getAvailableRescuerIds() {
    try {
      debugPrint('[DEBUG] Available rescuers raw data: ${_availableRescuers}');

      final ids = <int>{}
          .toList();

      for (final rescuer in _availableRescuers) {
        debugPrint('[DEBUG] Processing rescuer: $rescuer');

        dynamic id;
        final possibleIdFields = ['user_id', 'id', 'rescuer_id', 'userId'];

        for (final field in possibleIdFields) {
          if (rescuer.containsKey(field)) {
            id = rescuer[field];
            debugPrint('[DEBUG] Found ID in field "$field": $id');
            break;
          }
        }

        if (id != null) {
          int? finalId;

          if (id is int) {
            finalId = id;
          } else if (id is String) {
            finalId = int.tryParse(id);
          } else {
            try {
              finalId = int.parse(id.toString());
            } catch (e) {
              debugPrint('[DEBUG] Could not convert ID: $e');
            }
          }

          if (finalId != null && !ids.contains(finalId)) {
            ids.add(finalId);
            debugPrint('[DEBUG] Added unique rescuer ID: $finalId');
          } else if (finalId != null) {
            debugPrint('[DEBUG] Skipped duplicate rescuer ID: $finalId');
          }
        } else {
          debugPrint('[DEBUG] No ID field found in rescuer');
        }
      }

      debugPrint('[DEBUG] Final unique rescuer IDs: $ids');

      if (ids.isEmpty) {
        debugPrint(
          '[DEBUG] No valid IDs extracted, using rescuer data directly',
        );
        for (int i = 0; i < _availableRescuers.length; i++) {
          final rescuer = _availableRescuers[i];
          final actualId = rescuer['id'] ?? rescuer['user_id'];
          if (actualId != null && actualId is int) {
            ids.add(actualId);
          }
        }
      }

      final uniqueIds = ids.toSet().toList();
      debugPrint('[DEBUG] Final deduplicated rescuer IDs: $uniqueIds');

      return uniqueIds;
    } catch (e) {
      debugPrint('[DEBUG] Error extracting rescuer IDs: $e');
      return [];
    }
  }


  @override
  void initState() {
    super.initState();
    _loadUserData();
    _loadReports();
  }

  Future<void> _loadUserData() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _userName = prefs.getString('user_name') ?? 'Dispatcher';
    });
  }

  Future<void> _loadReports() async {
    try {
      setState(() {
        _isLoading = true;
        _error = null;
        _usingMockData = false;
      });

      debugPrint('[DEBUG] Fetching reports from API...');
      final response = await _apiService.getAllReports(offset: 0, limit: 100);
      debugPrint('[DEBUG] Reports API response: $response');

      List<ReportData> allReports = [];

      if (response is Map && response['data'] is List) {
        final dataList = response['data'] as List;
        debugPrint('[DEBUG] Found ${dataList.length} reports in response');
        for (var item in dataList) {
          try {
            final report = ReportData.fromJson(item as Map<String, dynamic>);
            allReports.add(report);
            debugPrint(
              '[DEBUG] Parsed report: ${report.reportId} - ${report.title}',
            );
          } catch (e) {
            debugPrint('[DEBUG] Error parsing report: $e');
          }
        }
      } else if (response is Map && response['detail'] != null) {
        final detail = response['detail'].toString();
        debugPrint('[DEBUG] API returned detail: $detail');
        if (detail.contains('No Report Has Been Added')) {
          _useMockData('No reports available from server. Using demo data.');
          return;
        }
      }

      if (allReports.isEmpty) {
        debugPrint('[DEBUG] No valid reports found, using mock data');
        _useMockData('No valid reports found. Using demo data.');
        return;
      }

      debugPrint('[DEBUG] Successfully loaded ${allReports.length} reports');

      debugPrint('[DEBUG] Fetching rescue personnel from API...');
      final rescuersResponse = await _apiService.getAllRescuePersonnel(
        offset: 0,
        limit: 100,
      );
      debugPrint('[DEBUG] Rescue personnel API response: $rescuersResponse');

      _availableRescuers = _parseRescuePersonnel(rescuersResponse);
      debugPrint(
        '[DEBUG] Loaded ${_availableRescuers.length} rescue personnel entries',
      );

      _pendingReports = allReports
          .where(
            (report) =>
                report.status == ReportStatus.pending ||
                report.status == ReportStatus.newReport ||
                report.responseStatus?.toLowerCase() == 'pending' ||
                report.reportStatus?.toLowerCase() == 'pending',
          )
          .toList();

      _assignedReports = allReports
          .where(
            (report) =>
                report.status == ReportStatus.inProgress ||
                (report.responseStatus?.toLowerCase() == 'assigned') ||
                (report.responseStatus?.toLowerCase() ==
                    'confirmed') ||
                (report.reportStatus?.toLowerCase() == 'assigned') ||
                (report.reportStatus?.toLowerCase() ==
                    'confirmed') ||
                report.assignedTo != null,
          )
          .toList();

      _resolvedReports = allReports
          .where(
            (report) =>
                report.status == ReportStatus.completed ||
                report.status == ReportStatus.resolved ||
                report.responseStatus?.toLowerCase() == 'completed' ||
                report.responseStatus?.toLowerCase() == 'resolved' ||
                report.reportStatus?.toLowerCase() == 'completed' ||
                report.reportStatus?.toLowerCase() == 'resolved',
          )
          .toList();

      debugPrint('[DEBUG] Categorized reports:');
      debugPrint('[DEBUG] - Pending: ${_pendingReports.length}');
      debugPrint('[DEBUG] - Assigned: ${_assignedReports.length}');
      debugPrint('[DEBUG] - Completed: ${_resolvedReports.length}');

      await _generateReportMarkers(allReports);

      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('[DEBUG] Error loading reports: $e');
      _useMockData('Failed to load reports: ${e.toString()}. Using demo data.');
    }
  }

  List<Map<String, dynamic>> _parseRescuePersonnel(dynamic response) {
    try {
      List<Map<String, dynamic>> rescuers = [];
      List<dynamic> dataList = [];

      debugPrint('[DEBUG] Starting rescue personnel parsing...');

      if (response is List) {
        dataList = response;
        debugPrint(
          '[DEBUG] Parsing from direct list: ${dataList.length} items',
        );
      } else if (response is Map && response.containsKey('data')) {
        dataList = response['data'] as List;
        debugPrint('[DEBUG] Parsing from data key: ${dataList.length} items');
      } else if (response is Map && response.containsKey('rescue_personnel')) {
        dataList = response['rescue_personnel'] as List;
        debugPrint(
          '[DEBUG] Parsing from rescue_personnel key: ${dataList.length} items',
        );
      }

      for (var item in dataList) {
        try {
          if (item is Map<String, dynamic>) {
            final role =
                item['role']?.toString().toLowerCase() ??
                item['user_type']?.toString().toLowerCase() ??
                item['type']?.toString().toLowerCase();

            final name =
                item['name'] ??
                item['full_name'] ??
                item['username'] ??
                'Unknown Rescuer';

            final id = item['id'] ?? item['user_id'] ?? item['rescuer_id'];

            if (id != null &&
                (role == 'rescuer' ||
                    role == 'rescue' ||
                    role == 'responder')) {
              final rescuer = {
                'id': id is String ? int.tryParse(id) ?? 0 : (id as int? ?? 0),
                'name': name,
                'email': item['email'] ?? 'No email',
                'phone':
                    item['phone'] ??
                    item['mobile_number'] ??
                    item['contact_number'] ??
                    'No phone',
                'role': role,
              };

              if (rescuer['id'] as int > 0) {
                rescuers.add(rescuer);
                debugPrint(
                  '[DEBUG] Added rescuer: ${rescuer['name']} (ID: ${rescuer['id']})',
                );
              }
            }
          }
        } catch (e) {
          debugPrint('[DEBUG] Error parsing rescue personnel item: $e');
        }
      }

      if (rescuers.isEmpty) {
        debugPrint(
          '[DEBUG] No rescuers found with standard parsing, trying alternative...',
        );
        _tryAlternativeRescuerParsing(response, rescuers);
      }

      debugPrint('[DEBUG] Final rescuer list: ${rescuers.length} rescuers');
      return rescuers;
    } catch (e) {
      debugPrint('[DEBUG] Error parsing rescue personnel: $e');
      return [];
    }
  }

  void _tryAlternativeRescuerParsing(
    dynamic response,
    List<Map<String, dynamic>> rescuers,
  ) {
    try {
      if (response is Map) {
        response.forEach((key, value) {
          if (value is List) {
            for (var item in value) {
              if (item is Map<String, dynamic>) {
                final id = item['id'] ?? item['user_id'];
                final name = item['name'] ?? item['username'];
                if (id != null && name != null) {
                  rescuers.add({
                    'id': id is String
                        ? int.tryParse(id) ??
                              DateTime.now().millisecondsSinceEpoch
                        : id,
                    'name': name,
                    'email': item['email'] ?? 'No email',
                    'phone':
                        item['phone'] ?? item['mobile_number'] ?? 'No phone',
                    'role': item['role'] ?? 'rescuer',
                  });
                }
              }
            }
          }
        });
      }
    } catch (e) {
      debugPrint('[DEBUG] Alternative parsing also failed: $e');
    }
  }

  Future<LatLng?> _fetchLocationForReport(ReportData report) async {
    try {
      debugPrint('[DEBUG] Fetching location for report ${report.reportId}');
      debugPrint(
        '[DEBUG] Report latitude: ${report.latitude}, longitude: ${report.longitude}',
      );
      debugPrint('[DEBUG] Report locationId: ${report.locationId}');
      if (report.latitude != null && report.longitude != null) {
        final location = LatLng(report.latitude!, report.longitude!);
        debugPrint(
          '[DEBUG] Using direct coordinates for report ${report.reportId}: $location',
        );
        return location;
      }

      if (report.location != null && report.location is Map) {
        final locationData = report.location as Map;
        final lat = _parseCoordinate(locationData['latitude']);
        final lng = _parseCoordinate(locationData['longitude']);
        if (lat != null && lng != null) {
          return LatLng(lat, lng);
        }
      }

      if (report.locationId != null) {
        final locationId = report.locationId!.toString();

        if (_locationCache.containsKey(locationId)) {
          debugPrint('[DEBUG] Using cached location for ID: $locationId');
          return _locationCache[locationId];
        }

        debugPrint('[DEBUG] Fetching location data for ID: $locationId');
        try {
          final locationData = await _apiService.getLocationById(
            int.parse(locationId),
          );

          debugPrint('[DEBUG] Location API response: $locationData');

          if (locationData != null) {
            double? lat;
            double? lng;

            if (locationData is Map<String, dynamic>) {
              if (locationData.containsKey('latitude') &&
                  locationData.containsKey('longitude')) {
                lat = _parseCoordinate(locationData['latitude']);
                lng = _parseCoordinate(locationData['longitude']);
              } else if (locationData.containsKey('data') &&
                  locationData['data'] is Map) {
                final data = locationData['data'] as Map;
                lat = _parseCoordinate(data['latitude']);
                lng = _parseCoordinate(data['longitude']);
              } else if (locationData.containsKey('location')) {
                final loc = locationData['location'] as Map;
                lat = _parseCoordinate(loc['latitude']);
                lng = _parseCoordinate(loc['longitude']);
              }
            }

            if (lat != null && lng != null) {
              final location = LatLng(lat, lng);
              _locationCache[locationId] = location;
              debugPrint(
                '[DEBUG] Found location for report ${report.reportId}: $location',
              );
              return location;
            }
          }
        } catch (e) {
          debugPrint('[DEBUG] Error fetching location ID $locationId: $e');
        }
      }

      debugPrint(
        '[DEBUG] No location data available for report ${report.reportId}, using fallback',
      );
      return _getFallbackLocation(report.reportId);
    } catch (e) {
      debugPrint(
        '[DEBUG] Error fetching location for report ${report.reportId}: $e',
      );
      return _getFallbackLocation(report.reportId);
    }
  }

  LatLng _getFallbackLocation(String reportId) {
    final hash = reportId.hashCode;
    final lat = 14.5995 + (hash % 1000 - 500) * 0.001;
    final lng = 120.9842 + (hash % 1000 - 500) * 0.001;
    return LatLng(lat, lng);
  }

  double? _parseCoordinate(dynamic coord) {
    if (coord == null) return null;

    if (coord is double) return coord;
    if (coord is int) return coord.toDouble();
    if (coord is String) {
      return double.tryParse(coord);
    }

    return null;
  }

  Future<void> _generateReportMarkers(List<ReportData> reports) async {
    _reportMarkers.clear();
    _validMarkerLocations.clear();

    debugPrint('[DEBUG] Generating markers for ${reports.length} reports');

    for (final report in reports) {
      final location = await _fetchLocationForReport(report);

      if (location != null) {
        _validMarkerLocations.add(location);
        _reportMarkers.add(
          Marker(
            markerId: MarkerId('report_${report.reportId}'),
            position: location,
            icon: _getMarkerIconForReport(report),
            infoWindow: InfoWindow(
              title: report.title ?? 'Flood Report',
              snippet: 'Status: ${_getStatusText(report.status)}',
            ),
          ),
        );
        debugPrint(
          '[DEBUG] Created marker for report ${report.reportId} at $location',
        );
      } else {
        debugPrint('[DEBUG] No location data for report ${report.reportId}');
      }
    }

    debugPrint(
      '[DEBUG] Generated ${_reportMarkers.length} markers from ${reports.length} reports',
    );

    if (_reportMarkers.isEmpty) {
      debugPrint(
        '[DEBUG] No markers were generated - creating fallback markers',
      );
      _createFallbackMarkers();
    }
  }

  void _createFallbackMarkers() {
    final fallbackLocation = const LatLng(14.5995, 120.9842); // Manila area
    _reportMarkers.add(
      Marker(
        markerId: const MarkerId('fallback_marker'),
        position: fallbackLocation,
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
        infoWindow: const InfoWindow(
          title: 'Fallback Location',
          snippet: 'No report locations available',
        ),
      ),
    );
    _validMarkerLocations.add(fallbackLocation);
  }

  BitmapDescriptor _getMarkerIconForReport(ReportData report) {
    final responseStatus = report.responseStatus?.toLowerCase();
    final reportStatus = report.reportStatus?.toLowerCase();
    final hasAssignedTo = report.assignedTo != null;

    if (responseStatus == 'assigned' ||
        reportStatus == 'assigned' ||
        hasAssignedTo ||
        report.status == ReportStatus.inProgress) {
      return BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueOrange);
    }

    if (responseStatus == 'completed' ||
        responseStatus == 'resolved' ||
        reportStatus == 'completed' ||
        reportStatus == 'resolved' ||
        report.status == ReportStatus.completed ||
        report.status == ReportStatus.resolved) {
      return BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen);
    }

    return BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed);
  }

  String _getStatusText(ReportStatus? status) {
    return status?.toString().split('.').last ?? 'Unknown';
  }


  void _centerMapOnReport(ReportData report) async {
    final location = await _fetchLocationForReport(report);
    if (location != null && _mapController != null) {
      _mapController!.animateCamera(
        CameraUpdate.newCameraPosition(
          CameraPosition(target: location, zoom: 15.0),
        ),
      );
    }
  }

  Map<String, dynamic> _getRescuerDetails(int rescuerId) {
    try {
      debugPrint('[DEBUG] Looking up details for rescuer ID: $rescuerId');

      for (final rescuer in _availableRescuers) {
        final possibleIdFields = ['user_id', 'id', 'rescuer_id', 'userId'];

        for (final field in possibleIdFields) {
          if (rescuer.containsKey(field)) {
            final idValue = rescuer[field];
            int? idInt;

            if (idValue is int) {
              idInt = idValue;
            } else if (idValue is String) {
              idInt = int.tryParse(idValue);
            }

            if (idInt == rescuerId) {
              debugPrint(
                '[DEBUG] Found exact match for rescuer ID $rescuerId: ${rescuer['name']}',
              );
              return {
                'name': rescuer['name'] ?? 'Rescue Team $rescuerId',
                'phone':
                    rescuer['mobile_number'] ?? rescuer['phone'] ?? 'Unknown',
                'email': rescuer['email'] ?? 'No email available',
                'actual_id': idInt,
              };
            }
          }
        }
      }

      debugPrint(
        '[DEBUG] No exact match found for ID $rescuerId, using fallback',
      );

      return {
        'name': 'Rescue Team $rescuerId',
        'phone': 'Unknown',
        'email': 'No email available',
      };
    } catch (e) {
      debugPrint('[DEBUG] Error getting rescuer details for ID $rescuerId: $e');
      return {
        'name': 'Rescue Team $rescuerId',
        'phone': 'Unknown',
        'email': 'No email available',
      };
    }
  }

  void _useMockData(String message) {
    debugPrint('[MOCK] $message');

    final mockReports = _generateMockReports();

    _pendingReports = mockReports
        .where(
          (report) =>
              report.status == ReportStatus.pending ||
              report.status == ReportStatus.newReport,
        )
        .toList();

    _assignedReports = mockReports
        .where((report) => report.status == ReportStatus.inProgress)
        .toList();

    _resolvedReports = mockReports
        .where(
          (report) =>
              report.status == ReportStatus.completed ||
              report.status == ReportStatus.resolved,
        )
        .toList();

    _availableRescuers = [
      {
        'id': 1,
        'name': 'Rescue Team Alpha',
        'phone': '+1234567890',
        'email': 'alpha@rescue.com',
      },
      {
        'id': 2,
        'name': 'Rescue Team Bravo',
        'phone': '+1234567891',
        'email': 'bravo@rescue.com',
      },
      {
        'id': 3,
        'name': 'Rescue Team Charlie',
        'phone': '+1234567892',
        'email': 'charlie@rescue.com',
      },
    ];

    _generateReportMarkers(mockReports);

    if (mounted) {
      setState(() {
        _isLoading = false;
        _usingMockData = true;
      });

      _scaffoldMessengerKey.currentState?.showSnackBar(
        SnackBar(
          content: Text(message),
          duration: const Duration(seconds: 4),
          backgroundColor: Colors.orange.shade600,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      );
    }
  }

  List<ReportData> _generateMockReports() {
    final now = DateTime.now();
    final List<Map<String, dynamic>> mockLocations = [
      {'lat': 14.5995, 'lng': 120.9842, 'address': 'Intramuros, Manila'},
      {'lat': 14.6091, 'lng': 120.9920, 'address': 'Ermita, Manila'},
      {'lat': 14.5890, 'lng': 120.9760, 'address': 'Malate, Manila'},
    ];

    return [
      ReportData(
        reportId: 'mock_1',
        title: 'Severe Flooding in Intramuros',
        floodHeight: 0.8,
        explanation: 'Heavy rainfall caused flooding in the historic district.',
        responseStatus: 'pending',
        createdBy: 'Demo User 1',
        createdAt: now.subtract(const Duration(hours: 2)),
        description: 'Major flooding reported in Intramuros area.',
        address: mockLocations[0]['address'].toString(),
        latitude: mockLocations[0]['lat'] as double?,
        longitude: mockLocations[0]['lng'] as double?,
        severity: FloodSeverity.high,
        status: ReportStatus.pending,
        timestamp: now.subtract(const Duration(hours: 2)),
        reporterId: 'demo_user_1',
        reportedBy: 'User1',
        phoneNumber: '092783726832',
      ),
      ReportData(
        reportId: 'mock_2',
        title: 'Moderate Flooding in Ermita',
        floodHeight: 0.4,
        explanation: 'Moderate flooding affecting main roads.',
        responseStatus: 'pending',
        createdBy: 'Demo User 2',
        createdAt: now.subtract(const Duration(hours: 1)),
        description: 'Flooding reported along major thoroughfares in Ermita.',
        address: mockLocations[1]['address'].toString(),
        latitude: mockLocations[1]['lat'] as double?,
        longitude: mockLocations[1]['lng'] as double?,
        severity: FloodSeverity.moderate,
        status: ReportStatus.pending,
        timestamp: now.subtract(const Duration(hours: 1)),
        reporterId: 'demo_user_2',
        reportedBy: 'User2',
        phoneNumber: '092783726833',
      ),
    ];
  }

  Future<void> _refreshData() async {
    await _loadReports();
  }

  void _showProfileMenu(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final double maxWidth = screenWidth > 600 ? 400 : screenWidth * 0.9;
    final double avatarRadius = screenWidth > 600 ? 40 : 32;
    final double titleFontSize = screenWidth > 600 ? 20 : 18;
    final double subtitleFontSize = screenWidth > 600 ? 14 : 12;
    final double menuItemFontSize = screenWidth > 600 ? 16 : 14;
    final double iconSize = screenWidth > 600 ? 22 : 20;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        minChildSize: 0.4,
        maxChildSize: 0.85,
        builder: (context, scrollController) => Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(20),
              topRight: Radius.circular(20),
            ),
          ),
          child: Column(
            children: [
              // Drag handle
              Container(
                margin: EdgeInsets.only(top: 12),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),

              // Draggable Scroll Sheet
              Expanded(
                child: SingleChildScrollView(
                  controller: scrollController,
                  child: Container(
                    width: maxWidth,
                    padding: EdgeInsets.symmetric(
                      horizontal: screenWidth > 600 ? 24 : 20,
                      vertical: 20,
                    ),
                    child: Column(
                      children: [
                        CircleAvatar(
                          radius: avatarRadius,
                          backgroundColor: Colors.blue.shade100,
                          child: Icon(
                            Icons.person,
                            size: avatarRadius,
                            color: Colors.blue.shade700,
                          ),
                        ),
                        SizedBox(height: screenWidth > 600 ? 16 : 12),
                        Text(
                          'Dispatcher',
                          style: TextStyle(
                            fontSize: titleFontSize,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF1D1D1F),
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          'dispatcher@fdr.com',
                          style: TextStyle(
                            fontSize: subtitleFontSize,
                            color: Color(0xFF6E6E73),
                          ),
                        ),
                        SizedBox(height: screenWidth > 600 ? 24 : 20),
                        _buildProfileMenuItem(
                          icon: Icons.person_outline,
                          title: 'Profile Settings',
                          iconSize: iconSize,
                          fontSize: menuItemFontSize,
                          onTap: () {
                            Navigator.pop(context);
                          },
                        ),
                        _buildProfileMenuItem(
                          icon: Icons.notifications_outlined,
                          title: 'Notifications',
                          iconSize: iconSize,
                          fontSize: menuItemFontSize,
                          onTap: () {
                            Navigator.pop(context);
                          },
                        ),
                        _buildProfileMenuItem(
                          icon: Icons.help_outline,
                          title: 'Help & Support',
                          iconSize: iconSize,
                          fontSize: menuItemFontSize,
                          onTap: () {
                            Navigator.pop(context);
                          },
                        ),
                        Divider(height: 32),
                        _buildProfileMenuItem(
                          icon: Icons.logout,
                          title: 'Logout',
                          iconSize: iconSize,
                          fontSize: menuItemFontSize,
                          color: Colors.red.shade600,
                          onTap: () {
                            Navigator.pop(context);
                            _showLogoutDialog(context);
                          },
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProfileMenuItem({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
    required double iconSize,
    required double fontSize,
    Color? color,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Icon(icon, size: iconSize, color: color ?? Color(0xFF1D1D1F)),
            SizedBox(width: 16),
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  fontSize: fontSize,
                  fontWeight: FontWeight.w500,
                  color: color ?? Color(0xFF1D1D1F),
                ),
              ),
            ),
            Icon(
              Icons.chevron_right,
              size: iconSize - 2,
              color: Color(0xFF6E6E73),
            ),
          ],
        ),
      ),
    );
  }

  void _showLogoutDialog(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final dialogWidth = screenWidth > 600 ? 400.0 : screenWidth * 0.85;
    final double titleFontSize = screenWidth > 600 ? 20 : 18;
    final contentFontSize = screenWidth > 600 ? 16.0 : 14.0;
    final buttonFontSize = screenWidth > 600 ? 16.0 : 14.0;

    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Container(
          width: dialogWidth,
          padding: EdgeInsets.all(screenWidth > 600 ? 24 : 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Logout',
                style: TextStyle(
                  fontSize: titleFontSize,
                  fontWeight: FontWeight.w600,
                ),
              ),
              SizedBox(height: 16),
              Text(
                'Are you sure you want to logout?',
                style: TextStyle(
                  fontSize: contentFontSize,
                  color: Color(0xFF6E6E73),
                ),
              ),
              SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    style: TextButton.styleFrom(
                      foregroundColor: Color(0xFF6E6E73),
                      padding: EdgeInsets.symmetric(
                        horizontal: screenWidth > 600 ? 20 : 16,
                        vertical: screenWidth > 600 ? 12 : 10,
                      ),
                    ),
                    child: Text(
                      'Cancel',
                      style: TextStyle(
                        fontSize: buttonFontSize,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  SizedBox(width: 12),
                  ElevatedButton(
                    onPressed: () {
                      Navigator.pop(context);
                      Navigator.pushReplacementNamed(context, AppRoutes.login);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red.shade600,
                      foregroundColor: Colors.white,
                      padding: EdgeInsets.symmetric(
                        horizontal: screenWidth > 600 ? 24 : 20,
                        vertical: screenWidth > 600 ? 12 : 10,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      elevation: 0,
                    ),
                    child: Text(
                      'Logout',
                      style: TextStyle(
                        fontSize: buttonFontSize,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }


  void _fitMapToMarkers() {
    if (_validMarkerLocations.isEmpty || _mapController == null) return;

    final bounds = _calculateBounds(_validMarkerLocations);
    _mapController!.animateCamera(CameraUpdate.newLatLngBounds(bounds, 50.0));
  }

  LatLngBounds _calculateBounds(List<LatLng> locations) {
    double? minLat, maxLat, minLng, maxLng;

    for (final location in locations) {
      minLat = minLat == null
          ? location.latitude
          : math.min(minLat, location.latitude);
      maxLat = maxLat == null
          ? location.latitude
          : math.max(maxLat, location.latitude);
      minLng = minLng == null
          ? location.longitude
          : math.min(minLng, location.longitude);
      maxLng = maxLng == null
          ? location.longitude
          : math.max(maxLng, location.longitude);
    }

    return LatLngBounds(
      southwest: LatLng(minLat ?? 0, minLng ?? 0),
      northeast: LatLng(maxLat ?? 0, maxLng ?? 0),
    );
  }

  Future<void> _showReportDetailsModal(ReportData report) async {
    final location = await _fetchLocationForReport(report);
    debugPrint(
      '[DEBUG] Main - Fetched location for report ${report.reportId}: $location',
    );

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => ReportDetailsModal(
        report: report,
        availableRescuers: _availableRescuers,
        onAssigned: _refreshData,
        apiService: _apiService,
        userName: _userName,
        reportLocation: location,
        getRescuerDetails: _getRescuerDetails,
        onMapCreated: (controller) {
          _centerMapOnReport(report);
        },
      ),
    );
  }

  void _viewResponseProgress(ReportData report) {
    debugPrint('View response progress for report: ${report.reportId}');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F7),
      appBar: AppBar(
        automaticallyImplyLeading: false,
        backgroundColor: Colors.white,
        elevation: 0,
        toolbarHeight: 70,
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.blue.shade600, Colors.blue.shade700],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(10),
                boxShadow: [
                  BoxShadow(
                    color: Colors.blue.withOpacity(0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: const Icon(
                Icons.water_drop,
                color: Colors.white,
                size: 20,
              ),
            ),
            const SizedBox(width: 16),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Flood Detection & Rescue',
                  style: TextStyle(
                    fontSize: 18,
                    color: Color(0xFF1D1D1F),
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 2),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    'Dispatcher Dashboard',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.blue.shade700,
                      fontWeight: FontWeight.w600,
                      letterSpacing: -0.2,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
        actions: [
          Row(
            children: [
              GestureDetector(
                onTap: () {
                  Navigator.pop(context);
                  Navigator.of(
                    context,
                  ).pushNamed(AppRoutes.dispatcherDashboard);
                },
                child: const Text(
                  "Dashboard",
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFF1D1D1F),
                  ),
                ),
              ),
              const SizedBox(width: 50),
              GestureDetector(
                onTap: () {
                  Navigator.pop(context);
                  Navigator.of(context).pushNamed(AppRoutes.operations);
                },
                child: const Text(
                  "Operations",
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFF1D1D1F),
                  ),
                ),
              ),
              const SizedBox(width: 100),
              Container(
                margin: const EdgeInsets.symmetric(vertical: 14),
                child: IconButton(
                  icon: const Icon(
                    Icons.person_outline,
                    color: Color(0xFF1D1D1F),
                    size: 24,
                  ),
                  onPressed: () => _showProfileMenu(context),
                  style: IconButton.styleFrom(
                    backgroundColor: Colors.grey.shade100,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(width: 20),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _refreshData,
        color: Colors.blue.shade600,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: 60.0,
              vertical: 16.0,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (_usingMockData)
                  Container(
                    padding: const EdgeInsets.all(10),
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: Colors.orange.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: Colors.orange.shade200,
                        width: 1,
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.info_outline,
                          color: Colors.orange.shade700,
                          size: 16,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'DEMO MODE — Showing sample data for demonstration',
                            style: TextStyle(
                              color: Colors.orange.shade800,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              letterSpacing: -0.2,
                            ),
                          ),
                        ),
                        IconButton(
                          icon: Icon(
                            Icons.close,
                            color: Colors.orange.shade700,
                            size: 14,
                          ),
                          onPressed: () =>
                              setState(() => _usingMockData = false),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                        ),
                      ],
                    ),
                  ),

                if (_isLoading)
                  const Center(
                    child: Padding(
                      padding: EdgeInsets.all(40.0),
                      child: CircularProgressIndicator(strokeWidth: 2.5),
                    ),
                  ),

                if (_error != null)
                  Container(
                    padding: const EdgeInsets.all(12),
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: Colors.red.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.red.shade200, width: 1),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.error_outline,
                          color: Colors.red.shade600,
                          size: 18,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            _error!,
                            style: TextStyle(
                              color: Colors.red.shade800,
                              fontSize: 12,
                              letterSpacing: -0.2,
                            ),
                          ),
                        ),
                        IconButton(
                          icon: Icon(
                            Icons.refresh,
                            color: Colors.red.shade600,
                            size: 18,
                          ),
                          onPressed: _refreshData,
                        ),
                      ],
                    ),
                  ),

                if (!_isLoading && _error == null) ...[
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Left Panel
                      Expanded(
                        flex: 4,
                        child: PendingRequestsPanel(
                          requests: _pendingReports,
                          onRefresh: _refreshData,
                          usingMockData: _usingMockData,
                          onOpenReport: _showReportDetailsModal,
                        ),
                      ),
                      const SizedBox(width: 16),

                      // Right Panel
                      Expanded(
                        flex: 6,
                        child: Column(
                          children: [
                            // Summary Cards Row
                            Row(
                              children: [
                                Expanded(
                                  child: SummaryCard(
                                    title: 'Pending Reports',
                                    count: _pendingReports.length,
                                    color: Colors.orange.shade600,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: SummaryCard(
                                    title: 'Assigned Rescues',
                                    count: _assignedReports.length,
                                    color: Colors.blue.shade600,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: SummaryCard(
                                    title: 'Completed',
                                    count: _resolvedReports.length,
                                    color: Colors.green.shade600,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),

                            // Operations Map
                            OperationsMapPanel(
                              pendingReports: _pendingReports,
                              assignedReports: _assignedReports,
                              resolvedReports: _resolvedReports,
                              usingMockData: _usingMockData,
                              reportMarkers: _reportMarkers,
                              onMapCreated: (controller) {
                                _mapController = controller;
                                if (_validMarkerLocations.isNotEmpty) {
                                  _fitMapToMarkers();
                                }
                              },
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Assigned Rescues
                  AssignedRescuesPanel(
                    rescues: _assignedReports,
                    onRefresh: _refreshData,
                    usingMockData: _usingMockData,
                    onViewProgress: _viewResponseProgress,
                  ),
                  const SizedBox(height: 16),
                  ResolvedReportsPanel(
                    reports: _resolvedReports,
                    onRefresh: _refreshData,
                    usingMockData: _usingMockData,
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// Report Details Modal
class ReportDetailsModal extends StatefulWidget {
  final ReportData report;
  final List<Map<String, dynamic>> availableRescuers;
  final VoidCallback onAssigned;
  final ApiService apiService;
  final String userName;
  final Map<String, dynamic> Function(int) getRescuerDetails;
  final Function(GoogleMapController)? onMapCreated;
  final LatLng? reportLocation;

  const ReportDetailsModal({
    Key? key,
    required this.report,
    required this.availableRescuers,
    required this.onAssigned,
    required this.apiService,
    required this.userName,
    required this.getRescuerDetails,
    this.reportLocation,
    this.onMapCreated,
  }) : super(key: key);

  @override
  State<ReportDetailsModal> createState() => _ReportDetailsModalState();
}

class _ReportDetailsModalState extends State<ReportDetailsModal> {
  String? _selectedSeverity;
  int? _selectedRescuerId;
  bool _isAssigning = false;
  GoogleMapController? _modalMapController;

  @override
  void initState() {
    super.initState();
    _selectedSeverity = _getCurrentSeverity(widget.report.severity);

    debugPrint('[DEBUG] Modal - Checking received data:');
    debugPrint(
      '[DEBUG] Modal - reportLocation parameter: ${widget.reportLocation}',
    );
    debugPrint(
      '[DEBUG] Modal - reportLocation type: ${widget.reportLocation?.runtimeType}',
    );
    debugPrint('[DEBUG] Modal - report ID: ${widget.report.reportId}');
    debugPrint(
      '[DEBUG] Modal - availableRescuers length: ${widget.availableRescuers.length}',
    );

    if (widget.reportLocation != null) {
      debugPrint(
        '[DEBUG] Modal - SUCCESS: Received valid location: ${widget.reportLocation!.latitude}, ${widget.reportLocation!.longitude}',
      );
    } else {
      debugPrint('[DEBUG] Modal - FAILED: reportLocation is null');
    }
  }

  List<int> _getAvailableRescuerIds() {
    try {
      final ids = <int>[];

      for (final rescuer in widget.availableRescuers) {
        final id = rescuer['id'] ?? rescuer['user_id'];
        if (id != null && id is int) {
          ids.add(id);
        }
      }

      if (ids.isEmpty) {
        for (int i = 0; i < widget.availableRescuers.length; i++) {
          ids.add(i + 1);
        }
      }

      return ids;
    } catch (e) {
      debugPrint('[DEBUG] Error getting rescuer IDs in modal: $e');
      return [];
    }
  }

  String _getCurrentSeverity(FloodSeverity? severity) {
    switch (severity) {
      case FloodSeverity.low:
        return 'low';
      case FloodSeverity.moderate:
        return 'medium';
      case FloodSeverity.high:
        return 'high';
      default:
        return 'Unappointed';
    }
  }

  Future<void> _assignRescuer() async {
    if (_selectedRescuerId == null || _selectedSeverity == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select both severity and a rescuer'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    final scaffoldMessenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);

    setState(() {
      _isAssigning = true;
    });

    try {
      final reportId = widget.report.reportId;
      final currentUserName = widget.userName;
      final dispatcherPhoneNumber = await _getDispatcherPhoneNumber();
      final now = DateTime.now().toUtc().toIso8601String();

      final prefs = await SharedPreferences.getInstance();
      final dispatcherId = prefs.getInt('user_id') ?? 1;

      final reporterUserId = _getReporterUserIdFromReport(widget.report);

      final updateData = {
        'report_id': int.tryParse(reportId) ?? 0,
        'location_id': widget.report.locationId ?? 0,
        'user_id': reporterUserId,
        'user_phone_number': widget.report.phoneNumber ?? 'Unknown',
        'dispatcher_id': dispatcherId,
        'dispatcher_phone_number': dispatcherPhoneNumber,
        'user_name': widget.report.reportedBy ?? 'Unknown User',
        'severity': _selectedSeverity,
        'rescue_personnel_id': _selectedRescuerId,
        'assigned_to': _selectedRescuerId,
        'title': widget.report.title ?? 'Flood Report',
        'flood_height': widget.report.floodHeight ?? 0.0,
        'explanation': widget.report.explanation ?? 'Assigned to rescue team',
        'response_status': 'assigned',
        'response_id': 0,
        'report_status': 'assigned',
        'created_by': widget.report.createdBy ?? 'Unknown',
        'created_at': widget.report.createdAt?.toUtc().toIso8601String() ?? now,
        'updated_by': currentUserName,
        'updated_at': now,
      };

      debugPrint('[DEBUG] Updating report $reportId for user $reporterUserId');
      debugPrint('[DEBUG] Update data: $updateData');

      await widget.apiService.updateReport(
        reportId,
        updateData,
        reporterUserId,
      );

      navigator.pop();
      scaffoldMessenger.showSnackBar(
        const SnackBar(
          content: Text('Rescuer assigned successfully!'),
          backgroundColor: Colors.green,
        ),
      );

      widget.onAssigned();
    } catch (e) {
      debugPrint('[DEBUG] Error assigning rescuer: $e');
      if (!mounted) return;

      scaffoldMessenger.showSnackBar(
        SnackBar(
          content: Text('Error assigning rescuer: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isAssigning = false;
        });
      }
    }
  }

  int _getReporterUserIdFromReport(ReportData report) {
    try {
      if (report.reporterId != null) {
        final userId = int.tryParse(report.reporterId!);
        if (userId != null) {
          debugPrint('[DEBUG] Found user_id from reporterId: $userId');
          return userId;
        }
      }

      if (report.userId != null) {
        debugPrint('[DEBUG] Found user_id from userId field: ${report.userId}');
        return report.userId!;
      }

      if (report.createdBy != null) {
        final match = RegExp(r'\((\d+)\)').firstMatch(report.createdBy!);
        if (match != null) {
          final userId = int.parse(match.group(1)!);
          debugPrint('[DEBUG] Extracted user_id from createdBy: $userId');
          return userId;
        }
      }

      debugPrint(
        '[DEBUG] Could not extract user_id from report, using fallback: 1',
      );
      return 1;
    } catch (e) {
      debugPrint('[DEBUG] Error extracting user_id from report: $e');
      return 1;
    }
  }

  Set<Marker> _createReportMarkersForModal() {
    final markers = <Marker>{};

    try {
      final report = widget.report;
      final location = widget.reportLocation;

      debugPrint('[DEBUG] Creating markers - reportLocation: $location');

      if (location != null) {
        markers.add(
          Marker(
            markerId: MarkerId('modal_report_${report.reportId}'),
            position: location,
            icon: _getMarkerIconForReport(report),
            infoWindow: InfoWindow(
              title: report.title ?? 'Flood Report',
              snippet: 'Status: ${_getStatusText(report.status)}',
            ),
          ),
        );
        debugPrint(
          '[DEBUG] Created modal marker for report ${report.reportId} at $location',
        );
      } else {
        debugPrint(
          '[DEBUG] No location available for modal report ${report.reportId}',
        );
        markers.add(
          Marker(
            markerId: const MarkerId('modal_fallback_marker'),
            position: const LatLng(14.5995, 120.9842),
            icon: BitmapDescriptor.defaultMarkerWithHue(
              BitmapDescriptor.hueRed,
            ),
            infoWindow: const InfoWindow(
              title: 'Report Location',
              snippet: 'Approximate location',
            ),
          ),
        );
      }
    } catch (e) {
      debugPrint('[DEBUG] Error creating modal markers: $e');
    }

    return markers;
  }

  BitmapDescriptor _getMarkerIconForReport(ReportData report) {
    switch (report.status) {
      case ReportStatus.newReport:
      case ReportStatus.pending:
        return BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed);
      case ReportStatus.inProgress:
      case ReportStatus.ongoing:
        return BitmapDescriptor.defaultMarkerWithHue(
          BitmapDescriptor.hueOrange,
        );
      case ReportStatus.complete:
      case ReportStatus.completed:
      case ReportStatus.resolved:
        return BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen);
      default:
        return BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue);
    }
  }

  String _getStatusText(ReportStatus? status) {
    return status?.toString().split('.').last ?? 'Unknown';
  }

  Widget _buildRescuerDropdown(List<int> availableRescuerIds) {
    final uniqueIds = availableRescuerIds.toSet().where((id) => id > 0).toList();

    if (uniqueIds.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.orange.shade50,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.orange.shade200),
        ),
        child: Row(
          children: [
            Icon(Icons.warning, color: Colors.orange.shade700, size: 16),
            const SizedBox(width: 8),
            const Expanded(
              child: Text(
                'No available rescue teams found',
                style: TextStyle(color: Colors.black87, fontSize: 14),
              ),
            ),
          ],
        ),
      );
    }

    return DropdownButtonFormField<int>(
      value: _selectedRescuerId,
      decoration: const InputDecoration(
        labelText: 'Select Rescue Team',
        border: OutlineInputBorder(),
        filled: true,
        fillColor: Colors.white,
        hintText: 'Choose a rescue team...',
      ),
      items: uniqueIds.map((rescuerId) {
        final rescuerDetails = widget.getRescuerDetails(rescuerId);
        final rescuerName = rescuerDetails['name'] ?? 'Rescue Team $rescuerId';
        final actualId = rescuerDetails['actual_id'] ?? rescuerId;

        return DropdownMenuItem<int>(
          value: rescuerId,
          child: Row(
            children: [
              // Badge for ID
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 3,
                ),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: Colors.blue.shade100),
                ),
                child: Text(
                  '#$actualId',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.blue.shade700,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              // Rescuer name
              Expanded(
                child: Text(
                  rescuerName,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
              ),
            ],
          ),
        );
      }).toList(),
      onChanged: (value) {
        debugPrint('[DEBUG] Selected rescuer: $value');
        setState(() {
          _selectedRescuerId = value;
        });
      },
      validator: (value) {
        if (value == null) {
          return 'Please select a rescue team';
        }
        return null;
      },
      isExpanded: true,
      menuMaxHeight: 300,
      dropdownColor: Colors.white,
      borderRadius: BorderRadius.circular(8),
    );
  }

  Future<String> _getDispatcherPhoneNumber() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('dispatcher_phone_number') ?? '09112223333';
  }

  @override
  Widget build(BuildContext context) {
    final availableRescuerIds = _getAvailableRescuerIds();
    final reportLocation = widget.reportLocation;

    return DraggableScrollableSheet(
      initialChildSize: 0.9,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (context, scrollController) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(20),
              topRight: Radius.circular(20),
            ),
          ),
          child: Column(
            children: [
              // Drag handle
              Container(
                margin: const EdgeInsets.only(top: 12),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(20),
                child: Row(
                  children: [
                    const Icon(Icons.assignment, color: Colors.blue, size: 24),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Report Details - #${widget.report.reportId}',
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: SingleChildScrollView(
                  controller: scrollController,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Report Details Section
                        _buildSectionTitle('Report Information'),
                        _buildDetailCard(
                          children: [
                            _buildDetailRow(
                              'Title',
                              widget.report.title ?? 'N/A',
                            ),
                            _buildDetailRow(
                              'Description',
                              widget.report.description ?? 'No description',
                            ),
                            _buildDetailRow(
                              'Flood Height',
                              widget.report.floodHeight != null
                                  ? '${widget.report.floodHeight!.toStringAsFixed(2)} meters'
                                  : 'Not specified',
                            ),
                            _buildDetailRow(
                              'Address',
                              widget.report.address ?? 'Unknown location',
                            ),
                            _buildDetailRow(
                              'Reported',
                              _formatDate(widget.report.createdAt),
                            ),
                            _buildDetailRow(
                              'Status',
                              _getStatusText(widget.report.status),
                            ),
                          ],
                        ),

                        // User Details Section
                        _buildSectionTitle('User Information'),
                        _buildDetailCard(
                          children: [
                            _buildDetailRow(
                              'Reported By',
                              widget.report.reportedBy ?? 'Unknown',
                            ),
                            _buildDetailRow(
                              'Phone Number',
                              widget.report.phoneNumber ?? 'Not provided',
                            ),
                            _buildDetailRow(
                              'User ID',
                              widget.report.reporterId ?? 'Unknown',
                            ),
                          ],
                        ),
                        // Map Section
                        _buildSectionTitle('Location Map'),
                        Container(
                          height: 300,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.grey.shade300),
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: MapViewer(
                              reports: [widget.report],
                              reportMarkers: _createReportMarkersForModal(),
                              initialLocation: widget.reportLocation,
                              onLocationSelected: (location, address) {},
                              disableSearch: true,
                              disableLocationSelection: true,
                              disableTapToPlace: true,
                              onMapCreated: (controller) {
                                _modalMapController = controller;
                                Future.delayed(
                                  const Duration(milliseconds: 500),
                                  () {
                                    if (reportLocation != null && mounted) {
                                      controller.animateCamera(
                                        CameraUpdate.newCameraPosition(
                                          CameraPosition(
                                            target: reportLocation,
                                            zoom: 15.0,
                                          ),
                                        ),
                                      );
                                      debugPrint(
                                        '[DEBUG] Modal map centered on: $reportLocation',
                                      );
                                    }
                                  },
                                );
                              },
                              mapScrollable: true,
                              enableZoom: true,
                              enablePan: true,
                              enableRotation: true,
                              enableTilt: true,
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),

                        // Assignment Section
                        _buildSectionTitle('Assign Rescue Team'),
                        _buildDetailCard(
                          children: [
                            // Severity Selection
                            DropdownButtonFormField<String>(
                              value: _selectedSeverity,
                              decoration: const InputDecoration(
                                labelText: 'Severity Level',
                                border: OutlineInputBorder(),
                                filled: true,
                                fillColor: Colors.white,
                              ),
                              items: const [
                                DropdownMenuItem(
                                  value: 'low',
                                  child: Text('Low'),
                                ),
                                DropdownMenuItem(
                                  value: 'medium',
                                  child: Text('Medium'),
                                ),
                                DropdownMenuItem(
                                  value: 'high',
                                  child: Text('High'),
                                ),
                              ],
                              onChanged: (value) {
                                setState(() {
                                  _selectedSeverity = value;
                                });
                              },
                            ),
                            const SizedBox(height: 16),

                            // Rescuer Selection
                            _buildRescuerDropdown(availableRescuerIds),

                            // Selected Rescuer Details Section
                            if (_selectedRescuerId != null) ...[
                              const SizedBox(height: 12),
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: Colors.blue.shade50,
                                  borderRadius: BorderRadius.circular(8),
                                  border:
                                      Border.all(color: Colors.blue.shade100),
                                ),
                                child: Row(
                                  children: [
                                    const Icon(Icons.person,
                                        size: 16, color: Colors.blue),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            'Selected: ${widget.getRescuerDetails(_selectedRescuerId!)['name']}',
                                            style: const TextStyle(
                                              fontSize: 13,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            'Phone: ${widget.getRescuerDetails(_selectedRescuerId!)['phone']}',
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: Colors.grey.shade700,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 12),
                            ],

                            const SizedBox(height: 20),

                            // Assign Button
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton(
                                onPressed: (_isAssigning ||
                                        _selectedRescuerId == null)
                                    ? null
                                    : _assignRescuer,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: (_selectedRescuerId == null)
                                      ? Colors.grey
                                      : Colors.blue.shade600,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 16,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                                child: _isAssigning
                                    ? const SizedBox(
                                        height: 20,
                                        width: 20,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          valueColor:
                                              AlwaysStoppedAnimation<Color>(
                                            Colors.white,
                                          ),
                                        ),
                                      )
                                    : Text(
                                        _selectedRescuerId == null
                                            ? 'Select a Rescue Team First'
                                            : 'Assign Rescue Team',
                                        style: const TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 40),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12, top: 20),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: Colors.blue,
        ),
      ),
    );
  }

  Widget _buildDetailCard({required List<Widget> children}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: children,
      ), );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              '$label:',
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                color: Colors.grey,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime? date) {
    if (date == null) return 'Unknown date';
    return '${date.day}/${date.month}/${date.year} ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
  }
}

class PendingRequestsPanel extends StatelessWidget {
  final List<ReportData> requests;
  final VoidCallback onRefresh;
  final bool usingMockData;
  final Function(ReportData) onOpenReport;

  const PendingRequestsPanel({
    required this.requests,
    required this.onRefresh,
    required this.usingMockData,
    required this.onOpenReport,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.black.withOpacity(0.06), width: 0.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          'Pending Requests',
                          style: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w600,
                            letterSpacing: -0.3,
                            color: Color(0xFF1D1D1F),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.orange.shade50,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: Colors.orange.shade200.withOpacity(0.5),
                              width: 0.5,
                            ),
                          ),
                          child: Text(
                            '${requests.length}',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: Colors.orange.shade700,
                              letterSpacing: -0.2,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      usingMockData
                          ? 'Demo: Manage unassigned flood rescue requests'
                          : 'Manage unassigned flood rescue requests',
                      style: const TextStyle(
                        fontSize: 13,
                        color: Color(0xFF6E6E73),
                        letterSpacing: -0.2,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.refresh_rounded, size: 20),
                onPressed: onRefresh,
                tooltip: 'Refresh',
                color: const Color(0xFF6E6E73),
                style: IconButton.styleFrom(
                  backgroundColor: Colors.black.withOpacity(0.04),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          if (requests.isEmpty)
            Center(
              child: Padding(
                padding: const EdgeInsets.all(40.0),
                child: Column(
                  children: [
                    Icon(
                      Icons.inbox_outlined,
                      size: 48,
                      color: Colors.grey.shade300,
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'No pending rescue requests',
                      style: TextStyle(
                        color: Color(0xFF6E6E73),
                        fontSize: 14,
                        letterSpacing: -0.2,
                      ),
                    ),
                  ],
                ),
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: requests.length,
              separatorBuilder: (context, index) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                return PendingRequestItem(
                  data: requests[index],
                  onOpenReport: onOpenReport,
                );
              },
            ),
        ],
      ),
    );
  }
}

class PendingRequestItem extends StatelessWidget {
  final ReportData data;
  final Function(ReportData) onOpenReport;

  const PendingRequestItem({
    required this.data,
    required this.onOpenReport,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFFAFAFA),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.black.withOpacity(0.06), width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  data.title ?? 'Flood Report',
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                    letterSpacing: -0.2,
                    color: Color(0xFF1D1D1F),
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.04),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  '#${data.reportId}',
                  style: const TextStyle(
                    fontSize: 11,
                    color: Color(0xFF6E6E73),
                    fontWeight: FontWeight.w500,
                    letterSpacing: -0.1,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _buildDetailRow(
            Icons.description_outlined,
            data.description ?? 'No description',
          ),
          if (data.address != null)
            _buildDetailRow(Icons.location_on_outlined, data.address!),
          _buildDetailRow(
            Icons.access_time_outlined,
            _formatDate(data.createdAt ?? data.timestamp),
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () => onOpenReport(data),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange.shade600,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                elevation: 0,
                shadowColor: Colors.transparent,
              ),
              child: const Text(
                'Open Report',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  letterSpacing: -0.2,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: const Color(0xFF6E6E73)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                fontSize: 13,
                color: Color(0xFF1D1D1F),
                letterSpacing: -0.2,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime? date) {
    if (date == null) return 'Unknown date';
    return '${date.month}/${date.day}/${date.year} ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
  }
}

class SummaryCard extends StatelessWidget {
  final String title;
  final int count;
  final Color color;
  final IconData? icon;

  const SummaryCard({
    required this.title,
    required this.count,
    required this.color,
    this.icon,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey.shade200, width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 12,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 12),
          Text(
            count.toString(),
            style: TextStyle(
              fontSize: 30,
              fontWeight: FontWeight.w800,
              color: color,
              letterSpacing: -1.2,
              height: 1,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: const TextStyle(
              fontSize: 11,
              color: Color(0xFF6E6E73),
              fontWeight: FontWeight.w600,
              letterSpacing: -0.2,
            ),
          ),
        ],
      ),
    );
  }
}

class AssignmentDialog extends StatefulWidget {
  final ReportData report;
  final List<int> availableRescuerIds;
  final VoidCallback onAssigned;
  final ApiService apiService;
  final String userName;
  final Map<String, dynamic> Function(int) getRescuerDetails;

  const AssignmentDialog({
    Key? key,
    required this.report,
    required this.availableRescuerIds,
    required this.onAssigned,
    required this.apiService,
    required this.userName,
    required this.getRescuerDetails,
  }) : super(key: key);

  @override
  State<AssignmentDialog> createState() => _AssignmentDialogState();
}

class _AssignmentDialogState extends State<AssignmentDialog> {
  String? _selectedSeverity;
  int? _selectedRescuerId;
  bool _isAssigning = false;

  @override
  void initState() {
    super.initState();
    _selectedSeverity = _getCurrentSeverity(widget.report.severity);
    debugPrint(
      '[DEBUG] Assignment dialog initialized for report: ${widget.report.reportId}',
    );
  }

  String _getCurrentSeverity(FloodSeverity? severity) {
    switch (severity) {
      case FloodSeverity.low:
        return 'low';
      case FloodSeverity.moderate:
        return 'medium';
      case FloodSeverity.high:
        return 'high';
      default:
        return 'medium';
    }
  }

  Future<void> _assignRescuer() async {
    if (_selectedRescuerId == null || _selectedSeverity == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select both severity and a rescuer'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    final scaffoldMessenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);

    setState(() {
      _isAssigning = true;
    });

    try {
      final reportId = widget.report.reportId;
      final currentUserName = widget.userName;
      final dispatcherPhoneNumber = await _getDispatcherPhoneNumber();
      final now = DateTime.now().toUtc().toIso8601String();

      final prefs = await SharedPreferences.getInstance();
      final dispatcherId = prefs.getInt('user_id') ?? 1;

      final reporterUserId = _getReporterUserIdFromReport(widget.report);

      final updateData = {
        'report_id': int.tryParse(reportId) ?? 0,
        'location_id': widget.report.locationId ?? 0,
        'user_id': reporterUserId,
        'user_phone_number': widget.report.phoneNumber ?? 'Unknown',
        'dispatcher_id': dispatcherId,
        'dispatcher_phone_number': dispatcherPhoneNumber,
        'user_name': widget.report.reportedBy ?? 'Unknown User',
        'severity': _selectedSeverity,
        'rescue_personnel_id': _selectedRescuerId,
        'assigned_to': _selectedRescuerId,
        'title': widget.report.title ?? 'Flood Report',
        'flood_height': widget.report.floodHeight ?? 0.0,
        'explanation': widget.report.explanation ?? 'Assigned to rescue team',
        'response_status': 'assigned',
        'response_id': 0,
        'report_status': 'assigned',
        'created_by': widget.report.createdBy ?? 'Unknown',
        'created_at': widget.report.createdAt?.toUtc().toIso8601String() ?? now,
        'updated_by': currentUserName,
        'updated_at': now,
      };

      debugPrint('[DEBUG] Updating report $reportId for user $reporterUserId');
      debugPrint('[DEBUG] Update data: $updateData');

      await widget.apiService.updateReport(
        reportId,
        updateData,
        reporterUserId,
      );

      navigator.pop();
      scaffoldMessenger.showSnackBar(
        const SnackBar(
          content: Text('Rescuer assigned successfully!'),
          backgroundColor: Colors.green,
        ),
      );

      widget.onAssigned();
    } catch (e) {
      debugPrint('[DEBUG] Error assigning rescuer: $e');
      if (!mounted) return;

      scaffoldMessenger.showSnackBar(
        SnackBar(
          content: Text('Error assigning rescuer: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isAssigning = false;
        });
      }
    }
  }

  int _getReporterUserIdFromReport(ReportData report) {
    try {

      if (report.reporterId != null) {
        final userId = int.tryParse(report.reporterId!);
        if (userId != null) {
          debugPrint('[DEBUG] Found user_id from reporterId: $userId');
          return userId;
        }
      }

      if (report.userId != null) {
        debugPrint('[DEBUG] Found user_id from userId field: ${report.userId}');
        return report.userId!;
      }

      if (report.createdBy != null) {
        final match = RegExp(r'\((\d+)\)').firstMatch(report.createdBy!);
        if (match != null) {
          final userId = int.parse(match.group(1)!);
          debugPrint('[DEBUG] Extracted user_id from createdBy: $userId');
          return userId;
        }
      }

      debugPrint(
        '[DEBUG] Could not extract user_id from report, using fallback: 1',
      );
      return 1; 
    } catch (e) {
      debugPrint('[DEBUG] Error extracting user_id from report: $e');
      return 1; 
    }
  }

  Future<String> _getDispatcherPhoneNumber() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('dispatcher_phone_number') ?? '09112223333';
  }

  @override
  Widget build(BuildContext context) {
    final reportId = widget.report.reportId;
    final title = widget.report.title ?? 'No Title';

    return AlertDialog(
      title: const Text('Assign Rescuer'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Report: $title',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            Text('ID: #$reportId'),
            const SizedBox(height: 20),

            // Severity Selection
            DropdownButtonFormField<String>(
              value: _selectedSeverity,
              decoration: const InputDecoration(
                labelText: 'Severity Level',
                border: OutlineInputBorder(),
              ),
              items: const [
                DropdownMenuItem(value: 'low', child: Text('Low')),
                DropdownMenuItem(value: 'medium', child: Text('Medium')),
                DropdownMenuItem(value: 'high', child: Text('High')),
              ],
              onChanged: (value) {
                setState(() {
                  _selectedSeverity = value;
                });
              },
            ),

            const SizedBox(height: 16),

            // Rescuer Selection
            DropdownButtonFormField<int>(
              value: _selectedRescuerId,
              decoration: const InputDecoration(
                labelText: 'Select Rescuer',
                border: OutlineInputBorder(),
              ),
              items: widget.availableRescuerIds.map((rescuerId) {
                final rescuerDetails = widget.getRescuerDetails(rescuerId);
                return DropdownMenuItem<int>(
                  value: rescuerId,
                  child: Text('${rescuerDetails['name']} (ID: $rescuerId)'),
                );
              }).toList(),
              onChanged: (value) {
                setState(() {
                  _selectedRescuerId = value;
                });
              },
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isAssigning ? null : () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _isAssigning ? null : _assignRescuer,
          child: _isAssigning
              ? const SizedBox(
                  height: 16,
                  width: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Assign Rescuer'),
        ),
      ],
    );
  }
}

class OperationsMapPanel extends StatelessWidget {
  final List<ReportData> pendingReports;
  final List<ReportData> assignedReports;
  final List<ReportData> resolvedReports;
  final bool usingMockData;
  final Set<Marker> reportMarkers;
  final Function(GoogleMapController) onMapCreated;

  const OperationsMapPanel({
    required this.pendingReports,
    required this.assignedReports,
    required this.resolvedReports,
    required this.usingMockData,
    required this.reportMarkers,
    required this.onMapCreated,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.black.withOpacity(0.06), width: 0.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Operations Map',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w600,
                  letterSpacing: -0.3,
                  color: Color(0xFF1D1D1F),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                usingMockData
                    ? 'Demo: Overview of sample rescue requests and flood zones'
                    : 'Overview of all rescue requests and flood zones',
                style: const TextStyle(
                  fontSize: 13,
                  color: Color(0xFF6E6E73),
                  letterSpacing: -0.2,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          Container(
            height: 400,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: Colors.black.withOpacity(0.06),
                width: 0.5,
              ),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: MapViewer(
                reports: [
                  ...pendingReports,
                  ...assignedReports,
                  ...resolvedReports,
                ],
                reportMarkers: reportMarkers,
                onMapCreated: onMapCreated,
                disableLocationSelection: true,
                disableTapToPlace: true,
                mapScrollable: true,
                disableSearch: true,
                onLocationSelected: (LatLng p1, String? p2) {},
                enableZoom: true,
                enablePan: true,
                enableRotation: true,
                enableTilt: true,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class AssignedRescuesPanel extends StatelessWidget {
  final List<ReportData> rescues;
  final VoidCallback onRefresh;
  final bool usingMockData;
  final Function(ReportData) onViewProgress;

  const AssignedRescuesPanel({
    required this.rescues,
    required this.onRefresh,
    required this.usingMockData,
    required this.onViewProgress,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.black.withOpacity(0.06), width: 0.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Text(
                          'Assigned Rescues',
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w600,
                            letterSpacing: -0.3,
                            color: Color(0xFF1D1D1F),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.blue.shade50,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: Colors.blue.shade200.withOpacity(0.5),
                              width: 0.5,
                            ),
                          ),
                          child: Text(
                            '${rescues.length}',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: Colors.blue.shade700,
                              letterSpacing: -0.2,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      usingMockData
                          ? 'Demo: List of sample rescue operations'
                          : 'List of active rescue operations',
                      style: const TextStyle(
                        fontSize: 13,
                        color: Color(0xFF6E6E73),
                        letterSpacing: -0.2,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.refresh_rounded, size: 20),
                onPressed: onRefresh,
                tooltip: 'Refresh',
                color: const Color(0xFF6E6E73),
                style: IconButton.styleFrom(
                  backgroundColor: Colors.black.withOpacity(0.04),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          if (rescues.isEmpty)
            Center(
              child: Padding(
                padding: const EdgeInsets.all(40.0),
                child: Column(
                  children: [
                    Icon(
                      Icons.assignment_outlined,
                      size: 48,
                      color: Colors.grey.shade300,
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'No assigned rescue operations',
                      style: TextStyle(
                        color: Color(0xFF6E6E73),
                        fontSize: 14,
                        letterSpacing: -0.2,
                      ),
                    ),
                  ],
                ),
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: rescues.length,
              separatorBuilder: (context, index) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                return AssignedRescueItem(
                  data: rescues[index],
                  onRefresh: onRefresh,
                  onViewProgress: onViewProgress,
                );
              },
            ),
        ],
      ),
    );
  }
}
