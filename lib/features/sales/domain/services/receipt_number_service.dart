import '../../../../core/utils/benin_day_range.dart';

class ReceiptNumberService {
  const ReceiptNumberService([this._deviceIdProvider]);

  final String Function()? _deviceIdProvider;

  String generate(int shopDayCount, int timestamp) {
    final datePart = beninDayKey(timestamp);
    final seq = (shopDayCount + 1).toString().padLeft(4, '0');
    final tag = _resolveTag();
    if (tag.isNotEmpty) {
      return 'REC-$datePart-$tag-$seq';
    }
    return 'REC-$datePart-$seq';
  }

  String _resolveTag() {
    final raw = _deviceIdProvider?.call()?.trim() ?? '';
    if (raw.isEmpty) return '';
    final sanitized = raw.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '').toUpperCase();
    if (sanitized.length >= 4) {
      return sanitized.substring(0, 4);
    }
    return sanitized;
  }
}
