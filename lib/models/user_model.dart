import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:summerschool/constants/user_roles.dart';

class UserModel {
  const UserModel({
    required this.id,
    required this.name,
    required this.phone,
    required this.confessionFather,
    required this.role,
    required this.stage,
    required this.email,
    required this.createdAt,
  });

  final String id;
  final String name;
  final String phone;
  final String confessionFather;
  final UserRole role;
  final String stage;
  final String email;
  final DateTime createdAt;

  // Alias for projects that still refer to this field as "class".
  String get className => stage;

  bool get isManager => role == UserRole.manager;
  bool get isMemberManager => role == UserRole.memberManager;
  bool get isMember => role == UserRole.member;

  UserModel copyWith({
    String? id,
    String? name,
    String? phone,
    String? confessionFather,
    UserRole? role,
    String? stage,
    String? email,
    DateTime? createdAt,
  }) {
    return UserModel(
      id: id ?? this.id,
      name: name ?? this.name,
      phone: phone ?? this.phone,
      confessionFather: confessionFather ?? this.confessionFather,
      role: role ?? this.role,
      stage: stage ?? this.stage,
      email: email ?? this.email,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  factory UserModel.fromMap(Map<String, dynamic> map) {
    final createdAtRaw = map['createdAt'];

    return UserModel(
      id: (map['id'] ?? '').toString(),
      name: (map['name'] ?? '').toString(),
      phone: (map['phone'] ?? '').toString(),
      confessionFather: (map['confessionFather'] ?? '').toString(),
      role: UserRoleX.fromValue(map['role']?.toString()),
      stage: (map['stage'] ?? map['class'] ?? '').toString(),
      email: (map['email'] ?? '').toString(),
      createdAt: _parseCreatedAt(createdAtRaw),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'phone': phone,
      'confessionFather': confessionFather,
      'role': role.value,
      'stage': stage,
      'class': stage,
      'email': email,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }

  static DateTime _parseCreatedAt(dynamic value) {
    if (value is Timestamp) {
      return value.toDate();
    }
    if (value is DateTime) {
      return value;
    }
    if (value is String) {
      return DateTime.tryParse(value) ?? DateTime.now();
    }
    return DateTime.now();
  }
}
