enum UserRole {
  owner('owner', 'Patron'),
  seller('seller', 'Vendeur'),
  viewer('viewer', 'Lecteur');

  const UserRole(this.code, this.label);

  final String code;
  final String label;

  static UserRole fromCode(String code) {
    return UserRole.values.firstWhere(
      (role) => role.code == code,
      orElse: () => UserRole.owner,
    );
  }
}
