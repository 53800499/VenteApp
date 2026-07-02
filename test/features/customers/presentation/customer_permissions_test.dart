import 'package:flutter_test/flutter_test.dart';
import 'package:venteapp/shared/enums/permission.dart';
import 'package:venteapp/shared/enums/user_role.dart';
import 'package:venteapp/shared/guards/permission_guard.dart';

void main() {
  test('le rôle viewer peut lire les clients mais pas les créer', () {
    final permissions = permissionsForRole(UserRole.viewer);

    expect(
      PermissionGuard.can(permissions, Permission.customersRead),
      isTrue,
    );
    expect(
      PermissionGuard.can(permissions, Permission.customersWrite),
      isFalse,
    );
  });

  test('le rôle vendeur peut créer des clients', () {
    final permissions = permissionsForRole(UserRole.seller);

    expect(
      PermissionGuard.can(permissions, Permission.customersWrite),
      isTrue,
    );
  });
}
