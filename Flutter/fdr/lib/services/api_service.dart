import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';

class ApiService {
  static const String baseUrl =
      'https://hackaton-1-bhl5.onrender.com';

  static const String googleMapsApiKey =
      'YOUR_GOOGLE_MAPS_API_KEY';

  static const String riskAssessmentUrl =
      'https://gh6tr9x3-8000.asse.devtunnels.ms/AI/assess-risk';

  final Dio _dio = Dio(
    BaseOptions(
      baseUrl: baseUrl,
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 20),
      headers: {'Content-Type': 'application/json'},
    ),
  );

  // GOOGLE MAPS API KEY VALIDATION

  bool _isValidGoogleMapsApiKey(String key) {
    final value = key.trim();

    return value.isNotEmpty &&
        value != 'YOUR_GOOGLE_MAPS_API_KEY' &&
        value != 'YOUR_ACTUAL_API_KEY' &&
        value != 'PASTE_YOUR_ACTUAL_API_KEY_HERE';
  }

  // REQUEST HELPER

  Future<dynamic> _request(
    String path, {
    String method = 'GET',
    Map? data,
    Map? query,
  }) async {
    final cleanPath = path.startsWith('/') ? path : '/$path';

    try {
      final response = await _dio.request(
        cleanPath,
        data: data == null
            ? null
            : Map<String, dynamic>.from(data),
        queryParameters: query == null
            ? null
            : Map<String, dynamic>.from(query),
        options: Options(method: method),
      );

      debugPrint('[API] $method ${response.requestOptions.uri}');
      debugPrint('[API] Status: ${response.statusCode}');

      return response.data;
    } on DioException catch (e) {
      debugPrint('[API ERROR] ${e.message}');
      debugPrint('[API ERROR] URL: ${e.requestOptions.uri}');
      debugPrint('[API ERROR] Status: ${e.response?.statusCode}');
      debugPrint('[API ERROR] Response: ${e.response?.data}');

      final responseData = e.response?.data;
      final message = responseData == null
          ? (e.message ?? 'Network request failed.')
          : responseData is String
              ? responseData
              : jsonEncode(responseData);

      throw Exception(
        'API request failed '
        '(${e.response?.statusCode ?? 'network error'}): $message',
      );
    } catch (e) {
      debugPrint('[API ERROR] $e');
      rethrow;
    }
  }

  Map<String, dynamic> _convertToStringMap(Map map) {
    return Map<String, dynamic>.from(
      map.map(
        (key, value) => MapEntry(key.toString(), value),
      ),
    );
  }

  Map<String, dynamic>? _extractMap(dynamic response) {
    if (response is String) {
      try {
        response = jsonDecode(response);
      } catch (_) {
        return null;
      }
    }

    if (response is! Map) return null;

    final result = _convertToStringMap(response);
    final data = result['data'];

    if (data is Map) {
      return _convertToStringMap(data);
    }

    return result;
  }

  List<dynamic> _extractList(dynamic response) {
    if (response is String) {
      try {
        response = jsonDecode(response);
      } catch (_) {
        return [];
      }
    }

    if (response is List) return response;

    if (response is Map) {
      final result = _convertToStringMap(response);
      final data = result['data'] ?? result['results'];

      if (data is List) return data;

      if (data is String) {
        try {
          final decoded = jsonDecode(data);
          if (decoded is List) return decoded;
        } catch (_) {}
      }
    }

    return [];
  }

  bool _isRescuer(dynamic user) {
    if (user is! Map) return false;

    final role = user['role']?.toString().toLowerCase().trim();

    return role == 'rescuer' || role == 'rescue personnel';
  }

  // CONNECTION TEST

  Future<bool> testConnection() async {
    try {
      await _dio.get('/');
      return true;
    } catch (e) {
      debugPrint('[API] Connection test failed: $e');
      return false;
    }
  }

  // USER AUTH

  Future<dynamic> login(String name, String password) {
    return _request(
      '/User/User/log_in',
      method: 'POST',
      data: {'name': name, 'password': password},
    );
  }

  Future<dynamic> getUserByName(String name) {
    return _request('/User/User/', query: {'name': name});
  }

  Future<dynamic> register(Map data) {
    return _request(
      '/User/User/register',
      method: 'POST',
      data: data,
    );
  }

  Future<dynamic> logout() {
    return _request('/User/User/log_out', method: 'POST');
  }

  Future<dynamic> changePassword(Map data) {
    return _request(
      '/User/User/Change_Password',
      method: 'PUT',
      data: data,
    );
  }

  Future<dynamic> forgotPassword(String email) {
    return _request(
      '/User/User/forgot_password',
      method: 'POST',
      data: {'email': email},
    );
  }

  Future<dynamic> resetPassword(
    String token,
    String newPassword,
  ) {
    return _request(
      '/User/User/reset_password',
      method: 'POST',
      data: {
        'token': token,
        'new_password': newPassword,
      },
    );
  }

  // LOCATION CRUD

  Future<dynamic> getAllLocations({
    int offset = 0,
    int limit = 100,
  }) {
    return _request(
      '/Location/',
      query: {'offset': offset, 'limit': limit},
    );
  }

  Future<dynamic> createLocation(
    Map<String, dynamic> locationData,
  ) {
    final latitude =
        locationData['latitude'] ?? locationData['lat'];

    final longitude = locationData['longitude'] ??
        locationData['lng'] ??
        locationData['lon'];

    if (latitude == null || longitude == null) {
      throw ArgumentError(
        'Latitude and longitude are required.',
      );
    }

    return _request(
      '/Location/',
      method: 'POST',
      data: {
        'location_id': locationData['location_id'] ?? 0,
        'latitude': latitude.toString(),
        'longitude': longitude.toString(),
      },
    );
  }

  Future<dynamic> updateUserLocation(
    int userId,
    int locationId,
  ) {
    return _request(
      '/User/User/update_user_location/$userId',
      method: 'PUT',
      data: {'location_id': locationId},
    );
  }

  Future<dynamic> updateLocation(Map data) {
    return _request('/Location/', method: 'PUT', data: data);
  }

  Future<dynamic> deleteLocation(Map data) {
    return _request('/Location/', method: 'DELETE', data: data);
  }

  Future<Map<String, dynamic>?> getLocationById(
    int locationId,
  ) async {
    try {
      return _extractMap(
        await _request('/Location/$locationId'),
      );
    } catch (e) {
      debugPrint('[API] Get location failed: $e');
      return null;
    }
  }

  Future<Map<String, dynamic>?> getLocationWithAddress(
    int locationId,
  ) async {
    final location = await getLocationById(locationId);

    if (location == null) {
      debugPrint('[ADDRESS] Location $locationId not found.');
      return null;
    }

    final address = await getAddressForLocation(location);

    location['address'] = address ?? 'Unable to get Address';

    return location;
  }

  Future<String> getPinnedLocationAddress({
    required double latitude,
    required double longitude,
  }) async {
    final address = await getAddressFromCoordinates(
      latitude,
      longitude,
      googleMapsApiKey: googleMapsApiKey,
    );

    return address ?? 'Unable to get Address';
  }

  // REPORT CRUD

  Future<dynamic> getAllReports({
    int offset = 0,
    int limit = 100,
  }) {
    return _request(
      '/User/Report/',
      query: {'offset': offset, 'limit': limit},
    );
  }

  Future<dynamic> createReport(Map<String, dynamic> data) {
    final userId = data['user_id'];

    if (userId == null) {
      throw ArgumentError(
        'user_id is required in report data.',
      );
    }

    debugPrint('[API] Creating report: $data');

    return _request(
      '/User/Report/$userId',
      method: 'POST',
      data: data,
    );
  }

  Future<dynamic> deleteReport(Map data) {
    return _request(
      '/User/Report/',
      method: 'DELETE',
      data: data,
    );
  }

  Future<Map<String, dynamic>?> getReportById(
    int reportId,
  ) async {
    try {
      return _extractMap(
        await _request('/User/Report/$reportId'),
      );
    } catch (e) {
      debugPrint('[API] Get report failed: $e');
      return null;
    }
  }

  Future<void> updateReport(
    String reportId,
    Map<String, dynamic> data,
    int userId,
  ) async {
    await _request(
      '/User/Report/$reportId',
      method: 'PUT',
      data: data,
      query: {'user_id': userId},
    );
  }

  Future<dynamic> getReportWithColor(int id) {
    return _request('/User/Report/$id/WithColor');
  }

  // RESPONSE CRUD

  Future<dynamic> getAllResponses() => _request('/Response/');

  Future<dynamic> addResponse(Map data) {
    return _request(
      '/Response/',
      method: 'POST',
      data: data,
    );
  }

  Future<dynamic> updateResponse(Map data) {
    return _request(
      '/Response/',
      method: 'PUT',
      data: data,
    );
  }

  Future<dynamic> deleteResponse(Map data) {
    return _request(
      '/Response/',
      method: 'DELETE',
      data: data,
    );
  }

  Future<dynamic> getResponseById(int id) {
    return _request('/Response/$id');
  }

  // DISPATCHER USERS

  Future<dynamic> getAllUsers() {
    return _request('/Dispatcher/User/');
  }

  Future<dynamic> deleteUser(Map data) {
    return _request(
      '/Dispatcher/User/',
      method: 'DELETE',
      data: data,
    );
  }

  Future<dynamic> setIsActive(Map data) {
    return _request(
      '/Rescuer/User/',
      method: 'PUT',
      data: data,
    );
  }

  Future<Map<String, dynamic>?> getRescuerById(
    int rescuerId,
  ) async {
    try {
      return _extractMap(
        await _request('/Dispatcher/User/$rescuerId'),
      );
    } catch (e) {
      debugPrint('[API] Get rescuer failed: $e');
      return null;
    }
  }

  Future<Map<String, dynamic>?> getUserById(int userId) async {
    try {
      return _extractMap(
        await _request('/User/User/$userId'),
      );
    } catch (e) {
      debugPrint('[API] Get user failed: $e');
      return null;
    }
  }

  Future<dynamic> updateUser(int userId, Map data) {
    return _request(
      '/User/User/$userId',
      method: 'PUT',
      data: data,
    );
  }

  // OPERATION

  Future<dynamic> getNumberStatus() {
    return _request('/Dispatcher/Operation/Number_of_Status');
  }

  Future<dynamic> getAllPendingReports() {
    return _request('/Dispatcher/Operation/All_Pending_Request');
  }

  Future<dynamic> getRescuerList() {
    return _request('/Dispatcher/Operation/Personel_List');
  }

  // MAPS

  Future<dynamic> getDirections(Map query) {
    return _request('/maps/directions', query: query);
  }

  Future<dynamic> searchPlace(String text) async {
    final response = await _request(
      '/maps/search_place',
      method: 'POST',
      data: {'query': text},
    );

    dynamic decoded = response;

    if (decoded is String) {
      try {
        decoded = jsonDecode(decoded);
      } catch (_) {
        throw Exception('The search API returned invalid JSON.');
      }
    }

    if (decoded is List) {
      return {'results': decoded};
    }

    if (decoded is Map) {
      final result = _convertToStringMap(decoded);
      final results = result['results'];

      if (results is String) {
        try {
          result['results'] = jsonDecode(results);
        } catch (_) {
          throw Exception(
            'The search API returned invalid JSON in results.',
          );
        }
      }

      return result;
    }

    throw Exception(
      'Unexpected response format from search API.',
    );
  }

  Future<dynamic> searchPlaceViaId(String id) {
    return _request(
      '/maps/search_place_via_place_id/',
      query: {'place_id': id},
    );
  }

  // REVERSE GEOCODING

  Future<String?> getAddressFromCoordinates(
    double latitude,
    double longitude, {
    required String googleMapsApiKey,
  }) async {
    if (!latitude.isFinite ||
        !longitude.isFinite ||
        latitude < -90 ||
        latitude > 90 ||
        longitude < -180 ||
        longitude > 180) {
      debugPrint(
        '[ADDRESS] Invalid coordinates: $latitude, $longitude',
      );
      return null;
    }

    final apiKey = googleMapsApiKey.trim();

    if (!_isValidGoogleMapsApiKey(apiKey)) {
      debugPrint('[ADDRESS] Google Maps API key is missing.');
      return null;
    }

    try {
      final response = await Dio().get(
        'https://maps.googleapis.com/maps/api/geocode/json',
        queryParameters: {
          'latlng': '$latitude,$longitude',
          'key': apiKey,
        },
        options: Options(
          connectTimeout: const Duration(seconds: 15),
          receiveTimeout: const Duration(seconds: 20),
        ),
      );

      final result = response.data;

      if (result is! Map) {
        debugPrint('[ADDRESS] Invalid response: $result');
        return null;
      }

      final status = result['status']?.toString();

      debugPrint('[ADDRESS] Geocoding status: $status');

      if (status != 'OK') {
        debugPrint(
          '[ADDRESS] Error: ${result['error_message']}',
        );
        return null;
      }

      final results = result['results'];

      if (results is List && results.isNotEmpty) {
        for (final item in results) {
          if (item is! Map) continue;

          final address =
              item['formatted_address']?.toString().trim();

          if (address != null && address.isNotEmpty) {
            debugPrint('[ADDRESS] Found: $address');
            return address;
          }
        }
      }

      debugPrint('[ADDRESS] No address returned.');
      return null;
    } on DioException catch (e) {
      debugPrint('[ADDRESS] Request failed: ${e.message}');
      debugPrint('[ADDRESS] Response: ${e.response?.data}');
      return null;
    } catch (e) {
      debugPrint('[ADDRESS] Unexpected error: $e');
      return null;
    }
  }

  Future<String?> getAddressFromPlaceId(
    String placeId,
  ) async {
    final apiKey = googleMapsApiKey.trim();

    if (!_isValidGoogleMapsApiKey(apiKey) ||
        placeId.trim().isEmpty) {
      debugPrint(
        '[ADDRESS] API key or Place ID is missing.',
      );
      return null;
    }

    try {
      final response = await Dio().get(
        'https://maps.googleapis.com/maps/api/geocode/json',
        queryParameters: {
          'place_id': placeId.trim(),
          'key': apiKey,
        },
        options: Options(
          connectTimeout: const Duration(seconds: 15),
          receiveTimeout: const Duration(seconds: 20),
        ),
      );

      final result = response.data;

      if (result is Map && result['status'] == 'OK') {
        final results = result['results'];

        if (results is List && results.isNotEmpty) {
          for (final item in results) {
            if (item is! Map) continue;

            final address =
                item['formatted_address']?.toString().trim();

            if (address != null && address.isNotEmpty) {
              return address;
            }
          }
        }
      }

      debugPrint(
        '[ADDRESS] Place ID lookup failed: '
        '${result is Map ? result['status'] : result}',
      );
    } catch (e) {
      debugPrint('[ADDRESS] Place ID error: $e');
    }

    return null;
  }

  Future<String?> getAddressFromRoute(
    String route,
  ) async {
    final apiKey = googleMapsApiKey.trim();

    if (route.trim().isEmpty ||
        !_isValidGoogleMapsApiKey(apiKey)) {
      debugPrint(
        '[ADDRESS] Route or Google Maps API key is missing.',
      );
      return null;
    }

    try {
      final response = await Dio().get(
        'https://maps.googleapis.com/maps/api/geocode/json',
        queryParameters: {
          'address': route.trim(),
          'key': apiKey,
          'region': 'ph',
        },
        options: Options(
          connectTimeout: const Duration(seconds: 15),
          receiveTimeout: const Duration(seconds: 20),
        ),
      );

      final result = response.data;

      if (result is Map && result['status'] == 'OK') {
        final results = result['results'];

        if (results is List && results.isNotEmpty) {
          for (final item in results) {
            if (item is! Map) continue;

            final address =
                item['formatted_address']?.toString().trim();

            if (address != null && address.isNotEmpty) {
              return address;
            }
          }
        }
      }

      debugPrint(
        '[ADDRESS] Route lookup failed: '
        '${result is Map ? result['status'] : result}',
      );
    } catch (e) {
      debugPrint('[ADDRESS] Route lookup error: $e');
    }

    return null;
  }

  // ADDRESS HELPERS

  double? _readCoordinate(
    Map<String, dynamic> data,
    List<String> keys,
  ) {
    for (final key in keys) {
      final value = data[key];

      if (value == null) continue;

      final number = double.tryParse(value.toString());

      if (number != null && number.isFinite) {
        return number;
      }
    }

    return null;
  }

  int? _readLocationId(Map<String, dynamic> data) {
    final value = data['location_id'] ??
        data['locationId'] ??
        data['LocationId'];

    return int.tryParse(value?.toString() ?? '');
  }

  String? _readExistingAddress(Map<String, dynamic> data) {
    const keys = [
      'address',
      'formatted_address',
      'formattedAddress',
      'full_address',
      'fullAddress',
      'street_address',
      'streetAddress',
    ];

    for (final key in keys) {
      final value = data[key]?.toString().trim();

      if (value == null || value.isEmpty) continue;

      final normalized = value.toLowerCase();

      if (normalized == 'unable to get address' ||
          normalized == 'address unavailable' ||
          normalized == 'n/a' ||
          normalized == 'null' ||
          normalized == 'unknown') {
        continue;
      }

      return value;
    }

    return null;
  }

  // Supports regular coordinate fields, nested coordinate maps,
  // and GeoJSON-style coordinates [longitude, latitude].

  List<dynamic>? _readCoordinateList(
    Map<String, dynamic> data,
  ) {
    final candidates = [
      data['coordinates'],
      data['coordinate'],
      if (data['geometry'] is Map)
        (data['geometry'] as Map)['coordinates'],
      if (data['location'] is Map)
        (data['location'] as Map)['coordinates'],
    ];

    for (final candidate in candidates) {
      if (candidate is List && candidate.length >= 2) {
        return candidate;
      }
    }

    return null;
  }

  double? _readLatitude(Map<String, dynamic> data) {
    final direct = _readCoordinate(
      data,
      [
        'latitude',
        'lat',
        'Latitude',
        'LatitudeCoordinate',
        'latitude_coordinate',
      ],
    );

    if (direct != null) return direct;

    final nested = data['coordinates'] ??
        data['coordinate'] ??
        data['geometry'] ??
        data['location'];

    if (nested is Map) {
      final map = _convertToStringMap(nested);

      final nestedLatitude = _readCoordinate(
        map,
        [
          'latitude',
          'lat',
          'Latitude',
          'LatitudeCoordinate',
          'latitude_coordinate',
        ],
      );

      if (nestedLatitude != null) return nestedLatitude;
    }

    final coordinateList = _readCoordinateList(data);

    // GeoJSON uses [longitude, latitude].
    if (coordinateList != null) {
      final latitude =
          double.tryParse(coordinateList[1].toString());

      if (latitude != null &&
          latitude.isFinite &&
          latitude >= -90 &&
          latitude <= 90) {
        return latitude;
      }
    }

    return null;
  }

  double? _readLongitude(Map<String, dynamic> data) {
    final direct = _readCoordinate(
      data,
      [
        'longitude',
        'lng',
        'lon',
        'long',
        'Longitude',
        'LongitudeCoordinate',
        'longitude_coordinate',
      ],
    );

    if (direct != null) return direct;

    final nested = data['coordinates'] ??
        data['coordinate'] ??
        data['geometry'] ??
        data['location'];

    if (nested is Map) {
      final map = _convertToStringMap(nested);

      final nestedLongitude = _readCoordinate(
        map,
        [
          'longitude',
          'lng',
          'lon',
          'long',
          'Longitude',
          'LongitudeCoordinate',
          'longitude_coordinate',
        ],
      );

      if (nestedLongitude != null) return nestedLongitude;
    }

    final coordinateList = _readCoordinateList(data);

    // GeoJSON uses [longitude, latitude].
    if (coordinateList != null) {
      final longitude =
          double.tryParse(coordinateList[0].toString());

      if (longitude != null &&
          longitude.isFinite &&
          longitude >= -180 &&
          longitude <= 180) {
        return longitude;
      }
    }

    return null;
  }

  Future<String?> getAddressForLocation(
    Map<String, dynamic> location,
  ) async {
    debugPrint('[ADDRESS] Checking location: $location');

    // 1. Use an address already provided by the API.
    final existingAddress = _readExistingAddress(location);

    if (existingAddress != null) {
      debugPrint('[ADDRESS] Existing address: $existingAddress');
      return existingAddress;
    }

    // 2. Try coordinates directly or inside a nested object.
    final latitude = _readLatitude(location);
    final longitude = _readLongitude(location);

    if (latitude != null && longitude != null) {
      final address = await getAddressFromCoordinates(
        latitude,
        longitude,
        googleMapsApiKey: googleMapsApiKey,
      );

      if (address != null) return address;

      debugPrint(
        '[ADDRESS] Reverse geocoding failed for '
        '$latitude, $longitude',
      );
    }

    // 3. Try a Google Place ID.
    final placeId = location['place_id'] ??
        location['placeId'] ??
        location['google_place_id'];

    if (placeId != null &&
        placeId.toString().trim().isNotEmpty) {
      final address = await getAddressFromPlaceId(
        placeId.toString(),
      );

      if (address != null) return address;
    }

    // 4. Try a route or road name.
    final route = location['route'] ??
        location['road'] ??
        location['road_name'] ??
        location['street'] ??
        location['street_name'];

    if (route != null && route.toString().trim().isNotEmpty) {
      final address = await getAddressFromRoute(
        route.toString(),
      );

      if (address != null) return address;

      return route.toString();
    }

    // 5. Try a nested location object.
    final nestedLocation =
        location['location'] ?? location['Location'];

    if (nestedLocation is Map) {
      final nestedMap = _convertToStringMap(nestedLocation);

      final address = await getAddressForLocation(nestedMap);

      if (address != null) return address;
    }

    // 6. Use location_id to retrieve saved coordinates.
    final locationId = _readLocationId(location);

    if (locationId != null) {
      final savedLocation = await getLocationById(locationId);

      if (savedLocation != null) {
        final savedAddress = _readExistingAddress(savedLocation);

        if (savedAddress != null) return savedAddress;

        final savedLatitude = _readLatitude(savedLocation);
        final savedLongitude = _readLongitude(savedLocation);

        if (savedLatitude != null && savedLongitude != null) {
          final address = await getAddressFromCoordinates(
            savedLatitude,
            savedLongitude,
            googleMapsApiKey: googleMapsApiKey,
          );

          if (address != null) return address;
        }

        final savedRoute = savedLocation['route'] ??
            savedLocation['road'] ??
            savedLocation['street'];

        if (savedRoute != null &&
            savedRoute.toString().trim().isNotEmpty) {
          final address = await getAddressFromRoute(
            savedRoute.toString(),
          );

          if (address != null) return address;

          return savedRoute.toString();
        }

        debugPrint(
          '[ADDRESS] Location ID $locationId returned no usable '
          'coordinates or address: $savedLocation',
        );
      }
    }

    debugPrint(
      '[ADDRESS] Could not resolve address for: $location',
    );

    return null;
  }

  Future<String?> getPersonAddress(
    Map<String, dynamic> person,
  ) async {
    final address = await getAddressForLocation(person);

    if (address != null) return address;

    final locationId = _readLocationId(person);

    if (locationId != null) {
      final savedLocation = await getLocationById(locationId);

      if (savedLocation != null) {
        return getAddressForLocation(savedLocation);
      }
    }

    return null;
  }

  Future<List<Map<String, dynamic>>> _addAddresses(
    List<dynamic> items,
  ) async {
    final result = <Map<String, dynamic>>[];

    for (final item in items) {
      if (item is! Map) continue;

      final person = _convertToStringMap(item);
      final address = await getPersonAddress(person);

      person['address'] = address ?? 'Unable to get Address';
      result.add(person);

      debugPrint(
        '[ADDRESS] ${person['name'] ?? person['user_id']}: '
        '${person['address']}',
      );
    }

    return result;
  }

  Future<List<Map<String, dynamic>>> getAllUsersWithAddresses() async {
    try {
      return _addAddresses(
        _extractList(await getAllUsers()),
      );
    } catch (e) {
      debugPrint('[ADDRESS] Get users failed: $e');
      return [];
    }
  }

  Future<List<Map<String, dynamic>>>
      getAllDispatchersWithAddresses() async {
    try {
      final response = await getAllUsers();
      final dispatchers = <dynamic>[];

      for (final item in _extractList(response)) {
        if (item is! Map) continue;

        final user = _convertToStringMap(item);
        final role = (user['role'] ?? '')
            .toString()
            .toLowerCase()
            .trim();

        if (role.contains('dispatcher')) {
          dispatchers.add(user);
        }
      }

      return _addAddresses(dispatchers);
    } catch (e) {
      debugPrint('[ADDRESS] Get dispatchers failed: $e');
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> getAllRescuersWithAddresses({
    int offset = 0,
    int limit = 100,
  }) async {
    try {
      final rescuers = await getAllRescuePersonnel(
        offset: offset,
        limit: limit,
      );

      return _addAddresses(rescuers);
    } catch (e) {
      debugPrint('[ADDRESS] Get rescuers failed: $e');
      return [];
    }
  }

  // AI FLOOD RISK ASSESSMENT

  Future<dynamic> assessFloodRisk({
    required double floodHeightByFeet,
    required double latitude,
    required double longitude,
  }) async {
    if (!floodHeightByFeet.isFinite ||
        floodHeightByFeet < 0 ||
        !latitude.isFinite ||
        latitude < -90 ||
        latitude > 90 ||
        !longitude.isFinite ||
        longitude < -180 ||
        longitude > 180) {
      throw ArgumentError(
        'Please provide valid flood height and coordinates.',
      );
    }

    try {
      final response = await Dio().get(
        riskAssessmentUrl,
        queryParameters: {
          'flood_height_by_feet': floodHeightByFeet,
          'latitude': latitude,
          'longitude': longitude,
        },
        options: Options(
          headers: {'accept': '*/*'},
          connectTimeout: const Duration(seconds: 15),
          receiveTimeout: const Duration(seconds: 20),
        ),
      );

      debugPrint(
        '[API] Risk assessment status: ${response.statusCode}',
      );
      debugPrint(
        '[API] Risk assessment result: ${response.data}',
      );

      return response.data;
    } on DioException catch (e) {
      debugPrint('[API] Risk assessment failed: ${e.message}');
      debugPrint('[API] Risk assessment URL: ${e.requestOptions.uri}');
      debugPrint('[API] Risk assessment status: ${e.response?.statusCode}');
      debugPrint('[API] Risk assessment response: ${e.response?.data}');
      rethrow;
    } catch (e) {
      debugPrint('[API] Unexpected risk assessment error: $e');
      rethrow;
    }
  }

  // ADD ADDRESSES TO AI RISK ASSESSMENT

  Future<Map<String, dynamic>> addAddressesToRiskAssessment(
    dynamic response,
  ) async {
    dynamic decoded = response;

    if (decoded is String) {
      try {
        decoded = jsonDecode(decoded);
      } catch (_) {
        throw Exception('Invalid flood-risk response.');
      }
    }

    if (decoded is! Map) {
      throw Exception('Unexpected flood-risk response format.');
    }

    final result = _convertToStringMap(decoded);

    final dynamic nestedData = result['data'];

    final Map<String, dynamic> riskResult = nestedData is Map
        ? _convertToStringMap(nestedData)
        : result;

    // Find the high-risk areas list.
    const possibleRiskKeys = [
      'high_risk_areas',
      'highRiskAreas',
      'high-risk-areas',
      'risk_areas',
      'riskAreas',
    ];

    String? riskAreasKey;

    for (final key in possibleRiskKeys) {
      if (riskResult[key] is List) {
        riskAreasKey = key;
        break;
      }
    }

    if (riskAreasKey != null) {
      final areas = riskResult[riskAreasKey] as List;
      final updatedAreas = <Map<String, dynamic>>[];

      for (final item in areas) {
        if (item is! Map) continue;

        final area = _convertToStringMap(item);
        final address = await getAddressForLocation(area);

        area['address'] = address ?? 'Unable to get Address';
        updatedAreas.add(area);

        debugPrint(
          '[ADDRESS] Risk area '
          '${area['grid_id'] ?? area['id'] ?? area['location_id'] ?? ''}: '
          '${area['address']}',
        );
      }

      riskResult[riskAreasKey] = updatedAreas;
    } else {
      debugPrint(
        '[ADDRESS] No high-risk area list found. '
        'Response keys: ${riskResult.keys.toList()}',
      );
    }

    // Find the safest area.
    const possibleSafestKeys = [
      'safest_area',
      'safestArea',
      'safest-area',
    ];

    String? safestAreaKey;

    for (final key in possibleSafestKeys) {
      if (riskResult[key] is Map) {
        safestAreaKey = key;
        break;
      }
    }

    if (safestAreaKey != null) {
      final area = _convertToStringMap(
        riskResult[safestAreaKey] as Map,
      );

      final address = await getAddressForLocation(area);

      area['address'] = address ?? 'Unable to get Address';
      riskResult[safestAreaKey] = area;

      debugPrint('[ADDRESS] Safest area: ${area['address']}');
    } else {
      debugPrint(
        '[ADDRESS] No safest area map found. '
        'Response keys: ${riskResult.keys.toList()}',
      );
    }

    // Preserve the original response structure.
    if (nestedData is Map) {
      result['data'] = riskResult;
      return result;
    }

    return riskResult;
  }

  // FLOOD SENSOR CRUD

  Future<dynamic> getAllSensors() {
    return _request('/Flood_Sensor/');
  }

  Future<dynamic> addSensor(Map data) {
    return _request(
      '/Flood_Sensor/',
      method: 'POST',
      data: data,
    );
  }

  Future<dynamic> updateSensor(Map data) {
    return _request(
      '/Flood_Sensor/',
      method: 'PUT',
      data: data,
    );
  }

  Future<dynamic> deleteSensor(Map data) {
    return _request(
      '/Flood_Sensor/',
      method: 'DELETE',
      data: data,
    );
  }

  Future<dynamic> getSensorById(int id) {
    return _request('/Flood_Sensor/$id');
  }

  // RESCUE PERSONNEL

  Future<List<dynamic>> getAllRescuePersonnel({
    int offset = 0,
    int limit = 100,
  }) async {
    try {
      final response = await _request(
        '/Rescue_Personel/',
        query: {'offset': offset, 'limit': limit},
      );

      return _extractList(response);
    } catch (e) {
      debugPrint('[API] Get rescue personnel failed: $e');
      return [];
    }
  }

  Future<dynamic> addRescuePersonnel(Map data) {
    return _request(
      '/Rescue_Personel/',
      method: 'POST',
      data: data,
    );
  }

  Future<dynamic> updateRescuePersonnel(
    int rescuePersonnelId,
    Map data,
  ) {
    return _request(
      '/Rescue_Personel/$rescuePersonnelId',
      method: 'PUT',
      data: data,
    );
  }

  Future<dynamic> deleteRescuePersonnel(Map data) {
    return _request(
      '/Rescue_Personel/',
      method: 'DELETE',
      data: data,
    );
  }

  Future<dynamic> getRescuePersonnelById(
    int rescuePersonnelId,
  ) {
    return _request('/Rescue_Personel/$rescuePersonnelId');
  }

  Future<List<dynamic>> getAllRescuers({
    int offset = 0,
    int limit = 100,
  }) {
    return getAllRescuePersonnel(
      offset: offset,
      limit: limit,
    );
  }

  // GET PENDING REPORTS

  Future<List<dynamic>> getPendingReports() async {
    final response = await _request(
      '/Dispatcher/Operation/All_Pending_Request',
    );

    return _extractList(response);
  }

  // GET ASSIGNED RESCUES

  Future<List<dynamic>> getAssignedRescues() async {
    try {
      final response = await _request(
        '/Dispatcher/Operation/Personel_List',
      );

      return _extractList(response);
    } catch (e) {
      debugPrint('[API] Get assigned rescues failed: $e');
      return [];
    }
  }

  // RESCUER LOCATION

  Future<Map<String, dynamic>?> getRescuerLocation(
    int rescuerId,
  ) async {
    try {
      final response = await _request(
        '/Location/Rescuer_Location',
        query: {'rescuer_id': rescuerId},
      );

      return _extractMap(response);
    } catch (e) {
      debugPrint('[API] Get rescuer location failed: $e');
      return null;
    }
  }

  Future<bool?> updateRescuerLocation(
    int rescuerId,
    int locationId,
  ) async {
    try {
      final response = await updateUserLocation(
        rescuerId,
        locationId,
      );

      if (response == null) return false;

      if (response is Map) {
        final result = _convertToStringMap(response);
        final status =
            result['status']?.toString().toLowerCase();
        final message =
            result['message']?.toString().toLowerCase();

        return result['success'] == true ||
            status == 'success' ||
            (message?.contains('success') ?? false);
      }

      return true;
    } catch (e) {
      debugPrint('[API] Rescuer location update failed: $e');
      return false;
    }
  }

  Future<bool?> updateRescuerLocationDirect(
    int rescuerId,
    double latitude,
    double longitude,
  ) async {
    try {
      final locationResponse = await createLocation({
        'latitude': latitude,
        'longitude': longitude,
      });

      final location = _extractMap(locationResponse);

      final locationId = int.tryParse(
        (location?['location_id'] ?? location?['id'] ?? '')
            .toString(),
      );

      if (locationId == null) {
        debugPrint('[API] Location ID missing from response.');
        return false;
      }

      return updateRescuerLocation(rescuerId, locationId);
    } catch (e) {
      debugPrint('[API] Direct location update failed: $e');
      return null;
    }
  }

  // RESCUER ASSIGNMENT

  Future<Map<String, dynamic>?> getRescuerAssignment(
    int rescuerId,
  ) async {
    debugPrint(
      '[API] No confirmed rescuer-assignment endpoint was provided.',
    );
    return null;
  }

  // RESCUER LOCATION BY REPORT

  Future<Map<String, dynamic>?> getRescuerLocationByReportId(
    String reportId,
  ) async {
    try {
      final response = await _request(
        '/Location/Rescuer_Location',
        query: {'report_id': reportId},
      );

      return _extractMap(response);
    } catch (e) {
      debugPrint(
        '[API] Get rescuer location by report failed: $e',
      );
      return null;
    }
  }

  // ADDRESS DEBUGGING

  Future<void> debugAddressData() async {
    try {
      final locationsResponse = await getAllLocations();

      debugPrint('========== LOCATIONS RESPONSE ==========');
      debugPrint(
        const JsonEncoder.withIndent('  ')
            .convert(locationsResponse),
      );

      final testAddress = await getPinnedLocationAddress(
        latitude: 10.295260922295434,
        longitude: 123.86982777993161,
      );

      debugPrint('========== TEST PIN ADDRESS ==========');
      debugPrint(testAddress);
    } catch (e) {
      debugPrint('[ADDRESS DEBUG ERROR] $e');
    }
  }
}