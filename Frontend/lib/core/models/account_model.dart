class AccountModel {
  final String userId;
  final String userName;
  final double balance;
  final double totalAssets;
  final bool isOnline;
  final List<Asset> assets;

  AccountModel({
    required this.userId,
    required this.userName,
    required this.balance,
    required this.totalAssets,
    required this.isOnline,
    required this.assets,
  });

  factory AccountModel.fromJson(Map<String, dynamic> json) {
    return AccountModel(
      userId: json['user_id'] ?? '',
      userName: json['user_name'] ?? 'User',
      balance: (json['balance'] ?? 0).toDouble(),
      totalAssets: (json['total_assets'] ?? 0).toDouble(),
      isOnline: json['is_online'] ?? false,
      assets: (json['assets'] as List<dynamic>?)
              ?.map((asset) => Asset.fromJson(asset))
              .toList() ??
          [],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'user_id': userId,
      'user_name': userName,
      'balance': balance,
      'total_assets': totalAssets,
      'is_online': isOnline,
      'assets': assets.map((asset) => asset.toJson()).toList(),
    };
  }
}

class Asset {
  final String symbol;
  final double amount;
  final String currency;

  Asset({
    required this.symbol,
    required this.amount,
    required this.currency,
  });

  factory Asset.fromJson(Map<String, dynamic> json) {
    return Asset(
      symbol: json['symbol'] ?? '',
      amount: (json['amount'] ?? 0).toDouble(),
      currency: json['currency'] ?? 'USD',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'symbol': symbol,
      'amount': amount,
      'currency': currency,
    };
  }
}
