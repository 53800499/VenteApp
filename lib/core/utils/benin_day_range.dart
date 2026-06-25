/// Bornes de la journée civile au Bénin (UTC+1, sans DST). [RG-DB-01]
({int dayStartMs, int dayEndMs}) getBeninDayBounds([int? now]) {
  const beninOffsetMs = 60 * 60 * 1000;
  final timestamp = now ?? DateTime.now().millisecondsSinceEpoch;
  final localMs = timestamp + beninOffsetMs;
  final localMidnight = (localMs ~/ 86400000) * 86400000;
  return (
    dayStartMs: localMidnight - beninOffsetMs,
    dayEndMs: timestamp,
  );
}

String formatBeninDate([int? now]) {
  const beninOffsetMs = 60 * 60 * 1000;
  final timestamp = now ?? DateTime.now().millisecondsSinceEpoch;
  final local = DateTime.fromMillisecondsSinceEpoch(
    timestamp + beninOffsetMs,
    isUtc: true,
  );
  final y = local.year;
  final m = local.month.toString().padLeft(2, '0');
  final d = local.day.toString().padLeft(2, '0');
  return '$y-$m-$d';
}
