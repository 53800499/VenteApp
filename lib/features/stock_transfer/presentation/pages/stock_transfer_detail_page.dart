import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../app/di/injection_container.dart';
import '../../../../app/theme/app_tokens.dart';
import '../../../../core/sync/sync_service.dart';
import '../../../../core/sync/sync_snapshot.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../../shared/enums/permission.dart';
import '../../../../shared/guards/permission_guard.dart';
import '../../domain/entities/stock_transfer.dart';
import '../../domain/repositories/stock_transfer_repository.dart';
import '../../domain/utils/stock_transfer_cloud_gate.dart';
import '../bloc/stock_transfer_bloc.dart' hide StockTransferEvent;
import '../services/stock_transfer_qr_sharer.dart';
import '../widgets/stock_transfer_qr_dialog.dart';
import '../widgets/transfer_missing_products_dialog.dart';
import '../widgets/transfer_receive_dialog.dart';
import '../widgets/transfer_resolve_discrepancy_dialog.dart';

class StockTransferDetailPage extends StatefulWidget {
  const StockTransferDetailPage({
    super.key,
    required this.transferId,
    this.initialReceiveQuantities,
    this.initialShipmentId,
  });

  final int transferId;
  final Map<int, int>? initialReceiveQuantities;
  final int? initialShipmentId;

  @override
  State<StockTransferDetailPage> createState() =>
      _StockTransferDetailPageState();
}

class _StockTransferDetailPageState extends State<StockTransferDetailPage> {
  bool _actionPending = false;
  String? _pendingQrShipmentLabel;
  StreamSubscription<dynamic>? _syncSubscription;
  final Map<int, TextEditingController> _receiveControllers = {};
  final Map<int, TextEditingController> _shipControllers = {};
  Set<int> _shopAliasIds = {};
  bool _shopAliasesLoaded = false;
  bool _qrReceivePromptScheduled = false;

  @override
  void initState() {
    super.initState();
    context
        .read<StockTransferBloc>()
        .add(StockTransferDetailLoadRequested(widget.transferId));

    _syncSubscription = sl<SyncService>().snapshots.listen((snapshot) {
      if (!mounted) return;
      if (snapshot.shopId != context.read<StockTransferBloc>().shopId) return;
      if (snapshot.phase != SyncRunPhase.completed) return;
      // Silent : pas de loader ni d'affichage intermédiaire incorrect.
      context.read<StockTransferBloc>().add(
            StockTransferDetailLoadRequested(
              widget.transferId,
              silent: true,
            ),
          );
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_shopAliasesLoaded) return;
    _shopAliasesLoaded = true;
    final shopId = context.read<StockTransferBloc>().shopId;
    unawaited(_loadShopAliases(shopId));
  }

  Future<void> _loadShopAliases(int shopId) async {
    final ids = await sl<StockTransferRepository>().shopAliases(shopId);
    if (!mounted) return;
    setState(() => _shopAliasIds = ids);
  }

  bool _matchesCurrentShop(int transferShopId, int sessionShopId) {
    if (transferShopId == sessionShopId) return true;
    if (_shopAliasIds.isEmpty) return false;
    return _shopAliasIds.contains(transferShopId);
  }

  @override
  void dispose() {
    _syncSubscription?.cancel();
    for (final c in _receiveControllers.values) {
      c.dispose();
    }
    for (final c in _shipControllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bloc = context.read<StockTransferBloc>();
    final session = bloc.session;
    final shopId = bloc.shopId;
    final canManage = PermissionGuard.can(
      session.user.permissions,
      Permission.inventoryTransferCreate,
    );
    final canApprove = PermissionGuard.can(
      session.user.permissions,
      Permission.inventoryTransferApprove,
    );
    final canReceive = PermissionGuard.can(
      session.user.permissions,
      Permission.inventoryTransferReceive,
    );

    return BlocConsumer<StockTransferBloc, StockTransferState>(
      listenWhen: (prev, curr) =>
          (_actionPending && prev.status != curr.status) ||
          (curr.successMessage != null &&
              curr.successMessage != prev.successMessage),
      listener: (context, state) async {
        if (state.successMessage != null && context.mounted) {
          final message = state.successMessage!;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(message)),
          );
        }
        if (!_actionPending) return;
        if (state.status == StockTransferBlocStatus.failure) {
          _actionPending = false;
          if (state.errorMessage != null && context.mounted) {
            WidgetsBinding.instance.addPostFrameCallback((_) async {
              if (!context.mounted) return;
              await showDialog<void>(
                context: context,
                builder: (_) => AlertDialog(
                  title: const Text('Action impossible'),
                  content: Text(state.errorMessage!),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('OK'),
                    ),
                  ],
                ),
              );
            });
          }
          return;
        }
        if (state.status == StockTransferBlocStatus.loaded) {
          _actionPending = false;
          final transfer = state.selectedTransfer;
          if (transfer == null) {
            if (context.mounted) {
              Navigator.of(context).pop();
            }
            return;
          }
          if (_pendingQrShipmentLabel != null) {
            final label = _pendingQrShipmentLabel!;
            _pendingQrShipmentLabel = null;
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (!context.mounted) return;
              _showQrForShipment(context, transfer, label);
            });
          }
          if (context.mounted && state.successMessage == null) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (!context.mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Transfert mis à jour')),
              );
            });
          }
        }
      },
      builder: (context, state) {
        final transfer = state.selectedTransfer;
        // Toujours attendre la fin du chargement initial (évite données stale).
        if (state.status == StockTransferBlocStatus.loading) {
          return Scaffold(
            appBar: AppBar(
              title: Text(
                transfer?.reference ?? 'Transfert',
              ),
            ),
            body: const Center(child: CircularProgressIndicator()),
          );
        }
        if (transfer == null) {
          return Scaffold(
            appBar: AppBar(title: const Text('Transfert')),
            body: const Center(child: Text('Transfert introuvable')),
          );
        }

        final isSource = _matchesCurrentShop(transfer.sourceShopId, shopId);
        final isDestination =
            _matchesCurrentShop(transfer.destinationShopId, shopId);
        final items = transfer.items ?? [];
        final shipments = transfer.shipments ?? [];

        for (final item in items) {
          final initialReceive = widget.initialReceiveQuantities?[item.id] ??
              (widget.initialShipmentId != null
                  ? item.quantityPendingReceiveInShipment(
                      widget.initialShipmentId!,
                    )
                  : item.quantityPendingReceive);
          _receiveControllers.putIfAbsent(
            item.id,
            () => TextEditingController(text: '$initialReceive'),
          );
          _shipControllers.putIfAbsent(
            item.id,
            () => TextEditingController(
              text: '${item.quantityPendingShip}',
            ),
          );
        }

        final canCancelDraft = StockTransferStatus.canCancel(transfer.status);
        final canClose = isSource &&
            canManage &&
            StockTransferStatus.canClose(transfer.status);
        final canResolveDiscrepancy = isSource &&
            canManage &&
            StockTransferStatus.canResolveDiscrepancy(transfer.status);

        if (!_qrReceivePromptScheduled &&
            widget.initialReceiveQuantities != null &&
            canReceive &&
            isDestination &&
            StockTransferStatus.canReceive(transfer.status)) {
          _qrReceivePromptScheduled = true;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted) return;
            unawaited(
              _submitReceive(
                context,
                transfer,
                shipmentId: widget.initialShipmentId,
              ),
            );
          });
        }

        final events = transfer.events ?? [];
        final cloudEnabled = transfer.cloudSyncEnabled;
        final canShowValidate = isSource &&
            canManage &&
            StockTransferCloudGate.canValidate(
              transfer: transfer,
              cloudSyncEnabled: cloudEnabled,
            );
        final canShowSubmitForApproval = isSource &&
            canManage &&
            StockTransferStatus.canSubmitForApproval(transfer.status);
        final canShowApprove = isSource &&
            canApprove &&
            StockTransferStatus.canApprove(transfer.status);
        final canShowShip = isSource &&
            canManage &&
            StockTransferCloudGate.canShip(
              transfer: transfer,
              cloudSyncEnabled: cloudEnabled,
            );
        final shipBlockedMessage = cloudEnabled
            ? StockTransferCloudGate.shipBlockedMessage(transfer)
            : null;
        final shipSyncPending =
            cloudEnabled && StockTransferCloudGate.isShipSyncPending(transfer);
        final awaitingCloud =
            cloudEnabled && StockTransferCloudGate.isAwaitingCloudConfirmation(transfer);

        return Scaffold(
          appBar: AppBar(title: Text(transfer.reference)),
          body: ListView(
            padding: const EdgeInsets.all(AppSpacing.md),
            children: [
              _InfoCard(transfer: transfer),
              if (awaitingCloud && shipBlockedMessage != null) ...[
                const SizedBox(height: AppSpacing.sm),
                Card(
                  color: Colors.orange.shade50,
                  child: Padding(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.cloud_sync_outlined, color: Colors.orange.shade800),
                        const SizedBox(width: AppSpacing.sm),
                        Expanded(
                          child: Text(
                            shipBlockedMessage,
                            style: TextStyle(color: Colors.orange.shade900),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ] else if (shipSyncPending) ...[
                const SizedBox(height: AppSpacing.sm),
                Card(
                  color: Colors.blue.shade50,
                  child: Padding(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.cloud_upload_outlined, color: Colors.blue.shade800),
                        const SizedBox(width: AppSpacing.sm),
                        Expanded(
                          child: Text(
                            'Expédition en cours de synchronisation avec le cloud. '
                            'Le statut reste « ${StockTransferStatus.label(transfer.status)} » '
                            'jusqu\'à confirmation serveur.',
                            style: TextStyle(color: Colors.blue.shade900),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ] else if (transfer.hasPendingReceive) ...[
                const SizedBox(height: AppSpacing.sm),
                Card(
                  color: Colors.blue.shade50,
                  child: Padding(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.cloud_upload_outlined, color: Colors.blue.shade800),
                        const SizedBox(width: AppSpacing.sm),
                        Expanded(
                          child: Text(
                            'Réception en cours de synchronisation avec le cloud.',
                            style: TextStyle(color: Colors.blue.shade900),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
              if (transfer.isReturn && transfer.parentReference != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                  child: Card(
                    child: ListTile(
                      leading: const Icon(Icons.reply_outlined),
                      title: const Text('Transfert retour'),
                      subtitle: Text('Lié à ${transfer.parentReference}'),
                    ),
                  ),
                ),
              if (transfer.hasOpenDiscrepancy) ...[
                const SizedBox(height: AppSpacing.sm),
                Card(
                  color: Colors.amber.shade50,
                  child: ListTile(
                    leading: Icon(Icons.warning_amber, color: Colors.amber.shade800),
                    title: const Text('Écart expédié / reçu'),
                    subtitle: Text(
                      '${transfer.openDiscrepancyQuantity} '
                      'unité(s) non reçue(s). '
                      '${canResolveDiscrepancy ? 'Résolvez l\'écart article par article, puis clôturez le transfert.' : 'La boutique source doit résoudre l\'écart.'}',
                    ),
                  ),
                ),
              ] else if (transfer.hasDiscrepancy) ...[
                const SizedBox(height: AppSpacing.sm),
                Card(
                  color: Colors.amber.shade50,
                  child: ListTile(
                    leading: Icon(Icons.warning_amber, color: Colors.amber.shade800),
                    title: const Text('Clôturé avec écart'),
                    subtitle: Text(
                      'Ce transfert a été clôturé avec '
                      '${transfer.openDiscrepancyQuantity > 0 ? transfer.openDiscrepancyQuantity : transfer.pendingReceptionQuantity} '
                      'unité(s) non reçue(s).',
                    ),
                  ),
                ),
              ] else if (transfer.isAwaitingReception) ...[
                const SizedBox(height: AppSpacing.sm),
                Card(
                  color: Colors.blue.shade50,
                  child: ListTile(
                    leading: Icon(Icons.local_shipping_outlined, color: Colors.blue.shade800),
                    title: const Text('En attente de réception'),
                    subtitle: Text(
                      '${transfer.pendingReceptionQuantity} unité(s) expédiée(s) — '
                      'la boutique destinataire doit confirmer la réception '
                      '(scan QR ou saisie manuelle).',
                    ),
                  ),
                ),
              ],
              if (shipments.isNotEmpty) ...[
                const SizedBox(height: AppSpacing.md),
                Text(
                  'Expéditions',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                ),
                const SizedBox(height: AppSpacing.sm),
                ...shipments.map(
                  (s) => _ShipmentCard(
                    transfer: transfer,
                    shipment: s,
                    canReceive: isDestination &&
                        canReceive &&
                        StockTransferStatus.canReceive(transfer.status) &&
                        s.pendingReceiveQuantity(transfer) > 0,
                    onShowQr: () => _showQrForShipment(context, transfer, s.label),
                    onShareQr: () => _shareQrForShipment(context, transfer, s.label),
                    onReceive: _actionPending
                        ? null
                        : () => _submitReceiveShipment(context, transfer, s),
                  ),
                ),
              ],
              if ((transfer.receipts ?? [])
                  .any((receipt) => receipt.shipmentId == null)) ...[
                const SizedBox(height: AppSpacing.md),
                Text(
                  'Réceptions globales',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                ),
                const SizedBox(height: AppSpacing.sm),
                ...(transfer.receipts ?? [])
                    .where((receipt) => receipt.shipmentId == null)
                    .map(
                      (receipt) => Card(
                        margin: const EdgeInsets.only(bottom: AppSpacing.sm),
                        child: _ReceiptTile(
                          transfer: transfer,
                          receipt: receipt,
                        ),
                      ),
                    ),
              ],
              const SizedBox(height: AppSpacing.md),
              Text(
                'Articles',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
              ),
              const SizedBox(height: AppSpacing.sm),
              ...items.map(
                (item) {
                  final openGap = item.openDiscrepancyQuantity(
                    transfer.discrepancies ?? [],
                  );
                  return _ItemCard(
                    item: item,
                    transferStatus: transfer.status,
                    receiveController: _receiveControllers[item.id],
                    shipController: _shipControllers[item.id],
                    isSource: isSource,
                    isDestination: isDestination,
                    openDiscrepancyQuantity: openGap,
                    onResolveDiscrepancy: canResolveDiscrepancy &&
                            openGap > 0 &&
                            !_actionPending
                        ? () => _resolveDiscrepancy(context, transfer, item, openGap)
                        : null,
                  );
                },
              ),
              if (events.isNotEmpty) ...[
                const SizedBox(height: AppSpacing.md),
                Text(
                  'Journal',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                ),
                const SizedBox(height: AppSpacing.sm),
                _EventsTimeline(events: events),
              ],
              const SizedBox(height: AppSpacing.lg),
              if (canShowSubmitForApproval)
                OutlinedButton.icon(
                  onPressed: _actionPending
                      ? null
                      : () => _confirmSubmitForApproval(context, transfer),
                  icon: const Icon(Icons.pending_actions_outlined),
                  label: const Text('Soumettre pour approbation'),
                ),
              if (canShowApprove)
                FilledButton.icon(
                  onPressed: _actionPending
                      ? null
                      : () => _confirmApprove(context, transfer),
                  icon: const Icon(Icons.how_to_reg_outlined),
                  label: const Text('Approuver (validation FIFO)'),
                ),
              if (canShowValidate)
                FilledButton.icon(
                  onPressed: _actionPending
                      ? null
                      : () => _confirmValidate(context, transfer),
                  icon: const Icon(Icons.verified_outlined),
                  label: const Text('Valider (réservation FIFO)'),
                ),
              if (isSource &&
                  canManage &&
                  StockTransferStatus.canShip(transfer.status) &&
                  !canShowShip &&
                  shipBlockedMessage != null)
                Padding(
                  padding: const EdgeInsets.only(top: AppSpacing.sm),
                  child: OutlinedButton.icon(
                    onPressed: null,
                    icon: const Icon(Icons.local_shipping_outlined),
                    label: const Text('Expédition en attente du cloud'),
                  ),
                ),
              if (canShowShip) ...[
                Padding(
                  padding: const EdgeInsets.only(top: AppSpacing.sm),
                  child: FilledButton.icon(
                    onPressed: _actionPending
                        ? null
                        : () => _confirmShipAll(context, transfer),
                    icon: const Icon(Icons.local_shipping_outlined),
                    label: const Text('Expédier tout'),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(top: AppSpacing.sm),
                  child: OutlinedButton.icon(
                    onPressed: _actionPending
                        ? null
                        : () => _openPartialShipDialog(context, transfer),
                    icon: const Icon(Icons.call_split_outlined),
                    label: const Text('Expédition partielle…'),
                  ),
                ),
              ],
              if (isSource && canManage && canCancelDraft)
                Padding(
                  padding: const EdgeInsets.only(top: AppSpacing.sm),
                  child: OutlinedButton.icon(
                    onPressed: _actionPending
                        ? null
                        : () => _confirmCancel(context, transfer),
                    icon: const Icon(Icons.cancel_outlined),
                    label: Text(
                      transfer.status == StockTransferStatus.validated
                          ? 'Annuler (libérer réservations)'
                          : transfer.status ==
                                  StockTransferStatus.pendingApproval
                              ? 'Annuler la demande'
                              : 'Annuler le brouillon',
                    ),
                  ),
                ),
              if (canClose)
                Padding(
                  padding: const EdgeInsets.only(top: AppSpacing.sm),
                  child: FilledButton.icon(
                    onPressed: _actionPending
                        ? null
                        : () => _confirmClose(context, transfer),
                    icon: const Icon(Icons.lock_outline),
                    label: Text(
                      transfer.hasOpenDiscrepancy
                          ? 'Clôturer avec écart'
                          : 'Clôturer le transfert',
                    ),
                  ),
                ),
              if (isDestination &&
                  canReceive &&
                  StockTransferStatus.canCreateReturn(
                    transfer.status,
                    transfer.transferType,
                  ))
                OutlinedButton.icon(
                  onPressed: _actionPending
                      ? null
                      : () => _confirmCreateReturn(context, transfer),
                  icon: const Icon(Icons.reply_outlined),
                  label: const Text('Créer un retour'),
                ),
              if (isDestination &&
                  canReceive &&
                  StockTransferStatus.canReceive(transfer.status))
                FilledButton.icon(
                  onPressed: _actionPending
                      ? null
                      : () => _submitReceive(context, transfer),
                  icon: const Icon(Icons.inventory_2_outlined),
                  label: const Text('Réceptionner'),
                ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _confirmSubmitForApproval(
    BuildContext context,
    StockTransfer transfer,
  ) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Soumettre pour approbation ?'),
        content: const Text(
          'Le transfert passera en attente d\'approbation. '
          'Un responsable devra l\'approuver avant expédition.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Soumettre'),
          ),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;
    setState(() => _actionPending = true);
    context.read<StockTransferBloc>().add(
          StockTransferSubmitForApprovalRequested(transfer.id),
        );
  }

  Future<void> _confirmApprove(
    BuildContext context,
    StockTransfer transfer,
  ) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Approuver le transfert ?'),
        content: const Text(
          'Le stock sera réservé en FIFO dans la boutique source, '
          'comme pour une validation directe.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Approuver'),
          ),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;
    setState(() => _actionPending = true);
    context.read<StockTransferBloc>().add(
          StockTransferApproveRequested(transfer.id),
        );
  }

  Future<void> _confirmValidate(BuildContext context, StockTransfer transfer) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Valider le transfert ?'),
        content: const Text(
          'Le stock sera réservé en FIFO dans la boutique source. '
          'L\'expédition sera disponible une fois la validation confirmée par le cloud.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Valider'),
          ),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;
    setState(() => _actionPending = true);
    context
        .read<StockTransferBloc>()
        .add(StockTransferValidateRequested(transfer.id));
  }

  String _nextShipmentLabel(StockTransfer transfer) {
    final n = (transfer.shipments?.length ?? 0) + 1;
    return 'Expédition $n';
  }

  Future<void> _confirmShipAll(
    BuildContext context,
    StockTransfer transfer,
  ) async {
    final pendingItems =
        (transfer.items ?? []).where((i) => i.quantityPendingShip > 0).toList();
    if (pendingItems.isEmpty) return;

    final totalUnits =
        pendingItems.fold(0, (sum, i) => sum + i.quantityPendingShip);
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Confirmer l\'expédition'),
        content: Text(
          'Expédier $totalUnits unité(s) restante(s) '
          '(${pendingItems.length} article(s)) ?\n\n'
          'Le stock sera déduit en FIFO.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Expédier'),
          ),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;

    final label = _nextShipmentLabel(transfer);
    setState(() {
      _actionPending = true;
      _pendingQrShipmentLabel = label;
    });
    context.read<StockTransferBloc>().add(
          StockTransferShipRequested(
            transferId: transfer.id,
            shipmentLabel: label,
          ),
        );
  }

  Future<void> _openPartialShipDialog(
    BuildContext context,
    StockTransfer transfer,
  ) async {
    final labelController =
        TextEditingController(text: _nextShipmentLabel(transfer));
    final notesController = TextEditingController();
    final driverController = TextEditingController();
    final plateController = TextEditingController();
    final result = await showDialog<
        ({
          String label,
          String? notes,
          String? driverName,
          String? vehiclePlate,
          Map<int, int> quantities,
        })?>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Expédition partielle'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: labelController,
                  decoration: const InputDecoration(
                    labelText: 'Libellé (optionnel)',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                TextField(
                  controller: notesController,
                  decoration: const InputDecoration(
                    labelText: 'Notes (optionnel)',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                TextField(
                  controller: driverController,
                  decoration: const InputDecoration(
                    labelText: 'Chauffeur (optionnel)',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                TextField(
                  controller: plateController,
                  decoration: const InputDecoration(
                    labelText: 'Immatriculation (optionnel)',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                const Align(
                  alignment: Alignment.centerLeft,
                  child: Text('Quantités à expédier'),
                ),
                ...((transfer.items ?? []).where((i) => i.quantityPendingShip > 0)).map(
                  (item) => Padding(
                    padding: const EdgeInsets.only(top: AppSpacing.sm),
                    child: TextField(
                      controller: _shipControllers[item.id],
                      decoration: InputDecoration(
                        labelText:
                            '${item.productName ?? item.sourceProductId} '
                            '(max ${item.quantityPendingShip})',
                        border: const OutlineInputBorder(),
                      ),
                      keyboardType: TextInputType.number,
                    ),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Annuler'),
            ),
            FilledButton(
              onPressed: () {
                final quantities = <int, int>{};
                for (final item in transfer.items ?? []) {
                  final qty =
                      int.tryParse(_shipControllers[item.id]?.text.trim() ?? '') ??
                          0;
                  if (qty > 0) quantities[item.id] = qty;
                }
                if (quantities.isEmpty) return;
                Navigator.pop(
                  dialogContext,
                  (
                    label: labelController.text.trim(),
                    notes: notesController.text.trim().isEmpty
                        ? null
                        : notesController.text.trim(),
                    driverName: driverController.text.trim().isEmpty
                        ? null
                        : driverController.text.trim(),
                    vehiclePlate: plateController.text.trim().isEmpty
                        ? null
                        : plateController.text.trim(),
                    quantities: quantities,
                  ),
                );
              },
              child: const Text('Expédier'),
            ),
          ],
        );
      },
    );

    labelController.dispose();
    notesController.dispose();
    driverController.dispose();
    plateController.dispose();

    if (result == null || !context.mounted) return;
    setState(() {
      _actionPending = true;
      _pendingQrShipmentLabel =
          result.label.isEmpty ? 'Expédition' : result.label;
    });
    context.read<StockTransferBloc>().add(
          StockTransferShipRequested(
            transferId: transfer.id,
            shipmentLabel: result.label.isEmpty ? 'Expédition' : result.label,
            shipmentNotes: result.notes,
            driverName: result.driverName,
            vehiclePlate: result.vehiclePlate,
            quantitiesByItemId: result.quantities,
          ),
        );
  }

  Future<void> _showQrForShipment(
    BuildContext context,
    StockTransfer transfer,
    String shipmentLabel,
  ) async {
    ensureStockTransferDependencies();
    StockTransferShipment? matched;
    for (final s in transfer.shipments ?? []) {
      if (s.label == shipmentLabel) {
        matched = s;
        break;
      }
    }
    if (matched == null || !context.mounted) return;

    final payload = await sl<StockTransferRepository>().buildShipmentQrPayload(
      transferId: transfer.id,
      shipmentId: matched.id,
    );
    if (!context.mounted) return;
    await StockTransferQrDialog.show(
      context,
      payload: payload,
      title: 'QR expédition',
    );
  }

  Future<void> _shareQrForShipment(
    BuildContext context,
    StockTransfer transfer,
    String shipmentLabel,
  ) async {
    ensureStockTransferDependencies();
    StockTransferShipment? matched;
    for (final s in transfer.shipments ?? []) {
      if (s.label == shipmentLabel) {
        matched = s;
        break;
      }
    }
    if (matched == null || !context.mounted) return;

    try {
      final payload = await sl<StockTransferRepository>().buildShipmentQrPayload(
        transferId: transfer.id,
        shipmentId: matched.id,
      );
      await StockTransferQrSharer.share(payload);
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('QR partagé')),
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Partage impossible : $e')),
      );
    }
  }

  Future<void> _confirmCreateReturn(
    BuildContext context,
    StockTransfer transfer,
  ) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Créer un retour ?'),
        content: const Text(
          'Un brouillon de retour sera créé vers la boutique source, '
          'avec les quantités reçues.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Créer'),
          ),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;
    setState(() => _actionPending = true);
    context.read<StockTransferBloc>().add(
          StockTransferReturnCreateRequested(parentTransferId: transfer.id),
        );
  }

  Future<void> _confirmCancel(
    BuildContext context,
    StockTransfer transfer,
  ) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Annuler le transfert ?'),
        content: Text(
          transfer.status == StockTransferStatus.validated
              ? 'Les réservations seront libérées.'
              : transfer.status == StockTransferStatus.pendingApproval
                  ? 'La demande d\'approbation sera annulée.'
                  : 'Le brouillon sera annulé.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Non'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Oui, annuler'),
          ),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;
    setState(() => _actionPending = true);
    context
        .read<StockTransferBloc>()
        .add(StockTransferCancelRequested(transfer.id));
  }

  Future<void> _confirmClose(
    BuildContext context,
    StockTransfer transfer,
  ) async {
    final notes = await showDialog<String?>(
      context: context,
      builder: (_) => _CloseTransferDialog(
        hasOpenDiscrepancy: transfer.hasOpenDiscrepancy,
        openDiscrepancyQuantity: transfer.openDiscrepancyQuantity,
      ),
    );
    if (notes == null || !context.mounted) return;
    setState(() => _actionPending = true);
    context.read<StockTransferBloc>().add(
          StockTransferCloseRequested(
            transferId: transfer.id,
            notes: notes.isEmpty ? null : notes,
          ),
        );
  }

  Future<void> _resolveDiscrepancy(
    BuildContext context,
    StockTransfer transfer,
    StockTransferItem item,
    int maxQuantity,
  ) async {
    final result = await TransferResolveDiscrepancyDialog.show(
      context,
      productName: item.productName ?? 'Produit #${item.sourceProductId}',
      maxQuantity: maxQuantity,
    );
    if (result == null || !context.mounted) return;
    setState(() => _actionPending = true);
    context.read<StockTransferBloc>().add(
          StockTransferResolveDiscrepancySubmitted(
            transferId: transfer.id,
            itemId: item.id,
            quantity: result.quantity,
            reason: result.reason,
            resolution: result.resolution,
            notes: result.notes,
          ),
        );
  }

  Future<void> _submitReceive(
    BuildContext context,
    StockTransfer transfer, {
    int? shipmentId,
  }) async {
    final quantities = <int, int>{};
    for (final item in transfer.items ?? []) {
      final maxQty = shipmentId != null
          ? item.quantityPendingReceiveInShipment(shipmentId)
          : item.quantityPendingReceive;
      if (maxQty <= 0) continue;

      final controller = _receiveControllers[item.id];
      final qty = int.tryParse(controller?.text.trim() ?? '') ?? 0;
      final effectiveQty = shipmentId != null ? (qty > 0 ? qty : maxQty) : qty;
      if (effectiveQty > 0) quantities[item.id] = effectiveQty;
    }

    final result = await TransferReceiveDialog.show(
      context,
      transfer: transfer,
      shipmentId: shipmentId,
      initialQuantities: quantities.isEmpty ? null : quantities,
    );
    if (result == null || !context.mounted) return;

    final shopId = context.read<StockTransferBloc>().shopId;
    final missing = await sl<StockTransferRepository>().listMissingDestinationProducts(
      destinationShopId: shopId,
      transferId: transfer.id,
      quantitiesByItemId: result.quantitiesByItemId,
      shipmentId: shipmentId,
    );

    if (missing.isNotEmpty && context.mounted) {
      final salePrices = await TransferMissingProductsDialog.show(
        context,
        products: missing,
      );
      if (salePrices == null || !context.mounted) return;

      setState(() => _actionPending = true);
      context.read<StockTransferBloc>().add(
            StockTransferReceiveSubmitted(
              transferId: transfer.id,
              quantitiesByItemId: result.quantitiesByItemId,
              refusalsByItemId: result.refusalsByItemId,
              salePriceByItemId: salePrices,
              shipmentId: shipmentId,
            ),
          );
      return;
    }

    setState(() => _actionPending = true);
    if (!context.mounted) return;
    context.read<StockTransferBloc>().add(
          StockTransferReceiveSubmitted(
            transferId: transfer.id,
            quantitiesByItemId: result.quantitiesByItemId,
            refusalsByItemId: result.refusalsByItemId,
            shipmentId: shipmentId,
          ),
        );
  }

  Future<void> _submitReceiveShipment(
    BuildContext context,
    StockTransfer transfer,
    StockTransferShipment shipment,
  ) async {
    final pending = shipment.pendingReceiveQuantity(transfer);
    if (pending <= 0) return;

    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('Réceptionner ${shipment.reference}'),
        content: Text(
          'Confirmer la réception de $pending unité(s) '
          'pour l\'expédition « ${shipment.label} » ?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Réceptionner'),
          ),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;

    for (final item in transfer.items ?? []) {
      final qty = item.quantityPendingReceiveInShipment(shipment.id);
      _receiveControllers[item.id]?.text = qty > 0 ? '$qty' : '0';
    }

    await _submitReceive(context, transfer, shipmentId: shipment.id);
  }
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({required this.transfer});

  final StockTransfer transfer;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _row('Statut', StockTransferStatus.label(transfer.status)),
            _row('Source', transfer.sourceShopLabel),
            _row('Destination', transfer.destinationShopLabel),
            if (transfer.notes != null && transfer.notes!.isNotEmpty)
              _row('Remarques', transfer.notes!),
            if (transfer.validatedAt != null)
              _row(
                'Validé le',
                DateTime.fromMillisecondsSinceEpoch(transfer.validatedAt!)
                    .toLocal()
                    .toString()
                    .substring(0, 16),
              ),
            if (transfer.shippedAt != null)
              _row(
                'Expédié le',
                DateTime.fromMillisecondsSinceEpoch(transfer.shippedAt!)
                    .toLocal()
                    .toString()
                    .substring(0, 16),
              ),
            if (transfer.receivedAt != null)
              _row(
                'Reçu le',
                DateTime.fromMillisecondsSinceEpoch(transfer.receivedAt!)
                    .toLocal()
                    .toString()
                    .substring(0, 16),
              ),
            if (transfer.closedAt != null)
              _row(
                'Clôturé le',
                DateTime.fromMillisecondsSinceEpoch(transfer.closedAt!)
                    .toLocal()
                    .toString()
                    .substring(0, 16),
              ),
          ],
        ),
      ),
    );
  }

  Widget _row(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.xs),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }
}

class _ShipmentCard extends StatelessWidget {
  const _ShipmentCard({
    required this.transfer,
    required this.shipment,
    required this.onShowQr,
    required this.onShareQr,
    this.canReceive = false,
    this.onReceive,
  });

  final StockTransfer transfer;
  final StockTransferShipment shipment;
  final VoidCallback onShowQr;
  final VoidCallback onShareQr;
  final bool canReceive;
  final VoidCallback? onReceive;

  @override
  Widget build(BuildContext context) {
    final date = DateTime.fromMillisecondsSinceEpoch(shipment.shippedAt)
        .toLocal()
        .toString()
        .substring(0, 16);
    final pending = shipment.pendingReceiveQuantity(transfer);
    final receipts = shipment.receiptsFor(transfer);
    final subtitleParts = <String>[
      shipment.reference,
      date,
      if (shipment.driverName != null && shipment.driverName!.isNotEmpty)
        'Chauffeur : ${shipment.driverName}',
      if (shipment.vehiclePlate != null && shipment.vehiclePlate!.isNotEmpty)
        'Plaque : ${shipment.vehiclePlate}',
      if (shipment.notes != null && shipment.notes!.isNotEmpty) shipment.notes!,
      if (pending > 0) '$pending unité(s) en attente de réception',
    ];
    return Card(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.sm),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.local_shipping_outlined),
              title: Text(shipment.label),
              subtitle: Text(subtitleParts.join('\n')),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    tooltip: 'Partager le QR',
                    icon: const Icon(Icons.share_outlined),
                    onPressed: onShareQr,
                  ),
                  IconButton(
                    tooltip: 'Afficher le QR',
                    icon: const Icon(Icons.qr_code),
                    onPressed: onShowQr,
                  ),
                ],
              ),
            ),
            if (canReceive && onReceive != null)
              Align(
                alignment: Alignment.centerRight,
                child: FilledButton.icon(
                  onPressed: onReceive,
                  icon: const Icon(Icons.inventory_2_outlined),
                  label: Text('Réceptionner ($pending)'),
                ),
              ),
            if (receipts.isNotEmpty) ...[
              const Divider(height: AppSpacing.md),
              Text(
                'Réceptions (${receipts.length})',
                style: Theme.of(context).textTheme.labelLarge,
              ),
              const SizedBox(height: AppSpacing.xs),
              ...receipts.map(
                (receipt) => _ReceiptTile(
                  transfer: transfer,
                  receipt: receipt,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ReceiptTile extends StatelessWidget {
  const _ReceiptTile({
    required this.transfer,
    required this.receipt,
  });

  final StockTransfer transfer;
  final StockTransferReceipt receipt;

  String _productLabel(int transferItemId) {
    for (final item in transfer.items ?? []) {
      if (item.id == transferItemId) {
        return item.productName ?? 'Produit #${item.sourceProductId}';
      }
    }
    return 'Article #$transferItemId';
  }

  @override
  Widget build(BuildContext context) {
    final date = DateTime.fromMillisecondsSinceEpoch(receipt.receivedAt)
        .toLocal()
        .toString()
        .substring(0, 16);
    final lines = receipt.items ?? [];
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.xs),
      child: ListTile(
        contentPadding: EdgeInsets.zero,
        dense: true,
        leading: const Icon(Icons.receipt_long_outlined, size: 20),
        title: Text(receipt.reference),
        subtitle: Text(
          [
            date,
            '${receipt.totalQuantityReceived} unité(s)',
            if (receipt.notes != null && receipt.notes!.isNotEmpty)
              receipt.notes!,
            ...lines.map(
              (line) =>
                  '· ${_productLabel(line.transferItemId)} : ${line.quantityReceived}',
            ),
          ].join('\n'),
        ),
      ),
    );
  }
}

class _ItemCard extends StatelessWidget {
  const _ItemCard({
    required this.item,
    required this.transferStatus,
    this.receiveController,
    this.shipController,
    required this.isSource,
    required this.isDestination,
    this.openDiscrepancyQuantity = 0,
    this.onResolveDiscrepancy,
  });

  final StockTransferItem item;
  final String transferStatus;
  final TextEditingController? receiveController;
  final TextEditingController? shipController;
  final bool isSource;
  final bool isDestination;
  final int openDiscrepancyQuantity;
  final VoidCallback? onResolveDiscrepancy;

  @override
  Widget build(BuildContext context) {
    final canEditReceive = isDestination &&
        StockTransferStatus.canReceive(transferStatus) &&
        item.quantityPendingReceive > 0;
    final awaitingReception = item.quantityPendingReceive > 0 &&
        transferStatus != StockTransferStatus.received &&
        !StockTransferStatus.isTerminal(transferStatus);
    final hasOpenGap = openDiscrepancyQuantity > 0;

    return Card(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              item.productName ?? 'Produit #${item.sourceProductId}',
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            if (hasOpenGap)
              Padding(
                padding: const EdgeInsets.only(top: AppSpacing.xs),
                child: Text(
                  'Écart ouvert : $openDiscrepancyQuantity unité(s)',
                  style: TextStyle(color: Colors.amber.shade800),
                ),
              )
            else if (awaitingReception)
              Padding(
                padding: const EdgeInsets.only(top: AppSpacing.xs),
                child: Text(
                  'En transit : ${item.quantityPendingReceive} unité(s)',
                  style: TextStyle(color: Colors.blue.shade800),
                ),
              ),
            const SizedBox(height: AppSpacing.xs),
            Text('Demandé : ${item.quantityRequested}'),
            Text('Expédié : ${item.quantityShipped}'),
            Text('Reçu : ${item.quantityReceived}'),
            if (item.lotLines != null && item.lotLines!.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.xs),
              Text(
                'Lots FIFO (${item.lotLines!.length})',
                style: Theme.of(context).textTheme.labelMedium,
              ),
              ...item.lotLines!.map(
                (l) => Text(
                  '· ${l.quantity} u @ ${formatFcfa(l.unitCost)}/u '
                  '(reçu ${l.quantityReceived})',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
            ],
            if (onResolveDiscrepancy != null) ...[
              const SizedBox(height: AppSpacing.sm),
              Align(
                alignment: Alignment.centerRight,
                child: OutlinedButton.icon(
                  onPressed: onResolveDiscrepancy,
                  icon: const Icon(Icons.rule_outlined),
                  label: const Text('Résoudre l\'écart'),
                ),
              ),
            ],
            if (canEditReceive && receiveController != null) ...[
              const SizedBox(height: AppSpacing.sm),
              TextFormField(
                controller: receiveController,
                decoration: InputDecoration(
                  labelText:
                      'Quantité à recevoir (max ${item.quantityPendingReceive})',
                  border: const OutlineInputBorder(),
                ),
                keyboardType: TextInputType.number,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _EventsTimeline extends StatelessWidget {
  const _EventsTimeline({required this.events});

  final List<StockTransferEvent> events;

  @override
  Widget build(BuildContext context) {
    final sorted = [...events]
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

    return Card(
      child: ListView.separated(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: sorted.length,
        separatorBuilder: (_, __) => const Divider(height: 1),
        itemBuilder: (context, index) {
          final event = sorted[index];
          final date = DateTime.fromMillisecondsSinceEpoch(event.createdAt)
              .toLocal()
              .toString()
              .substring(0, 16);
          return ListTile(
            dense: true,
            leading: Icon(_iconForEvent(event.eventType)),
            title: Text(StockTransferEventType.label(event.eventType)),
            subtitle: Text(
              [
                date,
                if (event.notes != null && event.notes!.isNotEmpty) event.notes!,
              ].join('\n'),
            ),
          );
        },
      ),
    );
  }

  IconData _iconForEvent(String type) => switch (type) {
        StockTransferEventType.created => Icons.add_circle_outline,
        StockTransferEventType.validated => Icons.verified_outlined,
        StockTransferEventType.shipped => Icons.local_shipping_outlined,
        StockTransferEventType.received => Icons.inventory_2_outlined,
        StockTransferEventType.cancelled => Icons.cancel_outlined,
        StockTransferEventType.discrepancyResolved => Icons.rule_outlined,
        StockTransferEventType.closed => Icons.lock_outline,
        StockTransferEventType.closedWithException => Icons.warning_amber_outlined,
        _ => Icons.history,
      };
}

class _CloseTransferDialog extends StatefulWidget {
  const _CloseTransferDialog({
    required this.hasOpenDiscrepancy,
    required this.openDiscrepancyQuantity,
  });

  final bool hasOpenDiscrepancy;
  final int openDiscrepancyQuantity;

  @override
  State<_CloseTransferDialog> createState() => _CloseTransferDialogState();
}

class _CloseTransferDialogState extends State<_CloseTransferDialog> {
  late final TextEditingController _notesController;

  @override
  void initState() {
    super.initState();
    _notesController = TextEditingController();
  }

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(
        widget.hasOpenDiscrepancy
            ? 'Clôturer avec écart ?'
            : 'Clôturer le transfert ?',
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.hasOpenDiscrepancy
                ? '${widget.openDiscrepancyQuantity} unité(s) restent en écart. '
                    'Le transfert passera en « Clôturé avec écart ».'
                : 'Le transfert sera archivé définitivement.',
          ),
          const SizedBox(height: AppSpacing.sm),
          TextField(
            controller: _notesController,
            decoration: const InputDecoration(
              labelText: 'Notes (optionnel)',
              border: OutlineInputBorder(),
            ),
            maxLines: 2,
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Annuler'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, _notesController.text.trim()),
          child: const Text('Clôturer'),
        ),
      ],
    );
  }
}
