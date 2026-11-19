import 'package:flutter/material.dart';

import '../../../../app/di/injection_container.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_tokens.dart';
import '../../../../core/errors/exception_mapper.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../../core/utils/date_formatter.dart';
import '../../../../shared/components/app_page_container.dart';
import '../../../../shared/enums/permission.dart';
import '../../../../shared/enums/user_role.dart';
import '../../../../shared/guards/permission_guard.dart';
import '../../../auth/domain/entities/auth_entities.dart';
import '../../domain/entities/cash_session_entities.dart';
import '../../domain/usecases/cash_session_usecases.dart';
import '../services/cash_session_pdf_exporter.dart';

class CashSessionDetailPage extends StatefulWidget {
  const CashSessionDetailPage({
    super.key,
    required this.session,
    required this.sessionId,
  });

  final AuthSession session;
  final int sessionId;

  @override
  State<CashSessionDetailPage> createState() => _CashSessionDetailPageState();
}

class _CashSessionDetailPageState extends State<CashSessionDetailPage> {
  CashSession? _session;
  List<CashMovement> _movements = const [];
  List<CashSessionSoldProduct> _soldProducts = const [];
  String? _error;
  bool _loading = true;
  bool _exporting = false;
  bool _approving = false;
  int _selectedTabIndex = 0;
  final TextEditingController _productSearchCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _productSearchCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    ensureCashSessionDependencies();
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final session = await sl<GetCashSession>()(
        session: widget.session,
        sessionId: widget.sessionId,
      );
      final movements = await sl<ListCashMovements>()(
        session: widget.session,
        sessionId: widget.sessionId,
      );
      final soldProducts = await sl<GetCashSessionSoldProducts>()(
        session: widget.session,
        openedAt: session.openedAt,
        closedAt: session.closedAt,
      );
      if (!mounted) return;
      setState(() {
        _session = session;
        _movements = movements;
        _soldProducts = soldProducts;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = friendlyErrorMessage(e);
        _loading = false;
      });
    }
  }

  Future<void> _exportPdf() async {
    final session = _session;
    if (session == null || _exporting) return;
    setState(() => _exporting = true);
    try {
      await sl<CashSessionPdfExporter>().sharePdf(
        shopName: widget.session.shop.name,
        session: session,
        movements: _movements,
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Export impossible : ${friendlyErrorMessage(e)}'),
        ),
      );
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  Future<void> _approveSession() async {
    final session = _session;
    if (session == null || _approving) return;

    final noteCtrl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Approuver la clôture de caisse'),
        content: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'En validant cette clôture, vous attestez avoir pris connaissance des montants comptés et des éventuels écarts de caisse.',
              ),
              const SizedBox(height: AppSpacing.md),
              TextField(
                controller: noteCtrl,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Observation / note de validation (optionnel)',
                  hintText: 'Ex: Écart validé, régularisation effectuée...',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Annuler'),
          ),
          FilledButton.icon(
            onPressed: () => Navigator.pop(ctx, true),
            icon: const Icon(Icons.check),
            label: const Text('Confirmer l\'approbation'),
            style: FilledButton.styleFrom(backgroundColor: Colors.teal.shade700),
          ),
        ],
      ),
    );

    if (ok != true || !mounted) return;

    setState(() => _approving = true);
    try {
      await sl<ApproveCashSession>()(
        session: widget.session,
        sessionId: session.id,
        input: ApproveCashSessionInput(
          reviewNote:
              noteCtrl.text.trim().isEmpty ? null : noteCtrl.text.trim(),
        ),
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Clôture de caisse validée avec succès.'),
          backgroundColor: Colors.green,
        ),
      );
      await _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erreur : ${friendlyErrorMessage(e)}'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) setState(() => _approving = false);
    }
  }

  Color _statusColor(CashSessionStatus status) => switch (status) {
        CashSessionStatus.open => Colors.green,
        CashSessionStatus.submitted => Colors.amber.shade800,
        CashSessionStatus.reviewRequired => Colors.deepOrange,
        CashSessionStatus.justified => Colors.blue.shade700,
        CashSessionStatus.approved => Colors.teal.shade700,
        CashSessionStatus.reopened => Colors.purple,
        CashSessionStatus.closed => Colors.grey.shade700,
      };

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          _session != null
              ? 'Rapport de caisse #${_session!.id}'
              : 'Détails de caisse',
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Actualiser',
            onPressed: _loading ? null : _load,
          ),
          if (_session != null && !_loading)
            IconButton(
              icon: _exporting
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.picture_as_pdf_outlined),
              tooltip: 'Exporter PDF',
              onPressed: _exporting ? null : _exportPdf,
            ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(AppSpacing.lg),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.error_outline, size: 48, color: Colors.red),
                        const SizedBox(height: AppSpacing.sm),
                        Text(_error!, textAlign: TextAlign.center),
                        const SizedBox(height: AppSpacing.md),
                        FilledButton(
                          onPressed: _load,
                          child: const Text('Réessayer'),
                        ),
                      ],
                    ),
                  ),
                )
              : _buildBody(context, _session!),
    );
  }

  Widget _buildBody(BuildContext context, CashSession s) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final statusColor = _statusColor(s.status);
    final canApprove = (widget.session.user.role == UserRole.owner ||
            PermissionGuard.can(
              widget.session.user.permissions,
              Permission.cashSessionsApprove,
            )) &&
        s.isPendingReview;

    final totalDiff = s.totalDifference;
    final totalSales = s.salesCash + s.salesMomo;
    final totalExpenses = s.expensesCash + s.expensesMomo;
    final totalExpected = (s.expectedCash ?? 0) + (s.expectedMomo ?? 0);
    final totalCounted = (s.countedCash ?? 0) + (s.countedMomo ?? 0);

    return LayoutBuilder(
      builder: (context, constraints) {
        final isDesktop = constraints.maxWidth >= 940;

        return AppPageContainer(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Bandeau Statut & Actions
                Container(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: isDark ? 0.2 : 0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: statusColor.withValues(alpha: isDark ? 0.5 : 0.35),
                    ),
                  ),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 22,
                        backgroundColor: statusColor.withValues(alpha: 0.15),
                        child: Icon(
                          s.status == CashSessionStatus.approved
                              ? Icons.verified_outlined
                              : s.isPendingReview
                                  ? Icons.pending_actions
                                  : s.status == CashSessionStatus.open
                                      ? Icons.lock_open
                                      : Icons.lock,
                          color: statusColor,
                          size: 26,
                        ),
                      ),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Statut de clôture : ${s.status.label}',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: statusColor,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              s.isPendingReview
                                  ? 'Cette session a été soumise par l\'employé et attend la validation du patron.'
                                  : s.status == CashSessionStatus.approved
                                      ? 'Clôture et rapprochement approuvés définitivement par le patron.'
                                      : s.status == CashSessionStatus.open
                                          ? 'Session en cours d\'activité.'
                                          : 'Session clôturée avec succès.',
                              style: TextStyle(
                                fontSize: 12,
                                color: colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (canApprove) ...[
                        FilledButton.icon(
                          onPressed: _approving ? null : _approveSession,
                          icon: _approving
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Icon(Icons.check, size: 18),
                          label: const Text('Approuver'),
                          style: FilledButton.styleFrom(
                            backgroundColor: Colors.teal.shade700,
                          ),
                        ),
                        const SizedBox(width: AppSpacing.sm),
                      ],
                      OutlinedButton.icon(
                        onPressed: _exporting ? null : _exportPdf,
                        icon: const Icon(Icons.picture_as_pdf_outlined, size: 18),
                        label: const Text('PDF'),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: AppSpacing.md),

                // Sélecteur d'onglets (SegmentedButton)
                SegmentedButton<int>(
                  segments: [
                    const ButtonSegment<int>(
                      value: 0,
                      icon: Icon(Icons.analytics_outlined),
                      label: Text('Rapprochement & Flux'),
                    ),
                    ButtonSegment<int>(
                      value: 1,
                      icon: const Icon(Icons.inventory_2_outlined),
                      label: Text('Articles vendus (${_soldProducts.length})'),
                    ),
                  ],
                  selected: {_selectedTabIndex},
                  onSelectionChanged: (newSelection) {
                    setState(() {
                      _selectedTabIndex = newSelection.first;
                    });
                  },
                ),

                const SizedBox(height: AppSpacing.md),

                // VUE ONGLETS
                if (_selectedTabIndex == 1) ...[
                  // Vue 2 : Articles vendus de la caisse
                  _buildSoldProductsView(context, s, totalSales),
                ] else ...[
                  // Vue 1 : Rapprochement financier & mouvements
                  // KPI Cards
                  _buildKpiSection(
                    context,
                    totalSales: totalSales,
                    saleCount: s.saleCount,
                    totalExpenses: totalExpenses +
                        s.withdrawalsCash +
                        s.withdrawalsMomo,
                    totalExpected: totalExpected,
                    totalCounted: totalCounted,
                    totalDiff: totalDiff,
                    isDesktop: isDesktop,
                  ),

                  const SizedBox(height: AppSpacing.lg),

                  // Disposition 2 colonnes desktop vs 1 colonne mobile
                  if (isDesktop)
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Colonne gauche : Synthèse financière complète
                        Expanded(
                          flex: 6,
                          child: _buildFinancialCard(context, s, totalDiff),
                        ),
                        const SizedBox(width: AppSpacing.lg),
                        // Colonne droite : Justifications, Arbitrage & Mouvements
                        Expanded(
                          flex: 5,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              if (s.justificationCategory != null ||
                                  s.justificationNote != null)
                                _buildJustificationCard(context, s),
                              if (s.reviewNote?.isNotEmpty == true)
                                _buildReviewCard(context, s),
                              _buildMovementsCard(context),
                            ],
                          ),
                        ),
                      ],
                    )
                  else ...[
                    _buildFinancialCard(context, s, totalDiff),
                    if (s.justificationCategory != null ||
                        s.justificationNote != null) ...[
                      const SizedBox(height: AppSpacing.md),
                      _buildJustificationCard(context, s),
                    ],
                    if (s.reviewNote?.isNotEmpty == true) ...[
                      const SizedBox(height: AppSpacing.md),
                      _buildReviewCard(context, s),
                    ],
                    if (_movements.isNotEmpty) ...[
                      const SizedBox(height: AppSpacing.md),
                      _buildMovementsCard(context),
                    ],
                  ],
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildKpiSection(
    BuildContext context, {
    required int totalSales,
    required int saleCount,
    required int totalExpenses,
    required int totalExpected,
    required int totalCounted,
    required int totalDiff,
    required bool isDesktop,
  }) {
    final kpis = [
      _StatMiniCard(
        label: 'Ventes conclues',
        value: formatFcfa(totalSales),
        sub: '$saleCount vente(s)',
        icon: Icons.trending_up,
        color: Colors.green.shade700,
      ),
      _StatMiniCard(
        label: 'Dépenses & Sorties',
        value: formatFcfa(totalExpenses),
        sub: 'Dépenses + remises',
        icon: Icons.receipt_long_outlined,
        color: Colors.deepOrange.shade700,
      ),
      _StatMiniCard(
        label: 'Solde attendu',
        value: formatFcfa(totalExpected),
        sub: 'Calcul théorique',
        icon: Icons.calculate_outlined,
        color: Colors.indigo.shade700,
      ),
      _StatMiniCard(
        label: 'Compté réel',
        value: formatFcfa(totalCounted),
        sub: 'Comptage physique',
        icon: Icons.fact_check_outlined,
        color: Colors.blueGrey.shade800,
      ),
      _StatMiniCard(
        label: 'Écart net global',
        value: totalDiff == 0
            ? '0 FCFA'
            : '${totalDiff > 0 ? '+' : ''}${formatFcfa(totalDiff)}',
        sub: totalDiff == 0
            ? 'Équilibré'
            : totalDiff > 0
                ? 'Excédent'
                : 'Déficit',
        icon: totalDiff == 0
            ? Icons.check_circle_outline
            : Icons.warning_amber_rounded,
        color: totalDiff == 0
            ? Colors.green.shade700
            : totalDiff > 0
                ? Colors.blue.shade700
                : Colors.red.shade700,
        isAccent: true,
      ),
    ];

    if (isDesktop) {
      return Row(
        children: kpis
            .map(
              (kpi) => Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: kpi,
                ),
              ),
            )
            .toList(),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final itemWidth = (constraints.maxWidth - 8) / 2;
        return Wrap(
          spacing: 8,
          runSpacing: 8,
          children: kpis
              .map((kpi) => SizedBox(width: itemWidth, child: kpi))
              .toList(),
        );
      },
    );
  }

  Widget _buildFinancialCard(BuildContext context, CashSession s, int totalDiff) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const Icon(Icons.analytics_outlined, color: AppColors.seed),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    'Rapprochement financier',
                    style: theme.textTheme.titleLarge,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              'Session ouverte par ${s.openedByName} le '
              '${AppDateFormatter.formatDateTime(DateTime.fromMillisecondsSinceEpoch(s.openedAt))}',
              style: TextStyle(fontSize: 12, color: colorScheme.onSurfaceVariant),
            ),
            if (s.submittedAt != null)
              Text(
                'Soumise le ${AppDateFormatter.formatDateTime(DateTime.fromMillisecondsSinceEpoch(s.submittedAt!))}',
                style: TextStyle(fontSize: 12, color: colorScheme.onSurfaceVariant),
              ),
            if (s.closedByName != null && s.closedAt != null)
              Text(
                'Clôturée le ${AppDateFormatter.formatDateTime(DateTime.fromMillisecondsSinceEpoch(s.closedAt!))} par ${s.closedByName}',
                style: TextStyle(fontSize: 12, color: colorScheme.onSurfaceVariant),
              ),
            if (s.approvedAt != null)
              Text(
                'Approuvée le ${AppDateFormatter.formatDateTime(DateTime.fromMillisecondsSinceEpoch(s.approvedAt!))}',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Colors.teal.shade800,
                ),
              ),
            const Divider(height: AppSpacing.lg),
            _row(context, 'Fond initial espèces', s.openingCash),
            _row(context, 'Fond initial MoMo', s.openingMomo),
            const Divider(),
            _row(context, 'Ventes espèces', s.salesCash, positive: true),
            _row(context, 'Ventes MoMo', s.salesMomo, positive: true),
            _row(context, 'Dépenses espèces', s.expensesCash, negative: true),
            _row(context, 'Dépenses MoMo', s.expensesMomo, negative: true),
            _row(context, 'Entrées diverses espèces', s.depositsCash, positive: true),
            _row(context, 'Entrées diverses MoMo', s.depositsMomo, positive: true),
            _row(context, 'Retraits / Remises espèces', s.withdrawalsCash, negative: true),
            _row(context, 'Retraits / Remises MoMo', s.withdrawalsMomo, negative: true),
            _row(context, 'Nombre de ventes conclues', s.saleCount, money: false),
            const Divider(height: AppSpacing.lg),
            _row(context, 'Attendu espèces (théorique)', s.expectedCash ?? 0, bold: true),
            _row(context, 'Attendu MoMo (théorique)', s.expectedMomo ?? 0, bold: true),
            _row(context, 'Compté espèces (réel)', s.countedCash ?? 0, bold: true),
            _row(context, 'Compté MoMo (réel)', s.countedMomo ?? 0, bold: true),
            const Divider(height: AppSpacing.md),
            _row(
              context,
              'Écart espèces',
              s.differenceCash ?? 0,
              bold: true,
              highlight: true,
            ),
            _row(
              context,
              'Écart Mobile Money',
              s.differenceMomo ?? 0,
              bold: true,
              highlight: true,
            ),
            _row(
              context,
              'Écart net global',
              totalDiff,
              bold: true,
              highlight: true,
            ),
            if (s.closingNote?.isNotEmpty == true) ...[
              const Divider(height: AppSpacing.md),
              Text(
                'Note de clôture générale :',
                style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 2),
              Text(
                s.closingNote!,
                style: TextStyle(color: colorScheme.onSurfaceVariant),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildJustificationCard(BuildContext context, CashSession s) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Card(
      color: isDark
          ? Colors.amber.shade900.withValues(alpha: 0.15)
          : Colors.amber.shade50,
      margin: const EdgeInsets.only(bottom: AppSpacing.md),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: isDark ? Colors.amber.shade700 : Colors.amber.shade300,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(
                  Icons.warning_amber_rounded,
                  color: isDark ? Colors.amber.shade300 : Colors.amber.shade900,
                ),
                const SizedBox(width: AppSpacing.sm),
                Text(
                  'Justification de l\'écart de caisse',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.amber.shade200 : Colors.amber.shade900,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            if (s.justificationCategory != null) ...[
              Text(
                'Motif : ${s.justificationCategory!.discrepancyCategoryLabel}',
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 4),
            ],
            if (s.justificationNote != null) ...[
              Text(
                'Explication fournie par l\'employé :',
                style: TextStyle(
                  fontSize: 12,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                s.justificationNote!,
                style: const TextStyle(fontStyle: FontStyle.italic),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildReviewCard(BuildContext context, CashSession s) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Card(
      color: isDark
          ? Colors.teal.shade900.withValues(alpha: 0.15)
          : Colors.teal.shade50,
      margin: const EdgeInsets.only(bottom: AppSpacing.md),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: isDark ? Colors.teal.shade700 : Colors.teal.shade300,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(
                  Icons.check_circle_outline,
                  color: isDark ? Colors.teal.shade300 : Colors.teal.shade900,
                ),
                const SizedBox(width: AppSpacing.sm),
                Text(
                  'Décision du responsable',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.teal.shade200 : Colors.teal.shade900,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(s.reviewNote!),
          ],
        ),
      ),
    );
  }

  Widget _buildMovementsCard(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    if (_movements.isEmpty) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Mouvements manuels enregistrés',
                style: theme.textTheme.titleMedium,
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                'Aucun mouvement manuel enregistré durant cette session.',
                style: TextStyle(
                  color: colorScheme.onSurfaceVariant,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const Icon(Icons.swap_vert, color: AppColors.seed),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    'Mouvements manuels enregistrés',
                    style: theme.textTheme.titleMedium,
                  ),
                ),
                Chip(label: Text('${_movements.length}')),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            ..._movements.map(
              (m) => Card(
                margin: const EdgeInsets.only(bottom: AppSpacing.xs),
                elevation: 0,
                color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
                child: ListTile(
                  dense: true,
                  leading: CircleAvatar(
                    radius: 16,
                    backgroundColor: m.movementType == CashMovementType.deposit
                        ? Colors.green.withValues(alpha: 0.15)
                        : m.movementType == CashMovementType.ownerDrop
                            ? Colors.indigo.withValues(alpha: 0.15)
                            : Colors.red.withValues(alpha: 0.15),
                    child: Icon(
                      m.movementType == CashMovementType.deposit
                          ? Icons.add_circle_outline
                          : m.movementType == CashMovementType.ownerDrop
                              ? Icons.payments_outlined
                              : Icons.remove_circle_outline,
                      color: m.movementType == CashMovementType.deposit
                          ? Colors.green
                          : m.movementType == CashMovementType.ownerDrop
                              ? Colors.indigo
                              : Colors.red,
                      size: 18,
                    ),
                  ),
                  title: Text(
                    '${m.movementType.label} · ${m.registerType.label}',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  subtitle: Text(
                    m.note ?? 'Par ${m.createdByName}',
                    style: TextStyle(color: colorScheme.onSurfaceVariant),
                  ),
                  trailing: Text(
                    formatFcfa(m.amount),
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Vue dédiée aux produits vendus durant cette session de caisse
  Widget _buildSoldProductsView(
    BuildContext context,
    CashSession s,
    int totalSessionSales,
  ) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final query = _productSearchCtrl.text.trim().toLowerCase();

    final filtered = query.isEmpty
        ? _soldProducts
        : _soldProducts
            .where((p) => p.productName.toLowerCase().contains(query))
            .toList();

    final totalUnits = _soldProducts.fold<double>(
      0,
      (sum, p) => sum + p.quantity,
    );
    final totalRevenue = _soldProducts.fold<int>(
      0,
      (sum, p) => sum + p.totalRevenue,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Synthèse rapide des produits vendus
        Card(
          color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    children: [
                      Text(
                        'Total unités vendues',
                        style: TextStyle(
                          fontSize: 11,
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        totalUnits % 1 == 0
                            ? '${totalUnits.toInt()} pièces'
                            : '$totalUnits pièces',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  height: 36,
                  width: 1,
                  color: colorScheme.outlineVariant,
                ),
                Expanded(
                  child: Column(
                    children: [
                      Text(
                        'Montant cumulé articles',
                        style: TextStyle(
                          fontSize: 11,
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        formatFcfa(totalRevenue),
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.green.shade700,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  height: 36,
                  width: 1,
                  color: colorScheme.outlineVariant,
                ),
                Expanded(
                  child: Column(
                    children: [
                      Text(
                        'Articles distincts',
                        style: TextStyle(
                          fontSize: 11,
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${_soldProducts.length} réf.',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),

        const SizedBox(height: AppSpacing.sm),

        // Barre de recherche
        TextField(
          controller: _productSearchCtrl,
          decoration: InputDecoration(
            hintText: 'Rechercher un produit vendu...',
            prefixIcon: const Icon(Icons.search, size: 20),
            suffixIcon: query.isNotEmpty
                ? IconButton(
                    icon: const Icon(Icons.clear, size: 18),
                    onPressed: () => setState(() => _productSearchCtrl.clear()),
                  )
                : null,
            border: const OutlineInputBorder(),
            isDense: true,
          ),
          onChanged: (_) => setState(() {}),
        ),

        const SizedBox(height: AppSpacing.md),

        // Liste des articles vendus
        if (filtered.isEmpty)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.xl),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.inventory_2_outlined,
                      size: 48,
                      color: colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      query.isNotEmpty
                          ? 'Aucun article trouvé pour "$query"'
                          : 'Aucun article vendu enregistré sur cette caisse.',
                      style: TextStyle(color: colorScheme.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
            ),
          )
        else
          Card(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
              child: ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: filtered.length,
                separatorBuilder: (context, index) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final p = filtered[index];
                  final pct = totalRevenue > 0
                      ? (p.totalRevenue / totalRevenue * 100).toStringAsFixed(1)
                      : '0';

                  return ListTile(
                    leading: CircleAvatar(
                      backgroundColor:
                          colorScheme.primary.withValues(alpha: 0.1),
                      child: Text(
                        '#${index + 1}',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: colorScheme.primary,
                        ),
                      ),
                    ),
                    title: Text(
                      p.productName,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Text(
                      '${p.quantity % 1 == 0 ? p.quantity.toInt() : p.quantity} vendu(s) · Prix unitaire : ${formatFcfa(p.unitPrice)} · ${p.saleCount} vente(s)',
                      style: TextStyle(
                        fontSize: 12,
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                    trailing: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          formatFcfa(p.totalRevenue),
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 1,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.green.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            '$pct % du CA',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: Colors.green.shade800,
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ),
      ],
    );
  }

  Widget _row(
    BuildContext context,
    String label,
    int value, {
    bool money = true,
    bool bold = false,
    bool highlight = false,
    bool positive = false,
    bool negative = false,
  }) {
    final text = money ? formatFcfa(value) : '$value';
    Color? color;
    if (highlight) {
      color = value == 0
          ? Colors.green
          : value > 0
              ? Colors.blue
              : Colors.red;
    } else if (positive && value > 0) {
      color = Colors.green.shade700;
    } else if (negative && value > 0) {
      color = Colors.red.shade700;
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3.5),
      child: Row(
        children: [
          Expanded(child: Text(label)),
          Text(
            text,
            style: TextStyle(
              fontWeight: bold ? FontWeight.bold : null,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

class _StatMiniCard extends StatelessWidget {
  const _StatMiniCard({
    required this.label,
    required this.value,
    required this.sub,
    required this.icon,
    required this.color,
    this.isAccent = false,
  });

  final String label;
  final String value;
  final String sub;
  final IconData icon;
  final Color color;
  final bool isAccent;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Card(
      elevation: isAccent ? 2 : 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: isAccent
            ? BorderSide(color: color.withValues(alpha: 0.5), width: 1.5)
            : BorderSide.none,
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.sm,
          vertical: AppSpacing.md,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircleAvatar(
              radius: 18,
              backgroundColor: color.withValues(alpha: 0.12),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(height: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                color: colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 2),
            Text(
              value,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 14,
                color: isAccent ? color : colorScheme.onSurface,
              ),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            Text(
              sub,
              style: TextStyle(
                fontSize: 10,
                color: colorScheme.onSurfaceVariant.withValues(alpha: 0.8),
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
