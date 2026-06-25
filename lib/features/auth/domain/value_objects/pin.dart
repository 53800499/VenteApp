class Pin {
  Pin._(this.value);

  final String value;

  static Pin create(String raw) {
    final trimmed = raw.trim();
    final pattern = RegExp(r'^\d{4,6}$');
    if (!pattern.hasMatch(trimmed)) {
      throw ArgumentError(
        'Le PIN doit comporter entre 4 et 6 chiffres numériques.',
      );
    }
    return Pin._(trimmed);
  }
}
