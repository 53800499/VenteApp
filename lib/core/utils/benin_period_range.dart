import 'benin_day_range.dart';

/// Périodes de rapport — fuseau Bénin (UTC+1), aligné backend `resolveReportPeriod`.
enum ReportPeriodPreset { today, week, month, custom }

class ResolvedReportPeriod {
  const ResolvedReportPeriod({
    required this.preset,
    required this.fromMs,
    required this.toMs,
    required this.label,
  });

  final ReportPeriodPreset preset;
  final int fromMs;
  final int toMs;
  final String label;
}

const _beninOffsetMs = 60 * 60 * 1000;
const _dayMs = 86_400_000;

int _beninLocalMidnight(int nowMs) {
  final localMs = nowMs + _beninOffsetMs;
  final localMidnight = (localMs ~/ _dayMs) * _dayMs;
  return localMidnight - _beninOffsetMs;
}

int _beninMonthStart(int nowMs) {
  final local = DateTime.fromMillisecondsSinceEpoch(
    nowMs + _beninOffsetMs,
    isUtc: true,
  );
  return DateTime.utc(local.year, local.month, 1).millisecondsSinceEpoch -
      _beninOffsetMs;
}

ResolvedReportPeriod resolveReportPeriod({
  required ReportPeriodPreset preset,
  int nowMs = 0,
  int? customFrom,
  int? customTo,
}) {
  final now = nowMs > 0 ? nowMs : DateTime.now().millisecondsSinceEpoch;

  if (preset == ReportPeriodPreset.custom) {
    if (customFrom == null || customTo == null || customFrom > customTo) {
      throw ArgumentError('Période personnalisée : from et to requis (from <= to).');
    }
    return ResolvedReportPeriod(
      preset: preset,
      fromMs: customFrom,
      toMs: customTo,
      label: '${formatBeninDate(customFrom)} → ${formatBeninDate(customTo)}',
    );
  }

  if (preset == ReportPeriodPreset.today) {
    final dayStart = _beninLocalMidnight(now);
    return ResolvedReportPeriod(
      preset: preset,
      fromMs: dayStart,
      toMs: now,
      label: "Aujourd'hui (${formatBeninDate(now)})",
    );
  }

  if (preset == ReportPeriodPreset.week) {
    final dayStart = _beninLocalMidnight(now);
    return ResolvedReportPeriod(
      preset: preset,
      fromMs: dayStart - 6 * _dayMs,
      toMs: now,
      label: '7 derniers jours',
    );
  }

  final fromMs = _beninMonthStart(now);
  return ResolvedReportPeriod(
    preset: ReportPeriodPreset.month,
    fromMs: fromMs,
    toMs: now,
    label: 'Mois en cours (${formatBeninDate(fromMs)} → ${formatBeninDate(now)})',
  );
}

String reportPeriodPresetLabel(ReportPeriodPreset preset) => switch (preset) {
      ReportPeriodPreset.today => 'Aujourd\'hui',
      ReportPeriodPreset.week => 'Semaine',
      ReportPeriodPreset.month => 'Mois',
      ReportPeriodPreset.custom => 'Personnalisé',
    };
