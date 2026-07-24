import '../entities/voice_draft.dart';

/// Normalisation + score de similarité pour matching catalogue.
class EntityMatcher {
  const EntityMatcher();

  String normalize(String input) {
    var s = input.toLowerCase().trim();
    const map = <String, String>{
      'à': 'a',
      'â': 'a',
      'ä': 'a',
      'á': 'a',
      'ç': 'c',
      'é': 'e',
      'è': 'e',
      'ê': 'e',
      'ë': 'e',
      'î': 'i',
      'ï': 'i',
      'ô': 'o',
      'ö': 'o',
      'ù': 'u',
      'û': 'u',
      'ü': 'u',
      'ÿ': 'y',
    };
    map.forEach((k, v) => s = s.replaceAll(k, v));
    s = s.replaceAll(RegExp(r'[^a-z0-9\s]'), ' ');
    s = s.replaceAll(RegExp(r'\s+'), ' ').trim();
    return s;
  }

  List<String> tokens(String input) =>
      normalize(input).split(' ').where((t) => t.length > 1).toList();

  /// Score 0..1. Contient, tokens partagés, préfixe.
  double score(String query, String candidate) {
    final q = normalize(query);
    final c = normalize(candidate);
    if (q.isEmpty || c.isEmpty) return 0;
    if (q == c) return 1;
    if (c.contains(q) || q.contains(c)) {
      final shorter = q.length < c.length ? q.length : c.length;
      final longer = q.length > c.length ? q.length : c.length;
      return 0.75 + 0.2 * (shorter / longer);
    }
    final qt = tokens(q).toSet();
    final ct = tokens(c).toSet();
    if (qt.isEmpty || ct.isEmpty) return 0;
    final inter = qt.intersection(ct).length;
    final union = qt.union(ct).length;
    final jaccard = inter / union;
    // Bonus si tous les tokens query sont dans candidate
    final coverage = inter / qt.length;
    return (jaccard * 0.55 + coverage * 0.45).clamp(0.0, 1.0);
  }

  VoiceMatchCandidate? bestMatch({
    required String query,
    required List<({int id, String label})> items,
    double minScore = 0.42,
  }) {
    if (query.trim().isEmpty || items.isEmpty) return null;
    VoiceMatchCandidate? best;
    for (final item in items) {
      final s = score(query, item.label);
      if (s < minScore) continue;
      if (best == null || s > best.score) {
        best = VoiceMatchCandidate(id: item.id, label: item.label, score: s);
      }
    }
    return best;
  }
}
