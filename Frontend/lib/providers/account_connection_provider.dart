import 'package:flutter/material.dart';
import 'package:forex_companion/core/models/account_connection.dart';
import 'package:forex_companion/services/api_service.dart';
import 'package:forex_companion/core/widgets/custom_snackbar.dart';

class AccountConnectionProvider extends ChangeNotifier {
  final ApiService _apiService = ApiService();
  List<AccountConnection> _connections = [];
  bool _isLoading = false;
  String? _selectedAccountId;

  List<AccountConnection> get connections => _connections;
  bool get isLoading => _isLoading;
  String? get selectedAccountId => _selectedAccountId;

  AccountConnection? get selectedAccount {
    if (_connections.isNotEmpty) {
      if (_selectedAccountId == null) {
        _selectedAccountId = _connections.first.id;
      }
      return _connections.firstWhere(
        (conn) => conn.id == _selectedAccountId,
        orElse: () => _connections.first,
      );
    }
    // Fallback to mock data if no connections
    return AccountConnection(
      id: 'demo-gondalgondal0000vlk2',
      broker: 'Forex.com',
      accountNumber: 'demo-gondalgondal0000vlk2',
      balance: 10000.00,
      currency: 'USD',
      status: AccountConnectionStatus.connected,
    );
  }

  Future<void> loadConnections() async {
    _isLoading = true;
    notifyListeners();

    try {
      final connections = await _apiService.getAccountConnections();
      debugPrint('Loaded connections: $connections');
      if (connections.isNotEmpty) {
        _connections = connections;
        if (_selectedAccountId == null) {
          _selectedAccountId = connections.first.id;
          debugPrint('Selected account: $_selectedAccountId');
        }
      }
    } catch (error) {
      // Load mock data if API fails
      _connections = _createMockConnections();
      _selectedAccountId = _connections.first.id;
      debugPrint('Failed to load account connections: $error');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> connectForexAccount(String username, String password) async {
    _isLoading = true;
    notifyListeners();

    try {
      final connection = await _apiService.connectForexAccount(username, password);
      _connections.add(connection);
      
      if (_selectedAccountId == null) {
        _selectedAccountId = connection.id;
      }
      
      debugPrint('Successfully connected to Forex.com');
    } catch (error) {
      debugPrint('Connection failed: $error');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> disconnectAccount(String accountId) async {
    _isLoading = true;
    notifyListeners();

    try {
      await _apiService.disconnectAccount(accountId);
      _connections.removeWhere((conn) => conn.id == accountId);
      
      if (_selectedAccountId == accountId) {
        _selectedAccountId = _connections.isNotEmpty ? _connections.first.id : null;
      }
      
      debugPrint('Account disconnected');
    } catch (error) {
      debugPrint('Disconnection failed: $error');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void selectAccount(String accountId) {
    if (_selectedAccountId != accountId) {
      _selectedAccountId = accountId;
      notifyListeners();
    }
  }

  List<AccountConnection> _createMockConnections() {
    return [
      AccountConnection(
        id: 'demo_account_001',
        broker: 'Forex.com',
        accountNumber: 'FXCM-12345',
        balance: 5843.21,
        currency: 'USD',
        status: AccountConnectionStatus.connected,
      ),
    ];
  }
}