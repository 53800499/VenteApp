import '../../../../core/errors/failures.dart';
import '../../../../core/network/remote_api_guard.dart';
import '../../../../core/sync/local_write_sync_recorder.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../domain/entities/customer_entities.dart';
import '../../domain/repositories/customer_repository.dart';
import '../../domain/services/customer_validation_service.dart';
import '../datasources/local/customers_local_datasource.dart';
import '../datasources/remote/customers_remote_datasource.dart';
import '../models/customer_api_models.dart';

class CustomerRepositoryImpl implements CustomerRepository {
  CustomerRepositoryImpl({
    required CustomersLocalDatasource local,
    required CustomersRemoteDatasource remote,
    required RemoteApiGuard apiGuard,
    LocalWriteSyncRecorder? recorder,
    CustomerValidationService? validation,
  })  : _local = local,
        _remote = remote,
        _apiGuard = apiGuard,
        _recorder = recorder,
        _validation = validation ?? const CustomerValidationService();

  final CustomersLocalDatasource _local;
  final CustomersRemoteDatasource _remote;
  final RemoteApiGuard _apiGuard;
  final LocalWriteSyncRecorder? _recorder;
  final CustomerValidationService _validation;

  @override
  Future<void> syncFromRemote({required int shopId}) async {
    try {
      await _apiGuard.ensureReady();
      final remoteCustomers = await _fetchAllRemoteCustomers();
      for (final remote in remoteCustomers) {
        await _local.upsertFromRemote(
          shopId: remote.shopId > 0 ? remote.shopId : shopId,
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
    } on Failure {
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
  Future<Customer> getCustomer({
    required int shopId,
    required int customerId,
  }) async {
    final local = await _local.findCustomer(shopId, customerId);
    if (local == null) {
      throw const NotFoundFailure('Client introuvable.');
    }

    try {
      if (local.serverId != null) {
        await _apiGuard.ensureReady();
        final remote = await _remote.getCustomer(int.parse(local.serverId!));
        await _local.upsertFromRemote(
          shopId: remote.shopId > 0 ? remote.shopId : shopId,
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
    } on Failure {
      // Données locales utilisées.
    }

    final refreshed = await _local.findCustomer(shopId, customerId);
    return refreshed!.copyWith(
      phoneWarning: _validation.phoneWarning(refreshed.phone),
    );
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

    try {
      if (customer.serverId != null) {
        await _apiGuard.ensureReady();
        return (await _remote.listCustomerSales(int.parse(customer.serverId!)))
            .map((s) => s.toEntity())
            .toList();
      }
    } on Failure {
      // Fallback local.
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

    try {
      if (customer.serverId != null) {
        await _apiGuard.ensureReady();
        final remote =
            await _remote.listCustomerSales(int.parse(customer.serverId!));
        if (remote.isNotEmpty) {
          return remote.map((s) => s.toEntity()).toList();
        }
      }
    } on Failure {
      // Fallback agrégation locale multi-boutiques.
    }

    return _local.listCustomerSalesLifetime(
      shopId: shopId,
      customerId: customerId,
    );
  }

  @override
  Future<DebtorsOverview> listDebtors({required int shopId}) async {
    try {
      await _apiGuard.ensureReady();
      return (await _remote.listDebtors()).toEntity();
    } on Failure {
      return _local.listDebtors(shopId: shopId);
    }
  }

  @override
  Future<DebtReminder> getDebtReminder({
    required int shopId,
    required int customerId,
    required String shopName,
  }) async {
    final customer = await getCustomer(shopId: shopId, customerId: customerId);

    try {
      if (customer.serverId != null) {
        await _apiGuard.ensureReady();
        return (await _remote.getDebtReminder(int.parse(customer.serverId!)))
            .toEntity();
      }
    } on Failure {
      // Fallback local.
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

    try {
      await _apiGuard.ensureReady();
      final remote = await _remote.createCustomer(
        name: name,
        phone: phone,
        address: input.address?.trim(),
        note: note,
        isShared: input.isShared,
      );
      return _local.insertCustomer(
        shopId: shopId,
        name: remote.name,
        phone: remote.phone,
        address: remote.address,
        note: remote.note,
        isShared: remote.isShared,
        serverId: '${remote.id}',
        syncedAt: DateTime.now().millisecondsSinceEpoch,
      );
    } catch (_) {
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
      return customer;
    }
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

    try {
      if (existing.serverId != null) {
        await _apiGuard.ensureReady();
        await _remote.updateCustomer(
          int.parse(existing.serverId!),
          name: input.name?.trim(),
          phone: input.phone?.trim(),
          address: input.address?.trim(),
          note: input.note?.trim(),
          isShared: input.isShared,
        );
      }
    } on Failure {
      // Mise à jour locale maintenue.
    }

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

    return updated;
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

    try {
      if (existing.serverId != null) {
        await _apiGuard.ensureReady();
        await _remote.archiveCustomer(int.parse(existing.serverId!));
      }
    } on Failure {
      // Archivage local si hors ligne.
    }

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
