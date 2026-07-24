/// Parse « remplacer X par Y » / « échanger X contre Y ».
class VoiceReplaceXYParse {
  const VoiceReplaceXYParse({
    required this.returnedQuery,
    required this.issuedQuery,
    this.quantity,
  });

  final String returnedQuery;
  final String issuedQuery;
  final int? quantity;
}

/// Extrait les produits X/Y d’une phrase de remplacement.
VoiceReplaceXYParse? parseReplaceXY(String transcript) {
  final text = transcript.trim();
  if (text.isEmpty) return null;

  final qtyMatch = RegExp(
    r'(?:quantite|quantité|qte|qty)\s+(\d+)',
    caseSensitive: false,
  ).firstMatch(text);
  final quantity = qtyMatch != null ? int.tryParse(qtyMatch.group(1)!) : null;

  final patterns = <RegExp>[
    RegExp(
      r'remplac(?:er|e)?\s+(.+?)\s+par\s+(.+)$',
      caseSensitive: false,
    ),
    RegExp(
      r'echang(?:er|e)?\s+(.+?)\s+(?:contre|par)\s+(.+)$',
      caseSensitive: false,
    ),
    RegExp(
      r'echange\s+(.+?)\s+(?:contre|par)\s+(.+)$',
      caseSensitive: false,
    ),
  ];

  for (final re in patterns) {
    final m = re.firstMatch(text);
    if (m == null) continue;
    final returned = _cleanProductQuery(m.group(1)!);
    final issued = _cleanProductQuery(m.group(2)!);
    if (returned.length < 2 || issued.length < 2) continue;
    return VoiceReplaceXYParse(
      returnedQuery: returned,
      issuedQuery: issued,
      quantity: quantity,
    );
  }
  return null;
}

String _cleanProductQuery(String raw) {
  return raw
      .replaceAll(
        RegExp(
          r'\b(quantite|quantité|qte|qty)\s+\d+\b',
          caseSensitive: false,
        ),
        '',
      )
      .replaceAll(
        RegExp(
          r'\b(le|la|les|un|une|du|de|des|produit|article)\b',
          caseSensitive: false,
        ),
        ' ',
      )
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
}
