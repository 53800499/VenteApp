import '../../../../app/di/injection_container.dart';
import '../../../../core/audit/local_audit_writer.dart';
import '../../../../shared/enums/audit_enums.dart';

/// Journalise une création issue de la saisie vocale.
Future<void> recordVoiceAudit({
  required int shopId,
  required int userId,
  required String action,
  required String module,
  required int entityId,
  required String entityTable,
  required String transcript,
  Map<String, dynamic>? extra,
}) {
  return sl<LocalAuditWriter>().record(
    shopId: shopId,
    userId: userId,
    action: action,
    module: module,
    entityId: entityId,
    entityTable: entityTable,
    reason: 'Création vocale',
    newValue: {
      'source': 'voice',
      'transcript': transcript,
      ...?extra,
    },
  );
}

Future<void> recordVoiceSaleAudit({
  required int shopId,
  required int userId,
  required int saleId,
  required String transcript,
}) {
  return recordVoiceAudit(
    shopId: shopId,
    userId: userId,
    action: AuditAction.saleCreated.code,
    module: AuditModule.sales.code,
    entityId: saleId,
    entityTable: 'sales',
    transcript: transcript,
  );
}

Future<void> recordVoiceExpenseAudit({
  required int shopId,
  required int userId,
  required int expenseId,
  required String transcript,
}) {
  return recordVoiceAudit(
    shopId: shopId,
    userId: userId,
    action: AuditAction.expenseCreated.code,
    module: AuditModule.expenses.code,
    entityId: expenseId,
    entityTable: 'expenses',
    transcript: transcript,
  );
}

Future<void> recordVoiceDebtPaymentAudit({
  required int shopId,
  required int userId,
  required int debtId,
  required String transcript,
  required int amount,
}) {
  return recordVoiceAudit(
    shopId: shopId,
    userId: userId,
    action: AuditAction.debtPaymentRecorded.code,
    module: AuditModule.debts.code,
    entityId: debtId,
    entityTable: 'debts',
    transcript: transcript,
    extra: {'amount': amount},
  );
}

Future<void> recordVoiceFxAudit({
  required int shopId,
  required int userId,
  required int operationId,
  required String transcript,
}) {
  return recordVoiceAudit(
    shopId: shopId,
    userId: userId,
    action: 'fx_operation_created',
    module: 'fx_exchange',
    entityId: operationId,
    entityTable: 'fx_operations',
    transcript: transcript,
  );
}
