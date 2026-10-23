import 'package:shared_preferences/shared_preferences.dart';

class StorageService {
  static final StorageService _instance = StorageService._internal();
  factory StorageService() => _instance;
  StorageService._internal();

  static const String _keyIsLoggedIn = 'is_logged_in';
  static const String _keyAuthToken = 'auth_token';
  
  static const String _keyUserId = 'user_id';
  static const String _keyUserName = 'user_name';
  static const String _keyUserEmail = 'user_email';
  static const String _keyUserRole = 'user_role';
  static const String _keyUserMobile = 'user_mobile';

  Future<void> saveUserData({
    required int userId,
    required String userName,
    required String userEmail,
    required String userRole,
    String? mobileNumber,
    String? token,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    
    await prefs.setBool(_keyIsLoggedIn, true);
    if (token != null) {
      await prefs.setString(_keyAuthToken, token);
    }
    
    await prefs.setInt(_keyUserId, userId);
    await prefs.setString(_keyUserName, userName);
    await prefs.setString(_keyUserEmail, userEmail);
    await prefs.setString(_keyUserRole, userRole);
    
    if (mobileNumber != null) {
      await prefs.setString(_keyUserMobile, mobileNumber);
    }
    
    print('User data saved:');
    print('ID: $userId');
    print('Name: $userName');
    print('Email: $userEmail');
    print('Role: $userRole');
    print('Mobile: $mobileNumber');
  }

  Future<Map<String, dynamic>> getUserData() async {
    final prefs = await SharedPreferences.getInstance();
    
    return {
      'isLoggedIn': prefs.getBool(_keyIsLoggedIn) ?? false,
      'token': prefs.getString(_keyAuthToken),
      
      'userId': prefs.getInt(_keyUserId),
      'userName': prefs.getString(_keyUserName),
      'userEmail': prefs.getString(_keyUserEmail),
      'userRole': prefs.getString(_keyUserRole),
      'mobileNumber': prefs.getString(_keyUserMobile),
    };
  }

  Future<void> clearUserData() async {
    final prefs = await SharedPreferences.getInstance();
    
    await prefs.remove(_keyIsLoggedIn);
    await prefs.remove(_keyAuthToken);
    
    await prefs.remove(_keyUserId);
    await prefs.remove(_keyUserName);
    await prefs.remove(_keyUserEmail);
    await prefs.remove(_keyUserRole);
    await prefs.remove(_keyUserMobile);
    
    print('All user data cleared');
  }

  Future<bool> isUserLoggedIn() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keyIsLoggedIn) ?? false;
  }

  Future<int?> getStoredUserId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_keyUserId);
  }

  Future<String?> getStoredUserName() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyUserName);
  }

  Future<String?> getStoredUserEmail() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyUserEmail);
  }

  Future<String?> getStoredUserRole() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyUserRole);
  }

  Future<String?> getStoredMobileNumber() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyUserMobile);
  }

  Future<void> printStoredData() async {
    final prefs = await SharedPreferences.getInstance();
    print('Stored User Data:');
    print('User ID: ${prefs.getInt(_keyUserId)}');
    print('User Name: ${prefs.getString(_keyUserName)}');
    print('User Email: ${prefs.getString(_keyUserEmail)}');
    print('User Role: ${prefs.getString(_keyUserRole)}');
    print('Mobile: ${prefs.getString(_keyUserMobile)}');
    print('Logged In: ${prefs.getBool(_keyIsLoggedIn)}');
  }
}