/// Champs du formulaire d'installation boutique.
enum SetupField {
  ownerName,
  ownerPhone,
  shopName,
  shopPhone,
  shopAddress,
  pin,
  confirmPin;

  String get code => name;

  static SetupField? fromCode(String? code) {
    if (code == null) return null;
    for (final field in SetupField.values) {
      if (field.code == code) return field;
    }
    return null;
  }

  static Map<SetupField, String> fromStringMap(Map<String, String> raw) {
    final result = <SetupField, String>{};
    raw.forEach((key, value) {
      final field = fromCode(key);
      if (field != null && value.isNotEmpty) {
        result[field] = value;
      }
    });
    return result;
  }

  static Map<String, String> toStringMap(Map<SetupField, String> fields) {
    return fields.map((key, value) => MapEntry(key.code, value));
  }
}
