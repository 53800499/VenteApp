class AppDateFormatter {
  const AppDateFormatter._();

  static const List<String> _monthsFr = [
    'janvier',
    'février',
    'mars',
    'avril',
    'mai',
    'juin',
    'juillet',
    'août',
    'septembre',
    'octobre',
    'novembre',
    'décembre',
  ];

  static const List<String> _daysFr = [
    'Lundi',
    'Mardi',
    'Mercredi',
    'Jeudi',
    'Vendredi',
    'Samedi',
    'Dimanche',
  ];

  /// Format numérique classique français: DD/MM/YYYY (ex: 31/07/2026)
  static String formatDate(DateTime dt) {
    final d = dt.day.toString().padLeft(2, '0');
    final m = dt.month.toString().padLeft(2, '0');
    return '$d/$m/${dt.year}';
  }

  /// Format court sans année: DD/MM (ex: 31/07)
  static String formatDateShort(DateTime dt) {
    final d = dt.day.toString().padLeft(2, '0');
    final m = dt.month.toString().padLeft(2, '0');
    return '$d/$m';
  }

  /// Format date et heure français: DD/MM/YYYY à HH:mm (ex: 31/07/2026 à 10:40)
  static String formatDateTime(DateTime dt) {
    final time = formatTime(dt);
    return '${formatDate(dt)} à $time';
  }

  /// Format court avec heure: DD/MM HH:mm (ex: 31/07 10:40)
  static String formatDateTimeShort(DateTime dt) {
    final time = formatTime(dt);
    return '${formatDateShort(dt)} $time';
  }

  /// Format heure français: HH:mm (ex: 10:40)
  static String formatTime(DateTime dt) {
    final h = dt.hour.toString().padLeft(2, '0');
    final min = dt.minute.toString().padLeft(2, '0');
    return '$h:$min';
  }

  /// Format littéral français long: ex "31 juillet 2026"
  static String formatDateLong(DateTime dt) {
    final m = _monthsFr[dt.month - 1];
    return '${dt.day} $m ${dt.year}';
  }

  /// Format littéral complet avec jour: ex "Vendredi 31 juillet 2026"
  static String formatDateFull(DateTime dt) {
    final dayName = _daysFr[dt.weekday - 1];
    final m = _monthsFr[dt.month - 1];
    return '$dayName ${dt.day} $m ${dt.year}';
  }

  /// Format Mois et Année: ex "Juillet 2026"
  static String formatMonthYear(DateTime dt) {
    final m = _monthsFr[dt.month - 1];
    final capitalized = m[0].toUpperCase() + m.substring(1);
    return '$capitalized ${dt.year}';
  }

  /// Format relatif intelligent: "Aujourd'hui à 10:40", "Hier à 15:20" ou "31/07/2026"
  static String formatRelativeOrDate(DateTime dt) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final targetDate = DateTime(dt.year, dt.month, dt.day);

    if (targetDate == today) {
      return 'Aujourd\'hui à ${formatTime(dt)}';
    } else if (targetDate == yesterday) {
      return 'Hier à ${formatTime(dt)}';
    } else {
      return formatDateTime(dt);
    }
  }
}

/// Helper extension direct sur DateTime
extension DateTimeFrenchFormatting on DateTime {
  String toFrenchDate() => AppDateFormatter.formatDate(this);
  String toFrenchDateShort() => AppDateFormatter.formatDateShort(this);
  String toFrenchDateTime() => AppDateFormatter.formatDateTime(this);
  String toFrenchDateTimeShort() => AppDateFormatter.formatDateTimeShort(this);
  String toFrenchTime() => AppDateFormatter.formatTime(this);
  String toFrenchDateLong() => AppDateFormatter.formatDateLong(this);
  String toFrenchDateFull() => AppDateFormatter.formatDateFull(this);
  String toFrenchMonthYear() => AppDateFormatter.formatMonthYear(this);
  String toFrenchRelative() => AppDateFormatter.formatRelativeOrDate(this);
}
