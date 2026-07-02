import '../../features/auth/domain/entities/auth_entities.dart';

/// Identifiants boutique — scoping données (V1 → V3).
///
/// - **V1** : une seule boutique (`shop_id` partout, invisible à l'utilisateur)
/// - **V3** : plusieurs boutiques ; toujours filtrer par la boutique active
class CommerceShopScope {
  const CommerceShopScope._();

  /// IDs locaux à interroger, dans l'ordre de priorité (V1 compat + V3 user.shopId).
  static List<int> candidateLocalShopIds(AuthSession session) {
    final ids = <int>{session.shop.id, session.user.shopId};
    return ids.toList();
  }

  /// Boutique cible pour la synchronisation cloud (V3 : une boutique à la fois).
  static int activeShopIdForSync(AuthSession session) => session.shop.id;
}
