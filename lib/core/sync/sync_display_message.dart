/// Formatage des messages de synchronisation affichés à l'utilisateur.
abstract final class SyncDisplayMessage {
  /// Retire les répétitions « msg · msg · msg » issues d'échecs parallèles.
  static String? dedupe(String? message) {
    if (message == null) return null;

    final trimmed = message.trim();
    if (trimmed.isEmpty) return null;

    final parts = trimmed
        .split(' · ')
        .map((part) => part.trim())
        .where((part) => part.isNotEmpty)
        .toList();
    if (parts.length <= 1) return trimmed;

    final unique = <String>[];
    final seen = <String>{};
    for (final part in parts) {
      if (seen.add(part)) unique.add(part);
    }

    if (unique.length == 1) return unique.first;
    return unique.join(' · ');
  }

  /// Fusionne plusieurs messages d'échec en un libellé unique.
  static String? collapse(Iterable<String?> messages) {
    final unique = <String>[];
    final seen = <String>{};
    for (final message in messages) {
      final trimmed = message?.trim();
      if (trimmed == null || trimmed.isEmpty) continue;
      if (seen.add(trimmed)) unique.add(trimmed);
    }
    if (unique.isEmpty) return null;
    if (unique.length == 1) return unique.first;
    return unique.join(' · ');
  }
}
