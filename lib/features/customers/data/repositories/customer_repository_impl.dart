import 'dart:async' show unawaited;

import '../../../../core/errors/failures.dart';
import '../../../../core/network/remote_api_guard.dart';
import '../../../../core/sync/local_write_sync_recorder.dart';
import '../../../../core/sync/sync_policy.dart';
import '../../../../core/sync/sync_pull_entity.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../domain/entities/customer_entities.dart';
import '../../domain/repositories/customer_repository.dart';
import '../../domain/services/customer_validation_service.dart';
import '../datasources/local/customers_local_datasource.dart';
import '../datasources/remote/customers_remote_datasource.dart';
import '../models/customer_api_models.dart';
import '../../../debts/data/datasources/local/debts_local_datasource.dart';
import '../../../sales/data/datasources/local/sales_local_datasource.dart';

class CustomerRepositoryImpl implements CustomerRepository {
  CustomerRepositoryImpl({
    required CustomersLocalDatasource local,
    required CustomersRemoteDatasource remote,
    required DebtsLocalDatasource debtsLocal,
    required SalesLocalDatasource salesLocal,
    required RemoteApiGuard apiGuard,
    required SyncPolicy syncPolicy,
    LocalWriteSyncRecorder? recorder,
    CustomerValidationService? validation,
  })  : _local = local,
        _remote = remote,
        _debtsLocal = debtsLocal,
        _salesLocal = salesLocal,
        _apiGuard = apiGuard,
        _syncPolicy = syncPolicy,
        _recorder = recorder,
        _validation = validation ?? const CustomerValidationService();

  final CustomersLocalDatasource _local;
  final CustomersRemoteDatasource _remote;
  final DebtsLocalDatasource _debtsLocal;
  final SalesLocalDatasource _salesLocal;
  final RemoteApiGuard _apiGuard;
  final SyncPolicy _syncPolicy;
  final LocalWriteSyncRecorder? _recorder;
  final CustomerValidationService _validation;

  @override
  Future<void> syncFromRemote({required int shopId, bool force = false}) async {
    if (!await _syncPolicy.shouldPullEntity(
      shopId: shopId,
      entity: SyncPullEntity.customers,
      force: force,
    )) {
      return;
    }

    try {
      await _apiGuard.ensureReady();
      final remoteCustomers = await _fetchAllRemoteCustomers();
      for (final remote in remoteCustomers) {
        final localShopId = remote.shopId > 0
            ? await _local.resolveLocalShopId(remote.shopId)
            : shopId;
        await _local.upsertFromRemote(
          shopId: localShopId,
          remoteId: remote.id,
          name: remote.name,
          phone: remote.phone,
          address: remote.address,
          note: remote.note,
          isArchived: remote.isArchived,
          isShared: remote.isShared,
          createdAt: remote.createdAt,
          updatedAt: remote.updatedAt,
        );
      }
      await _syncPolicy.markEntitySynced(
        shopId: shopId,
        entity: SyncPullEntity.customers,
      );
    } catch (_) {
      // Pull optionnel — la liste locale reste utilisable (offline-first).
    }
  }

  Future<List<CustomerApiDto>> _fetchAllRemoteCustomers() {
    return _remote.listCustomers();
  }

  @override
  Future<List<Customer>> listCustomers({
    required int shopId,
    CustomerListFilters filters = const CustomerListFilters(),
  }) async {
    final customers = await _local.listCustomers(
      shopId: shopId,
      filters: filters,
    );
    return customers
        .map(
          (c) => c.copyWith(
            phoneWarning: _validation.phoneWarning(c.phone),
          ),
        )
        .toList();
  }

  @override
  Future<CustomerDetail> getCustomer({
    required int shopId,
    required int customerId,
    bool force = false,
  }) async {
    final local = await _local.findCustomer(shopId, customerId);
    if (local == null) {
      throw const NotFoundFailure('Client introuvable.');
    }

    final detailEntity = SyncPullEntity.customerDetail(customerId);
    final shouldPull = await _syncPolicy.shouldPullEntity(
      shopId: shopId,
      entity: detailEntity,
      force: force,
    );

    if (shouldPull && local.serverId != null) {
      final pull = _pullCustomerDetailFromRemote(
        shopId: shopId,
        customerId: customerId,
        localServerId: local.serverId!,
        detailEntity: detailEntity,
      );
      if (force) {
        await pull;
      } else {
        unawaited(pull);
      }
    }

    return _buildDetailFromLocal(shopId: shopId, customerId: customerId);
  }

  Future<CustomerDetail> _buildDetailFromLocal({
    required int shopId,
    required int customerId,
  }) async {
    final refreshed = await _local.findCustomer(shopId, customerId);
    if (refreshed == null) {
      throw const NotFoundFailure('Client introuvable.');
    }

    final sales = await _local.listCustomerSales(
      shopId: shopId,
      customerId: customerId,
    );
    final debts = await _debtsLocal.listCustomerDebts(
      shopId: shopId,
      customerId: customerId,
      openOnly: true,
    );
    final paidDebts = await _debtsLocal.listPaidDebts(
      shopId: shopId,
      customerId: customerId,
    );
    final forgivenDebts = await _debtsLocal.listForgivenDebts(
      shopId: shopId,
      customerId: customerId,
    );

    return CustomerDetail(
      customer: refreshed.copyWith(
        phoneWarning: _validation.phoneWarning(refreshed.phone),
      ),
      sales: sales,
      debts: debts,
      paidDebts: paidDebts,
      forgivenDebts: forgivenDebts,
    );
  }

  Future<void> _pullCustomerDetailFromRemote({
    required int shopId,
    required int customerId,
    required String localServerId,
    required String detailEntity,
  }) async {
    try {
      await _apiGuard.ensureReady();
      final remote = await _remote.getCustomer(int.parse(localServerId));
      final localShopId = remote.customer.shopId > 0
          ? await _local.resolveLocalShopId(remote.customer.shopId)
          : shopId;
      await _local.upsertFromRemote(
        shopId: localShopId,
        remoteId: remote.customer.id,
        name: remote.customer.name,
        phone: remote.customer.phone,
        address: remote.customer.address,
        note: remote.customer.note,
        isArchived: remote.customer.isArchived,
        isShared: remote.customer.isShared,
        createdAt: remote.customer.createdAt,
        updatedAt: remote.customer.updatedAt,
      );

      await _syncCustomerDetailBundleFromRemote(
        shopId: localShopId,
        customerId: customerId,
        remote: remote,
      );

      await _syncPolicy.markEntitySynced(
        shopId: shopId,
        entity: detailEntity,
      );
    } catch (_) {
      // Données locales conservées.
    }
  }

  Future<void> _syncCustomerDetailBundleFromRemote({
    required int shopId,
    required int customerId,
    required CustomerDetailApiDto remote,
  }) async {
    final userId = await _salesLocal.resolveDefaultUserId(shopId);
    if (userId != null) {
      for (final sale in remote.sales) {
        await _salesLocal.upsertCustomerSaleFromRemote(
          shopId: shopId,
          userId: userId,
          localCustomerId: customerId,
          remoteId: sale.id,
          totalAmount: sale.totalAmount,
          status: sale.status,
          createdAt: sale.createdAt,
          receiptNumber: sale.receiptNumber,
        );
      }
    }

    for (final debt in remote.debts) {
      await _debtsLocal.upsertFromRemote(
        shopId: shopId,
        localCustomerId: customerId,
        remote: debt,
      );
    }
    for (final debt in remote.paidDebts) {
      await _debtsLocal.upsertFromRemote(
        shopId: shopId,
        localCustomerId: customerId,
        remote: debt,
      );
    }
    for (final debt in remote.forgivenDebts) {
      await _debtsLocal.upsertFromRemote(
        shopId: shopId,
        localCustomerId: customerId,
        remote: debt,
      );
    }
  }

  @override
  Future<List<CustomerSaleSummary>> listCustomerSales({
    required int shopId,
    required int customerId,
  }) async {
    final customer = await _local.findCustomer(shopId, customerId);
    if (customer == null) {
      throw const NotFoundFailure('Client introuvable.');
    }

    return _local.listCustomerSales(shopId: shopId, customerId: customerId);
  }

  @override
  Future<List<CustomerSaleSummary>> listCustomerSalesLifetime({
    required int shopId,
    required int customerId,
  }) async {
    final customer = await _local.findCustomer(shopId, customerId);
    if (customer == null) {
      throw const NotFoundFailure('Client introuvable.');
    }

    return _local.listCustomerSalesLifetime(
      shopId: shopId,
      customerId: customerId,
    );
  }

  @override
  Future<DebtorsOverview> listDebtors({required int shopId}) async {
    return _local.listDebtors(shopId: shopId);
  }

  @override
  Future<DebtReminder> getDebtReminder({
    required int shopId,
    required int customerId,
    required String shopName,
  }) async {
    final customer = await _local.findCustomer(shopId, customerId);
    if (customer == null) {
      throw const NotFoundFailure('Client introuvable.');
    }

    try {
      if (customer.serverId != null) {
        unawaited(_apiGuard.ensureReady().then((_) async {
          try {
            await _remote.getDebtReminder(int.parse(customer.serverId!));
          } catch (_) {}
        }));
      }
    } catch (_) {
      // Message local utilisé.
    }

    if (customer.phone == null || customer.phone!.trim().length < 8) {
      throw const ValidationFailure(
        'Ajoutez un numéro de téléphone pour envoyer un rappel WhatsApp.',
      );
    }

    final message = customer.balanceDue > 0
        ? 'Bonjour ${customer.name}, votre solde chez $shopName est de ${formatFcfa(customer.balanceDue)}. Merci de régulariser votre situation.'
        : 'Bonjour ${customer.name}, merci pour votre confiance chez $shopName !';

    return DebtReminder(
      customerId: customerId,
      customerName: customer.name,
      balanceDue: customer.balanceDue,
      message: message,
      whatsappUrl: _buildWhatsappUrl(customer.phone!, message),
    );
  }

  @override
  Future<Customer> createCustomer({
    required int shopId,
    required CreateCustomerInput input,
    int? serverShopId,
  }) async {
    final name = input.name.trim();
    _validation.assertName(name);
    final phone = input.phone?.trim();
    final note = input.note?.trim();

    final customer = await _local.insertCustomer(
      shopId: shopId,
      name: name,
      phone: phone?.isEmpty == true ? null : phone,
      address: input.address?.trim().isEmpty == true
          ? null
          : input.address?.trim(),
      note: note?.isEmpty == true ? null : note,
      isShared: input.isShared,
    );

    await _recorder?.recordCustomerCreate(
      shopId: shopId,
      customerId: customer.id,
      name: customer.name,
      phone: customer.phone,
      address: customer.address,
      note: customer.note,
      isShared: customer.isShared,
    );

    return customer.copyWith(
      phoneWarning: _validation.phoneWarning(customer.phone),
    );
  }

  @override
  Future<Customer> updateCustomer({
    required int shopId,
    required int customerId,
    required UpdateCustomerInput input,
  }) async {
    final existing = await _local.findCustomer(shopId, customerId);
    if (existing == null) {
      throw const NotFoundFailure('Client introuvable.');
    }
    if (existing.shopId != shopId) {
      throw const ValidationFailure(
        'Ce client partagé ne peut être modifié que depuis sa boutique d\'origine.',
      );
    }
    _validation.assertNotArchived(existing.isArchived);

    if (input.name != null) _validation.assertName(input.name!);

    final updated = await _local.updateCustomer(
      shopId: shopId,
      customerId: customerId,
      name: input.name?.trim(),
      phone: input.phone?.trim(),
      address: input.address?.trim(),
      note: input.note?.trim(),
      isShared: input.isShared,
    );

    await _recorder?.recordCustomerUpdate(
      shopId: shopId,
      customerId: customerId,
      fields: {
        if (input.name != null) 'name': input.name!.trim(),
        if (input.phone != null) 'phone': input.phone!.trim(),
        if (input.address != null) 'address': input.address!.trim(),
        if (input.note != null) 'note': input.note!.trim(),
        if (input.isShared != null) 'isShared': input.isShared!,
      },
      version: 1,
    );

    return updated.copyWith(
      phoneWarning: _validation.phoneWarning(updated.phone),
    );
  }

  @override
  Future<void> archiveCustomer({
    required int shopId,
    required int customerId,
  }) async {
    final existing = await _local.findCustomer(shopId, customerId);
    if (existing == null) {
      throw const NotFoundFailure('Client introuvable.');
    }
    if (existing.shopId != shopId) {
      throw const ValidationFailure(
        'Ce client partagé ne peut être archivé que depuis sa boutique d\'origine.',
      );
    }
    _validation.assertNotArchived(existing.isArchived);
    _validation.assertCanArchive(existing.openDebtsCount);

    await _local.archiveCustomer(shopId: shopId, customerId: customerId);
    await _recorder?.recordCustomerArchive(
      shopId: shopId,
      customerId: customerId,
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
}
