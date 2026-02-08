class HeaderUser {
  final String id;
  final String name;
  final String status;
  final String? avatarUrl;
  final String riskLevel;

  HeaderUser({
    required this.id,
    required this.name,
    required this.status,
    this.avatarUrl,
    required this.riskLevel,
  });

  factory HeaderUser.fromJson(Map<String, dynamic> json) {
    return HeaderUser(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      status: json['status'] as String? ?? 'Available Online',
      avatarUrl: json['avatar_url'] as String?,
      riskLevel: json['risk_level'] as String? ?? 'Moderate',
    );
  }
}

class HeaderBalance {
  final double amount;
  final String currency;

  HeaderBalance({
    required this.amount,
    required this.currency,
  });

  factory HeaderBalance.fromJson(Map<String, dynamic> json) {
    final amount = json['amount'];
    return HeaderBalance(
      amount: amount is num ? amount.toDouble() : 0.0,
      currency: json['currency'] as String? ?? 'USD',
    );
  }
}

class HeaderNotifications {
  final int unread;

  HeaderNotifications({required this.unread});

  factory HeaderNotifications.fromJson(Map<String, dynamic> json) {
    final unread = json['unread'];
    return HeaderNotifications(
      unread: unread is num ? unread.toInt() : 0,
    );
  }
}

class HeaderData {
  final HeaderUser user;
  final HeaderBalance balance;
  final HeaderNotifications notifications;

  HeaderData({
    required this.user,
    required this.balance,
    required this.notifications,
  });

  factory HeaderData.fromJson(Map<String, dynamic> json) {
    return HeaderData(
      user: HeaderUser.fromJson(json['user'] as Map<String, dynamic>? ?? {}),
      balance: HeaderBalance.fromJson(json['balance'] as Map<String, dynamic>? ?? {}),
      notifications: HeaderNotifications.fromJson(
        json['notifications'] as Map<String, dynamic>? ?? {},
      ),
    );
  }
}
