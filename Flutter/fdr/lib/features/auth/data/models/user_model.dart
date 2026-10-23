class User {
  final int id;
  final String name;
  final String email;
  final String phone;
  final UserRole role;
  final bool isActive;
  final double? latitude;
  final double? longitude;
  final DateTime? lastActive;
  final String? profileImageUrl;

  const User({
    required this.id,
    required this.name,
    required this.email,
    required this.phone,
    required this.role,
    required this.isActive,
    this.latitude,
    this.longitude,
    this.lastActive,
    this.profileImageUrl,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['user_id'] ?? json['id'] ?? 0,
      name: json['name'] ?? 'Unknown User',
      email: json['email'] ?? '',
      phone: json['phone'] ?? '',
      role: _parseRoleFromJson(json['role']),
      isActive: json['is_active'] ?? false,
      latitude: (json['latitude'] ?? 0.0).toDouble(),
      longitude: (json['longitude'] ?? 0.0).toDouble(),
      lastActive: json['last_active'] != null
          ? DateTime.parse(json['last_active'])
          : null,
      profileImageUrl: json['profile_image_url'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'user_id': id,
      'name': name,
      'email': email,
      'phone': phone,
      'role': role.name,
      'is_active': isActive,
      'latitude': latitude,
      'longitude': longitude,
      'last_active': lastActive?.toIso8601String(),
      'profile_image_url': profileImageUrl,
    };
  }

  static UserRole _parseRoleFromJson(dynamic role) {
    if (role == null) return UserRole.user;

    final roleStr = role.toString().toLowerCase();
    switch (roleStr) {
      case 'rescuer':
      case 'rescue':
        return UserRole.rescuer;
      case 'dispatcher':
      case 'dispatch':
        return UserRole.dispatcher;
      case 'admin':
        return UserRole.admin;
      default:
        return UserRole.user;
    }
  }

  User copyWith({
    int? id,
    String? name,
    String? email,
    String? phone,
    UserRole? role,
    bool? isActive,
    double? latitude,
    double? longitude,
    DateTime? lastActive,
    String? profileImageUrl,
  }) {
    return User(
      id: id ?? this.id,
      name: name ?? this.name,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      role: role ?? this.role,
      isActive: isActive ?? this.isActive,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      lastActive: lastActive ?? this.lastActive,
      profileImageUrl: profileImageUrl ?? this.profileImageUrl,
    );
  }

  bool get isRescuer => role == UserRole.rescuer;
  bool get isDispatcher => role == UserRole.dispatcher;
  bool get isAdmin => role == UserRole.admin;

  @override
  String toString() {
    return 'User(id: $id, name: $name, role: $role, isActive: $isActive)';
  }
}

enum UserRole { user, rescuer, dispatcher, admin }
