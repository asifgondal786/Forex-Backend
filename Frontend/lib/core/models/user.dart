// User plan enum with display names
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

// User model class
class User {
  final String id;
  final String name;
  final String email;
  final String? avatarUrl;
  final UserPlan plan;
  final DateTime createdAt;

  User({
    required this.id,
    required this.name,
    required this.email,
    this.avatarUrl,
    this.plan = UserPlan.free,
    required this.createdAt,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'] as String,
      name: json['name'] as String,
      email: json['email'] as String,
      avatarUrl: json['avatar_url'] as String?,
      plan: UserPlan.values.firstWhere(
        (e) => e.toString().split('.').last == json['plan'],
        orElse: () => UserPlan.free,
      ),
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'email': email,
      'avatar_url': avatarUrl,
      'plan': plan.toString().split('.').last,
      'created_at': createdAt.toIso8601String(),
    };
  }

  // Get user initials for avatar
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
  }) {
    return User(
      id: id ?? this.id,
      name: name ?? this.name,
      email: email ?? this.email,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      plan: plan ?? this.plan,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}