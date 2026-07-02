import 'package:flutter_test/flutter_test.dart';

import 'package:venteapp/features/notifications/domain/entities/notification_entities.dart';

void main() {
  test('NotificationCode expose les libellés SFD N-01 à N-07', () {
    expect(NotificationCode.stockLow.label, 'N-01');
    expect(NotificationCode.debtReminder.label, 'N-02');
    expect(NotificationCode.dailySummary.label, 'N-03');
    expect(NotificationCode.debtPaid.label, 'N-04');
    expect(NotificationCode.backupReminder.label, 'N-05');
    expect(NotificationCode.goodDay.label, 'N-06');
    expect(NotificationCode.syncConflict.label, 'N-07');
  });

  test('maxDebtRemindersPerDay respecte RG-NOTIF-03', () {
    expect(maxDebtRemindersPerDay, 3);
  });
}
