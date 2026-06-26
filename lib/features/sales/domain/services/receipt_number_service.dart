import '../../../../core/utils/benin_day_range.dart';

class ReceiptNumberService {
  const ReceiptNumberService();

  String generate(int shopDayCount, int timestamp) {
    final datePart = formatBeninDate(timestamp).replaceAll('-', '');
    final seq = (shopDayCount + 1).toString().padLeft(4, '0');
    return 'REC-$datePart-$seq';
  }
}
