enum UserRole { manager, memberManager, member }

extension UserRoleX on UserRole {
  static const List<UserRole> all = [
    UserRole.manager,
    UserRole.memberManager,
    UserRole.member,
  ];

  String get value {
    switch (this) {
      case UserRole.manager:
        return 'manager';
      case UserRole.memberManager:
        return 'member_manager';
      case UserRole.member:
        return 'member';
    }
  }

  String get label {
    switch (this) {
      case UserRole.manager:
        return 'Manager';
      case UserRole.memberManager:
        return 'Member Manager';
      case UserRole.member:
        return 'Member';
    }
  }

  bool get canManageUsers =>
      this == UserRole.manager || this == UserRole.memberManager;

  static UserRole fromValue(String? value) {
    switch (value) {
      case 'manager':
        return UserRole.manager;
      case 'member_manager':
        return UserRole.memberManager;
      case 'member':
      default:
        return UserRole.member;
    }
  }
}
