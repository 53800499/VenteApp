import '../../features/auth/domain/entities/auth_entities.dart';

/// Identifiants boutique — scoping données (V1 → V3).
///
/// - **V1** : une seule boutique (`shop_id` partout, invisible à l'utilisateur)
/// - **V3** : plusieurs boutiques ; toujours filtrer par la boutique active
class CommerceShopScope {
  const CommerceShopScope._();

  /// Boutique locale active (V3 : une seule boutique à la fois).
  static List<int> candidateLocalShopIds(AuthSession session) {
    return [session.shop.id];
  }

  /// Boutique cible pour la synchronisation cloud (V3 : une boutique à la fois).
  static int activeShopIdForSync(AuthSession session) => session.shop.id;
}
