import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/supabase_service.dart';
import '../services/shared_prefs_service.dart';

class AuthProvider with ChangeNotifier {
  bool _isLoading = false;
  String _errorMessage = '';
  Map<String, dynamic> _userData = {};
  User? _currentUser;

  bool get isLoading => _isLoading;
  String get errorMessage => _errorMessage;
  Map<String, dynamic> get userData => _userData;
  bool get isLoggedIn => _currentUser != null || (_userData['is_logged_in'] ?? false);
  bool get isAdmin => _userData['role'] == 'admin';
  bool get isOnline => true; // Always online with Supabase-only setup
  String? get username => _userData['username'];
  String? get fullName => _userData['full_name'];
  String? get userId => _currentUser?.id ?? _userData['user_id']?.toString();

  final SupabaseService _supabase = SupabaseService();

  Future<void> initialize() async {
    _isLoading = true;
    notifyListeners();

    try {
      // Initialize Supabase
      await _supabase.initialize();

      // Check if user is already logged in
      _currentUser = _supabase.currentUser;

      if (_currentUser != null) {
        // Get user data from Supabase
        final userData = await _supabase.getUserById(_currentUser!.id);
        if (userData != null) {
          _userData = Map<String, dynamic>.from(userData);
          _userData['is_logged_in'] = true;

          // Save to local storage
          await SharedPrefsService.saveUserData(
            userId: _currentUser!.id,
            fullName: _userData['full_name'] ?? '',
            username: _userData['username'] ?? '',
            role: _userData['role'] ?? '',
          );
        }
      } else {
        // Check local storage
        final isLoggedIn = await SharedPrefsService.isLoggedIn();
        if (isLoggedIn) {
          _userData = await SharedPrefsService.getUserData();
        }
      }

      print('✅ Auth provider initialized successfully');

    } catch (e) {
      print('❌ Auth initialization error: $e');
      _errorMessage = 'Initialization failed: ${e.toString()}';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> login(String username, String password) async {
    _isLoading = true;
    _errorMessage = '';
    notifyListeners();

    try {
      print('🔐 Attempting login for user: $username');
      
      // Login with Supabase
      final user = await _supabase.loginUser(username, password);

      if (user != null) {
        _userData = Map<String, dynamic>.from(user);
        _userData['is_logged_in'] = true;

        // Store user ID as string for consistency
        final userId = user['id']?.toString() ?? '';
        _userData['user_id'] = userId;

        // Save to local storage
        await SharedPrefsService.saveUserData(
          userId: userId,
          fullName: user['full_name'] ?? '',
          username: user['username'] ?? '',
          role: user['role'] ?? '',
        );

        print('✅ Login successful for user: $username');
        _isLoading = false;
        notifyListeners();
        return true;
      } else {
        _errorMessage = 'Invalid username or password';
        print('❌ Login failed: Invalid credentials');
      }
    } catch (e) {
      _errorMessage = 'Login error: ${e.toString()}';
      print('❌ Login error: $e');
    }

    _isLoading = false;
    notifyListeners();
    return false;
  }

  Future<void> logout() async {
    try {
      if (_supabase.currentUser != null) {
        await _supabase.signOut();
      }

      await SharedPrefsService.clearUserData();
      _userData = {};
      _currentUser = null;
      _errorMessage = '';

      print('👋 User logged out successfully');
      notifyListeners();
    } catch (e) {
      _errorMessage = 'Logout error: ${e.toString()}';
      print('❌ Logout error: $e');
      notifyListeners();
    }
  }

  Future<bool> checkLoginStatus() async {
    try {
      if (_supabase.currentUser != null) {
        return true;
      }

      final isLoggedIn = await SharedPrefsService.isLoggedIn();
      if (isLoggedIn) {
        _userData = await SharedPrefsService.getUserData();
      }
      return isLoggedIn;
    } catch (e) {
      print('❌ Error checking login status: $e');
      return false;
    }
  }

  void clearError() {
    _errorMessage = '';
    notifyListeners();
  }
}