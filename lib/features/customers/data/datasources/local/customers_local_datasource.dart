import 'package:drift/drift.dart';

import '../../../../../core/database/app_database.dart' as db;
import '../../../../../core/shop/shop_hierarchy.dart';
import '../../../../../core/utils/time.dart';
import '../../../domain/entities/customer_entities.dart';
import '../../mappers/customer_mapper.dart';

class _CustomerStats {
  const _CustomerStats({
    this.balanceDue = 0,
    this.openDebtsCount = 0,
    this.purchaseCount = 0,
    this.totalPurchases = 0,
    this.lastActivityAt,
    this.oldestDebtAt,
  });

  final int balanceDue;
  final int openDebtsCount;
  final int purchaseCount;
  final int totalPurchases;
  final int? lastActivityAt;
  final int? oldestDebtAt;
}

class CustomersLocalDatasource {
  CustomersLocalDatasource(this._db);

  final db.AppDatabase _db;

  Future<Set<int>> _ownerShopIds(int shopId) async {
    final ids = await ShopHierarchy.groupShopIdsFromDb(_db, shopId);
    return ids.toSet();
  }

  Expression<bool> _visibleCustomerExpr(
    db.$CustomersTable c,
    int shopId,
    Set<int> ownerShopIds,
  ) {
    final inOwnerShops = c.shopId.isIn(ownerShopIds.toList());
    if (ownerShopIds.length <= 1) {
      return c.shopId.equals(shopId);
    }
    return inOwnerShops &
        (c.shopId.equals(shopId) | c.isShared.equals(true));
  }

  Future<bool> _isCustomerVisible(int shopId, int customerId) async {
    final row = await (_db.select(_db.customers)
          ..where((c) => c.id.equals(customerId)))
        .getSingleOrNull();
    if (row == null) return false;
    if (row.shopId == shopId) return true;
    if (!row.isShared) return false;
    final ownerShops = await _ownerShopIds(shopId);
    return ownerShops.contains(row.shopId);
  }

  Future<List<Customer>> listCustomers({
    required int shopId,
    CustomerListFilters filters = const CustomerListFilters(),
  }) async {
    final ownerShopIds = await _ownerShopIds(shopId);
    final rows = await (_db.select(_db.customers)
          ..where((c) {
            var expr = _visibleCustomerExpr(c, shopId, ownerShopIds);
            if (!filters.includeArchived) {
              expr = expr & c.isArchived.equals(false);
            }
            if (filters.search.trim().isNotEmpty) {
              final term = '%${filters.search.trim()}%';
              expr = expr & (c.name.like(term) | c.phone.like(term));
            }
            return expr;
          }))
        .get();

    final customers = <Customer>[];
    for (final row in rows) {
      final stats = await _statsForCustomer(shopId, row.id);
      final lifetime = await _lifetimeStatsForCustomer(shopId, row.id);
      if (filters.hasDebtOnly && stats.balanceDue <= 0) continue;
      customers.add(
        CustomerMapper.fromRow(
          row,
          balanceDue: stats.balanceDue,
          openDebtsCount: stats.openDebtsCount,
          purchaseCount: stats.purchaseCount,
          totalPurchases: stats.totalPurchases,
          lifetimePurchaseCount: lifetime.purchaseCount,
          lifetimeTotalPurchases: lifetime.totalPurchases,
          lifetimeLastActivityAt: lifetime.lastActivityAt,
          lastActivityAt: stats.lastActivityAt,
        ),
      );
    }

    customers.sort((a, b) => switch (filters.sort) {
          CustomerSort.name => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
          CustomerSort.debt => b.balanceDue.compareTo(a.balanceDue),
          CustomerSort.lastActivity =>
            (b.lastActivityAt ?? 0).compareTo(a.lastActivityAt ?? 0),
        });

    if (customers.length > filters.limit) {
      return customers.sublist(0, filters.limit);
    }
    return customers;
  }

  Future<Customer?> findCustomer(int shopId, int customerId) async {
    if (!await _isCustomerVisible(shopId, customerId)) return null;

    final row = await (_db.select(_db.customers)
          ..where((c) => c.id.equals(customerId)))
        .getSingleOrNull();
    if (row == null) return null;

    final stats = await _statsForCustomer(shopId, customerId);
    final lifetime = await _lifetimeStatsForCustomer(shopId, customerId);
    return CustomerMapper.fromRow(
      row,
      balanceDue: stats.balanceDue,
      openDebtsCount: stats.openDebtsCount,
      purchaseCount: stats.purchaseCount,
      totalPurchases: stats.totalPurchases,
      lifetimePurchaseCount: lifetime.purchaseCount,
      lifetimeTotalPurchases: lifetime.totalPurchases,
      lifetimeLastActivityAt: lifetime.lastActivityAt,
      lastActivityAt: stats.lastActivityAt,
    );
  }

  Future<Customer?> findCustomerByServerId(int shopId, String serverId) async {
    final row = await (_db.select(_db.customers)
          ..where(
            (c) => c.shopId.equals(shopId) & c.serverId.equals(serverId),
          ))
        .getSingleOrNull();
    if (row == null) return null;

    final stats = await _statsForCustomer(shopId, row.id);
    final lifetime = await _lifetimeStatsForCustomer(shopId, row.id);
    return CustomerMapper.fromRow(
      row,
      balanceDue: stats.balanceDue,
      openDebtsCount: stats.openDebtsCount,
      purchaseCount: stats.purchaseCount,
      totalPurchases: stats.totalPurchases,
      lifetimePurchaseCount: lifetime.purchaseCount,
      lifetimeTotalPurchases: lifetime.totalPurchases,
      lifetimeLastActivityAt: lifetime.lastActivityAt,
      lastActivityAt: stats.lastActivityAt,
    );
  }

  Future<List<CustomerSaleSummary>> listCustomerSales({
    required int shopId,
    required int customerId,
    int limit = 50,
  }) async {
    final rows = await (_db.select(_db.sales)
          ..where(
            (s) =>
                s.shopId.equals(shopId) &
                s.customerId.equals(customerId) &
                s.status.equals('completed'),
          )
          ..orderBy([(s) => OrderingTerm.desc(s.createdAt)])
          ..limit(limit))
        .get();
    return rows.map((r) => CustomerMapper.saleFromRow(r)).toList();
  }

  Future<List<CustomerSaleSummary>> listCustomerSalesLifetime({
    required int shopId,
    required int customerId,
    int limit = 100,
  }) async {
    final customerIds = await _customerIdsForLifetime(shopId, customerId);
    final ownerShopIds = await _ownerShopIds(shopId);
    final shopNames = await _shopNames(ownerShopIds);

    final rows = await (_db.select(_db.sales)
          ..where(
            (s) =>
                s.shopId.isIn(ownerShopIds.toList()) &
                s.customerId.isIn(customerIds.toList()) &
                s.status.equals('completed'),
          )
          ..orderBy([(s) => OrderingTerm.desc(s.createdAt)])
          ..limit(limit))
        .get();

    return rows
        .map(
          (r) => CustomerMapper.saleFromRow(
            r,
            shopName: shopNames[r.shopId],
          ),
        )
        .toList();
  }

  Future<DebtorsOverview> listDebtors({required int shopId}) async {
    final customers = await listCustomers(
      shopId: shopId,
      filters: const CustomerListFilters(
        hasDebtOnly: true,
        sort: CustomerSort.debt,
        limit: 200,
      ),
    );

    const thirtyDaysMs = 30 * 24 * 60 * 60 * 1000;
    final now = nowMs();
    final debtors = <DebtorSummary>[];

    for (final customer in customers) {
      final stats = await _statsForCustomer(shopId, customer.id);
      final oldest = stats.oldestDebtAt ?? customer.lastActivityAt ?? now;
      debtors.add(
        DebtorSummary(
          customerId: customer.id,
          customerName: customer.name,
          phone: customer.phone,
          balanceDue: customer.balanceDue,
          openDebtsCount: customer.openDebtsCount,
          oldestDebtAt: oldest,
          isCritical: now - oldest >= thirtyDaysMs,
        ),
      );
    }

    final totalDebt =
        debtors.fold<int>(0, (sum, debtor) => sum + debtor.balanceDue);
    return DebtorsOverview(
      totalDebt: totalDebt,
      debtorCount: debtors.length,
      debtors: debtors,
    );
  }

  Future<Customer> insertCustomer({
    required int shopId,
    required String name,
    String? phone,
    String? address,
    String? note,
    bool isShared = false,
    String? serverId,
    int? syncedAt,
  }) async {
    final timestamp = nowMs();
    final id = await _db.into(_db.customers).insert(
          db.CustomersCompanion.insert(
            shopId: shopId,
            name: name,
            phone: Value(phone),
            address: Value(address),
            note: Value(note),
            isShared: Value(isShared),
            createdAt: timestamp,
            updatedAt: timestamp,
            serverId: Value(serverId),
            syncedAt: Value(syncedAt),
          ),
        );

    return Customer(
      id: id,
      shopId: shopId,
      name: name,
      phone: phone,
      address: address,
      note: note,
      isShared: isShared,
      createdAt: timestamp,
      updatedAt: timestamp,
      serverId: serverId,
    );
  }

  Future<Customer> updateCustomer({
    required int shopId,
    required int customerId,
    String? name,
    String? phone,
    String? address,
    String? note,
    bool? isShared,
  }) async {
    final row = await (_db.select(_db.customers)
          ..where((c) => c.id.equals(customerId) & c.shopId.equals(shopId)))
        .getSingleOrNull();
    if (row == null) {
      throw StateError('Client introuvable dans cette boutique.');
    }

    final timestamp = nowMs();
    await (_db.update(_db.customers)
          ..where(
            (c) => c.id.equals(customerId) & c.shopId.equals(shopId),
          ))
        .write(
      db.CustomersCompanion(
        name: name != null ? Value(name) : const Value.absent(),
        phone: phone != null ? Value(phone) : const Value.absent(),
        address: address != null ? Value(address) : const Value.absent(),
        note: note != null ? Value(note) : const Value.absent(),
        isShared: isShared != null ? Value(isShared) : const Value.absent(),
        updatedAt: Value(timestamp),
      ),
    );

    final updated = await findCustomer(shopId, customerId);
    return updated!;
  }

  Future<void> archiveCustomer({
    required int shopId,
    required int customerId,
  }) async {
    final row = await (_db.select(_db.customers)
          ..where((c) => c.id.equals(customerId) & c.shopId.equals(shopId)))
        .getSingleOrNull();
    if (row == null) {
      throw StateError('Seul le client de cette boutique peut être archivé.');
    }

    final timestamp = nowMs();
    await (_db.update(_db.customers)
          ..where(
            (c) => c.id.equals(customerId) & c.shopId.equals(shopId),
          ))
        .write(
      db.CustomersCompanion(
        isArchived: const Value(true),
        updatedAt: Value(timestamp),
      ),
    );
  }

  Future<void> upsertFromRemote({
    required int shopId,
    required int remoteId,
    required String name,
    String? phone,
    String? address,
    String? note,
    bool isArchived = false,
    bool isShared = false,
    required int createdAt,
    required int updatedAt,
  }) async {
    final existing = await (_db.select(_db.customers)
          ..where(
            (c) =>
                c.shopId.equals(shopId) &
                c.serverId.equals('$remoteId'),
          ))
        .getSingleOrNull();

    if (existing != null) {
      await (_db.update(_db.customers)..where((c) => c.id.equals(existing.id)))
          .write(
        db.CustomersCompanion(
          name: Value(name),
          phone: Value(phone),
          address: Value(address),
          note: Value(note),
          isArchived: Value(isArchived),
          isShared: Value(isShared),
          updatedAt: Value(updatedAt),
          syncedAt: Value(nowMs()),
        ),
      );
      return;
    }

    await _db.into(_db.customers).insert(
          db.CustomersCompanion.insert(
            shopId: shopId,
            name: name,
            phone: Value(phone),
            address: Value(address),
            note: Value(note),
            isArchived: Value(isArchived),
            isShared: Value(isShared),
            createdAt: createdAt,
            updatedAt: updatedAt,
            serverId: Value('$remoteId'),
            syncedAt: Value(nowMs()),
          ),
        );
  }

  Future<void> updateServerSync({
    required int customerId,
    required String serverId,
  }) async {
    final timestamp = nowMs();
    await (_db.update(_db.customers)..where((c) => c.id.equals(customerId)))
        .write(
      db.CustomersCompanion(
        serverId: Value(serverId),
        syncedAt: Value(timestamp),
        updatedAt: Value(timestamp),
      ),
    );
  }

  Future<_CustomerStats> _statsForCustomer(int shopId, int customerId) async {
    final debts = await (_db.select(_db.debts)
          ..where(
            (d) =>
                d.shopId.equals(shopId) &
                d.customerId.equals(customerId) &
                d.amountRemaining.isBiggerThanValue(0),
          ))
        .get();

    final openDebts = debts.where(
      (d) => d.status == 'open' || d.status == 'partial',
    );

    final balanceDue =
        openDebts.fold<int>(0, (sum, d) => sum + d.amountRemaining);
    final oldestDebtAt = openDebts.isEmpty
        ? null
        : openDebts.map((d) => d.createdAt).reduce((a, b) => a < b ? a : b);

    final sales = await (_db.select(_db.sales)
          ..where(
            (s) =>
                s.shopId.equals(shopId) &
                s.customerId.equals(customerId) &
                s.status.equals('completed'),
          ))
        .get();

    final purchaseCount = sales.length;
    final totalPurchases =
        sales.fold<int>(0, (sum, s) => sum + s.totalAmount);
    final lastActivityAt = sales.isEmpty
        ? null
        : sales.map((s) => s.createdAt).reduce((a, b) => a > b ? a : b);

    return _CustomerStats(
      balanceDue: balanceDue,
      openDebtsCount: openDebts.length,
      purchaseCount: purchaseCount,
      totalPurchases: totalPurchases,
      lastActivityAt: lastActivityAt,
      oldestDebtAt: oldestDebtAt,
    );
  }

  Future<Set<int>> _customerIdsForLifetime(int shopId, int customerId) async {
    final row = await (_db.select(_db.customers)
          ..where((c) => c.id.equals(customerId)))
        .getSingleOrNull();
    if (row == null) return {customerId};

    final ownerShopIds = await _ownerShopIds(shopId);
    if (row.serverId != null && row.serverId!.isNotEmpty) {
      final linked = await (_db.select(_db.customers)
            ..where(
              (c) =>
                  c.serverId.equals(row.serverId!) &
                  c.shopId.isIn(ownerShopIds.toList()),
            ))
          .get();
      if (linked.isNotEmpty) {
        return linked.map((c) => c.id).toSet();
      }
    }
    return {customerId};
  }

  Future<Map<int, String>> _shopNames(Set<int> shopIds) async {
    if (shopIds.isEmpty) return {};
    final rows = await (_db.select(_db.shops)
          ..where((s) => s.id.isIn(shopIds.toList())))
        .get();
    return {for (final s in rows) s.id: s.name};
  }

  Future<_CustomerStats> _lifetimeStatsForCustomer(
    int shopId,
    int customerId,
  ) async {
    final customerIds = await _customerIdsForLifetime(shopId, customerId);
    final ownerShopIds = await _ownerShopIds(shopId);

    final sales = await (_db.select(_db.sales)
          ..where(
            (s) =>
                s.shopId.isIn(ownerShopIds.toList()) &
                s.customerId.isIn(customerIds.toList()) &
                s.status.equals('completed'),
          ))
        .get();

    final purchaseCount = sales.length;
    final totalPurchases =
        sales.fold<int>(0, (sum, s) => sum + s.totalAmount);
    final lastActivityAt = sales.isEmpty
        ? null
        : sales.map((s) => s.createdAt).reduce((a, b) => a > b ? a : b);

    return _CustomerStats(
      purchaseCount: purchaseCount,
      totalPurchases: totalPurchases,
      lastActivityAt: lastActivityAt,
    );
  }
}
