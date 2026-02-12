enum AccountConnectionStatus {
  connected,
  connecting,
  disconnected,
  error,
}

class AccountConnection {
  final String id;
  final String broker;
  final String accountNumber;
  final double balance;
  final String currency;
  final AccountConnectionStatus status;
  final DateTime? lastUpdated;
  final String? errorMessage;

  AccountConnection({
    required this.id,
    required this.broker,
    required this.accountNumber,
    required this.balance,
    required this.currency,
    this.status = AccountConnectionStatus.connected,
    this.lastUpdated,
    this.errorMessage,
  });

  factory AccountConnection.fromJson(Map<String, dynamic> json) {
    return AccountConnection(
      id: json['id'] ?? '',
      broker: json['broker'] ?? 'Forex.com',
      accountNumber: json['account_number'] ?? '',
      balance: (json['balance'] ?? 0.0).toDouble(),
      currency: json['currency'] ?? 'USD',
      status: _parseStatus(json['status']),
      lastUpdated: json['last_updated'] != null 
          ? DateTime.parse(json['last_updated']) 
          : null,
      errorMessage: json['error_message'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'broker': broker,
      'account_number': accountNumber,
      'balance': balance,
      'currency': currency,
      'status': _statusToString(status),
      'last_updated': lastUpdated?.toIso8601String(),
      'error_message': errorMessage,
    };
  }

  AccountConnection copyWith({
    String? id,
    String? broker,
    String? accountNumber,
    double? balance,
    String? currency,
    AccountConnectionStatus? status,
    DateTime? lastUpdated,
    String? errorMessage,
  }) {
    return AccountConnection(
      id: id ?? this.id,
      broker: broker ?? this.broker,
      accountNumber: accountNumber ?? this.accountNumber,
      balance: balance ?? this.balance,
      currency: currency ?? this.currency,
      status: status ?? this.status,
      lastUpdated: lastUpdated ?? this.lastUpdated,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }

  static AccountConnectionStatus _parseStatus(String? status) {
    switch (status?.toLowerCase()) {
      case 'connected':
        return AccountConnectionStatus.connected;
      case 'connecting':
        return AccountConnectionStatus.connecting;
      case 'disconnected':
        return AccountConnectionStatus.disconnected;
      case 'error':
        return AccountConnectionStatus.error;
      default:
        return AccountConnectionStatus.connected;
    }
  }

  static String _statusToString(AccountConnectionStatus status) {
    switch (status) {
      case AccountConnectionStatus.connected:
        return 'connected';
      case AccountConnectionStatus.connecting:
        return 'connecting';
      case AccountConnectionStatus.disconnected:
        return 'disconnected';
      case AccountConnectionStatus.error:
        return 'error';
    }
  }

  bool get isConnected => status == AccountConnectionStatus.connected;
  bool get isConnecting => status == AccountConnectionStatus.connecting;
  bool get isDisconnected => status == AccountConnectionStatus.disconnected;
  bool get hasError => status == AccountConnectionStatus.error;
}