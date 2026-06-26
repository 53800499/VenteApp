/// Format national actuel : 10 chiffres commençant par 01 (ex. 01 97 00 00 00).
/// Format API / WhatsApp : +22901XXXXXXXX (229 + 10 chiffres nationaux).

const _beninCountry = '229';
const _nationalPrefix = '01';
const _nationalLength = 10;

const _minE164Digits = 10;
const _maxE164Digits = 15;

void _assertE164Digits(String digits) {
  if (digits.length < _minE164Digits || digits.length > _maxE164Digits) {
    throw const FormatException('Numéro invalide');
  }
}

String _normalizeBeninLocalDigits(String digits) {
  if (digits.length == _nationalLength && digits.startsWith(_nationalPrefix)) {
    return '+$_beninCountry$digits';
  }
  if (digits.length == 8) {
    return '+$_beninCountry$_nationalPrefix$digits';
  }
  if (digits.startsWith(_beninCountry)) {
    final national = digits.substring(_beninCountry.length);
    if (national.length == _nationalLength && national.startsWith(_nationalPrefix)) {
      return '+$_beninCountry$national';
    }
    if (national.length == 8) {
      return '+$_beninCountry$_nationalPrefix$national';
    }
  }
  throw const FormatException('Numéro invalide');
}

/// Normalise vers E.164 (+XXXXXXXX). Accepte tout indicatif international.
/// Sans indicatif, applique les règles béninoises (01XXXXXXXX).
String normalizePhone(String raw) {
  final trimmed = raw.trim();
  if (trimmed.isEmpty) {
    throw const FormatException('Numéro invalide');
  }

  if (trimmed.startsWith('+')) {
    final digits = trimmed.replaceAll(RegExp(r'\D'), '');
    _assertE164Digits(digits);
    return '+$digits';
  }

  final digits = trimmed.replaceAll(RegExp(r'\D'), '');
  if (digits.isEmpty) {
    throw const FormatException('Numéro invalide');
  }

  // Indicatif saisi sans + (ex. 22901..., 33612345678).
  if (digits.length >= 11 && digits.length <= _maxE164Digits) {
    _assertE164Digits(digits);
    return '+$digits';
  }

  return _normalizeBeninLocalDigits(digits);
}

bool isValidPhone(String raw) {
  try {
    normalizePhone(raw);
    return true;
  } on FormatException {
    return false;
  }
}

/// Chiffres WhatsApp (sans +) à partir d'une saisie utilisateur.
String phoneToWhatsAppDigits(String raw) =>
    normalizePhone(raw).replaceAll('+', '');

@Deprecated('Utiliser normalizePhone')
String normalizeBeninPhone(String raw) => normalizePhone(raw);

@Deprecated('Utiliser isValidPhone')
bool isValidBeninPhone(String raw) => isValidPhone(raw);
