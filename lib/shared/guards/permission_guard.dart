import '../enums/permission.dart';

class PermissionGuard {
  const PermissionGuard._();

  static bool can(Set<Permission> permissions, Permission required) {
    return permissions.contains(required);
  }

  static bool canAny(Set<Permission> permissions, Iterable<Permission> required) {
    return required.any(permissions.contains);
  }

  static bool canAll(Set<Permission> permissions, Iterable<Permission> required) {
    return required.every(permissions.contains);
  }
}
