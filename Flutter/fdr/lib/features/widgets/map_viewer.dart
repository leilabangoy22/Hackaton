
import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:flutter/foundation.dart';
import 'package:geocoding/geocoding.dart';

import '/services/api_service.dart';
import '/features/auth/data/models/report/report_data.dart';

class MapViewer extends StatefulWidget {
  final LatLng? initialLocation;
  final Function(LatLng, String?) onLocationSelected;
  final bool disableSearch;
  final String? addressName;
  final Set<Marker>? reportMarkers;
  final List<ReportData>? reports;
  final CameraPosition? initialCameraPosition;
  final LatLngBounds? fitBounds;
  final bool preventInteraction;
  final Function(GoogleMapController controller) onMapCreated;
  final bool disableLocationSelection;
  final bool disableTapToPlace;
  final bool mapScrollable;
  final Set<Circle>? floodCircles;
  final bool usingMockFloodData;
  final Function(ReportData)? onReportTap;
  final List<Map<String, dynamic>>? highRiskAreas;
  final Map<String, dynamic>? safestArea;
  final String? currentUserId;

  const MapViewer({
    super.key,
    this.initialLocation,
    required this.onLocationSelected,
    this.disableSearch = false,
    this.addressName = '',
    this.reportMarkers,
    this.reports,
    this.initialCameraPosition,
    this.fitBounds,
    this.preventInteraction = false,
    this.mapScrollable = true,
    required this.onMapCreated,
    required this.disableLocationSelection,
    required this.disableTapToPlace,
    this.floodCircles,
    this.usingMockFloodData = false,
    this.onReportTap,
    this.highRiskAreas,
    this.safestArea,
    this.currentUserId,
    required bool enableZoom,
    required bool enablePan,
    required bool enableRotation,
    required bool enableTilt,
  });

  @override
  State<MapViewer> createState() => _MapViewerState();
}

class _MapViewerState extends State<MapViewer> {
  GoogleMapController? _mapController;
  final ApiService _api = ApiService();

  LatLng? _selectedLocation;
  String? _selectedAddressName;

  final TextEditingController _searchController =
      TextEditingController();

  Timer? _searchDebounce;
  List<Map<String, dynamic>> _searchResults = [];
  bool _isSearching = false;

  final Set<Marker> _markers = {};
  final Set<Circle> _circles = {};

  BitmapDescriptor? _reportDotIcon;

  String _errorMessage = '';
  bool _isLoadingLocation = false;
  List<dynamic> _sensors = [];
  bool _isLoadingSensors = false;
  bool _usingMockData = false;
  bool _markerWasTapped = false;

  @override
  void initState() {
    super.initState();

    if (!widget.disableLocationSelection) {
      _selectedLocation = widget.initialLocation;
      _selectedAddressName = widget.addressName;

      if (_selectedLocation != null) {
        _updateMarker(
          _selectedLocation!,
          _selectedAddressName,
        );
      }
    }

    _initializeFloodCircles();
    _initializeAIRiskMarkers();
    _loadReportDotIcon();
  }

  Future<void> _loadReportDotIcon() async {
    const double size = 48;

    final recorder = ui.PictureRecorder();
    final canvas = ui.Canvas(recorder);
    const center = ui.Offset(size / 2, size / 2);

    canvas.drawCircle(
      center,
      12,
      ui.Paint()..color = Colors.white,
    );

    canvas.drawCircle(
      center,
      9,
      ui.Paint()..color = Colors.red,
    );

    final picture = recorder.endRecording();
    final image = await picture.toImage(
      size.toInt(),
      size.toInt(),
    );

    final byteData = await image.toByteData(
      format: ui.ImageByteFormat.png,
    );

    image.dispose();

    if (byteData == null || !mounted) return;

    setState(() {
      _reportDotIcon = BitmapDescriptor.fromBytes(
        byteData.buffer.asUint8List(),
      );

      _initializeReportMarkers();
    });
  }

  void _initializeFloodCircles() {
    if (widget.floodCircles != null &&
        widget.floodCircles!.isNotEmpty) {
      _circles
        ..clear()
        ..addAll(widget.floodCircles!);

      _usingMockData = widget.usingMockFloodData;
    }
  }

  bool _isCurrentUserReport(ReportData report) {
    final currentId = widget.currentUserId?.trim();
    final reporter = report.reportedBy?.trim();

    if (currentId == null ||
        currentId.isEmpty ||
        reporter == null ||
        reporter.isEmpty) {
      return false;
    }

    return reporter.toLowerCase() == currentId.toLowerCase();
  }

  void _initializeReportMarkers() {
    _markers.removeWhere(
      (marker) => marker.markerId.value.startsWith('report_'),
    );

    if (_reportDotIcon == null) return;

    if (widget.reports != null) {
      _markers.addAll(
        _generateMarkersFromReports(widget.reports!),
      );
      return;
    }

    // Without report data, the current user's report
    // cannot be identified. Use the supplied markers as-is.
    if (widget.reportMarkers != null) {
      _markers.addAll(widget.reportMarkers!);
    }
  }

  double? _readCoordinate(dynamic value) {
    if (value is num) return value.toDouble();

    if (value is String) {
      return double.tryParse(value);
    }

    return null;
  }

  Marker? _createAIRiskMarker(
    Map<String, dynamic> area, {
    required String markerId,
    required String title,
    required double hue,
  }) {
    final latitude = _readCoordinate(area['latitude']);
    final longitude = _readCoordinate(area['longitude']);

    if (latitude == null ||
        longitude == null ||
        latitude < -90 ||
        latitude > 90 ||
        longitude < -180 ||
        longitude > 180) {
      debugPrint('[AI MAP] Invalid coordinates: $area');
      return null;
    }

    return Marker(
      markerId: MarkerId(markerId),
      position: LatLng(latitude, longitude),
      icon: BitmapDescriptor.defaultMarkerWithHue(hue),
      infoWindow: InfoWindow(
        title: title,
        snippet:
            'Grid: ${area['grid_id'] ?? 'Unknown'}'
            ' | Risk Score: ${area['risk_score'] ?? 'N/A'}',
      ),
    );
  }

  void _initializeAIRiskMarkers() {
    _markers.removeWhere(
      (marker) =>
          marker.markerId.value.startsWith('ai_high_risk_') ||
          marker.markerId.value == 'ai_safest_area',
    );

    for (final area in widget.highRiskAreas ?? []) {
      final gridId = area['grid_id']?.toString() ?? 'unknown';

      final marker = _createAIRiskMarker(
        area,
        markerId: 'ai_high_risk_$gridId',
        title: 'High Risk Area !',
        hue: BitmapDescriptor.hueRed,
      );

      if (marker != null) {
        _markers.add(marker);
      }
    }

    final safest = widget.safestArea;

    if (safest != null) {
      final marker = _createAIRiskMarker(
        safest,
        markerId: 'ai_safest_area',
        title: 'Safest Area !',
        hue: BitmapDescriptor.hueGreen,
      );

      if (marker != null) {
        _markers.add(marker);
      }
    }
  }

  Set<Marker> _generateMarkersFromReports(
    List<ReportData> reports,
  ) {
    final markers = <Marker>{};
    final usedIds = <String>{};

    for (final report in reports) {
      final location = report.locationLatLng;

      if (location == null) continue;

      final reportId = 'report_${report.reportId}';

      if (!usedIds.add(reportId)) continue;

      final isCurrentUser = _isCurrentUserReport(report);

      markers.add(
        Marker(
          markerId: MarkerId(reportId),
          position: location,

          // Current user's report: red pin.
          // Other users' reports: red dot.
          icon: isCurrentUser
              ? BitmapDescriptor.defaultMarkerWithHue(
                  BitmapDescriptor.hueRed,
                )
              : _reportDotIcon!,

          // Center the dot on the report coordinates.
          anchor: isCurrentUser
              ? const Offset(0.5, 1.0)
              : const Offset(0.5, 0.5),

          infoWindow: InfoWindow(
            title: report.title ?? 'Flood Report',
            snippet: _getReportSnippet(report),
          ),

          onTap: () {
            _markerWasTapped = true;
            _handleReportMarkerTap(report);

            Future.delayed(
              const Duration(milliseconds: 100),
              () {
                if (mounted) {
                  _markerWasTapped = false;
                }
              },
            );
          },
        ),
      );
    }

    return markers;
  }

  String _getReportSnippet(ReportData report) {
    final parts = <String>[];

    if (report.floodHeight != null) {
      parts.add(
        'Height: ${report.floodHeight!.toStringAsFixed(1)}m',
      );
    }

    if (report.severity != null) {
      parts.add(
        'Severity: ${_formatSeverity(report.severity!)}',
      );
    }

    if (report.status != null) {
      parts.add(
        'Status: ${_formatStatus(report.status!)}',
      );
    }

    return parts.isNotEmpty
        ? parts.join(' • ')
        : 'Tap for details';
  }

  String _formatSeverity(FloodSeverity severity) {
    switch (severity) {
      case FloodSeverity.low:
        return 'Low';
      case FloodSeverity.moderate:
        return 'Moderate';
      case FloodSeverity.high:
        return 'High';
    }
  }

  String _formatStatus(ReportStatus status) {
    switch (status) {
      case ReportStatus.newReport:
        return 'New';
      case ReportStatus.pending:
        return 'Pending';
      case ReportStatus.assigned:
        return 'Assigned';
      case ReportStatus.inProgress:
      case ReportStatus.ongoing:
        return 'In Progress';
      case ReportStatus.complete:
      case ReportStatus.completed:
        return 'Completed';
      case ReportStatus.resolved:
        return 'Resolved';
      case ReportStatus.confirmed:
        return 'Confirmed';
    }
  }

  void _handleReportMarkerTap(ReportData report) {
    widget.onReportTap?.call(report);
    _showReportInfoDialog(report);
  }

  String _getReportLocation(ReportData report) {
    if (report.address != null &&
        report.address!.trim().isNotEmpty) {
      return report.address!;
    }

    final location = report.locationLatLng;

    if (location != null) {
      return '${location.latitude}, ${location.longitude}';
    }

    return 'Unknown location';
  }

  void _showReportInfoDialog(ReportData report) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(report.title ?? 'Flood Report'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (report.description != null &&
                  report.description!.trim().isNotEmpty) ...[
                Text(report.description!),
                const SizedBox(height: 12),
              ],
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _buildStatusIndicator(report.status),
                  _buildSeverityIndicator(report.severity),
                ],
              ),
              const SizedBox(height: 12),
              _buildDetailRow(
                'Flood Height',
                report.floodHeight != null
                    ? '${report.floodHeight!.toStringAsFixed(2)} meters'
                    : 'Not specified',
              ),
              _buildDetailRow(
                'Location',
                _getReportLocation(report),
              ),
              _buildDetailRow(
                'Coordinates',
                report.locationLatLng != null
                    ? '${report.locationLatLng!.latitude}, '
                        '${report.locationLatLng!.longitude}'
                    : 'Not available',
              ),
              _buildDetailRow(
                'Reported',
                _formatDate(report.createdAt),
              ),
              if (report.reportedBy != null &&
                  report.reportedBy!.trim().isNotEmpty)
                _buildDetailRow(
                  'Reported By',
                  report.reportedBy!,
                ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
          if (widget.onReportTap != null)
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                widget.onReportTap!(report);
              },
              child: const Text('View Details'),
            ),
        ],
      ),
    );
  }

  Widget _buildStatusIndicator(ReportStatus? status) {
    late Color color;
    late String text;

    switch (status) {
      case ReportStatus.newReport:
      case ReportStatus.pending:
        color = Colors.red;
        text = 'Pending';
        break;
      case ReportStatus.inProgress:
      case ReportStatus.ongoing:
        color = Colors.orange;
        text = 'In Progress';
        break;
      case ReportStatus.complete:
      case ReportStatus.completed:
      case ReportStatus.resolved:
        color = Colors.green;
        text = 'Resolved';
        break;
      case ReportStatus.assigned:
        color = Colors.blue;
        text = 'Assigned';
        break;
      case ReportStatus.confirmed:
        color = Colors.red;
        text = 'Confirmed';
        break;
      default:
        color = Colors.grey;
        text = 'Unknown';
    }

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 8,
        vertical: 4,
      ),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildSeverityIndicator(FloodSeverity? severity) {
    late Color color;
    late String text;

    switch (severity) {
      case FloodSeverity.low:
        color = Colors.green;
        text = 'Low';
        break;
      case FloodSeverity.moderate:
        color = Colors.orange;
        text = 'Moderate';
        break;
      case FloodSeverity.high:
        color = Colors.red;
        text = 'High';
        break;
      default:
        color = Colors.grey;
        text = 'Unknown';
    }

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 8,
        vertical: 4,
      ),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.bold,
        ),
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
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime? date) {
    if (date == null) return 'Unknown';

    return '${date.day}/${date.month}/${date.year} '
        '${date.hour}:${date.minute.toString().padLeft(2, '0')}';
  }

  @override
  void didUpdateWidget(covariant MapViewer oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (widget.reports != oldWidget.reports ||
        widget.reportMarkers != oldWidget.reportMarkers ||
        widget.currentUserId != oldWidget.currentUserId) {
      _initializeReportMarkers();
    }

    if (widget.highRiskAreas != oldWidget.highRiskAreas ||
        widget.safestArea != oldWidget.safestArea) {
      _initializeAIRiskMarkers();
    }

    if (widget.floodCircles != oldWidget.floodCircles) {
      _circles
        ..clear()
        ..addAll(widget.floodCircles ?? {});

      _usingMockData = widget.usingMockFloodData;
    }
  }

  void _onSearchChanged(String query) {
    _searchDebounce?.cancel();

    setState(() {
      _errorMessage = '';
      _searchResults.clear();
    });

    if (query.trim().isEmpty) {
      setState(() => _isSearching = false);
      return;
    }

    _searchDebounce = Timer(
      const Duration(milliseconds: 500),
      () {
        if (mounted) _searchPlaces(query);
      },
    );
  }

  dynamic _decodeResponse(dynamic response) {
    return response is String ? jsonDecode(response) : response;
  }

  dynamic _extractRawResults(dynamic response) {
    dynamic decoded = _decodeResponse(response);

    if (decoded is List) return decoded;
    if (decoded is! Map) return null;

    dynamic results = decoded['results'] ??
        decoded['data'] ??
        decoded['places'] ??
        decoded['predictions'];

    if (results is String) {
      results = _decodeResponse(results);
    }

    if (results is Map) {
      results = results['results'] ??
          results['data'] ??
          results['places'] ??
          results['predictions'];
    }

    return results;
  }

  Map<String, dynamic>? _convertPlace(dynamic item) {
    if (item is! Map) return null;

    final geometry = item['geometry'];
    final geometryLocation =
        geometry is Map ? geometry['location'] : null;

    dynamic location = item['location'];

    if (location is String) {
      try {
        location = jsonDecode(location);
      } catch (_) {
        location = null;
      }
    }

    final coordinates = item['coordinates'];

    dynamic latitudeValue;
    dynamic longitudeValue;

    if (geometryLocation is Map) {
      latitudeValue =
          geometryLocation['lat'] ?? geometryLocation['latitude'];

      longitudeValue = geometryLocation['lng'] ??
          geometryLocation['lon'] ??
          geometryLocation['longitude'];
    }

    latitudeValue ??= item['latitude'] ??
        item['lat'] ??
        (location is Map
            ? location['latitude'] ?? location['lat']
            : null) ??
        (coordinates is Map
            ? coordinates['latitude'] ?? coordinates['lat']
            : null);

    longitudeValue ??= item['longitude'] ??
        item['lng'] ??
        item['lon'] ??
        (location is Map
            ? location['longitude'] ??
                location['lng'] ??
                location['lon']
            : null) ??
        (coordinates is Map
            ? coordinates['longitude'] ??
                coordinates['lng'] ??
                coordinates['lon']
            : null);

    if (coordinates is List && coordinates.length >= 2) {
      longitudeValue ??= coordinates[0];
      latitudeValue ??= coordinates[1];
    }

    final latitude = _readCoordinate(latitudeValue);
    final longitude = _readCoordinate(longitudeValue);

    final nameValue = item['name'] ??
        item['formatted_address'] ??
        item['display_name'] ??
        item['description'] ??
        item['address'] ??
        item['place_name'];

    if (latitude == null ||
        longitude == null ||
        nameValue == null ||
        latitude < -90 ||
        latitude > 90 ||
        longitude < -180 ||
        longitude > 180) {
      return null;
    }

    return {
      'name': nameValue.toString(),
      'latitude': latitude,
      'longitude': longitude,
    };
  }

  Future<void> _searchPlaces(String query) async {
    final searchText = query.trim();

    if (searchText.isEmpty || widget.disableLocationSelection) {
      if (!mounted) return;

      setState(() {
        _searchResults.clear();
        _errorMessage = '';
        _isSearching = false;
      });

      return;
    }

    setState(() {
      _isSearching = true;
      _searchResults.clear();
      _errorMessage = '';
    });

    try {
      final response = await _api.searchPlace(searchText);
      final rawResults = _extractRawResults(response);

      if (rawResults is! List) {
        throw Exception('The API did not return a list of places.');
      }

      final places = <Map<String, dynamic>>[];

      for (final item in rawResults) {
        final place = _convertPlace(item);
        if (place != null) places.add(place);
      }

      if (!mounted) return;

      setState(() {
        _searchResults = places;

        if (places.isEmpty) {
          _errorMessage =
              'No usable places found. Try another search.';
        }
      });
    } catch (e) {
      debugPrint('[MAPVIEWER] Search error: $e');

      if (!mounted) return;

      setState(() {
        _searchResults.clear();
        _errorMessage =
            'Could not search for this place. Please try again.';
      });
    } finally {
      if (mounted) {
        setState(() => _isSearching = false);
      }
    }
  }

  Future<void> _goToSearchedLocation(
    Map<String, dynamic> place,
  ) async {
    final lat = (place['latitude'] as num).toDouble();
    final lng = (place['longitude'] as num).toDouble();

    final position = LatLng(lat, lng);
    final name = place['name']?.toString();

    await _mapController?.animateCamera(
      CameraUpdate.newLatLngZoom(position, 16),
    );

    if (!mounted) return;

    _updateSelectedLocation(position, name);

    setState(() {
      _searchResults.clear();
      _searchController.clear();
      _errorMessage = '';
      _isSearching = false;
    });
  }

  void _clearSearch() {
    _searchDebounce?.cancel();
    _searchController.clear();

    setState(() {
      _searchResults.clear();
      _errorMessage = '';
      _isSearching = false;
    });
  }

  Future<String?> _reverseGeocode(LatLng location) async {
    try {
      final placemarks = await placemarkFromCoordinates(
        location.latitude,
        location.longitude,
      );

      if (placemarks.isNotEmpty) {
        final p = placemarks.first;

        return [p.street, p.locality, p.country]
            .where((e) => e != null && e.isNotEmpty)
            .join(', ');
      }

      return null;
    } catch (e) {
      debugPrint('[MAPVIEWER] Reverse geocoding error: $e');
      return null;
    }
  }

  void _handleMapTap(LatLng tappedPoint) async {
    if (widget.preventInteraction || widget.disableTapToPlace) {
      return;
    }

    if (_markerWasTapped) {
      _markerWasTapped = false;
      return;
    }

    final name = await _reverseGeocode(tappedPoint);

    if (!mounted) return;

    _updateSelectedLocation(tappedPoint, name);
  }

  void _updateSelectedLocation(
    LatLng location,
    String? name,
  ) {
    if (widget.disableLocationSelection) return;

    setState(() {
      _selectedLocation = location;
      _selectedAddressName = name;

      _updateMarker(location, name);
    });

    widget.onLocationSelected(location, name);
  }

  void _updateMarker(LatLng location, String? name) {
    _markers.removeWhere(
      (marker) => marker.markerId.value == 'selected_location',
    );

    _markers.add(
      Marker(
        markerId: const MarkerId('selected_location'),
        position: location,
        icon: BitmapDescriptor.defaultMarkerWithHue(
          BitmapDescriptor.hueAzure,
        ),
        infoWindow: InfoWindow(
          title: 'Selected Location',
          snippet: name,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentMarkers = Set<Marker>.of(_markers);
    final circlesToRender = widget.floodCircles ?? _circles;

    return Column(
      children: [
        if (!widget.disableSearch)
          Padding(
            padding: const EdgeInsets.all(8),
            child: TextField(
              controller: _searchController,
              onChanged: _onSearchChanged,
              onSubmitted: (query) {
                _searchDebounce?.cancel();
                _searchPlaces(query);
              },
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.search),
                hintText: 'Search city or place...',
                border: const OutlineInputBorder(),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: _clearSearch,
                      )
                    : null,
              ),
            ),
          ),
        if (_isSearching)
          const Padding(
            padding: EdgeInsets.all(8),
            child: CircularProgressIndicator(),
          ),
        if (_errorMessage.isNotEmpty)
          Padding(
            padding: const EdgeInsets.all(8),
            child: Text(
              _errorMessage,
              style: const TextStyle(color: Colors.red),
              textAlign: TextAlign.center,
            ),
          ),
        if (_searchResults.isNotEmpty)
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 200),
            child: Material(
              elevation: 4,
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: _searchResults.length,
                itemBuilder: (_, index) {
                  final item = _searchResults[index];

                  return ListTile(
                    leading: const Icon(Icons.location_on),
                    title: Text(
                      item['name']?.toString() ?? 'Unnamed place',
                    ),
                    onTap: () => _goToSearchedLocation(item),
                  );
                },
              ),
            ),
          ),
        Expanded(
          child: GoogleMap(
            onMapCreated: (controller) {
              _mapController = controller;
              widget.onMapCreated(controller);

              if (widget.fitBounds != null) {
                controller.animateCamera(
                  CameraUpdate.newLatLngBounds(
                    widget.fitBounds!,
                    50,
                  ),
                );
              }
            },
            markers: currentMarkers,
            circles: circlesToRender,
            onTap: _handleMapTap,
            scrollGesturesEnabled: widget.mapScrollable,
            zoomGesturesEnabled: true,
            rotateGesturesEnabled: true,
            tiltGesturesEnabled: true,
            initialCameraPosition:
                widget.initialCameraPosition ??
                    CameraPosition(
                      target: widget.initialLocation ??
                          const LatLng(10.3157, 123.8854),
                      zoom: 12,
                    ),
            myLocationButtonEnabled: true,
            myLocationEnabled: true,
            mapType: MapType.normal,
            buildingsEnabled: false,
            trafficEnabled: false,
          ),
        ),
      ],
    );
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchController.dispose();
    _mapController?.dispose();
    super.dispose();
  }
}
