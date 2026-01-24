import 'package:flutter/foundation.dart';
import '../core/models/user.dart';
import '../services/api_service.dart';

class UserProvider with ChangeNotifier {
  final ApiService _apiService;
  
  User? _user;
  bool _isLoading = false;
  String? _error;

  UserProvider({required ApiService apiService}) : _apiService = apiService;

  // Getters
  User? get user => _user;
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get isAuthenticated => _user != null;

  // Fetch current user
  Future<void> fetchUser() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _user = await _apiService.getCurrentUser();
      _error = null;
    } catch (e) {
      _error = e.toString();
      debugPrint('Error fetching user: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Update user
  Future<void> updateUser({
    String? name,
    String? email,
  }) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _user = await _apiService.updateUser(
        name: name,
        email: email,
      );
      _error = null;
    } catch (e) {
      _error = e.toString();
      debugPrint('Error updating user: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Set user (for initial load or manual update)
  void setUser(User user) {
    _user = user;
    notifyListeners();
  }

  // Clear user (logout)
  void clearUser() {
    _user = null;
    notifyListeners();
  }

  // Logout (alias for clearUser)
  void logout() {
    clearUser();
  }

  // Clear error
  void clearError() {
    _error = null;
    notifyListeners();
  }
}