import 'dart:io';

import 'package:dio/dio.dart';
import 'package:fdr/features/auth/data/models/report/report_data.dart';
import 'package:fdr/features/auth/user/presentation/report_detail/report_detail_page.dart';
import 'package:fdr/features/widgets/map_viewer.dart';
import 'package:fdr/services/api_service.dart';
import 'package:fdr/services/storage_service.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:geocoding/geocoding.dart';

class ReportFloodPage extends StatelessWidget {
  static const routeName = '/report_flood_page';

  const ReportFloodPage({super.key});

  @override
  Widget build(BuildContext context) {
    final primaryColor = Theme.of(context).colorScheme.primary;

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: Colors.white,
        appBar: PreferredSize(
          preferredSize: const Size.fromHeight(100.0),
          child: AppBar(
            automaticallyImplyLeading: false,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_ios, color: Colors.black),
              onPressed: () => Navigator.of(context).pop(),
            ),
            backgroundColor: Colors.white,
            elevation: 0,
            flexibleSpace: Column(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TabBar(
                  tabs: const [
                    Tab(text: 'Report'),
                    Tab(text: 'My Reports'),
                  ],
                  indicatorSize: TabBarIndicatorSize.label,
                  indicatorWeight: 3,
                  indicatorColor: primaryColor,
                  labelColor: primaryColor,
                  unselectedLabelColor: Colors.grey,
                  labelStyle: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ],
            ),
          ),
        ),
        body: const TabBarView(children: [ReportForm(), _ReportHistory()]),
      ),
    );
  }
}

class ReportForm extends StatefulWidget {
  const ReportForm({super.key});

  @override
  State<ReportForm> createState() => _ReportFormState();
}

class _ReportFormState extends State<ReportForm> {
  LatLng? _selectedLocation;
  String _locationDisplay = 'Tap map or use button to set location';
  int? _locationId;
  String? _selectedAddress;

  final _titleController = TextEditingController();
  final _floodHeightController = TextEditingController();
  final _explanationController = TextEditingController();

  String _userId = '';
  String _userPhoneNumber = '';
  String _userName = '';
  bool _isLoggedIn = false;

  final LatLng _initialCenter = const LatLng(7.0731, 125.6128);
  bool _isLoadingLocation = false;
  bool _isSubmitting = false;
  bool _isLoadingUserData = false;
  final ApiService _apiService = ApiService();
  final StorageService _storageService = StorageService();

  final Map<int, Map<String, dynamic>> _locationCache = {};

  static const String _keyIsLoggedIn = 'is_logged_in';
  static const String _keyAuthToken = 'auth_token';
  static const String _keyUserId = 'user_id';
  static const String _keyUserName = 'user_name';
  static const String _keyUserMobile = 'user_mobile';

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<bool> _checkSharedPreferencesAuth() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      final isLoggedIn = prefs.getBool(_keyIsLoggedIn) ?? false;
      final token = prefs.getString(_keyAuthToken);
      final userId = prefs.getInt(_keyUserId);

      debugPrint('[ReportForm] SharedPreferences check:');
      debugPrint('  - isLoggedIn: $isLoggedIn');
      debugPrint('  - token: ${token != null ? 'present' : 'null'}');
      debugPrint('  - userId: $userId');

      return isLoggedIn && userId != null;
    } catch (e) {
      debugPrint('[ReportForm] Error checking SharedPreferences: $e');
      return false;
    }
  }

  Future<void> _loadUserData() async {
    if (!mounted) return;

    setState(() {
      _isLoadingUserData = true;
    });

    try {
      _isLoggedIn = await _checkSharedPreferencesAuth();

      if (_isLoggedIn) {
        final prefs = await SharedPreferences.getInstance();
        _userId = prefs.getInt(_keyUserId)?.toString() ?? '';
        _userPhoneNumber = prefs.getString(_keyUserMobile) ?? '';
        _userName = prefs.getString(_keyUserName) ?? '';

        debugPrint(
          '[ReportForm] Loaded user data: isLoggedIn=$_isLoggedIn, userId=$_userId, phone=$_userPhoneNumber, name=$_userName',
        );

        if (_userId.isEmpty || _userName.isEmpty) {
          await _fetchUserDataFromApi();
        }
      } else {
        debugPrint('[ReportForm] User is not logged in');
      }

      if (!_isLoggedIn || _userId.isEmpty) {
        if (mounted) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Please log in to submit a report'),
                backgroundColor: Colors.orange,
              ),
            );
          });
        }
      }
    } catch (e) {
      debugPrint('[ReportForm] Error loading user data: $e');
      if (mounted) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Error loading user information'),
              backgroundColor: Colors.red,
            ),
          );
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingUserData = false;
        });
      }
    }
  }

  Future<void> _fetchUserDataFromApi() async {
    try {
      debugPrint('[ReportForm] Fetching user data from API...');
      final allUsersResponse = await _apiService.getAllUsers();
      final prefs = await SharedPreferences.getInstance();
      final currentUserName = prefs.getString(_keyUserName) ?? '';

      if (currentUserName.isNotEmpty) {
        final userData = _findUserInList(allUsersResponse, currentUserName);

        _userId = (userData['user_id'] ?? userData['id'] ?? '').toString();
        _userName = userData['name'] ?? userData['username'] ?? currentUserName;
        _userPhoneNumber = userData['mobile_number']?.toString() ?? '';

        debugPrint(
          '[ReportForm] Fetched from API: userId=$_userId, name=$_userName, phone=$_userPhoneNumber',
        );

        await _storageService.saveUserData(
          userId: int.tryParse(_userId) ?? 0,
          userName: _userName,
          userEmail: userData['email'] ?? '${_userName}@example.com',
          userRole: userData['role']?.toString() ?? 'user',
          mobileNumber: _userPhoneNumber,
          token: 'dummy_token',
        );

        setState(() {});
      }
    } catch (e) {
      debugPrint('[ReportForm] Error fetching user data from API: $e');
    }
  }

  Map<String, dynamic> _findUserInList(dynamic usersResponse, String username) {
    debugPrint('Users List Response: $usersResponse');

    if (usersResponse is Map) {
      final usersData = usersResponse['data'] ?? usersResponse;

      if (usersData is List) {
        for (final user in usersData) {
          if (user is Map) {
            final userName = user['name'] ?? user['username'] ?? user['email'];
            if (userName?.toString().toLowerCase() == username.toLowerCase()) {
              debugPrint('Found matching user: $user');
              return user.cast<String, dynamic>();
            }
          }
        }
      }
    }

    throw Exception('User not found in users list');
  }

  @override
  void dispose() {
    _titleController.dispose();
    _floodHeightController.dispose();
    _explanationController.dispose();
    super.dispose();
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
          final double? lng =
              _parseDouble(locationData['longitude']) ??
              _parseDouble(locationData['longitude']);

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

  Widget _buildCustomTextField({
    required TextEditingController controller,
    required String hint,
    int maxLines = 1,
    TextInputType keyboardType = TextInputType.text,
    bool required = false,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              hint.split('(').first.trim(),
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Colors.grey.shade700,
              ),
            ),
            if (required)
              Text(
                ' *',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.red.shade600,
                ),
              ),
          ],
        ),
        const SizedBox(height: 4),
        TextField(
          controller: controller,
          maxLines: maxLines,
          keyboardType: keyboardType,
          style: const TextStyle(fontSize: 16, color: Colors.black87),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(color: Colors.grey[400]),
            contentPadding: const EdgeInsets.symmetric(vertical: 8),
            isDense: true,
            filled: false,
            enabledBorder: UnderlineInputBorder(
              borderSide: BorderSide(color: Colors.grey.shade300, width: 1),
            ),
            focusedBorder: UnderlineInputBorder(
              borderSide: BorderSide(
                color: Theme.of(context).colorScheme.primary,
                width: 2,
              ),
            ),
          ),
        ),
      ],
    );
  }

  void _handleLocationSelected(LatLng location, String? name) {
    if (!mounted) return;

    setState(() {
      _selectedLocation = location;
      _selectedAddress = name;
      _locationDisplay =
          'Lat: ${location.latitude.toStringAsFixed(6)}, Lon: ${location.longitude.toStringAsFixed(6)}';
      _locationId = null;
    });
  }

  Future<void> _setMyCurrentLocation() async {
    if (!mounted) return;

    setState(() {
      _isLoadingLocation = true;
    });

    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (mounted) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Please enable location services.')),
            );
          });
        }
        if (mounted) {
          setState(() {
            _isLoadingLocation = false;
          });
        }
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          if (mounted) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Location permission denied.')),
              );
            });
          }
          if (mounted) {
            setState(() {
              _isLoadingLocation = false;
            });
          }
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        if (mounted) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Location permissions are permanently denied.'),
              ),
            );
          });
        }
        if (mounted) {
          setState(() {
            _isLoadingLocation = false;
          });
        }
        return;
      }

      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      final currentLocation = LatLng(position.latitude, position.longitude);
      _handleLocationSelected(currentLocation, 'Your Current Location');
    } catch (e) {
      if (mounted) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('Error getting location: $e')));
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingLocation = false;
        });
      }
    }
  }

  Future<void> _submitReport() async {
    if (!_isLoggedIn || _userId.isEmpty) {
      if (mounted) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Please log in to submit a report'),
              backgroundColor: Colors.orange,
            ),
          );
        });
      }
      return;
    }

    if (_titleController.text.isEmpty || _selectedLocation == null) {
      if (mounted) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Please set a location and provide a title'),
              backgroundColor: Colors.orange,
            ),
          );
        });
      }
      return;
    }

    if (!mounted) return;

    setState(() {
      _isSubmitting = true;
    });

    try {
      // Step 1: Create location
      final locationData = {
        'location_id': 0,
        'latitude': _selectedLocation!.latitude.toString(),
        'longitude': _selectedLocation!.longitude.toString(),
      };

      debugPrint('[API] Creating location: $locationData');
      final locationResponse = await _apiService.createLocation(locationData);

      int locationId;

      if (locationResponse is Map) {
        if (locationResponse.containsKey('location_id')) {
          locationId = locationResponse['location_id'] as int;
        } else if (locationResponse.containsKey('id')) {
          locationId = locationResponse['id'] as int;
        } else if (locationResponse.containsKey('data') &&
            locationResponse['data'] is Map) {
          final data = locationResponse['data'] as Map;
          if (data.containsKey('location_id')) {
            locationId = data['location_id'] as int;
          } else if (data.containsKey('id')) {
            locationId = data['id'] as int;
          } else {
            throw Exception('No location_id or id found in response data');
          }
        } else {
          debugPrint('[API] Full location response: $locationResponse');
          throw Exception('Unexpected location response format');
        }
      } else {
        throw Exception('Location response is not a Map');
      }

      debugPrint('[API] Location created with ID: $locationId');

      final floodHeightText = _floodHeightController.text.trim();
      final double? floodHeight = floodHeightText.isNotEmpty
          ? double.tryParse(floodHeightText)
          : null;

      String severity;
      double reportFloodHeight = 0.0;

      if (floodHeight == null) {
        severity = 'unappointed';
      } else {
        if (floodHeight < 0.5) {
          severity = 'low';
        } else if (floodHeight >= 0.5 && floodHeight <= 0.9) {
          severity = 'medium';
        } else {
          // floodHeight >= 1.0
          severity = 'high';
        }
      }

      // Step 2: Create report
      final now = DateTime.now().toUtc().toIso8601String();
      final reportData = {
        'location_id': locationId,
        'title': _titleController.text.trim(),
        'flood_height': reportFloodHeight,
        'explanation': _explanationController.text.isNotEmpty
            ? _explanationController.text.trim()
            : 'No explanation provided',
        'user_id': _userId,
        'user_phone_number': _userPhoneNumber,
        'dispatcher_phone_number': "09112223333",
        'user_name': _userName,
        'severity':
            severity, //default, dispatcher will set the severity if the severity is unappointed
        'response_status':
            'pending', //if dispatcher kay mag assign na ug rescuers - set to assigned, if rescuer confirms the rescue - set to in_progress, if rescuer completes the rescue - set to resolved
        'response_id': 0,
        'report_status':
            'pending', //if dispatcher kay mag assign na ug rescuers - set to assigned, if rescuer confirms the rescue - set to in_progress, if rescuer completes the rescue - set to resolved
        'assigned_to': 0, //this will update if the dispatcher assigns a rescuer
        'created_by': _userName,
        'created_at': now,
        'updated_by': _userName,
        'updated_at': now,
      };
      debugPrint('[DEBUG] Checking API configuration...');
      debugPrint('[API] Creating report: $reportData');
      final reportResponse = await _apiService.createReport(reportData);
      debugPrint('[API] Report created successfully: $reportResponse');

      if (mounted) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Flood report submitted successfully!'),
              backgroundColor: Colors.green,
            ),
          );
        });

        _titleController.clear();
        _floodHeightController.clear();
        _explanationController.clear();
        if (mounted) {
          setState(() {
            _selectedLocation = null;
            _locationDisplay = 'Tap map or use button to set location';
          });
        }

        await Future.delayed(const Duration(milliseconds: 1500));

        if (mounted) {
          Navigator.pop(context);
        }
      }
    } catch (e, stackTrace) {
      debugPrint('[API] Error submitting report: $e');

      if (e is DioException) {
        debugPrint('[API] Dio Error Type: ${e.type}');
        debugPrint('[API] Dio Error Message: ${e.message}');
        debugPrint('[API] Dio Request Options: ${e.requestOptions}');

        debugPrint('[API] Dio Response Status: ${e.response?.statusCode}');
        debugPrint('[API] Dio Response Data: ${e.response?.data}');
        debugPrint('[API] Dio Response Headers: ${e.response?.headers}');
      }

      debugPrint('[API] Stack trace: $stackTrace');

      String errorMessage = 'Failed to submit report';

      if (e is DioException && e.response != null) {
        errorMessage = "API Error: ${e.response?.data}";
      }

      if (mounted) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(errorMessage),
              backgroundColor: Colors.red,
              duration: const Duration(seconds: 5),
            ),
          );
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final primaryColor = Theme.of(context).colorScheme.primary;

    final LatLng mapTarget = _selectedLocation ?? _initialCenter;
    final double mapZoom = _selectedLocation != null ? 15.0 : 12.0;

    final CameraPosition initialPosition = CameraPosition(
      target: mapTarget,
      zoom: mapZoom,
    );

    if (_isLoadingUserData) {
      return const Center(child: CircularProgressIndicator());
    }

    if (!_isLoggedIn || _userId.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.warning_amber, size: 64, color: Colors.orange),
            const SizedBox(height: 16),
            const Text(
              'Login Required',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              'Please log in to submit flood reports',
              style: TextStyle(fontSize: 16, color: Colors.grey),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Go Back'),
            ),
          ],
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Report a Flood',
            style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          Text(
            'Provide information and confirm the location of the flood.',
            style: TextStyle(fontSize: 14, color: Colors.grey[600]),
          ),
          const SizedBox(height: 32),

          // MAP SECTION
          const Text(
            '1. Set Flood Location',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Tap anywhere on the map to set the flood location',
            style: TextStyle(fontSize: 14, color: Colors.grey[600]),
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Container(
              height: 300,
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey.shade300, width: 1),
              ),
              child: MapViewer(
                initialLocation: _selectedLocation,
                initialCameraPosition: initialPosition,
                onLocationSelected: _handleLocationSelected,
                onMapCreated: (GoogleMapController controller) {},
                disableLocationSelection: false,
                disableTapToPlace: false,
                disableSearch: false,
                mapScrollable: true,
                preventInteraction: false,
                reportMarkers: const {},
                enableZoom: true,
                enablePan: true,
                enableRotation: true,
                enableTilt: true,
              ),
            ),
          ),

          const SizedBox(height: 16),

          // Location Display
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: primaryColor.withOpacity(0.05),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: _selectedLocation != null
                    ? primaryColor
                    : Colors.grey.shade300,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  _selectedLocation != null
                      ? Icons.location_on
                      : Icons.pin_drop_outlined,
                  color: _selectedLocation != null ? primaryColor : Colors.grey,
                  size: 24,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    _locationDisplay,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: _selectedLocation != null
                          ? FontWeight.w600
                          : FontWeight.normal,
                      color: _selectedLocation != null
                          ? Colors.black87
                          : Colors.grey[500],
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 8),

          // Set My Location Button
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: _isLoadingLocation ? null : _setMyCurrentLocation,
              icon: _isLoadingLocation
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Icon(Icons.my_location, size: 20, color: primaryColor),
              label: Text(
                _isLoadingLocation
                    ? 'Getting Location...'
                    : 'Use My Current Location',
              ),
              style: TextButton.styleFrom(foregroundColor: primaryColor),
            ),
          ),

          const SizedBox(height: 40),

          // FORM FIELDS SECTION
          const Text(
            '2. Enter Report Details',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 20),

          _buildCustomTextField(
            controller: _titleController,
            hint: 'Title * (e.g., Street flooded near park)',
            required: true,
          ),
          const SizedBox(height: 24),

          _buildCustomTextField(
            controller: _floodHeightController,
            hint: 'Flood Height in meter (optional)',
            keyboardType: TextInputType.number,
          ),
          const SizedBox(height: 24),

          _buildCustomTextField(
            controller: _explanationController,
            hint: 'Additional details (optional)',
            maxLines: 4,
          ),

          const SizedBox(height: 40),

          // User Info Display
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.blue.withOpacity(0.05),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.blue.shade200),
            ),
            child: Row(
              children: [
                const Icon(Icons.person, color: Colors.blue, size: 24),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Reporting as: $_userName',
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Colors.blue,
                        ),
                      ),
                      if (_userPhoneNumber.isNotEmpty)
                        Text(
                          'Phone: $_userPhoneNumber',
                          style: const TextStyle(
                            fontSize: 12,
                            color: Colors.blue,
                          ),
                        ),
                      Text(
                        'User ID: $_userId',
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.blue,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // Action Buttons
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(
                onPressed: _isSubmitting ? null : () => Navigator.pop(context),
                child: Text(
                  'Cancel',
                  style: TextStyle(
                    color: _isSubmitting
                        ? Colors.grey.shade400
                        : Colors.grey.shade600,
                    fontSize: 16,
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: ElevatedButton(
                  onPressed: _isSubmitting ? null : _submitReport,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _isSubmitting ? Colors.grey : primaryColor,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 14,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 5,
                  ),
                  child: _isSubmitting
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              Colors.white,
                            ),
                          ),
                        )
                      : const Text(
                          'Submit Report',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                ),
              ),
            ],
          ),
          SizedBox(height: MediaQuery.of(context).padding.bottom + 16),
        ],
      ),
    );
  }
}

class _ReportHistory extends StatefulWidget {
  const _ReportHistory();

  @override
  State<_ReportHistory> createState() => __ReportHistoryState();
}

class __ReportHistoryState extends State<_ReportHistory> {
  final ApiService _apiService = ApiService();
  List<ReportData> _userReports = [];
  bool _isLoading = true;
  String? _error;
  int? _currentUserId;

  final Map<int, Map<String, dynamic>> _locationCache = {};

  @override
  void initState() {
    super.initState();
    _loadUserReports();
  }

  Future<void> _loadUserReports() async {
    if (!mounted) return;

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      await _getCurrentUserId();

      if (_currentUserId == null) {
        setState(() {
          _error = 'User not logged in';
          _isLoading = false;
        });
        return;
      }

      debugPrint('[ReportHistory] Fetching reports from API...');
      final response = await _apiService.getAllReports(offset: 0, limit: 100);

      if (response != null) {
        final List<ReportData> allReports = await _parseReports(response);
        _userReports = _filterReportsByUser(allReports, _currentUserId!);

        debugPrint(
          '[ReportHistory] Loaded ${_userReports.length} reports for user $_currentUserId',
        );
      } else {
        setState(() {
          _error = 'Failed to load reports';
        });
      }
    } catch (e) {
      debugPrint('[ReportHistory] Error loading reports: $e');
      setState(() {
        _error = 'Error loading reports: ${e.toString()}';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _getCurrentUserId() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _currentUserId = prefs.getInt('user_id');
      debugPrint('[ReportHistory] Current user ID: $_currentUserId');
    } catch (e) {
      debugPrint('[ReportHistory] Error getting user ID: $e');
      _currentUserId = null;
    }
  }

  Future<List<ReportData>> _parseReports(dynamic response) async {
    final List<ReportData> reports = [];

    try {
      if (response == null) return reports;

      if (response is Map && response['data'] is List) {
        final dataList = response['data'] as List;
        for (var item in dataList) {
          final report = await _parseReportItem(item);
          if (report != null) {
            reports.add(report);
          }
        }
      } else if (response is List) {
        for (var item in response) {
          final report = await _parseReportItem(item);
          if (report != null) {
            reports.add(report);
          }
        }
      }
    } catch (e) {
      debugPrint('[ReportHistory] Error parsing reports: $e');
    }

    return reports;
  }

  Future<ReportData?> _parseReportItem(dynamic item) async {
    if (item is! Map) return null;

    try {
      final jsonData = item.cast<String, dynamic>();

      final report = ReportData.fromJson(jsonData);

      if (report.locationId != null) {
        final locationData = await _fetchLocationData(report.locationId!);
        if (locationData != null) {
          return report.copyWith(
            latitude: locationData['latitude'],
            longitude: locationData['longitude'],
            address: locationData['address'],
          );
        }
      }

      return report;
    } catch (e) {
      debugPrint('[ReportHistory] Error parsing report item: $e');
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
          final double? lng =
              _parseDouble(locationData['longitude']) ??
              _parseDouble(locationData['longitude']);

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

  List<ReportData> _filterReportsByUser(
    List<ReportData> allReports,
    int currentUserId,
  ) {
    return allReports.where((report) {
      return report.userId == currentUserId;
    }).toList();
  }

  String _getCleanStatusName(ReportStatus? status) {
    if (status == null) return 'N/A';
    return status
        .toString()
        .split('.')
        .last
        .splitMapJoin(
          RegExp(r'[A-Z]'),
          onMatch: (m) => ' ${m.group(0)}',
          onNonMatch: (n) =>
              n.isEmpty ? '' : n[0].toUpperCase() + n.substring(1),
        )
        .trim();
  }

  Widget _buildHistoryReportCard(
    BuildContext context,
    ReportData report,
    Color severityColor,
  ) {
    Color statusColor;

    if (report.status == ReportStatus.pending ||
        report.status == ReportStatus.newReport) {
      statusColor = Colors.grey.shade700;
    } else if (report.status == ReportStatus.ongoing ||
        report.status == ReportStatus.inProgress) {
      statusColor = Colors.orange.shade700;
    } else if (report.status == ReportStatus.resolved ||
        report.status == ReportStatus.complete) {
      statusColor = Colors.teal.shade600;
    } else {
      statusColor = Colors.blue.shade700;
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: GestureDetector(
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (ctx) => ReportDetailScreen(
                report: report,
                severityColor: severityColor,
                address: _fetchLocationData, reportLocation: report.location,
              ),
            ),
          );
        },
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey.shade100),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.08),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 10,
                height: 10,
                margin: const EdgeInsets.only(top: 4, right: 12),
                decoration: BoxDecoration(
                  color: severityColor,
                  shape: BoxShape.circle,
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      report.title ?? 'Untitled Report',
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w600,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Reported by You',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.black54,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Text(
                          'Status: ',
                          style: TextStyle(fontSize: 14, color: Colors.black54),
                        ),
                        Text(
                          _getCleanStatusName(report.status),
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: statusColor,
                          ),
                        ),
                      ],
                    ),
                    if (report.address != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        report.address!,
                        style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    report.timestamp != null
                        ? '${report.timestamp!.hour % 12}:${report.timestamp!.minute.toString().padLeft(2, '0')} ${report.timestamp!.hour >= 12 ? 'PM' : 'AM'}'
                        : 'N/A',
                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    report.timestamp != null
                        ? '${report.timestamp!.day}/${report.timestamp!.month}/${report.timestamp!.year}'
                        : '',
                    style: TextStyle(fontSize: 10, color: Colors.grey[500]),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLoadingState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(),
          const SizedBox(height: 16),
          Text(
            'Loading your reports...',
            style: TextStyle(fontSize: 16, color: Colors.grey[600]),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error_outline, size: 64, color: Colors.grey.shade400),
          const SizedBox(height: 16),
          Text(
            'Unable to load reports',
            style: TextStyle(fontSize: 18, color: Colors.grey.shade600),
          ),
          const SizedBox(height: 8),
          Text(
            _error ?? 'Please try again later',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 14, color: Colors.grey.shade500),
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: _loadUserReports,
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.report_problem_outlined,
            size: 64,
            color: Colors.grey.shade400,
          ),
          const SizedBox(height: 16),
          Text(
            'No reports submitted yet',
            style: TextStyle(fontSize: 18, color: Colors.grey.shade600),
          ),
          const SizedBox(height: 8),
          Text(
            'When you submit flood reports, they will appear here.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 14, color: Colors.grey.shade500),
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (context) => ReportFloodPage()),
              );
            },
            child: const Text('Submit Your First Report'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final mockSeverityColors = {
      'pending': Colors.grey.shade500,
      'ongoing': Colors.deepOrange.shade600,
      'resolved': Colors.green.shade600,
      'newReport': Colors.red.shade600,
      'inProgress': Colors.orange.shade600,
      'complete': Colors.green.shade600,
    };

    return Scaffold(
      backgroundColor: Colors.white,
      body: _isLoading
          ? _buildLoadingState()
          : _error != null
          ? _buildErrorState()
          : _userReports.isEmpty
          ? _buildEmptyState()
          : SingleChildScrollView(
              padding: const EdgeInsets.symmetric(
                horizontal: 24.0,
                vertical: 16.0,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'My Reports (${_userReports.length})',
                    style: const TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Track the status of the flood reports you have submitted.',
                    style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                  ),
                  const SizedBox(height: 32),
                  const Text(
                    'Recent Submissions',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 12),
                  ..._userReports.map((report) {
                    final statusKey = report.status.toString().split('.').last;
                    final Color severityColor =
                        mockSeverityColors[statusKey] ?? Colors.blue;
                    return _buildHistoryReportCard(
                      context,
                      report,
                      severityColor,
                    );
                  }),
                  SizedBox(height: MediaQuery.of(context).padding.bottom + 16),
                ],
              ),
            ),
    );
  }
}
