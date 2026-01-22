import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../models/user_model.dart';

class AuthService {
  static const String _baseUrl = 'http://127.0.0.1:8080';
  static const String _tokenKey = 'auth_token';
  static const String _refreshTokenKey = 'refresh_token';
  static const String _userKey = 'user_data';
  
  final _secureStorage = const FlutterSecureStorage();
  
  // State management
  final _authStateController = StreamController<bool>.broadcast();
  final _userController = StreamController<User?>.broadcast();
  
  Stream<bool> get authStateStream => _authStateController.stream;
  Stream<User?> get userStream => _userController.stream;
  
  User? _currentUser;
  String? _currentToken;
  
  User? get currentUser => _currentUser;
  bool get isAuthenticated => _currentToken != null;
  
  AuthService() {
    _initializeAuth();
  }
  
  /// Initialize auth on app startup
  Future<void> _initializeAuth() async {
    try {
      _currentToken = await _secureStorage.read(key: _tokenKey);
      final userData = await _secureStorage.read(key: _userKey);
      
      if (_currentToken != null && userData != null) {
        _currentUser = User.fromJson(jsonDecode(userData));
        _authStateController.add(true);
        _userController.add(_currentUser);
        
        // Verify token is still valid
        await _verifyToken();
      } else {
        _authStateController.add(false);
      }
    } catch (e) {
      debugPrint('❌ Auth initialization error: $e');
      _authStateController.add(false);
    }
  }
  
  /// Signup new user
  Future<AuthResponse> signup({
    required String email,
    required String password,
    required String username,
    required String fullName,
  }) async {
    try {
      final request = SignupRequest(
        email: email,
        password: password,
        username: username,
        fullName: fullName,
      );
      
      final response = await http.post(
        Uri.parse('$_baseUrl/api/auth/signup'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(request.toJson()),
      ).timeout(const Duration(seconds: 30));
      
      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = AuthResponse.fromJson(jsonDecode(response.body));
        
        if (data.success && data.user != null && data.token != null) {
          await _saveAuthData(data.user!, data.token!);
          return data;
        }
      }
      
      return AuthResponse(
        success: false,
        message: 'Signup failed: ${response.statusCode}',
      );
    } catch (e) {
      return AuthResponse(
        success: false,
        message: 'Signup error: $e',
      );
    }
  }
  
  /// Login user
  Future<AuthResponse> login({
    required String email,
    required String password,
  }) async {
    try {
      final request = LoginRequest(
        email: email,
        password: password,
      );
      
      final response = await http.post(
        Uri.parse('$_baseUrl/api/auth/login'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(request.toJson()),
      ).timeout(const Duration(seconds: 30));
      
      if (response.statusCode == 200) {
        final data = AuthResponse.fromJson(jsonDecode(response.body));
        
        if (data.success && data.user != null && data.token != null) {
          await _saveAuthData(data.user!, data.token!);
          return data;
        }
      }
      
      return AuthResponse(
        success: false,
        message: 'Login failed: ${response.statusCode}',
      );
    } catch (e) {
      return AuthResponse(
        success: false,
        message: 'Login error: $e',
      );
    }
  }
  
  /// Logout user
  Future<bool> logout() async {
    try {
      if (_currentToken != null) {
        await http.post(
          Uri.parse('$_baseUrl/api/auth/logout'),
          headers: _getHeaders(),
        ).timeout(const Duration(seconds: 10));
      }
      
      await _clearAuthData();
      return true;
    } catch (e) {
      debugPrint('❌ Logout error: $e');
      return false;
    }
  }
  
  /// Get current user
  Future<User?> getCurrentUser() async {
    try {
      if (!isAuthenticated) return null;
      
      final response = await http.get(
        Uri.parse('$_baseUrl/api/users/me'),
        headers: _getHeaders(),
      ).timeout(const Duration(seconds: 10));
      
      if (response.statusCode == 200) {
        _currentUser = User.fromJson(jsonDecode(response.body));
        _userController.add(_currentUser);
        
        // Save updated user data
        await _secureStorage.write(
          key: _userKey,
          value: jsonEncode(_currentUser!.toJson()),
        );
        
        return _currentUser;
      }
    } catch (e) {
      debugPrint('❌ Get current user error: $e');
    }
    return null;
  }
  
  /// Verify token is valid
  Future<bool> _verifyToken() async {
    try {
      if (_currentToken == null) return false;
      
      final response = await http.post(
        Uri.parse('$_baseUrl/api/auth/verify'),
        headers: _getHeaders(),
      ).timeout(const Duration(seconds: 10));
      
      if (response.statusCode == 200) {
        return true;
      } else {
        await _clearAuthData();
        return false;
      }
    } catch (e) {
      return false;
    }
  }
  
  /// Save authentication data
  Future<void> _saveAuthData(User user, String token) async {
    _currentUser = user;
    _currentToken = token;
    
    await _secureStorage.write(key: _tokenKey, value: token);
    await _secureStorage.write(key: _userKey, value: jsonEncode(user.toJson()));
    
    _authStateController.add(true);
    _userController.add(user);
  }
  
  /// Clear authentication data
  Future<void> _clearAuthData() async {
    _currentUser = null;
    _currentToken = null;
    
    await _secureStorage.delete(key: _tokenKey);
    await _secureStorage.delete(key: _refreshTokenKey);
    await _secureStorage.delete(key: _userKey);
    
    _authStateController.add(false);
    _userController.add(null);
  }
  
  /// Get authorization headers
  Map<String, String> _getHeaders() {
    return {
      'Content-Type': 'application/json',
      if (_currentToken != null) 'Authorization': 'Bearer $_currentToken',
    };
  }
  
  /// Dispose streams
  void dispose() {
    _authStateController.close();
    _userController.close();
  }
}
