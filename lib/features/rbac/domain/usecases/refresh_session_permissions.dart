import '../../../auth/domain/entities/auth_entities.dart';
import '../../../auth/domain/repositories/auth_repository.dart';
import '../../../../core/storage/auth_credentials_storage.dart';
import '../usecases/rbac_usecases.dart';

/// Recharge les permissions effectives depuis `GET /rbac/me`.
class RefreshSessionPermissions {
  const RefreshSessionPermissions({
    required GetMyPermissions getMyPermissions,
    required AuthCredentialsStorage credentials,
    required AuthRepository authRepository,
  })  : _getMyPermissions = getMyPermissions,
        _credentials = credentials,
        _authRepository = authRepository;

  final GetMyPermissions _getMyPermissions;
  final AuthCredentialsStorage _credentials;
  final AuthRepository _authRepository;

  Future<AuthSession?> call() async {
    final my = await _getMyPermissions();
    await _credentials.updatePermissions(
      my.permissions.map((p) => p.code).toList(),
    );
    return _authRepository.restoreSession();
  }
}
