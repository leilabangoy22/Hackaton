import 'package:bloc/bloc.dart';
import 'package:fdr/features/auth/data/models/user_role.dart';
import 'package:fdr/services/api_service.dart';
import 'package:equatable/equatable.dart';
import 'package:fdr/services/storage_service.dart';
part 'login_event.dart';
part 'login_state.dart';

class LoginBloc extends Bloc<LoginEvent, LoginState> {
  final ApiService _apiService;
  final StorageService _storageService;
  LoginBloc(ApiService apiService)
    : _apiService = apiService,
      _storageService = StorageService(),
      super(LoginInitial()) {
    on<LoginSubmitted>(_onLoginSubmitted);
  }

  Future<void> _onLoginSubmitted(
    LoginSubmitted event,
    Emitter<LoginState> emit,
  ) async {
    if (event.name.isEmpty || event.password.isEmpty) {
      emit(LoginError('Name and password cannot be empty'));
      return;
    }

    emit(LoginLoading());

    try {
      final loginResponse = await _apiService.login(event.name, event.password);

      print('Login Response: $loginResponse');

      if (loginResponse['status_code'] == 200) {
        try {
          final allUsersResponse = await _apiService.getAllUsers();
          final userData = _findUserInList(allUsersResponse, event.name);
          final userRole = userRoleFromString(userData['role']);

          print('Found user data:');
          print('ID: ${userData['user_id'] ?? userData['id']}');
          print('Name: ${userData['name']}');
          print('Email: ${userData['email']}');
          print('Role: ${userData['role']}');
          print('Mobile: ${userData['mobile_number']}');

          await _saveUserData(userData: userData, userRole: userRole);

          emit(LoginSuccess(userRole));
        } catch (e) {
          print('Could not fetch users list: $e');
          final defaultRole = _getDefaultRoleForUser(event.name);
          print('Using default role: $defaultRole for user: ${event.name}');

          await _storageService.saveUserData(
            userId: 0,
            userName: event.name,
            userEmail: '${event.name}@gmail.com',
            userRole: defaultRole.toString().split('.').last,
            mobileNumber: null,
            token: 'dummy_token',
          );

          emit(LoginSuccess(defaultRole));
        }
      } else {
        emit(LoginError(loginResponse['message'] ?? 'Login failed'));
      }
    } catch (e) {
      print('Login error: $e');
      emit(LoginError('Login failed: ${e.toString()}'));
    }
  }

  Future<void> _saveUserData({
    required Map<String, dynamic> userData,
    required UserRole userRole,
  }) async {
    try {
      await _storageService.saveUserData(
        userId: userData['user_id'] ?? userData['id'] ?? 0,
        userName: userData['name'] ?? userData['username'] ?? 'Unknown',
        userEmail: userData['email'] ?? '${userData['name']}@example.com',
        userRole: userRole.toString().split('.').last,
        mobileNumber: userData['mobile_number']?.toString(),
        token: userData['token'] ?? 'dummy_token',
      );

      print('Successfully saved user data to local storage');

      await _storageService.printStoredData();
    } catch (e) {
      print('Error saving user data: $e');
    }
  }

  Map<String, dynamic> _findUserInList(dynamic usersResponse, String username) {
    print('Users List Response: $usersResponse');

    if (usersResponse is Map) {
      final usersData = usersResponse['data'] ?? usersResponse;

      if (usersData is List) {
        for (final user in usersData) {
          if (user is Map) {
            final userName = user['name'] ?? user['username'] ?? user['email'];
            if (userName?.toString().toLowerCase() == username.toLowerCase()) {
              print('Found matching user: $user');
              return user.cast<String, dynamic>();
            }
          }
        }
      }
    }

    throw Exception('User not found in users list');
  }

  UserRole _getDefaultRoleForUser(String username) {
    final lowerUsername = username.toLowerCase();

    if (lowerUsername.contains('admin') || lowerUsername.contains('dispatch')) {
      return UserRole.dispatcher;
    } else if (lowerUsername.contains('rescue') ||
        lowerUsername.contains('respond')) {
      return UserRole.rescuer;
    } else {
      return UserRole.user;
    }
  }

  UserRole _findUserRoleInList(dynamic usersResponse, String username) {
    print('Users List Response: $usersResponse');

    if (usersResponse is Map) {
      final usersData = usersResponse['data'] ?? usersResponse;

      if (usersData is List) {
        for (final user in usersData) {
          if (user is Map) {
            print('👤 Checking user: $user');

            final userName = user['name'] ?? user['username'] ?? user['email'];
            if (userName?.toString().toLowerCase() == username.toLowerCase()) {
              final roleString = user['role']?.toString();
              if (roleString != null) {
                print('Found role for $username: $roleString');
                return userRoleFromString(roleString);
              } else {
                print('User found but no role field');
                throw Exception('User found but role is missing');
              }
            }
          }
        }
      }
    }

    throw Exception('User not found in users list');
  }

}
