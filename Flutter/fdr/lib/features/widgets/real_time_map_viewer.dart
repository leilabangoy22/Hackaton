import 'dart:math';

import 'package:fdr/features/auth/data/models/crew_location.dart';
import 'package:fdr/features/auth/data/models/rescuer/rescue_personnel_model.dart';
import 'package:fdr/features/auth/data/models/rescuer/rescuer_location.dart';
import 'package:fdr/services/api_service.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_polyline_points/flutter_polyline_points.dart';
import 'package:shared_preferences/shared_preferences.dart';

class MapReportDetails {
  final String title;
  final String description;
  final String status;
  final String locationString;
  final String eta;
  final double distance;

  MapReportDetails({
    required this.title,
    required this.description,
    required this.status,
    required this.locationString,
    this.eta = 'Calculating...',
    this.distance = 0.0,
  });
}

class RealTimeMapViewer extends StatefulWidget {
  static const routeName = '/real_time_map_viewer';

  final LatLng initialLocation;
  final int? assignmentId;
  final String? reportId;
  final String? rescuerId;
  final RescuePersonnel? rescuePersonnel;

  const RealTimeMapViewer({
    super.key,
    required this.initialLocation,
    this.assignmentId,
    this.reportId,
    this.rescuerId,
    this.rescuePersonnel,
  });

  @override
  State<RealTimeMapViewer> createState() => _RealTimeMapViewerState();
}

class _RealTimeMapViewerState extends State<RealTimeMapViewer> {
  final Completer<GoogleMapController> _controller = Completer();
  Set<Marker> _markers = {};
  Set<Polyline> _polylines = {};
  Timer? _fetchTimer;
  Timer? _locationTimer;
  Position? _currentPosition;
  Marker? _currentLocationMarker;
  bool _isTrackingLocation = false;
  int? _currentUserId;
  int? _lastLocationId;

  MapReportDetails? _reportData;
  CrewLocation? _assignedCrew;
  RescuerLocation? _rescuerLocation;
  RescuePersonnel? _rescuePersonnel;
  bool _isLoading = true;
  String? _errorMessage;
  bool _usingMockData = false;

  final ApiService _apiService = ApiService();
  late final PolylinePoints _polylinePoints;

  static const String _googleMapsApiKey =
      'AIzaSyDhzpe1OOiFzO2BHNsiuwAf2M7J6nKmUvI';
  static const double _initialZoom = 15.0;
  static const Duration _locationUpdateInterval = Duration(minutes: 2);
  static const Duration _crewLocationUpdateInterval = Duration(seconds: 10);
  static const Duration _rescuerLocationUpdateInterval = Duration(seconds: 15);
  Timer? _rescuerLocationTimer;
  Position? _lastRescuerPosition;
  bool _isRescuer = false;

  bool get _isWeb => kIsWeb;

  bool get _isMobile {
    if (_isWeb) {
      final mediaQuery = MediaQuery.of(context);
      return mediaQuery.size.width < 768;
    }
    return true;
  }

  bool get _isTablet {
    if (_isWeb) {
      final mediaQuery = MediaQuery.of(context);
      final width = mediaQuery.size.width;
      return width >= 768 && width < 1024;
    }
    return false;
  }

  bool get _isDesktop {
    if (_isWeb) {
      final mediaQuery = MediaQuery.of(context);
      return mediaQuery.size.width >= 1024;
    }
    return false;
  }

  @override
  void initState() {
    super.initState();
    _polylinePoints = PolylinePoints(apiKey: _googleMapsApiKey);
    _initializeData();
    _initializeLocationTracking();

    _fetchTimer = Timer.periodic(_crewLocationUpdateInterval, (timer) {
      _fetchCrewLocations();
    });

    _rescuerLocationTimer = Timer.periodic(_rescuerLocationUpdateInterval, (
      timer,
    ) {
      _updateRescuerLocationIfNeeded();
    });
  }

  @override
  void dispose() {
    _fetchTimer?.cancel();
    _rescuerLocationTimer?.cancel();
    _stopLocationTracking();
    super.dispose();
  }
  // ==================== LOCATION TRACKING ====================

  Future<void> _initializeLocationTracking() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final userId = prefs.getInt('user_id');
      final userRole = prefs.getString('user_role');

      setState(() {
        _currentUserId = userId;
        _isRescuer = userRole == 'Rescuer';
      });

      if (_currentUserId != null) {
        await _checkAndRequestLocationPermission();
        _startLocationTracking();
      }
    } catch (e) {
      debugPrint('Location tracking initialization error: $e');
    }
  }

  Future<void> _updateRescuerLocationIfNeeded() async {
    try {
      if (_isRescuer &&
          widget.rescuerId != null &&
          _currentUserId.toString() == widget.rescuerId) {
        final position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.best,
          timeLimit: const Duration(seconds: 10),
        );

        setState(() {
          _lastRescuerPosition = position;
        });

        await _updateRescuerLocationOnServer(position);

        debugPrint(
          '[DEBUG] Rescuer location updated: ${position.latitude}, ${position.longitude}',
        );
      }
    } catch (e) {
      debugPrint('Rescuer location update error: $e');
    }
  }

  Future<void> _updateRescuerLocationOnServer(Position position) async {
    try {
      if (widget.rescuerId != null) {
        final rescuerId = int.tryParse(widget.rescuerId!);
        if (rescuerId != null) {
          final success = await _apiService.updateRescuerLocationDirect(
            rescuerId,
            position.latitude,
            position.longitude,
          );

          if (success == true && mounted) {
            _showSnackBar('Location shared with dispatch', Colors.blue);
          }
        }
      }
    } catch (e) {
      debugPrint('Rescuer location server update error: $e');
    }
  }

  Future<void> _checkAndRequestLocationPermission() async {
    try {
      LocationPermission permission = await Geolocator.checkPermission();

      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          debugPrint('Location permission denied');
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        debugPrint('Location permission permanently denied');
        return;
      }
    } catch (e) {
      debugPrint('Permission check error: $e');
    }
  }

  void _startLocationTracking() {
    _getCurrentLocation();

    _locationTimer = Timer.periodic(_locationUpdateInterval, (timer) {
      _getCurrentLocation();
    });

    setState(() {
      _isTrackingLocation = true;
    });
  }

  Future<void> _getCurrentLocation() async {
    try {
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.best,
        timeLimit: const Duration(seconds: 10),
      );

      setState(() {
        _currentPosition = position;
      });

      _updateCurrentLocationMarker();
      await _updateUserLocationOnServer(position);
    } catch (e) {
      debugPrint('Location fetch error: $e');

      try {
        final lastPosition = await Geolocator.getLastKnownPosition();
        if (lastPosition != null) {
          setState(() {
            _currentPosition = lastPosition;
          });
          _updateCurrentLocationMarker();
        }
      } catch (fallbackError) {
        debugPrint('Last known position error: $fallbackError');
      }
    }
  }

  void _updateCurrentLocationMarker() {
    if (_currentPosition == null) return;

    final currentLocation = LatLng(
      _currentPosition!.latitude,
      _currentPosition!.longitude,
    );

    setState(() {
      _currentLocationMarker = Marker(
        markerId: const MarkerId('current_user_location'),
        position: currentLocation,
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
        infoWindow: const InfoWindow(
          title: 'Your Current Location',
          snippet: 'Real-time GPS position',
        ),
        zIndex: 3.0,
      );
    });

    _updateAllMapMarkers();
  }

  Future<void> _updateUserLocationOnServer(Position position) async {
    if (_currentUserId == null) return;

    try {
      final locationId = await _createLocationOnServer(
        position.latitude,
        position.longitude,
      );

      if (locationId != null) {
        if (_lastLocationId == locationId) return;

        _lastLocationId = locationId;

        final response = await _apiService.updateUserLocation(
          _currentUserId!,
          locationId,
        );

        if (response != null && mounted) {
          _showSnackBar(
            'Location updated at ${DateTime.now().toString().substring(11, 16)}',
            Colors.green,
          );
        } else if (mounted) {
          _showSnackBar('Failed to update location', Colors.orange);
        }
      }
    } catch (e) {
      debugPrint('Location update error: $e');
      if (mounted) {
        _showSnackBar('Location update error: ${e.toString()}', Colors.red, 4);
      }
    }
  }

  Future<int?> _createLocationOnServer(
    double latitude,
    double longitude,
  ) async {
    try {
      final response = await _apiService.createLocation({
        'location_id': 0,
        'latitude': latitude.toString(),
        'longitude': longitude.toString(),
      });

      if (response != null) {
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
          } else if (response['locationId'] != null) {
            locationId = int.tryParse(response['locationId'].toString());
          }
        }

        return locationId;
      }
      return null;
    } catch (e) {
      debugPrint('Create location error: $e');
      return null;
    }
  }

  Future<void> _stopLocationTracking() async {
    _locationTimer?.cancel();
    _locationTimer = null;

    setState(() {
      _isTrackingLocation = false;
      _currentLocationMarker = null;
    });
  }

  Future<void> _refreshLocationManually() async {
    if (mounted) {
      _showSnackBar('Refreshing your location...', Colors.blue);
    }
    await _getCurrentLocation();
  }

  // ==================== UI HELPERS ====================

  void _showSnackBar(String message, Color color, [int seconds = 2]) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        duration: Duration(seconds: seconds),
        backgroundColor: color,
      ),
    );
  }

  Widget _buildWebDetailsPanel() {
    double panelWidth;
    if (_isDesktop) {
      panelWidth = 450;
    } else if (_isTablet) {
      panelWidth = 380;
    } else {
      panelWidth = 320;
    }

    return Container(
      width: panelWidth,
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.15),
            blurRadius: 20.0,
            spreadRadius: 5.0,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.grey[50],
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(16),
                topRight: Radius.circular(16),
              ),
              border: Border(
                bottom: BorderSide(color: Colors.grey[300]!, width: 1),
              ),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.real_estate_agent,
                  color: Colors.blue,
                  size: 24,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    _usingMockData ? 'Demo Tracking' : 'Live Dispatch',
                    style: TextStyle(
                      fontSize: _isDesktop ? 20 : 18,
                      fontWeight: FontWeight.w700,
                      color: Colors.black87,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, size: 20),
                  onPressed: () => Navigator.of(context).pop(),
                  tooltip: 'Close',
                ),
              ],
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              child: _buildReportDetailsContent(context),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReportDetailsContent(BuildContext context) {
    if (_isLoading) {
      return Center(
        child: Padding(
          padding: EdgeInsets.all(_isMobile ? 12.0 : 16.0),
          child: const CircularProgressIndicator(),
        ),
      );
    }

    if (_reportData == null) {
      return Center(
        child: Padding(
          padding: EdgeInsets.all(_isMobile ? 12.0 : 16.0),
          child: const Text('Failed to load report details'),
        ),
      );
    }

    return Container(
      padding: _isMobile
          ? const EdgeInsets.all(16.0)
          : const EdgeInsets.all(20.0),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          if (_isMobile)
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),

          if (_usingMockData) _buildDemoBadge(),

          _buildErrorBanner(),

          _buildStatusBadge(),

          SizedBox(height: _isMobile ? 12 : 16),

          Text(
            _reportData!.title,
            style: TextStyle(
              fontSize: _isMobile ? 18 : 22,
              fontWeight: FontWeight.w700,
              color: Colors.black87,
              letterSpacing: -0.5,
            ),
          ),

          SizedBox(height: _isMobile ? 12 : 16),

          if (_assignedCrew != null || _rescuerLocation != null) ...[
            Row(
              children: [
                Expanded(
                  child: _buildInfoCard(
                    icon: Icons.access_time_rounded,
                    label: 'ESTIMATED TIME',
                    value: _reportData!.eta,
                    color: _usingMockData ? Colors.orange : Colors.blue,
                  ),
                ),
                SizedBox(width: _isMobile ? 8 : 12),
                Expanded(
                  child: _buildInfoCard(
                    icon: Icons.social_distance_rounded,
                    label: 'DISTANCE',
                    value: '${_reportData!.distance.toStringAsFixed(1)} km',
                    color: _usingMockData ? Colors.orange : Colors.blue,
                  ),
                ),
              ],
            ),
            SizedBox(height: _isMobile ? 12 : 16),
          ],

          if (_assignedCrew != null) ...[
            _buildCrewInfo(),
            SizedBox(height: _isMobile ? 12 : 16),
          ],

          _buildLocationInfo(),

          SizedBox(height: _isMobile ? 12 : 16),

          Text(
            'DESCRIPTION',
            style: TextStyle(
              fontSize: _isMobile ? 11 : 12,
              fontWeight: FontWeight.w600,
              color: Colors.grey,
              letterSpacing: 0.5,
            ),
          ),
          SizedBox(height: _isMobile ? 6 : 8),
          Container(
            width: double.infinity,
            padding: _isMobile
                ? const EdgeInsets.all(12)
                : const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.grey[50],
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey[200]!, width: 1),
            ),
            child: Text(
              _reportData!.description,
              style: TextStyle(
                fontSize: _isMobile ? 13 : 14,
                height: 1.5,
                color: Colors.black87,
              ),
            ),
          ),

          SizedBox(height: _isMobile ? 16 : 20),
        ],
      ),
    );
  }

  Widget _buildDemoBadge() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Colors.orange.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.orange.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.sim_card_alert,
            size: _isMobile ? 12 : 14,
            color: Colors.orange[700],
          ),
          SizedBox(width: _isMobile ? 4 : 6),
          Text(
            'DEMO MODE',
            style: TextStyle(
              fontSize: _isMobile ? 9 : 10,
              fontWeight: FontWeight.w700,
              color: Colors.orange[700],
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: _usingMockData
            ? Colors.orange.withOpacity(0.15)
            : Colors.green.withOpacity(0.15),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: _usingMockData
              ? Colors.orange.withOpacity(0.4)
              : Colors.green.withOpacity(0.4),
          width: 1.5,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: _usingMockData ? Colors.orange : Colors.green,
              shape: BoxShape.circle,
            ),
          ),
          SizedBox(width: _isMobile ? 6 : 8),
          Text(
            _reportData!.status.toUpperCase(),
            style: TextStyle(
              fontSize: _isMobile ? 10 : 11,
              fontWeight: FontWeight.w700,
              color: _usingMockData ? Colors.orange : Colors.green,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCrewInfo() {
    return Container(
      padding: _isMobile ? const EdgeInsets.all(12) : const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[200]!, width: 1),
      ),
      child: Row(
        children: [
          Container(
            padding: _isMobile
                ? const EdgeInsets.all(8)
                : const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: _usingMockData
                  ? Colors.orange.withOpacity(0.1)
                  : Colors.blue.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              Icons.groups_rounded,
              size: _isMobile ? 20 : 24,
              color: _usingMockData ? Colors.orange : Colors.blue,
            ),
          ),
          SizedBox(width: _isMobile ? 10 : 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _usingMockData ? 'DEMO CREW' : 'ASSIGNED CREW',
                  style: TextStyle(
                    fontSize: _isMobile ? 10 : 11,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey,
                    letterSpacing: 0.5,
                  ),
                ),
                SizedBox(height: _isMobile ? 2 : 4),
                Text(
                  _assignedCrew!.name,
                  style: TextStyle(
                    fontSize: _isMobile ? 14 : 16,
                    fontWeight: FontWeight.w700,
                    color: _usingMockData ? Colors.orange : Colors.black87,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLocationInfo() {
    return Container(
      padding: _isMobile ? const EdgeInsets.all(12) : const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[200]!, width: 1),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: _isMobile
                ? const EdgeInsets.all(8)
                : const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.red.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              Icons.location_on_rounded,
              size: _isMobile ? 20 : 24,
              color: Colors.red,
            ),
          ),
          SizedBox(width: _isMobile ? 10 : 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'COORDINATES',
                  style: TextStyle(
                    fontSize: _isMobile ? 10 : 11,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey,
                    letterSpacing: 0.5,
                  ),
                ),
                SizedBox(height: _isMobile ? 2 : 4),
                Text(
                  _reportData!.locationString,
                  style: TextStyle(
                    fontSize: _isMobile ? 12 : 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoCard({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Container(
      padding: _isMobile ? const EdgeInsets.all(12) : const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3), width: 1.5),
      ),
      child: Row(
        children: [
          Container(
            padding: _isMobile
                ? const EdgeInsets.all(6)
                : const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: _isMobile ? 18 : 20, color: color),
          ),
          SizedBox(width: _isMobile ? 10 : 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: _isMobile ? 10 : 11,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey[600],
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: _isMobile ? 14 : 16,
                    fontWeight: FontWeight.w700,
                    color: color,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorBanner() {
    if (_errorMessage == null) return const SizedBox.shrink();

    return Container(
      width: double.infinity,
      padding: _isMobile ? const EdgeInsets.all(10) : const EdgeInsets.all(12),
      margin: _isMobile
          ? const EdgeInsets.only(bottom: 12)
          : const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: _usingMockData
            ? Colors.orange.withOpacity(0.1)
            : Colors.blue.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: _usingMockData
              ? Colors.orange.withOpacity(0.3)
              : Colors.blue.withOpacity(0.3),
        ),
      ),
      child: Row(
        children: [
          Icon(
            _usingMockData ? Icons.warning_amber_rounded : Icons.info_rounded,
            color: _usingMockData ? Colors.orange[700] : Colors.blue[700],
            size: _isMobile ? 18 : 20,
          ),
          SizedBox(width: _isMobile ? 10 : 12),
          Expanded(
            child: Text(
              _errorMessage!,
              style: TextStyle(
                color: _usingMockData ? Colors.orange[800] : Colors.blue[800],
                fontSize: _isMobile ? 11 : 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          IconButton(
            icon: Icon(
              Icons.close,
              color: _usingMockData ? Colors.orange[700] : Colors.blue[700],
              size: _isMobile ? 16 : 18,
            ),
            onPressed: () {
              setState(() {
                _errorMessage = null;
              });
            },
          ),
        ],
      ),
    );
  }

  Widget _buildMobileDetailsSheet() {
    return DraggableScrollableSheet(
      initialChildSize: 0.35,
      minChildSize: 0.2,
      maxChildSize: 0.75,
      builder: (BuildContext context, ScrollController scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: const BorderRadius.vertical(
              top: Radius.circular(20.0),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.15),
                blurRadius: 20.0,
                spreadRadius: 5.0,
                offset: const Offset(0, -2),
              ),
            ],
          ),
          child: SingleChildScrollView(
            controller: scrollController,
            child: _buildReportDetailsContent(context),
          ),
        );
      },
    );
  }

  // ==================== API DATA FETCHING ====================

  Future<void> _fetchRescuerLocation() async {
    try {
      String? reportId = widget.reportId;
      int? rescuerId;

      if (reportId != null && reportId.isNotEmpty) {
        try {
          final reportData = await _apiService.getReportById(
            int.parse(reportId),
          );
          if (reportData != null && reportData.isNotEmpty) {
            final possibleFields = [
              'assigned_to',
              'rescue_personnel_id',
              'rescuer_id',
              'assigned_rescuer_id',
              'personnel_id',
            ];

            for (String field in possibleFields) {
              if (reportData[field] != null) {
                rescuerId = int.tryParse(reportData[field].toString());
                if (rescuerId != null) break;
              }
            }
          }
        } catch (e) {
          debugPrint('Report fetch error: $e');
        }
      }

      if (rescuerId == null && widget.rescuerId != null) {
        rescuerId = int.tryParse(widget.rescuerId!);
      }

      if (rescuerId == null) {
        throw Exception('No rescuer ID available');
      }

      debugPrint('[DEBUG] Fetching rescuer location for ID: $rescuerId');

      final rescuerLocationData = await _apiService.getRescuerLocation(
        rescuerId,
      );

      double? latitudeRescuer;
      double? longitudeRescuer;

      if (rescuerLocationData != null &&
          rescuerLocationData['error'] != 'true') {
        latitudeRescuer = _extractCoordinate(rescuerLocationData, [
          'latitude',
          'lat',
        ]);
        longitudeRescuer = _extractCoordinate(rescuerLocationData, [
          'longitude',
          'lon',
          'lng',
        ]);

        debugPrint(
          '[DEBUG] Found rescuer location from API: ($latitudeRescuer, $longitudeRescuer)',
        );
      }

      if (latitudeRescuer == null || longitudeRescuer == null) {
        debugPrint(
          '[DEBUG] No dedicated rescuer location, checking rescuer profile...',
        );
        final rescuerData = await _apiService.getRescuerById(rescuerId);

        if (rescuerData != null) {
          final possibleLocationFields = [
            'location_id',
            'locationId',
            'current_location_id',
          ];
          int? locationId;

          for (String field in possibleLocationFields) {
            if (rescuerData[field] != null) {
              locationId = int.tryParse(rescuerData[field].toString());
              if (locationId != null) break;
            }
          }

          if (locationId != null) {
            final locationData = await _apiService.getLocationById(locationId);
            if (locationData != null) {
              latitudeRescuer = _extractCoordinate(locationData, [
                'latitude',
                'lat',
              ]);
              longitudeRescuer = _extractCoordinate(locationData, [
                'longitude',
                'lon',
                'lng',
              ]);
              debugPrint(
                '[DEBUG] Found rescuer location from profile: ($latitudeRescuer, $longitudeRescuer)',
              );
            }
          }
        }
      }

      if (latitudeRescuer == null || longitudeRescuer == null) {
        if (_lastRescuerPosition != null) {
          latitudeRescuer = _lastRescuerPosition!.latitude;
          longitudeRescuer = _lastRescuerPosition!.longitude;
          debugPrint('[DEBUG] Using last known rescuer position');
        } else {
          latitudeRescuer = widget.initialLocation.latitude + 0.01;
          longitudeRescuer = widget.initialLocation.longitude + 0.01;
          debugPrint('[DEBUG] Using default rescuer position');
        }
      }

      int? reportLocationId;
      double? latitudeReport;
      double? longitudeReport;

      if (reportId != null) {
        final reportData = await _apiService.getReportById(int.parse(reportId));
        if (reportData != null && reportData['location_id'] != null) {
          reportLocationId = int.tryParse(reportData['location_id'].toString());
        }
      }

      if (reportLocationId != null) {
        final reportLocationData = await _apiService.getLocationById(
          reportLocationId,
        );
        if (reportLocationData != null) {
          latitudeReport = _extractCoordinate(reportLocationData, [
            'latitude',
            'lat',
          ]);
          longitudeReport = _extractCoordinate(reportLocationData, [
            'longitude',
            'lon',
            'lng',
          ]);
        }
      }

      if (latitudeReport == null || longitudeReport == null) {
        latitudeReport = widget.initialLocation.latitude;
        longitudeReport = widget.initialLocation.longitude;
      }

      final rescuerLocation = RescuerLocation(
        latitudeRescuer: latitudeRescuer,
        longitudeRescuer: longitudeRescuer,
        latitudeReport: latitudeReport,
        longitudeReport: longitudeReport,
        distance: _calculateDistance(
          latitudeRescuer,
          longitudeRescuer,
          latitudeReport,
          longitudeReport,
        ),
        timeArrival: _calculateETA(
          latitudeRescuer,
          longitudeRescuer,
          latitudeReport,
          longitudeReport,
        ),
      );

      debugPrint('[DEBUG] RescuerLocation created: $rescuerLocation');

      if (mounted) {
        setState(() {
          _rescuerLocation = rescuerLocation;
          _usingMockData = false;
          _errorMessage = null;
        });
      }
    } catch (e) {
      debugPrint('Rescuer location fetch error: $e');

      final errorMsg = 'Unable to load live tracking data: ${e.toString()}';

      if (mounted) {
        setState(() {
          _errorMessage = errorMsg;
          _usingMockData = true;
        });
      }
    }
  }

  double? _extractCoordinate(Map<String, dynamic> data, List<String> fields) {
    for (String field in fields) {
      if (data[field] != null) {
        final value = double.tryParse(data[field].toString());
        if (value != null) {
          debugPrint('[DEBUG] Found coordinate in $field: $value');
          return value;
        }
      }
    }

    if (data['data'] is Map) {
      final dataMap = data['data'] as Map;
      for (String field in fields) {
        if (dataMap[field] != null) {
          final value = double.tryParse(dataMap[field].toString());
          if (value != null) {
            debugPrint('[DEBUG] Found coordinate in data.$field: $value');
            return value;
          }
        }
      }
    }

    debugPrint('[DEBUG] No coordinate found in fields: $fields');
    debugPrint('[DEBUG] Available keys: ${data.keys}');
    return null;
  }

  double _calculateDistance(
    double lat1,
    double lon1,
    double lat2,
    double lon2,
  ) {
    const double earthRadius = 6371;

    double dLat = _toRadians(lat2 - lat1);
    double dLon = _toRadians(lon2 - lon1);

    double a =
        sin(dLat / 2) * sin(dLat / 2) +
        cos(_toRadians(lat1)) *
            cos(_toRadians(lat2)) *
            sin(dLon / 2) *
            sin(dLon / 2);

    double c = 2 * atan2(sqrt(a), sqrt(1 - a));

    return earthRadius * c;
  }

  double _toRadians(double degrees) {
    return degrees * pi / 180;
  }

  String _calculateETA(double lat1, double lon1, double lat2, double lon2) {
    final distance = _calculateDistance(lat1, lon1, lat2, lon2);
    const averageSpeed = 30.0;
    final timeInHours = distance / averageSpeed;

    if (timeInHours < 1) {
      final minutes = (timeInHours * 60).round();
      return '$minutes mins';
    } else {
      final hours = timeInHours.floor();
      final minutes = ((timeInHours - hours) * 60).round();
      return '${hours}h ${minutes}m';
    }
  }

  Future<void> _updateFromApiData() async {
    try {
      if (_rescuerLocation == null) {
        debugPrint('[DEBUG] _updateFromApiData: _rescuerLocation is null');
        return;
      }

      debugPrint(
        '[DEBUG] _updateFromApiData: Starting with rescuer location: $_rescuerLocation',
      );

      final rescuerName = await _getRescuerNameFromId(widget.rescuerId);
      debugPrint('[DEBUG] _updateFromApiData: Rescuer name: $rescuerName');

      final rescuerCrew = CrewLocation(
        id:
            widget.rescuerId ??
            'api_rescuer_${DateTime.now().millisecondsSinceEpoch}',
        name: rescuerName,
        latitude: _rescuerLocation!.latitudeRescuer,
        longitude: _rescuerLocation!.longitudeRescuer,
        hasAssignment: true,
        isTracking: true,
      );

      debugPrint('[DEBUG] _updateFromApiData: Created crew: $rescuerCrew');

      if (mounted) {
        setState(() {
          _assignedCrew = rescuerCrew;
        });
      }

      final apiReport = MapReportDetails(
        title: 'Emergency Report #${widget.reportId ?? 'N/A'}',
        description:
            _reportData?.description ??
            'Emergency situation requiring immediate response',
        status: 'Rescue Team En Route',
        locationString:
            '${_rescuerLocation!.latitudeReport.toStringAsFixed(6)}, ${_rescuerLocation!.longitudeReport.toStringAsFixed(6)}',
        eta: _rescuerLocation!.timeArrival.isNotEmpty
            ? _formatTimeArrival(_rescuerLocation!.timeArrival)
            : 'Calculating ETA...',
        distance: _rescuerLocation!.distance,
      );

      debugPrint('[DEBUG] _updateFromApiData: Created report: $apiReport');

      if (mounted) {
        setState(() {
          _reportData = apiReport;
        });
      }

      _updateAllMapMarkers();
      await _drawRouteLine(rescuerCrew);

      debugPrint('[DEBUG] _updateFromApiData: Completed successfully');
    } catch (e, stackTrace) {
      debugPrint('[DEBUG] _updateFromApiData error: $e');
      debugPrint('[DEBUG] Stack trace: $stackTrace');

      if (mounted) {
        setState(() {
          _usingMockData = true;
          _errorMessage = 'Live data update failed: ${e.toString()}';
        });
      }
    }
  }

  Future<void> _drawRouteLine(CrewLocation assignedCrew) async {
    LatLng reportTarget = _rescuerLocation != null && !_usingMockData
        ? LatLng(
            _rescuerLocation!.latitudeReport,
            _rescuerLocation!.longitudeReport,
          )
        : widget.initialLocation;

    try {
      final origin = PointLatLng(assignedCrew.latitude, assignedCrew.longitude);
      final destination = PointLatLng(
        reportTarget.latitude,
        reportTarget.longitude,
      );

      debugPrint(
        'Fetching route from ${assignedCrew.latitude},${assignedCrew.longitude} to ${reportTarget.latitude},${reportTarget.longitude}',
      );

      final result = await _polylinePoints.getRouteBetweenCoordinates(
        request: PolylineRequest(
          origin: origin,
          destination: destination,
          mode: TravelMode.driving,
        ),
      );

      debugPrint(
        'Polyline result: ${result.points.length} points, Status: ${result.status}, Error: ${result.errorMessage}',
      );

      if (result.points.isNotEmpty) {
        final List<LatLng> routePoints = result.points.map((point) {
          return LatLng(point.latitude, point.longitude);
        }).toList();

        debugPrint(
          'Successfully created route with ${routePoints.length} points',
        );

        final polyline = Polyline(
          polylineId: PolylineId('route_to_${assignedCrew.id}'),
          points: routePoints,
          color: _usingMockData
              ? Colors.blue.shade700.withOpacity(0.5)
              : Colors.blue.shade700,
          width: 5,
          geodesic: true,
          patterns: [PatternItem.dash(20), PatternItem.gap(10)],
        );

        if (mounted) {
          setState(() {
            _polylines = {polyline};
          });
        }
      } else {
        debugPrint(
          'No route points returned. Status: ${result.status}, Error: ${result.errorMessage}',
        );
        _drawStraightLine(assignedCrew, reportTarget);
      }
    } catch (e) {
      debugPrint('Route drawing error: $e');
      _drawStraightLine(assignedCrew, reportTarget);
    }
  }

  void _drawStraightLine(CrewLocation assignedCrew, LatLng reportTarget) {
    final routePoints = [
      LatLng(assignedCrew.latitude, assignedCrew.longitude),
      reportTarget,
    ];

    final polyline = Polyline(
      polylineId: PolylineId('straight_line_to_${assignedCrew.id}'),
      points: routePoints,
      color: _usingMockData
          ? Colors.blue.shade700.withOpacity(0.3)
          : Colors.blue.shade700.withOpacity(0.6),
      width: 3,
      geodesic: true,
      patterns: [PatternItem.dash(10), PatternItem.gap(5)],
    );

    if (mounted) {
      setState(() {
        _polylines = {polyline};
      });
    }
  }

  Future<void> _centerMapOnMarkers(Set<LatLng> points) async {
    if (points.isEmpty) return;

    final GoogleMapController controller = await _controller.future;

    double minLat = points.first.latitude;
    double maxLat = points.first.latitude;
    double minLon = points.first.longitude;
    double maxLon = points.first.longitude;

    for (var point in points) {
      minLat = min(minLat, point.latitude);
      maxLat = max(maxLat, point.latitude);
      minLon = min(minLon, point.longitude);
      maxLon = max(maxLon, point.longitude);
    }

    final LatLngBounds bounds = LatLngBounds(
      southwest: LatLng(minLat, minLon),
      northeast: LatLng(maxLat, maxLon),
    );

    final double padding = _isMobile ? 80.0 : 100.0;

    controller.animateCamera(CameraUpdate.newLatLngBounds(bounds, padding));
  }

  String _formatTimeArrival(String timeArrival) {
    try {
      if (timeArrival.contains('min') ||
          timeArrival.contains('hour') ||
          timeArrival.contains(':')) {
        return timeArrival;
      }

      final time = DateTime.tryParse(timeArrival);
      if (time != null) {
        final now = DateTime.now();
        final difference = time.difference(now);

        if (difference.inMinutes <= 0) {
          return 'Arrived';
        } else if (difference.inMinutes < 60) {
          return '${difference.inMinutes} mins';
        } else {
          return '${difference.inHours} h ${difference.inMinutes.remainder(60)} mins';
        }
      }

      return timeArrival;
    } catch (e) {
      return timeArrival;
    }
  }

  Future<String> _getRescuerNameFromId(String? rescuerId) async {
    try {
      if (rescuerId == null || rescuerId.isEmpty) {
        debugPrint('[DEBUG] No rescuer ID provided, using default name');
        return 'Rescue Team Unknown';
      }

      final int? parsedId = int.tryParse(rescuerId);
      if (parsedId == null) {
        debugPrint('[DEBUG] Invalid rescuer ID format: $rescuerId');
        return 'Rescue Team $rescuerId';
      }

      debugPrint('[DEBUG] Fetching rescuer details for ID: $parsedId');

      final rescuerData = await _apiService.getRescuerById(parsedId);

      if (rescuerData != null && rescuerData.isNotEmpty) {
        debugPrint('[DEBUG] Rescuer data received: ${rescuerData.keys}');

        String? rescuerName;

        final possibleNameFields = [
          'name',
          'username',
          'full_name',
          'user_name',
        ];
        for (String field in possibleNameFields) {
          if (rescuerData[field] != null &&
              rescuerData[field].toString().isNotEmpty) {
            rescuerName = rescuerData[field].toString();
            debugPrint(
              '[DEBUG] Found rescuer name in field "$field": $rescuerName',
            );
            break;
          }
        }

        if (rescuerName == null && rescuerData['data'] is Map) {
          final dataMap = rescuerData['data'] as Map;
          for (String field in possibleNameFields) {
            if (dataMap[field] != null &&
                dataMap[field].toString().isNotEmpty) {
              rescuerName = dataMap[field].toString();
              debugPrint(
                '[DEBUG] Found rescuer name in data.$field: $rescuerName',
              );
              break;
            }
          }
        }

        if (rescuerName != null) {
          return rescuerName;
        } else {
          debugPrint(
            '[DEBUG] No name field found in rescuer data, using fallback',
          );

          final possibleFallbackFields = [
            'email',
            'user_id',
            'id',
            'mobile_number',
            'phone',
          ];
          for (String field in possibleFallbackFields) {
            if (rescuerData[field] != null &&
                rescuerData[field].toString().isNotEmpty) {
              final fallbackValue = rescuerData[field].toString();
              debugPrint(
                '[DEBUG] Using fallback field "$field": $fallbackValue',
              );
              return 'Rescuer $fallbackValue';
            }
          }

          if (rescuerData['data'] is Map) {
            final dataMap = rescuerData['data'] as Map;
            for (String field in possibleFallbackFields) {
              if (dataMap[field] != null &&
                  dataMap[field].toString().isNotEmpty) {
                final fallbackValue = dataMap[field].toString();
                debugPrint(
                  '[DEBUG] Using fallback field data.$field: $fallbackValue',
                );
                return 'Rescuer $fallbackValue';
              }
            }
          }

          return 'Rescue Team $rescuerId';
        }
      } else {
        debugPrint('[DEBUG] No rescuer data found for ID: $parsedId');
        return 'Rescue Team $rescuerId';
      }
    } catch (e) {
      debugPrint('[DEBUG] Error fetching rescuer name for ID $rescuerId: $e');

      final nameMap = {
        '1': 'Rescue Team Alpha',
        '2': 'Rescue Team Bravo',
        '3': 'Rescue Team Charlie',
        '101': 'Emergency Response Unit 1',
        '102': 'Emergency Response Unit 2',
      };

      return nameMap[rescuerId] ?? 'Rescue Team ${rescuerId ?? 'Unknown'}';
    }
  }

  // ==================== INITIALIZATION ====================

  Future<void> _initializeData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _usingMockData = false;
    });

    try {
      if (widget.rescuePersonnel != null) {
        _rescuePersonnel = widget.rescuePersonnel;
      }

      await _fetchRescuerLocation();

      if (_rescuerLocation != null) {
        await _updateFromApiData();
      }

      await _fetchReportDetails();
    } catch (e) {
      debugPrint('Initialization error: $e');

      _useMockData();

      final friendlyError =
          'Live tracking temporarily unavailable. Showing demonstration data.';
      if (mounted) {
        setState(() {
          _errorMessage = friendlyError;
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _useMockData() {
    if (mounted) {
      setState(() {
        _usingMockData = true;
      });
    }

    final mockReport = MapReportDetails(
      title: 'Emergency Report #${widget.assignmentId ?? 'N/A'}',
      description:
          'Confirmed severe flooding reported by local residents. Road partly blocked and rescue required.',
      status: widget.assignmentId != null
          ? 'Crew Dispatched'
          : 'Pending Assignment',
      locationString:
          '${widget.initialLocation.latitude.toStringAsFixed(6)}, ${widget.initialLocation.longitude.toStringAsFixed(6)}',
      eta: '15 mins',
      distance: 2.8,
    );

    final mockCrews = _getMockCrewData();
    final assignedCrew = _findAssignedCrew(mockCrews);

    if (mounted) {
      setState(() {
        _reportData = mockReport;
        _assignedCrew = assignedCrew;
        _errorMessage ??= 'Using demo data - API unavailable';
      });
      _updateAllMapMarkers();
    }
  }

  List<CrewLocation> _getMockCrewData() {
    return [
      CrewLocation(
        id: 'C101',
        name: 'Rescue Team Alpha',
        latitude: widget.initialLocation.latitude + 0.005,
        longitude: widget.initialLocation.longitude,
        hasAssignment: true,
        isTracking: widget.assignmentId == 101,
      ),
      CrewLocation(
        id: 'C102',
        name: 'Rescue Team Bravo',
        latitude: widget.initialLocation.latitude - 0.008,
        longitude: widget.initialLocation.longitude + 0.003,
        hasAssignment: false,
        isTracking: false,
      ),
      CrewLocation(
        id: 'C103',
        name: 'Rescue Team Charlie',
        latitude: widget.initialLocation.latitude,
        longitude: widget.initialLocation.longitude - 0.005,
        hasAssignment: true,
        isTracking: widget.assignmentId == 103,
      ),
    ];
  }

  CrewLocation? _findAssignedCrew(List<CrewLocation> crews) {
    if (widget.assignmentId == null) return null;

    var assignedCrew = crews.firstWhere(
      (crew) => crew.id == 'C${widget.assignmentId}',
      orElse: () => CrewLocation(
        id: '',
        name: '',
        latitude: 0,
        longitude: 0,
        hasAssignment: false,
        isTracking: false,
      ),
    );

    if (assignedCrew.id.isEmpty) {
      assignedCrew = crews.firstWhere(
        (crew) => !crew.hasAssignment,
        orElse: () => crews.first,
      );
    }

    return assignedCrew.id.isNotEmpty ? assignedCrew : null;
  }

  Future<void> _fetchCrewLocations() async {
    try {
      if (!_usingMockData &&
          (widget.rescuerId != null ||
              widget.reportId != null ||
              _rescuePersonnel != null)) {
        await _fetchRescuerLocation();
        if (_rescuerLocation != null) {
          await _updateFromApiData();
        }
      } else {
        await Future.delayed(const Duration(milliseconds: 300));
        final mockCrews = _getMockCrewData();
        final assignedCrew = _findAssignedCrew(mockCrews);

        if (mounted) {
          setState(() {
            _assignedCrew = assignedCrew;
          });
        }

        _updateAllMapMarkers();

        if (assignedCrew != null && widget.assignmentId != null) {
          await _drawRouteLine(assignedCrew);
        } else {
          if (mounted) {
            setState(() {
              _polylines = {};
            });
          }
        }
      }
    } catch (e) {
      debugPrint('Crew location fetch error: $e');
      if (!_usingMockData) {
        _useMockData();
      }
    }
  }

  Future<void> _fetchReportDetails() async {
    try {
      if (_usingMockData || _reportData == null) {
        await Future.delayed(const Duration(milliseconds: 500));

        final reportData = MapReportDetails(
          title: 'Emergency Report #${widget.assignmentId ?? 'N/A'}',
          description:
              'Confirmed severe flooding reported by local residents. Road partly blocked and rescue required.',
          status: widget.assignmentId != null
              ? 'Crew Dispatched'
              : 'Pending Assignment',
          locationString:
              '${widget.initialLocation.latitude.toStringAsFixed(6)}, ${widget.initialLocation.longitude.toStringAsFixed(6)}',
          eta: _rescuerLocation?.timeArrival.isNotEmpty == true
              ? _formatTimeArrival(_rescuerLocation!.timeArrival)
              : '12 mins',
          distance: _rescuerLocation?.distance ?? 3.2,
        );

        if (mounted) {
          setState(() {
            _reportData = reportData;
          });
        }
      }
    } catch (e) {
      debugPrint('Report details fetch error: $e');
    }
  }

  void _updateAllMapMarkers() {
    final newMarkers = <Marker>{};
    final Set<LatLng> markerPositions = {};

    LatLng reportPosition;
    if (_rescuerLocation != null && !_usingMockData) {
      reportPosition = LatLng(
        _rescuerLocation!.latitudeReport,
        _rescuerLocation!.longitudeReport,
      );
    } else {
      reportPosition = widget.initialLocation;
    }

    newMarkers.add(
      Marker(
        markerId: const MarkerId('report_location'),
        position: reportPosition,
        infoWindow: InfoWindow(
          title: _usingMockData ? 'Emergency Site (Demo)' : 'Emergency Site',
          snippet: 'Reported Location',
        ),
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
      ),
    );
    markerPositions.add(reportPosition);

    if (_currentLocationMarker != null) {
      newMarkers.add(_currentLocationMarker!);
      markerPositions.add(_currentLocationMarker!.position);
    }

    if (_rescuerLocation != null && !_usingMockData) {
      final rescuerPosition = LatLng(
        _rescuerLocation!.latitudeRescuer,
        _rescuerLocation!.longitudeRescuer,
      );

      newMarkers.add(
        Marker(
          markerId: const MarkerId('rescuer_location'),
          position: rescuerPosition,
          infoWindow: InfoWindow(
            title: 'Rescue Team',
            snippet: _isRescuer
                ? 'Your Location (Live)'
                : 'Rescuer Location (Live)',
          ),
          icon: BitmapDescriptor.defaultMarkerWithHue(
            _isRescuer ? BitmapDescriptor.hueGreen : BitmapDescriptor.hueBlue,
          ),
          zIndex: 3.0,
        ),
      );
      markerPositions.add(rescuerPosition);

      debugPrint('[DEBUG] Added rescuer marker at: $rescuerPosition');
    }

    if (mounted) {
      setState(() {
        _markers = newMarkers;
      });

      _centerMapOnMarkers(markerPositions);
    }
  }

  Future<void> _refreshRescuerLocation() async {
    if (mounted) {
      _showSnackBar('Refreshing rescuer location...', Colors.blue);
    }
    await _fetchRescuerLocation();
  }

  // ==================== MAP WIDGETS ====================

  Widget _buildMapWithLocationControls() {
    return Stack(
      children: [
        GoogleMap(
          mapType: MapType.normal,
          initialCameraPosition: CameraPosition(
            target: widget.initialLocation,
            zoom: _initialZoom,
          ),
          onMapCreated: (GoogleMapController controller) {
            _controller.complete(controller);
          },
          markers: _markers,
          polylines: _polylines,
          myLocationEnabled: true,
          myLocationButtonEnabled: true,
          zoomControlsEnabled: false,
          compassEnabled: true,
          mapToolbarEnabled: false,
        ),
        Positioned(
          bottom: 100,
          right: 16,
          child: Column(
            children: [
              if (!_isRescuer && _rescuerLocation != null)
                Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: FloatingActionButton(
                    onPressed: _refreshRescuerLocation,
                    mini: true,
                    backgroundColor: Colors.blue,
                    child: const Icon(
                      Icons.refresh,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                ),
              FloatingActionButton(
                onPressed: _refreshLocationManually,
                mini: true,
                backgroundColor: Colors.white,
                child: const Icon(
                  Icons.my_location,
                  color: Colors.blue,
                  size: 20,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTabletLayout() {
    return Row(
      children: [
        Expanded(flex: 2, child: _buildMapWithLocationControls()),
        SizedBox(width: 400, child: _buildWebDetailsPanel()),
      ],
    );
  }

  Widget _buildDesktopLayout() {
    return Stack(
      children: [
        _buildMapWithLocationControls(),
        Positioned(right: 0, top: 0, bottom: 0, child: _buildWebDetailsPanel()),
      ],
    );
  }

  Widget _buildMobileLayout() {
    return Stack(
      children: [_buildMapWithLocationControls(), _buildMobileDetailsSheet()],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: _isMobile
          ? AppBar(
              title: Text(
                _usingMockData
                    ? 'Demo Dispatch Tracking'
                    : 'Live Dispatch Tracking',
                style: TextStyle(
                  fontSize: _isMobile ? 16 : 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
              backgroundColor: Colors.white.withOpacity(0.95),
              foregroundColor: Colors.black87,
              elevation: 0,
              leading: IconButton(
                icon: Icon(Icons.arrow_back_ios_new, size: _isMobile ? 18 : 20),
                onPressed: () => Navigator.of(context).pop(),
              ),
            )
          : null,
      body: _isWeb
          ? (_isDesktop
                ? _buildDesktopLayout()
                : (_isTablet ? _buildTabletLayout() : _buildMobileLayout()))
          : _buildMobileLayout(),
    );
  }
}
