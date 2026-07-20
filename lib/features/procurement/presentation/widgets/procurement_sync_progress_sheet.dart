import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../app/di/injection_container.dart';
import '../../../../app/theme/app_tokens.dart';
import '../../../../core/sync/sync_service.dart';
import '../../data/services/procurement_sync_status_service.dart';
import '../../domain/entities/procurement_sync_entities.dart';

/// Feuille de suivi post approvisionnement direct (3 étapes cloud).
class ProcurementSyncProgressSheet {
  static Future<void> show(
    BuildContext context, {
    required int shopId,
    required String receiptNumber,
    required bool invoiceExpected,
    required bool paymentExpected,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isDismissible: true,
      builder: (ctx) => _ProcurementSyncProgressBody(
        shopId: shopId,
        receiptNumber: receiptNumber,
        invoiceExpected: invoiceExpected,
        paymentExpected: paymentExpected,
      ),
    );
  }
}

class _ProcurementSyncProgressBody extends StatefulWidget {
  const _ProcurementSyncProgressBody({
    required this.shopId,
    required this.receiptNumber,
    required this.invoiceExpected,
    required this.paymentExpected,
  });

  final int shopId;
  final String receiptNumber;
  final bool invoiceExpected;
  final bool paymentExpected;

  @override
  State<_ProcurementSyncProgressBody> createState() =>
      _ProcurementSyncProgressBodyState();
}

class _ProcurementSyncProgressBodyState
    extends State<_ProcurementSyncProgressBody> {
  ProcurementDirectSyncProgress? _progress;
  Timer? _timer;
  bool _syncTriggered = false;

  @override
  void initState() {
    super.initState();
    _triggerSync();
    _poll();
    _timer = Timer.periodic(const Duration(seconds: 2), (_) => _poll());
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _triggerSync() {
    if (_syncTriggered) return;
    _syncTriggered = true;
    sl<SyncService>().scheduleSync(shopId: widget.shopId);
  }

  Future<void> _poll() async {
    final service = sl<ProcurementSyncStatusService>();
    final progress = await service.loadDirectProgress(
      shopId: widget.shopId,
      receiptNumber: widget.receiptNumber,
      invoiceExpected: widget.invoiceExpected,
      paymentExpected: widget.paymentExpected,
    );
    if (!mounted) return;
    setState(() => _progress = progress);
    if (progress.allDone && !progress.hasError) {
      _timer?.cancel();
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = _progress;
    final theme = Theme.of(context);

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Enregistré sur cet appareil',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              'Bon ${widget.receiptNumber} — envoi cloud en cours. '
              'Vous pouvez continuer à travailler.',
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: AppSpacing.lg),
            _StepRow(
              label: 'Réception',
              done: p?.receiptDone ?? false,
              active: p != null && !p.receiptDone,
              error: p?.hasError == true && !(p?.receiptDone ?? true),
            ),
            if (widget.invoiceExpected)
              _StepRow(
                label: 'Facture fournisseur',
                done: p?.invoiceDone ?? false,
                active: p?.receiptDone == true && p?.invoiceDone != true,
                error: p?.hasError == true && p?.receiptDone == true && p?.invoiceDone != true,
              ),
            if (widget.paymentExpected)
              _StepRow(
                label: 'Paiement fournisseur',
                done: p?.paymentDone ?? false,
                active: p?.invoiceDone == true && p?.paymentDone != true,
                error: p?.hasError == true && p?.invoiceDone == true && p?.paymentDone != true,
              ),
            const SizedBox(height: AppSpacing.lg),
            if (p?.allDone == true && !p!.hasError)
              Text(
                'Tout est synchronisé avec le cloud.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: Colors.green.shade800,
                  fontWeight: FontWeight.w600,
                ),
              ),
            if (p?.hasError == true)
              Text(
                'Un élément nécessite une vérification. '
                'Consultez « Sync appro » depuis l\'écran principal.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.error,
                ),
              ),
            const SizedBox(height: AppSpacing.md),
            FilledButton(
              onPressed: () => Navigator.pop(context),
              child: Text(p?.allDone == true ? 'Terminer' : 'Continuer'),
            ),
          ],
        ),
      ),
    );
  }
}

class _StepRow extends StatelessWidget {
  const _StepRow({
    required this.label,
    required this.done,
    required this.active,
    required this.error,
  });

  final String label;
  final bool done;
  final bool active;
  final bool error;

  @override
  Widget build(BuildContext context) {
    final icon = error
        ? Icons.error_outline
        : done
            ? Icons.check_circle
            : active
                ? Icons.hourglass_top
                : Icons.radio_button_unchecked;
    final color = error
        ? Theme.of(context).colorScheme.error
        : done
            ? Colors.green.shade700
            : active
                ? Colors.orange.shade800
                : Theme.of(context).colorScheme.outline;

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Row(
        children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(width: AppSpacing.sm),
          Expanded(child: Text(label)),
          if (active && !done)
            SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2, color: color),
            ),
        ],
      ),
    );
  }
}
