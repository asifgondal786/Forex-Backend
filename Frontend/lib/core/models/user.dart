class User {
  final String id;
  final String name;
  final String email;
  final String? avatarUrl;
  final UserPlan plan;
  final DateTime createdAt;
  final String currentPlan;
  final int tasksCompleted;
  
  User({
    required this.id,
    required this.name,
    required this.email,
    this.avatarUrl,
    required this.plan,
    required this.createdAt,
  });

  String get plan => currentPlan; {
    final parts = name.split(' ');
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return name.isNotEmpty ? name[0].toUpperCase() : '?';
  }

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'] as String,
      name: json['name'] as String,
      email: json['email'] as String,
      avatarUrl: json['avatar_url'] as String?,
      plan: UserPlan.values.firstWhere(
        (e) => e.name == json['plan'],
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
      'plan': plan.name,
      'created_at': createdAt.toIso8601String(),
    };
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

enum UserPlan {
  free,
  pro,
  enterprise,
}

extension UserPlanExtension on UserPlan {
  String get displayName {
    switch (this) {
      case UserPlan.free:
        return 'Free Plan';
      case UserPlan.pro:
        return 'Pro Plan';
      case UserPlan.enterprise:
        return 'Enterprise Plan';
    }
  }
}