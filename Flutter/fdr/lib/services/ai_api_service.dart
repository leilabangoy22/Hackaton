
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

class AiApiService {
  static const String baseUrl =
      'https://gh6tr9x3-8000.asse.devtunnels.ms';

  final Dio _dio = Dio(
    BaseOptions(
      baseUrl: baseUrl,
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 30),
      headers: {'Content-Type': 'application/json'},
    ),
  );

  Future<dynamic> get(String path, {Map<String, dynamic>? query}) async {
    try {
      final response = await _dio.get(
        path,
        queryParameters: query,
      );

      return response.data;
    } on DioException catch (e) {
      debugPrint('[AI API] GET $path failed: ${e.message}');
      debugPrint('[AI API] Response: ${e.response?.data}');
      rethrow;
    }
  }

  Future<dynamic> post(
    String path, {
    Map<String, dynamic>? data,
    Map<String, dynamic>? query,
  }) async {
    try {
      final response = await _dio.post(
        path,
        data: data,
        queryParameters: query,
      );

      return response.data;
    } on DioException catch (e) {
      debugPrint('[AI API] POST $path failed: ${e.message}');
      debugPrint('[AI API] Response: ${e.response?.data}');
      rethrow;
    }
  }

  Future<bool> testConnection() async {
    try {
      await _dio.get('/');
      return true;
    } catch (e) {
      debugPrint('[AI API] Connection test failed: $e');
      return false;
    }
  }
}
