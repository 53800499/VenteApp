import 'dart:convert';
import 'sync_constants.dart';
import '../database/app_database.dart';

/// Graphe de dépendances d'entités pour le moteur de synchronisation ARIKE.
///
/// Permet de vérifier si une opération sur une entité dépend d'une autre entité
/// amont dont la synchronisation sur le cloud n'est pas encore confirmée.
class SyncDependencyGraph {
  const SyncDependencyGraph();

  /// Extrait la liste des clés de dépendances d'un élément (`table:recordId`).
  ///
  /// Exemple: Une Vente liée au Client #12 et aux Produits #5, #8
  /// retourne `['customers:12', 'products:5', 'products:8']`.
  Set<String> getPrerequisiteKeys(SyncQueueData item) {
    final keys = <String>{};
    if (item.payload.isEmpty) return keys;

    Map<String, dynamic> payload;
    try {
      final decoded = jsonDecode(item.payload);
      if (decoded is Map<String, dynamic>) {
        payload = decoded;
      } else {
        return keys;
      }
    } catch (_) {
      return keys;
    }

    switch (item.entityTable) {
      case SyncEntityTable.sales:
        _addKeyIfPresent(keys, SyncEntityTable.customers, payload['customer_id'] ?? payload['customerId']);
        _addKeyIfPresent(keys, SyncEntityTable.cashSessions, payload['cash_session_id'] ?? payload['cashSessionId']);
        final items = payload['items'] ?? payload['lines'];
        if (items is List) {
          for (final line in items) {
            if (line is Map<String, dynamic>) {
              _addKeyIfPresent(keys, SyncEntityTable.products, line['product_id'] ?? line['productId']);
            }
          }
        }
      case SyncEntityTable.debts:
        _addKeyIfPresent(keys, SyncEntityTable.customers, payload['customer_id'] ?? payload['customerId']);
        _addKeyIfPresent(keys, SyncEntityTable.sales, payload['sale_id'] ?? payload['saleId']);
      case SyncEntityTable.expenses:
        _addKeyIfPresent(keys, SyncEntityTable.cashSessions, payload['cash_session_id'] ?? payload['cashSessionId']);
      case SyncEntityTable.cashMovements:
        _addKeyIfPresent(keys, SyncEntityTable.cashSessions, payload['cash_session_id'] ?? payload['cashSessionId']);
      case SyncEntityTable.purchaseOrders:
        _addKeyIfPresent(keys, SyncEntityTable.suppliers, payload['supplier_id'] ?? payload['supplierId']);
      case SyncEntityTable.purchaseReceipts:
        _addKeyIfPresent(keys, SyncEntityTable.purchaseOrders, payload['purchase_order_id'] ?? payload['purchaseOrderId']);
        _addKeyIfPresent(keys, SyncEntityTable.suppliers, payload['supplier_id'] ?? payload['supplierId']);
      case SyncEntityTable.supplierInvoices:
        _addKeyIfPresent(keys, SyncEntityTable.suppliers, payload['supplier_id'] ?? payload['supplierId']);
        _addKeyIfPresent(keys, SyncEntityTable.purchaseOrders, payload['purchase_order_id'] ?? payload['purchaseOrderId']);
      case SyncEntityTable.supplierPayments:
        _addKeyIfPresent(keys, SyncEntityTable.suppliers, payload['supplier_id'] ?? payload['supplierId']);
        _addKeyIfPresent(keys, SyncEntityTable.supplierInvoices, payload['supplier_invoice_id'] ?? payload['supplierInvoiceId']);
      case SyncEntityTable.stockTransfers:
        final items = payload['items'];
        if (items is List) {
          for (final line in items) {
            if (line is Map<String, dynamic>) {
              _addKeyIfPresent(keys, SyncEntityTable.products, line['product_id'] ?? line['productId']);
            }
          }
        }
      case SyncEntityTable.salesOrders:
        _addKeyIfPresent(keys, SyncEntityTable.customers, payload['customer_id'] ?? payload['customerId']);
      case SyncEntityTable.fxOperations:
        _addKeyIfPresent(keys, SyncEntityTable.fxSessions, payload['fx_session_id'] ?? payload['fxSessionId']);
      case SyncEntityTable.fxMovements:
        _addKeyIfPresent(keys, SyncEntityTable.fxSessions, payload['fx_session_id'] ?? payload['fxSessionId']);
        _addKeyIfPresent(keys, SyncEntityTable.fxOperations, payload['fx_operation_id'] ?? payload['fxOperationId']);
      default:
        break;
    }

    return keys;
  }

  /// Détermine si un élément peut être exécuté immédiatement sans bloquer
  /// sur des dépendances parentes en file.
  bool canRun({
    required SyncQueueData item,
    required Set<String> pendingRecordKeys,
  }) {
    final prerequisites = getPrerequisiteKeys(item);
    for (final prereqKey in prerequisites) {
      if (pendingRecordKeys.contains(prereqKey)) {
        return false;
      }
    }
    return true;
  }

  /// Construit la clé unique d'enregistrement d'un élément (`table:recordId`).
  String getItemKey(SyncQueueData item) => '${item.entityTable}:${item.recordId}';

  /// Calcule le surélèvement de priorité (Priority Boost) pour les éléments amonts
  /// dont dépendent d'autres éléments prioritaires en file d'attente.
  Map<String, int> calculateDependencyBoosts(List<SyncQueueData> pendingItems) {
    final boosts = <String, int>{};

    for (final item in pendingItems) {
      final prereqs = getPrerequisiteKeys(item);
      if (prereqs.isEmpty) continue;

      // Si l'élément lui-même a une priorité ou criticité élevée, on la transmet à ses prérequis
      final boostAmount = item.basePriority + (item.businessCriticality == 'CRITICAL' ? 5000 : 500);
      for (final prereqKey in prereqs) {
        boosts[prereqKey] = (boosts[prereqKey] ?? 0) + boostAmount;
      }
    }

    return boosts;
  }

  void _addKeyIfPresent(Set<String> keys, String table, dynamic id) {
    if (id == null) return;
    if (id is int && id > 0) {
      keys.add('$table:$id');
    } else if (id is String && id.trim().isNotEmpty) {
      keys.add('$table:$id');
    }
  }
}
