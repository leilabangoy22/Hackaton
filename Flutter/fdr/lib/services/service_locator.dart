// lib/services/service_locator.dart
import 'package:fdr/services/api_service.dart';

class ServiceLocator {
  static final ServiceLocator _instance = ServiceLocator._internal();
  factory ServiceLocator() => _instance;
  ServiceLocator._internal();

  final Map<Type, dynamic> _services = {};

  void register<T>(T service) {
    _services[T] = service;
  }

  T get<T>() {
    if (_services.containsKey(T)) {
      return _services[T] as T;
    }
    throw Exception('Service $T not registered');
  }

  bool contains<T>() => _services.containsKey(T);
}

void setupServices() {
  final locator = ServiceLocator();
  locator.register<ApiService>(ApiService());
}