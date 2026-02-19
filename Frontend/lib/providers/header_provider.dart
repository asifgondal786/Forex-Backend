import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import '../core/models/header_model.dart';
import '../services/api_service.dart';

class HeaderProvider with ChangeNotifier {
  final ApiService _apiService;

  HeaderData? _header;
  bool _isLoading = false;
  String? _error;

  HeaderProvider({required ApiService apiService}) : _apiService = apiService;

  HeaderData? get header => _header;
  bool get isLoading => _isLoading;
  String? get error => _error;

  Future<void> fetchHeader() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      const devUserId = String.fromEnvironment('DEV_USER_ID', defaultValue: '');
      final firebaseUser = firebase_auth.FirebaseAuth.instance.currentUser;
      if (firebaseUser == null && devUserId.isEmpty) {
        _isLoading = false;
        _error = null;
        notifyListeners();
        return;
      }

      _header = await _apiService.getHeader();
      _error = null;
    } catch (e) {
      _error = e.toString();
      if (kDebugMode) {
        debugPrint('Error fetching header: $e');
      }
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void setHeader(HeaderData header) {
    _header = header;
    notifyListeners();
  }

  void incrementUnreadNotifications({int by = 1}) {
    if (_header == null || by <= 0) {
      return;
    }

    final currentHeader = _header!;
    _header = HeaderData(
      user: currentHeader.user,
      balance: currentHeader.balance,
      notifications: HeaderNotifications(
        unread: currentHeader.notifications.unread + by,
      ),
    );
    notifyListeners();
  }

  void clearHeader() {
    _header = null;
    notifyListeners();
  }
}
