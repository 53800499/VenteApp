import '../constants/api_config.dart';
import '../utils/time.dart';

/// Preuve d'identité PIN en mémoire vive — jamais persistée.
///
/// Utilisée pour réparer la session cloud juste après un déverrouillage PIN,
/// sans stocker le code en clair sur disque.
class RecentPinCredential {
  const RecentPinCredential({
    required this.pin,
    required this.serverShopId,
    required this.localShopId,
    required this.validatedAtMs,
    this.serverUserId,
  });

  final String pin;
  final int serverShopId;
  final int localShopId;
  final int? serverUserId;
  final int validatedAtMs;

  bool isRecent({int? now}) {
    final at = now ?? nowMs();
    return at - validatedAtMs <= ApiConfig.recentPinProofTtlMs;
  }
}

class RecentPinProof {
  RecentPinCredential? _current;

  RecentPinCredential? get current {
    final proof = _current;
    if (proof == null) return null;
    if (!proof.isRecent()) {
      _current = null;
      return null;
    }
    return proof;
  }

  bool get hasRecentProof => current != null;

  void record({
    required String pin,
    required int serverShopId,
    required int localShopId,
    int? serverUserId,
  }) {
    _current = RecentPinCredential(
      pin: pin,
      serverShopId: serverShopId,
      localShopId: localShopId,
      serverUserId: serverUserId,
      validatedAtMs: nowMs(),
    );
  }

  void clear() => _current = null;
}
