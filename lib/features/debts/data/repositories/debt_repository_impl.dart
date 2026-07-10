import '../../../../core/errors/failures.dart';
import '../../../../core/network/remote_api_guard.dart';
import '../../../../core/sync/local_write_sync_recorder.dart';
import '../../../../core/notifications/notification_orchestrator.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../customers/domain/entities/customer_entities.dart';
import '../../domain/entities/debt_entities.dart';
import '../../domain/repositories/debt_repository.dart';
import '../../domain/services/debt_validation_service.dart';
import '../datasources/local/debts_local_datasource.dart';
import '../datasources/remote/debts_remote_datasource.dart';
import '../../../customers/data/datasources/local/customers_local_datasource.dart';

class DebtRepositoryImpl implements DebtRepository {
  DebtRepositoryImpl({
    required DebtsLocalDatasource local,
    required DebtsRemoteDatasource remote,
    required CustomersLocalDatasource customersLocal,
    required RemoteApiGuard apiGuard,
    DebtValidationService? validation,
    LocalWriteSyncRecorder? recorder,
    NotificationOrchestrator? notificationOrchestrator,
  })  : _local = local,
        _remote = remote,
        _customersLocal = customersLocal,
        _apiGuard = apiGuard,
        _validation = validation ?? const DebtValidationService(),
        _recorder = recorder,
        _notificationOrchestrator = notificationOrchestrator;

  final DebtsLocalDatasource _local;
  final DebtsRemoteDatasource _remote;
  final CustomersLocalDatasource _customersLocal;
  final RemoteApiGuard _apiGuard;
  final DebtValidationService _validation;
  final LocalWriteSyncRecorder? _recorder;
  final NotificationOrchestrator? _notificationOrchestrator;

  @override
  Future<List<Debt>> listCustomerDebts({
    required int shopId,
    required int customerId,
    bool openOnly = true,
  }) {
    return _local.listCustomerDebts(
      shopId: shopId,
      customerId: customerId,
      openOnly: openOnly,
    );
  }

  @override
  Future<List<ForgivenDebtEntry>> listForgivenDebts({
    required int shopId,
    int? customerId,
  }) {
    return _local.listForgivenDebts(
      shopId: shopId,
      customerId: customerId,
    );
  }

  @override
  Future<List<Debt>> listPaidDebts({
    required int shopId,
    int? customerId,
  }) {
    return _local.listPaidDebts(
      shopId: shopId,
      customerId: customerId,
    );
  }

  @override
  Future<DebtForgivenessInfo?> getDebtForgivenessInfo({
    required int shopId,
    required int debtId,
  }) {
    return _local.getDebtForgivenessInfo(shopId: shopId, debtId: debtId);
  }

  @override
  Future<Debt> getDebt({
    required int shopId,
    required int debtId,
  }) async {
    final debt = await _local.findDebt(shopId, debtId);
    if (debt == null) {
      throw const NotFoundFailure('Dette introuvable.');
    }
    return debt;
  }

  @override
  Future<DebtDetail> getDebtDetail({
    required int shopId,
    required int debtId,
  }) async {
    var debt = await getDebt(shopId: shopId, debtId: debtId);

    try {
      if (debt.serverId != null) {
        await _apiGuard.ensureReady();
        final remote = await _remote.getDebt(int.parse(debt.serverId!));
        final customer = await _customersLocal.findCustomer(
          shopId,
          debt.customerId,
        );
        await _local.upsertFromRemote(
          shopId: shopId,
          localCustomerId: debt.customerId,
          remote: remote,
          localSaleId: debt.saleId,
        );
        debt = (await _local.findDebt(shopId, debtId)) ?? debt;
        return DebtDetail(
          debt: debt.copyWithMetadata(
            customerName: remote.customerName ?? customer?.name,
            isCritical: remote.isCritical,
          ),
          customerName: remote.customerName ?? customer?.name,
          payments: remote.payments.map((p) => p.toEntity()).toList(),
          daysWithoutPayment: remote.daysWithoutPayment,
          lastPaymentAt: remote.lastPaymentAt,
          forgiveness: debt.status == DebtStatus.forgiven
              ? await _local.getDebtForgivenessInfo(
                  shopId: shopId,
                  debtId: debtId,
                )
              : null,
        );
      }
    } on Failure {
      // Données locales.
    }

    final customer =
        await _customersLocal.findCustomer(shopId, debt.customerId);
    final payments = await _local.listPaymentHistory(
      shopId: shopId,
      debtId: debtId,
    );
    final lastPaymentAt =
        payments.isNotEmpty ? payments.last.createdAt : null;
    final daysWithoutPayment = _validation.computeDaysWithoutPayment(
      createdAt: debt.createdAt,
      amountPaid: debt.amountPaid,
      lastPaymentAt: lastPaymentAt,
    );
    final forgiveness = debt.status == DebtStatus.forgiven
        ? await _local.getDebtForgivenessInfo(shopId: shopId, debtId: debtId)
        : null;

    return DebtDetail(
      debt: debt.copyWithMetadata(customerName: customer?.name),
      customerName: customer?.name,
      payments: payments,
      daysWithoutPayment: daysWithoutPayment,
      lastPaymentAt: lastPaymentAt,
      forgiveness: forgiveness,
    );
  }

  @override
  Future<DebtPaymentResult> recordPayment({
    required int shopId,
    required int debtId,
    required int userId,
    required RecordDebtPaymentInput input,
  }) async {
    final debt = await getDebt(shopId: shopId, debtId: debtId);
    _validation.assertRepayable(debt);
    _validation.assertPaymentAmount(input.amount, debt.amountRemaining);
    _validation.assertMomoReference(input.method, input.reference);
    final changeGiven = _validation.computeChangeGiven(
      input.method,
      input.amount,
      input.amountTendered,
    );

    try {
      if (debt.serverId != null) {
        await _apiGuard.ensureReady();
        final remote = await _remote.recordPayment(
          int.parse(debt.serverId!),
          amount: input.amount,
          method: input.method.code,
          reference: input.reference,
          amountTendered: input.amountTendered,
          note: input.note,
        );
        await _local.applyRemotePayment(
          shopId: shopId,
          debtId: debtId,
          amountPaid: debt.amountPaid + input.amount,
          amountRemaining: remote.amountRemaining,
          status: remote.status,
        );
        final paidResult =
            remote.toEntity(localDebtId: debtId).copyWithChange(changeGiven);
        await _notifyDebtPaidIfNeeded(
          shopId: shopId,
          debt: debt,
          result: paidResult,
        );
        return paidResult;
      }
    } on Failure {
      if (debt.serverId != null) rethrow;
    }

    final newStatus =
        _validation.resolveStatusAfterPayment(debt.amountRemaining - input.amount);
    final result = await _local.recordPaymentWithAudit(
      shopId: shopId,
      debtId: debtId,
      userId: userId,
      amount: input.amount,
      method: input.method,
      newStatus: newStatus,
      reference: input.reference,
      note: input.note,
    );

    await _recorder?.recordDebtPayment(
      shopId: shopId,
      debtId: debtId,
      payload: {
        'amount': input.amount,
        'method': input.method.code,
        if (input.reference != null && input.reference!.isNotEmpty)
          'reference': input.reference,
        if (input.amountTendered != null) 'amountTendered': input.amountTendered,
        if (input.note != null && input.note!.isNotEmpty) 'note': input.note,
      },
    );

    final paidResult = result.copyWithChange(changeGiven);
    await _notifyDebtPaidIfNeeded(
      shopId: shopId,
      debt: debt,
      result: paidResult,
    );
    return paidResult;
  }

  @override
  Future<Debt> forgiveDebt({
    required int shopId,
    required int debtId,
    required int userId,
    required String reason,
  }) async {
    final debt = await getDebt(shopId: shopId, debtId: debtId);
    _validation.assertForgivable(debt);
    _validation.assertForgiveReason(reason);
    final trimmedReason = reason.trim();

    try {
      if (debt.serverId != null) {
        await _apiGuard.ensureReady();
        await _remote.forgiveDebt(
          int.parse(debt.serverId!),
          reason: trimmedReason,
        );
        return _local.forgiveDebt(
          shopId: shopId,
          debtId: debtId,
          userId: userId,
          reason: trimmedReason,
        );
      }
    } on Failure {
      if (debt.serverId != null) rethrow;
    }

    final forgiven = await _local.forgiveDebt(
      shopId: shopId,
      debtId: debtId,
      userId: userId,
      reason: trimmedReason,
    );

    await _recorder?.recordDebtForgive(
      shopId: shopId,
      debtId: debtId,
      reason: trimmedReason,
    );

    return forgiven;
  }

  @override
  Future<DebtReminder> getDebtReminder({
    required int shopId,
    required int debtId,
    required String shopName,
  }) async {
    final detail = await getDebtDetail(shopId: shopId, debtId: debtId);
    final customer =
        await _customersLocal.findCustomer(shopId, detail.debt.customerId);
    final phone = customer?.phone?.trim();
    if (phone == null || phone.length < 8) {
      throw const ValidationFailure(
        'Ajoutez un numéro de téléphone pour envoyer un rappel WhatsApp.',
      );
    }

    final customerName = detail.customerName ?? customer?.name ?? 'Client';
    final remaining = detail.debt.amountRemaining;
    final message = remaining > 0
        ? 'Bonjour $customerName, concernant votre dette chez $shopName : '
            'il reste ${formatFcfa(remaining)} à régler. Merci de votre compréhension.'
        : 'Bonjour $customerName, merci pour votre confiance chez $shopName !';

    return DebtReminder(
      customerId: detail.debt.customerId,
      customerName: customerName,
      balanceDue: remaining,
      message: message,
      whatsappUrl: _buildWhatsappUrl(phone, message),
    );
  }

  String _buildWhatsappUrl(String phone, String message) {
    var digits = phone.replaceAll(RegExp(r'\D'), '');
    if (digits.startsWith('0')) {
      digits = '229${digits.substring(1)}';
    } else if (!digits.startsWith('229')) {
      digits = '229$digits';
    }
    return 'https://wa.me/$digits?text=${Uri.encodeComponent(message)}';
  }

  Future<void> _notifyDebtPaidIfNeeded({
    required int shopId,
    required Debt debt,
    required DebtPaymentResult result,
  }) async {
    if (result.amountRemaining > 0 || result.status != DebtStatus.paid) {
      return;
    }
    final customer =
        await _customersLocal.findCustomer(shopId, debt.customerId);
    await _notificationOrchestrator?.showDebtPaid(
      shopId: shopId,
      customerName: customer?.name ?? 'Client',
      amount: result.amount,
      customerId: debt.customerId,
    );
  }

  @override
  Future<void> syncFromRemote({required int shopId}) async {
    await _apiGuard.ensureReady();
    final remoteDebts = await _remote.listDebts();

    for (final remote in remoteDebts) {
      final customer = await _customersLocal.findCustomerByServerId(
        shopId,
        '${remote.customerId}',
      );
      if (customer == null) continue;

      await _local.upsertFromRemote(
        shopId: shopId,
        localCustomerId: customer.id,
        remote: remote,
      );
    }
  }
}

extension on DebtPaymentResult {
  DebtPaymentResult copyWithChange(int changeGiven) {
    return DebtPaymentResult(
      debtId: debtId,
      paymentId: paymentId,
      receiptNumber: receiptNumber,
      amount: amount,
      changeGiven: changeGiven,
      amountRemaining: amountRemaining,
      status: status,
    );
  }
}

extension on Debt {
  Debt copyWithMetadata({
    String? customerName,
    bool? isCritical,
  }) {
    return Debt(
      id: id,
      shopId: shopId,
      customerId: customerId,
      customerName: customerName ?? this.customerName,
      saleId: saleId,
      receiptNumber: receiptNumber,
      originalAmount: originalAmount,
      amountPaid: amountPaid,
      amountRemaining: amountRemaining,
      status: status,
      createdAt: createdAt,
      dueAt: dueAt,
      serverId: serverId,
      isCritical: isCritical ?? this.isCritical,
    );
  }
}
