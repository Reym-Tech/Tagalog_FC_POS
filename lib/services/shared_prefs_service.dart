import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

class SharedPrefsService {
  static const String _userIdKey = 'user_id';
  static const String _fullNameKey = 'full_name';
  static const String _usernameKey = 'username';
  static const String _roleKey = 'role';
  static const String _isLoggedInKey = 'is_logged_in';
  static const String _userDataKey = 'user_data';

  // Save user data - FIXED: Store UUID as string instead of converting to int
  static Future<void> saveUserData({
    required String userId,  // Changed from int to String
    required String fullName,
    required String username,
    required String role,
  }) async {
    final prefs = await SharedPreferences.getInstance();

    // Store userId as string (UUID from Supabase)
    await prefs.setString(_userIdKey, userId);
    await prefs.setString(_fullNameKey, fullName);
    await prefs.setString(_usernameKey, username);
    await prefs.setString(_roleKey, role);
    await prefs.setBool(_isLoggedInKey, true);

    // Save complete user data as JSON
    final userData = {
      'user_id': userId,
      'full_name': fullName,
      'username': username,
      'role': role,
      'is_logged_in': true,
    };
    await prefs.setString(_userDataKey, json.encode(userData));

    print('💾 SharedPrefs: User data saved for: $username (ID: $userId)');
  }

  // Get user data as Map
  static Future<Map<String, dynamic>> getUserData() async {
    final prefs = await SharedPreferences.getInstance();

    // Try to get from JSON first
    final userJson = prefs.getString(_userDataKey);
    if (userJson != null && userJson.isNotEmpty) {
      try {
        final data = json.decode(userJson);
        print('📖 SharedPrefs: Retrieved user data from JSON: $data');
        return data;
      } catch (e) {
        print('❌ SharedPrefs: Error decoding user JSON: $e');
      }
    }

    // Fallback to individual keys
    final userData = {
      'user_id': prefs.getString(_userIdKey) ?? '0',
      'full_name': prefs.getString(_fullNameKey) ?? '',
      'username': prefs.getString(_usernameKey) ?? '',
      'role': prefs.getString(_roleKey) ?? '',
      'is_logged_in': prefs.getBool(_isLoggedInKey) ?? false,
    };

    print('📖 SharedPrefs: Retrieved user data from individual keys: $userData');
    return userData;
  }

  // Check if user is logged in
  static Future<bool> isLoggedIn() async {
    final prefs = await SharedPreferences.getInstance();
    final isLoggedIn = prefs.getBool(_isLoggedInKey) ?? false;
    print('🔐 SharedPrefs: isLoggedIn = $isLoggedIn');
    return isLoggedIn;
  }

  // Clear all user data (logout)
  static Future<void> clearUserData() async {
    final prefs = await SharedPreferences.getInstance();

    await prefs.remove(_userIdKey);
    await prefs.remove(_fullNameKey);
    await prefs.remove(_usernameKey);
    await prefs.remove(_roleKey);
    await prefs.remove(_isLoggedInKey);
    await prefs.remove(_userDataKey);

    print('🗑️ SharedPrefs: User data cleared');
  }

  // Get user ID
  static Future<String> getUserId() async {
    final prefs = await SharedPreferences.getInstance();
    final userId = prefs.getString(_userIdKey) ?? '0';
    print('🆔 SharedPrefs: User ID = $userId');
    return userId;
  }

  // Get username
  static Future<String> getUsername() async {
    final prefs = await SharedPreferences.getInstance();
    final username = prefs.getString(_usernameKey) ?? '';
    print('👤 SharedPrefs: Username = $username');
    return username;
  }

  // Get user role
  static Future<String> getUserRole() async {
    final prefs = await SharedPreferences.getInstance();
    final role = prefs.getString(_roleKey) ?? '';
    print('🎭 SharedPrefs: Role = $role');
    return role;
  }
}