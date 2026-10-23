// ignore_for_file: use_build_context_synchronously

import 'dart:async';
import 'package:fdr/features/auth/data/auth_state.dart';
import 'package:fdr/features/auth/data/models/report/report_data.dart';
import 'package:fdr/features/auth/rescuer/presentation/assignments_page.dart';
import 'package:fdr/features/auth/user/presentation/home/home_bloc.dart';
import 'package:fdr/features/auth/user/presentation/profile/profile_page.dart';
import 'package:fdr/features/widgets/draggable_reports_sheet_widget.dart';
import 'package:fdr/features/widgets/map_overlay_header_widget.dart';
import 'package:fdr/features/widgets/map_viewer.dart';
import 'package:fdr/features/widgets/report_card_widget.dart';
import 'package:fdr/features/widgets/rescuer_bottom_bar_widget.dart';
import 'package:fdr/services/api_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc_pattern/flutter_bloc_pattern.dart';
import 'package:flutter_disposebag/flutter_disposebag.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

class RescuerHomePage extends StatefulWidget {
  static const routeName = '/rescuer_home_page';

  const RescuerHomePage({super.key});

  @override
  State<RescuerHomePage> createState() => _RescuerHomePageState();
}

class _RescuerHomePageState extends State<RescuerHomePage>
    with SingleTickerProviderStateMixin<RescuerHomePage>, DisposeBagMixin {
  int _selectedIndex = 0;

  // Sheet configuration
  static const double _initialSheetSize = 0.15;
  static const double _maxSheetSize = 0.95;

  DraggableScrollableController _sheetController =
      DraggableScrollableController();
  final ValueNotifier<double> _currentSheetSize = ValueNotifier(
    _initialSheetSize,
  );

  // Search state
  final TextEditingController _searchController = TextEditingController();
  List<ReportData> _filteredReports = [];
  String _searchQuery = '';
  bool _isSearchingLocation = false;

  // Map state
  GoogleMapController? _mapController;
  String _currentCityName = 'Cebu';

  late final ApiService _apiService;
  List<ReportData> _reports = [];
  bool _isLoadingReports = true;
  String? _loadError;
  bool _usingMockData = false;

  Set<Marker> _reportMarkers = {};
  Set<Circle> _floodCircles = {};
  List<LatLng> _validMarkerLocations = [];

  Timer? _locationTimer;
  Position? _currentPosition;
  Marker? _rescuerMarker;
  bool _isTrackingLocation = false;
  int? _currentUserId;
  int? _lastLocationId;

  bool _isLoadingFloodData = false;
  bool _usingMockFloodData = false;
  List<dynamic> _sensors = [];

  static const Map<int, Color> _floodLevelColors = {
    1: Color(0xEEFFEB3B),
    2: Color(0xEEFF9800),
    3: Color(0xEED32F2F),
  };

  static const Map<int, String> _floodLevelLabels = {
    1: "Low",
    2: "Medium",
    3: "High",
  };

  final Map<int, Map<String, dynamic>> _locationCache = {};

  @override
  void initState() {
    super.initState();
    _apiService = ApiService();
    _searchController.addListener(_onSearchChanged);
    _sheetController = DraggableScrollableController();
    _sheetController.addListener(_updateSheetSize);
    _fetchReportsFromAPI();
    _fetchFloodData();
    _initializeLocationTracking();
    _updateCityName(const LatLng(14.5995, 120.9842));
  }

  Future<void> _initializeLocationTracking() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final userRole = prefs.getString('user_role');
      final userId = prefs.getInt('user_id');

      debugPrint('User Role: $userRole');
      debugPrint('User ID: $userId');

      setState(() {
        _currentUserId = userId;
      });
    } catch (e) {
      debugPrint('ERROR loading user data: $e');
    }

    if (_currentUserId != null) {
      final permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        final requestedPermission = await Geolocator.requestPermission();
        if (requestedPermission != LocationPermission.whileInUse &&
            requestedPermission != LocationPermission.always) {
          debugPrint('Location permission denied');
          return;
        }
      }

      _startLocationTracking();
    } else {
      debugPrint('User ID not available for location tracking');
    }
  }

  void _startLocationTracking() {
    _getCurrentLocation();

    _locationTimer = Timer.periodic(const Duration(minutes: 2), (timer) {
      _getCurrentLocation();
    });

    setState(() {
      _isTrackingLocation = true;
    });

    debugPrint('Location tracking started - updating every 2 minutes');
  }

  Future<void> _getCurrentLocation() async {
    try {
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.best,
      );

      setState(() {
        _currentPosition = position;
      });

      debugPrint(
        'Rescuer location: ${position.latitude}, ${position.longitude}',
      );

      _updateRescuerMarker();

      await _updateUserLocationOnServer(position);
    } catch (e) {
      debugPrint('Error getting location: $e');
    }
  }

  void _updateRescuerMarker() {
    if (_currentPosition != null && _mapController != null) {
      final rescuerPosition = LatLng(
        _currentPosition!.latitude,
        _currentPosition!.longitude,
      );

      setState(() {
        _rescuerMarker = Marker(
          markerId: const MarkerId('rescuer_location'),
          position: rescuerPosition,
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue),
          infoWindow: const InfoWindow(
            title: 'Your Location',
            snippet: 'Rescuer current position',
          ),
        );
      });

      debugPrint('Rescuer marker updated at: $rescuerPosition');
    }
  }

  Future<void> _updateUserLocationOnServer(Position position) async {
    if (_currentUserId == null) {
      debugPrint('Cannot update location: User ID not available');
      return;
    }

    try {
      final locationId = await _createLocationOnServer(
        position.latitude,
        position.longitude,
      );

      if (locationId != null) {
        if (_lastLocationId == locationId) {
          debugPrint('Location ID unchanged, skipping update');
          return;
        }

        _lastLocationId = locationId;

        final response = await _apiService.updateUserLocation(
          _currentUserId!,
          locationId,
        );

        if (response != null) {
          debugPrint(' Successfully updated rescuer location on server');
          debugPrint('  - User ID: $_currentUserId');
          debugPrint('  - Location ID: $locationId');
          debugPrint(
            '  - Coordinates: ${position.latitude}, ${position.longitude}',
          );

          // if (mounted) {
          //   ScaffoldMessenger.of(context).showSnackBar(
          //     SnackBar(
          //       content: Text('Location updated at ${DateTime.now().toString().substring(11, 16)}'),
          //       duration: const Duration(seconds: 2),
          //       backgroundColor: Colors.green,
          //     ),
          //   );
          // }
        } else {
          debugPrint('✗ Failed to update rescuer location on server');
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: const Text('Failed to update location'),
                duration: const Duration(seconds: 3),
                backgroundColor: Colors.red,
              ),
            );
          }
        }
      } else {
        debugPrint('✗ Could not create location on server');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Failed to create location'),
              duration: const Duration(seconds: 3),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('Error updating user location on server: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Location update error: ${e.toString()}'),
            duration: const Duration(seconds: 4),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<int?> _createLocationOnServer(
    double latitude,
    double longitude,
  ) async {
    try {
      debugPrint('[LOCATION] Creating new location on server...');
      debugPrint('[LOCATION] Coordinates: $latitude, $longitude');

      final response = await _apiService.createLocation({
        'latitude': latitude.toString(),
        'longitude': longitude.toString(),
      });

      if (response != null) {
        debugPrint('[LOCATION] Server response: $response');

        int? locationId;

        if (response is Map) {
          if (response['location_id'] != null) {
            locationId = int.tryParse(response['location_id'].toString());
          } else if (response['data'] != null && response['data'] is Map) {
            locationId = int.tryParse(
              response['data']['location_id'].toString(),
            );
          } else if (response['id'] != null) {
            locationId = int.tryParse(response['id'].toString());
          }
        }

        if (locationId != null) {
          debugPrint(
            '[LOCATION] ✓ Successfully created location with ID: $locationId',
          );
          return locationId;
        } else {
          debugPrint(
            '[LOCATION] ✗ Could not parse location_id from response: $response',
          );
          return null;
        }
      } else {
        debugPrint(
          '[LOCATION] ✗ No response from server when creating location',
        );
        return null;
      }
    } catch (e) {
      debugPrint('[LOCATION] ✗ Error creating location on server: $e');
      return null;
    }
  }

  Future<void> _stopLocationTracking() async {
    _locationTimer?.cancel();
    _locationTimer = null;

    setState(() {
      _isTrackingLocation = false;
      _rescuerMarker = null;
    });

    debugPrint('Location tracking stopped');
  }

  Set<Marker> _generateMarkers(List<ReportData> reports) {
    debugPrint('[MARKERS] Generating markers for ${reports.length} reports');

    _validMarkerLocations.clear();

    final markers = reports
        .map((report) {
          if (report.latitude == null || report.longitude == null) {
            debugPrint(
              '[MARKERS] Skipping report ${report.reportId} - no coordinates',
            );
            return null;
          }

          final position = LatLng(report.latitude!, report.longitude!);
          _validMarkerLocations.add(position);

          debugPrint(
            '[MARKERS] Creating marker for ${report.reportId} at ${report.latitude}, ${report.longitude}',
          );

          return Marker(
            markerId: MarkerId(report.reportId),
            position: position,
            infoWindow: InfoWindow(
              title: report.title ?? 'Flood Report',
              snippet:
                  report.explanation ??
                  report.description ??
                  'Tap to view details',
            ),
            icon: _getMarkerIcon(report.status),
            onTap: () {
              debugPrint('[MARKERS] Marker tapped: ${report.reportId}');
              _handleReportMarkerTap(report);
            },
          );
        })
        .whereType<Marker>()
        .toSet();

    if (_rescuerMarker != null) {
      markers.add(_rescuerMarker!);
    }

    debugPrint(
      '[MARKERS] Created ${markers.length} markers from ${_validMarkerLocations.length} valid locations',
    );
    return markers;
  }

  @override
  void dispose() {
    _stopLocationTracking();
    _sheetController.removeListener(_updateSheetSize);
    _sheetController.dispose();
    _currentSheetSize.dispose();
    _searchController.dispose();
    _mapController?.dispose();
    super.dispose();
  }

  Future<void> _fetchFloodData() async {
    setState(() {
      _isLoadingFloodData = true;
      _usingMockFloodData = false;
    });

    try {
      debugPrint('[FLOOD] Fetching flood sensor data...');
      final response = await _apiService.getAllSensors();

      if (response != null &&
          response['data'] is List &&
          (response['data'] as List).isNotEmpty) {
        setState(() {
          _sensors = response['data'];
          _createFloodCircles();
        });
        debugPrint(
          '[FLOOD] Loaded ${_sensors.length} sensor readings from API',
        );
      } else {
        _useMockFloodData('No flood sensor data available. Using demo data.');
      }
    } catch (e) {
      debugPrint('[FLOOD] Error loading flood data: $e');
      _useMockFloodData('Failed to load flood data. Using demo data.');
    } finally {
      setState(() {
        _isLoadingFloodData = false;
      });
    }
  }

  void _useMockFloodData(String message) {
    debugPrint('[FLOOD-MOCK] $message');

    final mockSensorData = [
      {
        'data_id': 1001,
        'data': 0.65,
        'latitude': 14.5995,
        'longitude': 120.9842,
        'created_at': DateTime.now().toIso8601String(),
      },
    ];

    setState(() {
      _sensors = mockSensorData;
      _usingMockFloodData = true;
      _createFloodCircles();
    });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('$message Showing Cebu flood sensor.'),
          duration: const Duration(seconds: 4),
          backgroundColor: Colors.blue,
        ),
      );
    }
  }

  void _createFloodCircles() {
    debugPrint(
      '[FLOOD] Creating flood circle for ${_sensors.length} sensor readings',
    );

    _floodCircles.clear();

    if (_sensors.isEmpty) {
      debugPrint('[FLOOD] No sensor data available');
      return;
    }

    final LatLng mandaue_location = const LatLng(10.3478, 123.9275);
    final latestSensor = _sensors.first;
    final sensorData = latestSensor['data'] as num?;

    if (sensorData != null) {
      final floodLevel = _calculateFloodLevel(sensorData.toDouble());

      _floodCircles.add(
        Circle(
          circleId: const CircleId('IOT flood_sensor'),
          center: mandaue_location,
          radius: 1000.0,
          fillColor: _getSolidFillColor(floodLevel),
          strokeColor: _getSolidStrokeColor(floodLevel),
          strokeWidth: 6,
          consumeTapEvents: true,
          zIndex: 999,
          visible: true,
          onTap: () {
            _showSensorInfo(latestSensor, floodLevel);
          },
        ),
      );

      debugPrint('[FLOOD] Created flood circle with SOLID COLOR');
      debugPrint(
        '[FLOOD] Fill: ${_getSolidFillColor(floodLevel)}, Stroke: ${_getSolidStrokeColor(floodLevel)}',
      );
    }

    setState(() {});

    if (_mapController != null && _floodCircles.isNotEmpty) {
      Future.delayed(const Duration(milliseconds: 800), () {
        _centerMapOnFloodSensor();
      });
    }
  }

  Color _getSolidFillColor(int floodLevel) {
    switch (floodLevel) {
      case 1:
        return const Color(0xCCFFEB3B).withOpacity(0.3);
      case 2:
        return const Color(0xCCFF9800).withOpacity(0.3);
      case 3:
        return const Color(0xCCF44336).withOpacity(0.3);
      default:
        return const Color(0xCCF44336).withOpacity(0.3);
    }
  }

  Color _getSolidStrokeColor(int floodLevel) {
    switch (floodLevel) {
      case 1:
        return const Color(0xFFFDD835).withOpacity(0.3);
      case 2:
        return const Color(0xFFFF6F00).withOpacity(0.3);
      case 3:
        return const Color(0xFFD32F2F).withOpacity(0.3);
      default:
        return const Color(0xFFD32F2F).withOpacity(0.3);
    }
  }

  void _centerMapOnFloodSensor() {
    if (_floodCircles.isEmpty || _mapController == null) {
      debugPrint('[MAP] Cannot center - no flood circles or map controller');
      return;
    }

    final circle = _floodCircles.first;

    debugPrint('[MAP] Centering on flood sensor at ${circle.center}');

    _mapController!.animateCamera(
      CameraUpdate.newCameraPosition(
        CameraPosition(target: circle.center, zoom: 15.0),
      ),
    );

    _updateCityName(circle.center);
  }

  int _calculateFloodLevel(double sensorData) {
    if (sensorData < 0.5) return 1;
    if (sensorData < 0.5) return 2;
    if (sensorData > 1) return 3;
    return 3;
  }

  Color _getStrokeColorForFloodLevel(int level) {
    switch (level) {
      case 1:
        return const Color(0xFFFBC02D).withOpacity(0.3);
      case 2:
        return const Color(0xFFF57C00).withOpacity(0.3);
      case 3:
        return const Color(0xFFC62828).withOpacity(0.3);
      default:
        return Colors.grey.withOpacity(0.3);
    }
  }

  void _showSensorInfo(dynamic sensorReading, int floodLevel) {
    final floodLabel = _floodLevelLabels[floodLevel] ?? "Unknown";
    final sensorData = sensorReading['data'] as num?;
    final createdAt = sensorReading['created_at']?.toString() ?? 'Unknown';

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cebu Flood Sensor'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (_usingMockFloodData)
              Container(
                padding: const EdgeInsets.all(8),
                margin: const EdgeInsets.only(bottom: 8),
                decoration: BoxDecoration(
                  color: Colors.blue.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info, color: Colors.blue, size: 16),
                    const SizedBox(width: 4),
                    Text(
                      'Demo Sensor Data',
                      style: TextStyle(color: Colors.blue),
                    ),
                  ],
                ),
              ),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: _getStrokeColorForFloodLevel(
                  floodLevel,
                ).withOpacity(0.1),
                borderRadius: BorderRadius.circular(4),
                border: Border.all(
                  color: _getStrokeColorForFloodLevel(floodLevel),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.sensors,
                    color: _getStrokeColorForFloodLevel(floodLevel),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Water Level: ${sensorData?.toStringAsFixed(2)}m',
                    style: TextStyle(
                      color: _getStrokeColorForFloodLevel(floodLevel),
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: _getStrokeColorForFloodLevel(
                  floodLevel,
                ).withOpacity(0.1),
                borderRadius: BorderRadius.circular(4),
                border: Border.all(
                  color: _getStrokeColorForFloodLevel(floodLevel),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.water,
                    color: _getStrokeColorForFloodLevel(floodLevel),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Flood Level: $floodLabel',
                    style: TextStyle(
                      color: _getStrokeColorForFloodLevel(floodLevel),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            _buildDetailRow('Location', 'AS Fortuna Area'),
            _buildDetailRow('City', 'Mandaue City, Cebu'),
            _buildDetailRow(
              'Area Type',
              'Commercial/Residential - Flood Prone',
            ),
            _buildDetailRow(
              'Sensor ID',
              sensorReading['data_id']?.toString() ?? 'MS-001',
            ),
            _buildDetailRow('Last Reading', _formatSensorDate(createdAt)),
            const SizedBox(height: 8),
            const Divider(),
            const SizedBox(height: 8),
            const Text(
              'Flood Level Guide:',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            _buildLevelGuide(
              'Low (< 0.5m)',
              'Minimal flooding - Caution advised',
            ),
            _buildLevelGuide(
              'Medium (0.5m - 0.9m)',
              'Moderate flooding - Some roads impassable',
            ),
            _buildLevelGuide(
              'High (> 1.0m)',
              'Significant flooding - Avoid area',
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  String _formatSensorDate(String dateString) {
    try {
      final date = DateTime.parse(dateString);
      return '${date.hour}:${date.minute.toString().padLeft(2, '0')} - ${date.day}/${date.month}/${date.year}';
    } catch (e) {
      return 'Unknown';
    }
  }

  Widget _buildLevelGuide(String level, String description) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          const Icon(Icons.info_outline, size: 12, color: Colors.grey),
          const SizedBox(width: 4),
          Expanded(
            child: Text(
              '$level: $description',
              style: const TextStyle(fontSize: 11, color: Colors.grey),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              '$label:',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(child: Text(value, style: const TextStyle(fontSize: 13))),
        ],
      ),
    );
  }

  Future<void> _fetchReportsFromAPI() async {
    try {
      setState(() {
        _isLoadingReports = true;
        _loadError = null;
        _usingMockData = false;
      });

      debugPrint('[API] Fetching reports from server...');
      final response = await _apiService.getAllReports(offset: 0, limit: 100);

      debugPrint('[API] Response received: ${response.runtimeType}');

      final List<ReportData> fetchedReports = [];

      if (response == null || (response is List && response.isEmpty)) {
        debugPrint('[API] No reports found in response');
        _useMockData('No flood reports available yet. Using demo data.');
        return;
      } else if (response is Map && response['data'] is List) {
        final dataList = response['data'] as List;
        debugPrint(
          '[API] Processing ${dataList.length} reports from wrapped response...',
        );

        for (var item in dataList) {
          final report = await _parseAndEnrichReport(item);
          if (report != null) {
            fetchedReports.add(report);
          }
        }
      } else if (response is List) {
        debugPrint(
          '[API] Processing ${response.length} reports from direct list...',
        );

        for (var item in response) {
          final report = await _parseAndEnrichReport(item);
          if (report != null) {
            fetchedReports.add(report);
          }
        }
      } else if (response is Map && response['detail'] != null) {
        final detail = response['detail'].toString();
        debugPrint('[API] API returned detail message: $detail');

        if (detail.contains('No Report Has Been Added')) {
          _useMockData(
            'No flood reports have been submitted yet. Using demo data.',
          );
          return;
        }
      } else {
        debugPrint(
          '[API] WARNING: Unexpected response format: ${response.runtimeType}',
        );
        _useMockData(
          'Unexpected response format from server. Using demo data.',
        );
        return;
      }

      if (fetchedReports.isEmpty) {
        _useMockData('No valid reports found in response. Using demo data.');
        return;
      }

      debugPrint('[API] Successfully parsed ${fetchedReports.length} reports');

      setState(() {
        _reports = fetchedReports;
        _filteredReports = List.from(_reports);
        _isLoadingReports = false;
        _usingMockData = false;
        _reportMarkers = _generateMarkers(_reports);
      });

      debugPrint('[API] Generated ${_reportMarkers.length} markers');

      if (_validMarkerLocations.isNotEmpty && _mapController != null) {
        _fitMapToMarkers();
      } else if (_mapController != null && _floodCircles.isNotEmpty) {
        _centerMapOnFloodSensor();
      }
    } catch (e, stackTrace) {
      debugPrint('[API] ✗✗✗ Critical error fetching reports: $e');
      debugPrint('[API] Stack trace: $stackTrace');

      _useMockData('Failed to load reports: ${e.toString()}. Using demo data.');
    }
  }

  void _useMockData(String message) {
    debugPrint('[MOCK] $message');

    final mockReports = _generateMockReports();

    if (mounted) {
      setState(() {
        _reports = mockReports.cast<ReportData>();
        _filteredReports = List.from(_reports);
        _isLoadingReports = false;
        _usingMockData = true;
        _reportMarkers = _generateMarkers(_reports);
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          duration: const Duration(seconds: 4),
          backgroundColor: Colors.orange,
        ),
      );

      if (_validMarkerLocations.isNotEmpty && _mapController != null) {
        _fitMapToMarkers();
      } else if (_mapController != null && _floodCircles.isNotEmpty) {
        _centerMapOnFloodSensor();
      }
    }
  }

  List<ReportData> _generateMockReports() {
    final now = DateTime.now();
    final mockLocations = [
      {'lat': 14.5995, 'lng': 120.9842, 'address': 'Intramuros, Manila'},
      {'lat': 14.6091, 'lng': 120.9920, 'address': 'Ermita, Manila'},
      {'lat': 14.5890, 'lng': 120.9760, 'address': 'Malate, Manila'},
      {'lat': 14.6200, 'lng': 121.0000, 'address': 'Sampaloc, Manila'},
      {'lat': 14.5800, 'lng': 120.9900, 'address': 'Paco, Manila'},
    ];

    final mockReports = [
      ReportData(
        reportId: 'mock_1',
        title: 'Severe Flooding in Intramuros',
        floodHeight: 0.8,
        explanation:
            'Heavy rainfall caused flooding in the historic district. Water level rising rapidly.',
        responseStatus: 'in_progress',
        createdBy: 'Demo User 1',
        createdAt: now.subtract(const Duration(hours: 2)),
        description:
            'Major flooding reported in Intramuros area. Roads impassable.',
        address: mockLocations[0]['address'].toString(),
        latitude: mockLocations[0]['lat'] as double?,
        longitude: mockLocations[0]['lng'] as double?,
        severity: FloodSeverity.high,
        status: ReportStatus.inProgress,
        timestamp: now.subtract(const Duration(hours: 2)),
        reporterId: 'demo_user_1',
        reportedBy: 'user1',
        phoneNumber: '09123827789',
      ),
      ReportData(
        reportId: 'mock_2',
        title: 'Moderate Flooding in Ermita',
        floodHeight: 0.4,
        explanation:
            'Moderate flooding affecting main roads. Traffic building up.',
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
        reportedBy: 'user1',
        phoneNumber: '09123827789',
      ),
    ];

    debugPrint('[MOCK] Generated ${mockReports.length} demo reports');
    return mockReports;
  }

  Future<ReportData?> _parseAndEnrichReport(dynamic item) async {
    if (item is! Map) {
      debugPrint('[PARSE] Item is not a Map: ${item.runtimeType}');
      return null;
    }

    try {
      final jsonData = item.cast<String, dynamic>();
      final report = ReportData.fromJson(jsonData);

      debugPrint(
        '[PARSE] Processing report ${report.reportId}, locationId: ${report.locationId}',
      );

      if (report.locationId != null) {
        final locationData = await _fetchLocationData(report.locationId!);

        if (locationData != null) {
          final double? lat = locationData['latitude'];
          final double? lng = locationData['longitude'];
          final String? address = locationData['address'];

          debugPrint(
            '[PARSE] Location data for ${report.locationId}: lat=$lat, lng=$lng, address=$address',
          );

          return report.copyWith(
            latitude: lat,
            longitude: lng,
            address: address,
            location: (lat != null && lng != null) ? LatLng(lat, lng) : null,
          );
        } else {
          debugPrint(
            '[PARSE] No location data found for locationId ${report.locationId}',
          );
        }
      } else {
        debugPrint('[PARSE] Report ${report.reportId} has no locationId');
      }

      return report;
    } catch (e, stackTrace) {
      debugPrint('[PARSE] Error parsing report: $e');
      debugPrint('[PARSE] Stack: $stackTrace');
      debugPrint('[PARSE] Problematic item: $item');
      return null;
    }
  }

  Future<Map<String, dynamic>?> _fetchLocationData(int locationId) async {
    if (_locationCache.containsKey(locationId)) {
      debugPrint('[LOCATION] Using cached data for location $locationId');
      return _locationCache[locationId];
    }

    try {
      debugPrint('[LOCATION] Fetching data for location $locationId');
      final response = await _apiService.getLocationById(locationId);

      if (response != null && response is Map) {
        dynamic locationData;

        if (response['data'] != null) {
          locationData = response['data'];
        } else {
          locationData = response;
        }

        if (locationData is Map) {
          final double? lat = _parseDouble(locationData['latitude']);
          final double? lng = _parseDouble(locationData['longitude']);

          String? address =
              locationData['address']?.toString() ??
              locationData['name']?.toString();

          if (address == null && lat != null && lng != null) {
            address = await _getAddressFromCoordinates(lat, lng);
          }

          address ??= 'Location $locationId';

          debugPrint(
            '[LOCATION] Parsed coordinates: lat=$lat, lng=$lng, address=$address',
          );

          final result = {
            'latitude': lat,
            'longitude': lng,
            'address': address,
          };

          if (lat != null && lng != null) {
            _locationCache[locationId] = result;
            debugPrint(
              '[LOCATION] ✓ Successfully cached location $locationId at $lat, $lng',
            );
            return result;
          } else {
            debugPrint(
              '[LOCATION] ✗ Location $locationId has invalid coordinates',
            );
          }
        }
      }
    } catch (e) {
      debugPrint('[LOCATION] ✗ Error fetching location $locationId: $e');
    }

    return null;
  }

  Future<String> _getAddressFromCoordinates(double lat, double lng) async {
    try {
      final placemarks = await placemarkFromCoordinates(lat, lng);
      if (placemarks.isNotEmpty) {
        final placemark = placemarks.first;
        final addressParts = [
          placemark.street,
          placemark.subLocality,
          placemark.locality,
          placemark.administrativeArea,
        ].where((part) => part != null && part.isNotEmpty).toList();

        return addressParts.isNotEmpty
            ? addressParts.join(', ')
            : 'Unable to get Address';
      }
    } catch (e) {
      debugPrint('[GEOCODING] Error getting address from coordinates: $e');
    }

    return 'Unable to get Address';
  }

  double? _parseDouble(dynamic value) {
    if (value == null) return null;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) return double.tryParse(value);
    return null;
  }

  Future<void> _refreshReports() async {
    _locationCache.clear();
    await _fetchReportsFromAPI();
  }

  Future<void> _refreshFloodData() async {
    await _fetchFloodData();
  }

  void _updateSheetSize() {
    if (_sheetController.isAttached) {
      _currentSheetSize.value = _sheetController.size;
    }
  }

  void _handleReportMarkerTap(ReportData report) {
    debugPrint(
      '[MARKERS] Report marker tapped: ${report.reportId} - ${report.title}',
    );

    _sheetController.animateTo(
      _maxSheetSize,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOut,
    );

    if (report.latitude != null &&
        report.longitude != null &&
        _mapController != null) {
      final reportLocation = LatLng(report.latitude!, report.longitude!);
      _mapController!.animateCamera(
        CameraUpdate.newCameraPosition(
          CameraPosition(target: reportLocation, zoom: 15.0),
        ),
      );
    }

    _showReportDetails(report);
  }

  BitmapDescriptor _getMarkerIcon(ReportStatus? status) {
    if (status == ReportStatus.newReport || status == ReportStatus.pending) {
      return BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed);
    } else if (status == ReportStatus.inProgress) {
      return BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueOrange);
    } else {
      return BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueYellow);
    }
  }

  void _onSearchChanged() {
    final query = _searchController.text;
    setState(() {
      _searchQuery = query.toLowerCase();
      if (_searchQuery.isEmpty) {
        _filteredReports = List.from(_reports);
      } else {
        _filteredReports = _reports.where((report) {
          final titleMatch =
              report.title?.toLowerCase().contains(_searchQuery) ?? false;
          final descMatch =
              report.description?.toLowerCase().contains(_searchQuery) ?? false;
          final explanationMatch =
              report.explanation?.toLowerCase().contains(_searchQuery) ?? false;
          final locationMatch =
              report.address?.toLowerCase().contains(_searchQuery) ?? false;
          return titleMatch || descMatch || explanationMatch || locationMatch;
        }).toList();
      }
    });
  }

  Future<void> _searchLocationOnMap(String query) async {
    if (query.trim().isEmpty || _mapController == null) return;

    setState(() {
      _isSearchingLocation = true;
    });

    try {
      final locations = await locationFromAddress(query);

      if (locations.isNotEmpty) {
        final location = locations.first;
        final targetPosition = LatLng(location.latitude, location.longitude);
        await _animateToLocation(query, targetPosition);
      } else {
        _showSearchError(
          'Location "$query" not found. Try a more specific location or address.',
        );
      }
    } catch (e) {
      debugPrint('Geocoding Error: $e');

      String userMessage;
      if (e.toString().contains('Unexpected null value')) {
        userMessage =
            'Search failed: The location could not be resolved. Try a more precise query (e.g., "123 Main St, Cebu").';
      } else {
        userMessage =
            'Search failed due to a system error. Check network connection.';
      }

      _showSearchError(userMessage);
    } finally {
      if (mounted) {
        setState(() {
          _isSearchingLocation = false;
        });
      }
    }
  }

  Future<void> _animateToLocation(String query, LatLng targetPosition) async {
    await _sheetController.animateTo(
      _initialSheetSize,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOut,
    );

    await _mapController!.animateCamera(
      CameraUpdate.newCameraPosition(
        CameraPosition(target: targetPosition, zoom: 12),
      ),
    );

    await _updateCityName(targetPosition);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Showing: ${_formatLocationName(query)}'),
          duration: const Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
          margin: EdgeInsets.only(
            bottom: MediaQuery.of(context).size.height * 0.25 + 20,
            left: 16,
            right: 16,
          ),
        ),
      );
    }
  }

  void _showSearchError(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          duration: const Duration(seconds: 4),
          behavior: SnackBarBehavior.floating,
          margin: EdgeInsets.only(
            bottom: MediaQuery.of(context).size.height * 0.25 + 20,
            left: 16,
            right: 16,
          ),
        ),
      );
    }
  }

  Future<void> _updateCityName(LatLng position) async {
    try {
      final placemarks = await placemarkFromCoordinates(
        position.latitude,
        position.longitude,
      );

      if (placemarks.isNotEmpty) {
        final placemark = placemarks.first;
        final cityName =
            placemark.locality ??
            placemark.subAdministrativeArea ??
            placemark.administrativeArea ??
            'Unknown Location';

        if (mounted) {
          setState(() {
            _currentCityName = cityName;
          });
        }
      }
    } catch (e) {
      debugPrint('Error getting city name: $e');
      if (mounted) {
        setState(() {
          _currentCityName = 'Recent Reports';
        });
      }
    }
  }

  String _formatLocationName(String location) {
    return location
        .split(' ')
        .map(
          (word) => word.isEmpty
              ? ''
              : word[0].toUpperCase() + word.substring(1).toLowerCase(),
        )
        .join(' ');
  }

  DateTime get _mostRecentReportDate {
    if (_reports.isEmpty) {
      return DateTime.now();
    }
    return _reports
        .map((r) => r.timestamp ?? r.createdAt)
        .whereType<DateTime>()
        .reduce((a, b) => a.isAfter(b) ? a : b);
  }

  String get _formattedMostRecentDate {
    final date = _mostRecentReportDate;
    return '${_getMonthAbbreviation(date.month)} ${date.day}, ${date.year}';
  }

  String _getMonthAbbreviation(int month) {
    const months = [
      '',
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
    return months[month];
  }

  void _fitMapToMarkers() {
    if (_validMarkerLocations.isEmpty || _mapController == null) return;

    double minLat = _validMarkerLocations.first.latitude;
    double maxLat = _validMarkerLocations.first.latitude;
    double minLng = _validMarkerLocations.first.longitude;
    double maxLng = _validMarkerLocations.first.longitude;

    for (var loc in _validMarkerLocations) {
      minLat = loc.latitude < minLat ? loc.latitude : minLat;
      maxLat = loc.latitude > maxLat ? loc.latitude : maxLat;
      minLng = loc.longitude < minLng ? loc.longitude : minLng;
      maxLng = loc.longitude > maxLng ? loc.longitude : maxLng;
    }

    final bounds = LatLngBounds(
      southwest: LatLng(minLat, minLng),
      northeast: LatLng(maxLat, maxLng),
    );

    Future.delayed(const Duration(milliseconds: 50), () {
      _mapController!.animateCamera(CameraUpdate.newLatLngBounds(bounds, 50));
    });

    final centerLat = (minLat + maxLat) / 2;
    final centerLng = (minLng + maxLng) / 2;
    _updateCityName(LatLng(centerLat, centerLng));
  }

  LatLng _getInitialMapTarget() {
    if (_validMarkerLocations.isNotEmpty) {
      double totalLat = 0;
      double totalLng = 0;
      for (var location in _validMarkerLocations) {
        totalLat += location.latitude;
        totalLng += location.longitude;
      }
      return LatLng(
        totalLat / _validMarkerLocations.length,
        totalLng / _validMarkerLocations.length,
      );
    }
    return const LatLng(14.5995, 120.9842);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBody: true,
      body: Stack(
        children: [
          Positioned.fill(child: _buildMapArea(context)),
          if (_isLoadingReports)
            Positioned.fill(
              child: Container(
                color: Colors.black26,
                child: const Center(child: CircularProgressIndicator()),
              ),
            ),
          const MapOverlayHeaderWidget(),
          Positioned(
            top: 90,
            left: 16,
            child: ValueListenableBuilder<double>(
              valueListenable: _currentSheetSize,
              builder: (context, sheetSize, child) {
                final shouldHideLegend = sheetSize > _initialSheetSize + 0.1;
                return AnimatedOpacity(
                  opacity: shouldHideLegend ? 0.0 : 1.0,
                  duration: const Duration(milliseconds: 200),
                  child: Visibility(
                    visible: !shouldHideLegend && _floodCircles.isNotEmpty,
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.15),
                            blurRadius: 8,
                            offset: const Offset(0, 4),
                          ),
                        ],
                        border: Border.all(
                          color: Colors.grey.shade300,
                          width: 1,
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const SizedBox(width: 6),
                              Text(
                                'Flood Levels',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.grey.shade800,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          _buildLegendItem(
                            color: const Color(0xFFFBC02D),
                            label: "Low",
                            description: "< 0.5m",
                          ),
                          _buildLegendItem(
                            color: const Color(0xFFF57C00),
                            label: "Medium",
                            description: "0.5m - 0.9m",
                          ),
                          _buildLegendItem(
                            color: const Color(0xFFE64A19),
                            label: "High",
                            description: "> 1.0m",
                          ),
                          if (_usingMockFloodData)
                            Container(
                              margin: const EdgeInsets.only(top: 8),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.blue.shade50,
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(
                                  color: Colors.blue.shade200,
                                  width: 1,
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.info_outline,
                                    size: 12,
                                    color: Colors.blue.shade600,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    'Demo Data',
                                    style: TextStyle(
                                      fontSize: 10,
                                      color: Colors.blue.shade700,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          DraggableReportsSheetWidget(
            sheetController: _sheetController,
            currentSheetSize: _currentSheetSize,
            initialSheetSize: _initialSheetSize,
            maxSheetSize: _maxSheetSize,
            currentCityName: _currentCityName,
            formattedDate: _formattedMostRecentDate,
            searchController: _searchController,
            searchQuery: _searchQuery,
            isSearching: _isSearchingLocation,
            filteredReports: _filteredReports,
            onSearch: () => _searchLocationOnMap(_searchController.text),
            onClear: () => _searchController.clear(),
            onSubmitted: (value) {
              if (value.trim().isNotEmpty) {
                _searchLocationOnMap(value);
              }
            },
            onReportTap: (report) {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => ReportCardWidget(
                    severityColor: _getSeverityColorFromReport(report),
                    report: report,
                    onBack: () {},
                  ),
                ),
              );
            },
            isLoading: false,
            hasError: false,
            usingMockData: _usingMockData,
            onSearchChanged: () {},
          ),
          RescuerBottomBarWidget(
            selectedIndex: _selectedIndex,
            onHomePressed: _navigateToHome,
            onAssignmentsPressed: _navigateToAssignmentsPage,
            onProfilePressed: _navigateToProfilePage,
          ),
        ],
      ),
    );
  }

  Widget _buildLegendItem({
    required Color color,
    required String label,
    required String description,
  }) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 16,
            height: 16,
            decoration: BoxDecoration(
              color: color.withOpacity(0.3),
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: color, width: 2),
            ),
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Colors.black87,
                ),
              ),
              Text(
                description,
                style: TextStyle(fontSize: 10, color: Colors.grey.shade600),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMapArea(BuildContext context) {
    return ValueListenableBuilder<double>(
      valueListenable: _currentSheetSize,
      builder: (context, sheetSize, child) {
        final shouldDisableMap = sheetSize > _initialSheetSize + 0.05;
        final bool isMapScrollable = !shouldDisableMap;

        return MapViewer(
          reports: _reports,
          reportMarkers: _reportMarkers,
          floodCircles: _floodCircles,
          usingMockFloodData: _usingMockFloodData,
          onReportTap: _handleReportMarkerTap,
          initialCameraPosition: CameraPosition(
            target: _getInitialMapTarget(),
            zoom: 14,
          ),
          onMapCreated: (GoogleMapController controller) {
            _mapController = controller;
            debugPrint('[MAP] Map created successfully');

            if (_floodCircles.isNotEmpty) {
              Future.delayed(const Duration(milliseconds: 1000), () {
                debugPrint('[MAP] Centering on flood sensor after delay');
                _centerMapOnFloodSensor();
              });
            }
          },
          disableLocationSelection: true,
          disableTapToPlace: true,
          mapScrollable: isMapScrollable,
          disableSearch: true,
          preventInteraction: shouldDisableMap,
          onLocationSelected: (LatLng p1, String? p2) {},
          enableZoom: true,
          enablePan: true,
          enableRotation: true,
          enableTilt: true,
        );
      },
    );
  }

  void _showReportDetails(ReportData report) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(report.title ?? 'Flood Report'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (report.latitude != null && report.longitude != null) ...[
                Container(
                  height: 200,
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey.shade300, width: 2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: GoogleMap(
                      initialCameraPosition: CameraPosition(
                        target: LatLng(report.latitude!, report.longitude!),
                        zoom: 15,
                      ),
                      markers: {
                        Marker(
                          markerId: MarkerId('report_${report.reportId}'),
                          position: LatLng(report.latitude!, report.longitude!),
                          icon: _getMarkerIcon(report.status),
                          infoWindow: InfoWindow(
                            title: report.title ?? 'Report Location',
                          ),
                        ),
                      },
                      zoomControlsEnabled: false,
                      myLocationButtonEnabled: false,
                      scrollGesturesEnabled: false,
                      rotateGesturesEnabled: false,
                      tiltGesturesEnabled: false,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
              ],
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: _getSeverityColorFromReport(report).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: _getSeverityColorFromReport(report),
                    width: 2,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      _getStatusIcon(report.status),
                      color: _getSeverityColorFromReport(report),
                      size: 16,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      _formatStatus(report.status),
                      style: TextStyle(
                        color: _getSeverityColorFromReport(report),
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              if (report.description != null) ...[
                Text(report.description!, style: const TextStyle(fontSize: 14)),
                const SizedBox(height: 16),
              ],
              _buildDetailRow('Location', report.address ?? 'Unknown location'),
              if (report.floodHeight != null)
                _buildDetailRow(
                  'Flood Height',
                  '${report.floodHeight!.toStringAsFixed(2)} meters',
                ),
              _buildDetailRow(
                'Reported',
                _formatDate(report.createdAt ?? DateTime.now()),
              ),
              if (report.reportedBy != null)
                _buildDetailRow('Reported By', report.reportedBy!),
              if (report.phoneNumber != null)
                _buildDetailRow('Contact', report.phoneNumber!),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
          if (report.latitude != null && report.longitude != null)
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                _mapController?.animateCamera(
                  CameraUpdate.newCameraPosition(
                    CameraPosition(
                      target: LatLng(report.latitude!, report.longitude!),
                      zoom: 16,
                    ),
                  ),
                );
              },
              child: const Text('Show on Map'),
            ),
        ],
      ),
    );
  }

  IconData _getStatusIcon(ReportStatus? status) {
    switch (status) {
      case ReportStatus.newReport:
      case ReportStatus.pending:
        return Icons.report_problem;
      case ReportStatus.inProgress:
        return Icons.sync;
      case ReportStatus.complete:
      case ReportStatus.completed:
      case ReportStatus.resolved:
        return Icons.check_circle;
      default:
        return Icons.info;
    }
  }

  String _formatStatus(ReportStatus? status) {
    switch (status) {
      case ReportStatus.newReport:
        return 'New Report';
      case ReportStatus.pending:
        return 'Pending';
      case ReportStatus.inProgress:
        return 'In Progress';
      case ReportStatus.ongoing:
        return 'Ongoing';
      case ReportStatus.complete:
      case ReportStatus.completed:
        return 'Completed';
      case ReportStatus.resolved:
        return 'Resolved';
      default:
        return 'Unknown';
    }
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year} ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
  }

  Color _getSeverityColorFromReport(ReportData report) {
    if (report.status == ReportStatus.newReport ||
        report.status == ReportStatus.pending) {
      return const Color.fromARGB(255, 164, 27, 17);
    } else if (report.status == ReportStatus.inProgress) {
      return const Color.fromARGB(255, 182, 110, 3);
    } else {
      return const Color.fromARGB(255, 205, 188, 34);
    }
  }

  void _navigateToAssignmentsPage() {
    setState(() => _selectedIndex = 1);
    Navigator.of(context)
        .push(MaterialPageRoute(builder: (context) => const AssignmentsPage()))
        .then((_) {
          if (mounted) {
            setState(() => _selectedIndex = 0);
          }
        });
  }

  void _navigateToProfilePage() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => BlocProvider<HomeBloc>(
          initBloc: (context) =>
              HomeBloc(_apiService, const UnauthenticatedState()),
          child: const ProfilePage(),
        ),
      ),
    );
  }

  void _navigateToHome() async {
    if (_selectedIndex != 0) {
      setState(() => _selectedIndex = 0);
    }

    if (_sheetController.isAttached &&
        _sheetController.size > _initialSheetSize + 0.01) {
      await _sheetController.animateTo(
        _initialSheetSize,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }

    if (_validMarkerLocations.isNotEmpty && _mapController != null) {
      _fitMapToMarkers();
    } else if (_floodCircles.isNotEmpty && _mapController != null) {
      _centerMapOnFloodSensor();
    }
  }
}
