enum UserPlan { 
  free, 
  premium, 
  enterprise;

  String get displayName {
    switch (this) {
      case UserPlan.free:
        return 'Free Plan';
      case UserPlan.premium:
        return 'Premium Plan';
      case UserPlan.enterprise:
        return 'Enterprise Plan';
    }
  }
}

class User {
  final String id;
  final String name;
  final String email;
  final String? avatarUrl;
  final UserPlan plan;
  final DateTime createdAt;
  final Map<String, dynamic>? preferences;

  User({
    required this.id,
    required this.name,
    required this.email,
    this.avatarUrl,
    this.plan = UserPlan.free,
    required this.createdAt,
    this.preferences,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'] as String,
      name: json['name'] as String,
      email: json['email'] as String,
      avatarUrl: json['avatar_url'] as String?,
      plan: UserPlan.values.firstWhere(
        (e) => e.name == (json['plan'] as String?)?.toLowerCase(),
        orElse: () => UserPlan.free,
      ),
      createdAt: DateTime.parse(json['created_at'] as String),
      preferences: json['preferences'] as Map<String, dynamic>?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'email': email,
      'avatar_url': avatarUrl,
      'plan': plan.name,
      'created_at': createdAt.toIso8601String(),
      'preferences': preferences,
    };
  }

  String get initials {
    final nameParts = name.split(' ');
    if (nameParts.length >= 2) {
      return '${nameParts[0][0]}${nameParts[1][0]}'.toUpperCase();
    } else if (name.isNotEmpty) {
      return name[0].toUpperCase();
    }
    return 'U';
  }

  User copyWith({
    String? id,
    String? name,
    String? email,
    String? avatarUrl,
    UserPlan? plan,
    DateTime? createdAt,
    Map<String, dynamic>? preferences,
  }) {
    return User(
      id: id ?? this.id,
      name: name ?? this.name,
      email: email ?? this.email,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      plan: plan ?? this.plan,
      createdAt: createdAt ?? this.createdAt,
      preferences: preferences ?? this.preferences,
    );
  }
}
