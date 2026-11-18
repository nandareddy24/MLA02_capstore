/// Represents an authenticated technician or operator profile in FixWise.
class UserProfileModel {
  const UserProfileModel({
    required this.id,
    required this.fullName,
    required this.email,
    required this.role,
    required this.createdAt,
  });

  final String id;
  final String fullName;
  final String email;
  final String role;
  final DateTime createdAt;

  UserProfileModel copyWith({
    String? id,
    String? fullName,
    String? email,
    String? role,
    DateTime? createdAt,
  }) {
    return UserProfileModel(
      id: id ?? this.id,
      fullName: fullName ?? this.fullName,
      email: email ?? this.email,
      role: role ?? this.role,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  Map<String, Object?> toMap() => {
        'id': id,
        'full_name': fullName,
        'email': email,
        'role': role,
        'created_at': createdAt.toIso8601String(),
      };

  factory UserProfileModel.fromMap(Map<String, Object?> map) {
    return UserProfileModel(
      id: map['id'] as String,
      fullName: map['full_name'] as String,
      email: map['email'] as String,
      role: (map['role'] as String?) ?? 'Field Technician',
      createdAt: DateTime.parse(map['created_at'] as String),
    );
  }

  factory UserProfileModel.fromJson(Map<String, dynamic> json) {
    return UserProfileModel(
      id: json['id'].toString(),
      fullName: (json['full_name'] ?? json['name'] ?? '') as String,
      email: (json['email'] ?? '') as String,
      role: (json['role'] ?? 'Field Technician') as String,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : DateTime.now(),
    );
  }
}
