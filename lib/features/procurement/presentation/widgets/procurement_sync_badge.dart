import 'package:flutter/material.dart';

import '../../domain/entities/procurement.dart';
import '../../domain/entities/procurement_sync_entities.dart';
import 'procurement_sync_scope.dart';

/// Badge cloud sur une ligne document (réception, facture, commande).
class ProcurementSyncBadge extends StatelessWidget {
  const ProcurementSyncBadge({
    super.key,
    required this.kind,
    required this.localId,
    this.serverId,
    this.compact = true,
  });

  final ProcurementSyncEntityKind kind;
  final int localId;
  final String? serverId;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final overview = ProcurementSyncScope.overviewOf(context);
    final state = overview.stateFor(
      kind: kind,
      localId: localId,
      serverId: serverId,
    );

    if (state == ProcurementCloudSyncState.synced) {
      return compact
          ? const SizedBox.shrink()
          : _chip(
              context,
              label: 'Synchronisé',
              fg: Colors.green.shade800,
              bg: Colors.green.shade100,
              icon: Icons.cloud_done_outlined,
            );
    }

    if (state == ProcurementCloudSyncState.error) {
      return _chip(
        context,
        label: compact ? 'Sync' : 'À vérifier',
        fg: Theme.of(context).colorScheme.error,
        bg: Theme.of(context).colorScheme.errorContainer,
        icon: Icons.cloud_off_outlined,
      );
    }

    return _chip(
      context,
      label: compact ? 'Sync…' : 'Envoi cloud…',
      fg: Colors.orange.shade900,
      bg: Colors.orange.shade100,
      icon: Icons.cloud_upload_outlined,
    );
  }

  Widget _chip(
    BuildContext context, {
    required String label,
    required Color fg,
    required Color bg,
    required IconData icon,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: fg),
          if (!compact) ...[
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                color: fg,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Statut paiement + sync pour factures payées localement.
class ProcurementInvoiceStatusChip extends StatelessWidget {
  const ProcurementInvoiceStatusChip({
    super.key,
    required this.invoiceId,
    required this.status,
    this.serverId,
  });

  final int invoiceId;
  final SupplierInvoiceStatus status;
  final String? serverId;

  @override
  Widget build(BuildContext context) {
    final overview = ProcurementSyncScope.overviewOf(context);
    final invoicePending = overview.stateFor(
          kind: ProcurementSyncEntityKind.invoice,
          localId: invoiceId,
          serverId: serverId,
        ) !=
        ProcurementCloudSyncState.synced;

    if (status == SupplierInvoiceStatus.paid && invoicePending) {
      return _labelChip(
        'Payée (sync…)',
        Colors.teal.shade800,
        Colors.teal.shade100,
      );
    }

    final (label, fg, bg) = switch (status) {
      SupplierInvoiceStatus.unpaid => (
          'Impayée',
          Colors.red.shade800,
          Colors.red.shade100,
        ),
      SupplierInvoiceStatus.partiallyPaid => (
          'Partielle',
          Colors.orange.shade900,
          Colors.orange.shade100,
        ),
      SupplierInvoiceStatus.paid => (
          'Payée',
          Colors.green.shade800,
          Colors.green.shade100,
        ),
    };
    return _labelChip(label, fg, bg);
  }

  Widget _labelChip(String label, Color fg, Color bg) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: fg,
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
