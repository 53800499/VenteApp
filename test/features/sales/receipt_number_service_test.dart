import 'package:flutter_test/flutter_test.dart';
import 'package:venteapp/core/utils/benin_day_range.dart';
import 'package:venteapp/features/sales/domain/services/receipt_number_service.dart';

void main() {
  group('ReceiptNumberService', () {
    final testTimestamp = DateTime.utc(2026, 10, 8, 12, 0).millisecondsSinceEpoch;
    final dayKey = beninDayKey(testTimestamp);

    test('generates standard receipt number when no device tag is provided', () {
      const service = ReceiptNumberService();
      final ref1 = service.generate(0, testTimestamp);
      final ref2 = service.generate(1, testTimestamp);

      expect(ref1, 'REC-$dayKey-0001');
      expect(ref2, 'REC-$dayKey-0002');
    });

    test('generates collision-free device-tagged receipt numbers for different devices', () {
      final phoneAService = ReceiptNumberService(() => 'a7b2e3f4-1234');
      final phoneBService = ReceiptNumberService(() => 'c4d5e6f7-5678');

      // Both phones start offline on the same day with 0 prior local sales
      final phoneARef1 = phoneAService.generate(0, testTimestamp);
      final phoneBRef1 = phoneBService.generate(0, testTimestamp);

      expect(phoneARef1, 'REC-$dayKey-A7B2-0001');
      expect(phoneBRef1, 'REC-$dayKey-C4D5-0001');

      // Guaranteed distinct!
      expect(phoneARef1, isNot(equals(phoneBRef1)));
    });

    test('cleans and uppercases device tags properly', () {
      final service = ReceiptNumberService(() => 'dev-99-special');
      final ref = service.generate(41, testTimestamp);

      expect(ref, 'REC-$dayKey-DEV9-0042');
    });
  });
}
