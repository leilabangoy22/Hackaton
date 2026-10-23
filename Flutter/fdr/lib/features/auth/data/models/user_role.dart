enum UserRole {
  user,
  dispatcher,
  rescuer,
  unknown,
}

UserRole userRoleFromString(String? role) {
  if (role == null) return UserRole.unknown;
  switch (role.toLowerCase()) {
    case 'user':
      return UserRole.user;
    case 'dispatcher':
      return UserRole.dispatcher;
    case 'rescuer':
      return UserRole.rescuer;
    default:
      return UserRole.unknown;
  }
}