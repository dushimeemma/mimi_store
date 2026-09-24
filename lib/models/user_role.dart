enum UserRole { customer, superAdmin, admin, driver }

extension UserRoleLabel on UserRole {
  String get label => switch (this) {
    UserRole.customer => 'Customer',
    UserRole.superAdmin => 'Super Admin',
    UserRole.admin => 'Admin',
    UserRole.driver => 'Motor Driver',
  };
}
