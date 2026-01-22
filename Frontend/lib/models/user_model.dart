/// User model for authentication and profile management
class User {
  final String id;
  final String email;
  final String? username;
  final String? fullName;
  final String? avatar;
  final DateTime createdAt;
  final bool isVerified;
  final Map<String, dynamic>? riskProfile;
  final double? initialInvestment;
  
  User({
    required this.id,
    required this.email,
    this.username,
    this.fullName,
    this.avatar,
    required this.createdAt,
    this.isVerified = false,
    this.riskProfile,
    this.initialInvestment,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'] ?? json['user_id'] ?? '',
      email: json['email'] ?? '',
      username: json['username'],
      fullName: json['full_name'] ?? json['fullName'],
      avatar: json['avatar'],
      createdAt: json['created_at'] != null 
          ? DateTime.parse(json['created_at'].toString())
          : DateTime.now(),
      isVerified: json['is_verified'] ?? json['isVerified'] ?? false,
      riskProfile: json['risk_profile'] ?? json['riskProfile'],
      initialInvestment: (json['initial_investment'] ?? json['initialInvestment'])?.toDouble(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'email': email,
      'username': username,
      'full_name': fullName,
      'avatar': avatar,
      'created_at': createdAt.toIso8601String(),
      'is_verified': isVerified,
      'risk_profile': riskProfile,
      'initial_investment': initialInvestment,
    };
  }

  User copyWith({
    String? id,
    String? email,
    String? username,
    String? fullName,
    String? avatar,
    DateTime? createdAt,
    bool? isVerified,
    Map<String, dynamic>? riskProfile,
    double? initialInvestment,
  }) {
    return User(
      id: id ?? this.id,
      email: email ?? this.email,
      username: username ?? this.username,
      fullName: fullName ?? this.fullName,
      avatar: avatar ?? this.avatar,
      createdAt: createdAt ?? this.createdAt,
      isVerified: isVerified ?? this.isVerified,
      riskProfile: riskProfile ?? this.riskProfile,
      initialInvestment: initialInvestment ?? this.initialInvestment,
    );
  }
}

/// Request models for authentication
class SignupRequest {
  final String email;
  final String password;
  final String username;
  final String fullName;

  SignupRequest({
    required this.email,
    required this.password,
    required this.username,
    required this.fullName,
  });

  Map<String, dynamic> toJson() => {
    'email': email,
    'password': password,
    'username': username,
    'full_name': fullName,
  };
}

class LoginRequest {
  final String email;
  final String password;

  LoginRequest({
    required this.email,
    required this.password,
  });

  Map<String, dynamic> toJson() => {
    'email': email,
    'password': password,
  };
}

/// Response models
class AuthResponse {
  final bool success;
  final String message;
  final User? user;
  final String? token;
  final String? refreshToken;

  AuthResponse({
    required this.success,
    required this.message,
    this.user,
    this.token,
    this.refreshToken,
  });

  factory AuthResponse.fromJson(Map<String, dynamic> json) {
    return AuthResponse(
      success: json['success'] ?? false,
      message: json['message'] ?? 'Unknown error',
      user: json['user'] != null ? User.fromJson(json['user']) : null,
      token: json['token'] ?? json['access_token'],
      refreshToken: json['refresh_token'],
    );
  }
}
