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
  String? _error;
  bool _loading = true;
  bool _exporting = false;
  bool _approving = false;

  @override
  void initState() {
    super.initState();
    _load();
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
      if (!mounted) return;
      setState(() {
        _session = session;
        _movements = movements;
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
        title: const Text('Rapport de clôture'),
        actions: [
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
              ? Center(child: Text(_error!))
              : _buildBody(context, _session!),
    );
  }

  Widget _buildBody(BuildContext context, CashSession s) {
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
                    color: statusColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                    border:
                        Border.all(color: statusColor.withValues(alpha: 0.4)),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        s.status == CashSessionStatus.approved
                            ? Icons.verified_outlined
                            : s.isPendingReview
                                ? Icons.pending_actions
                                : s.status == CashSessionStatus.open
                                    ? Icons.lock_open
                                    : Icons.lock,
                        color: statusColor,
                        size: 32,
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
                            if (s.isPendingReview)
                              const Text(
                                'Cette session a été soumise par l\'employé et attend la validation du patron.',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.black54,
                                ),
                              )
                            else if (s.status == CashSessionStatus.approved)
                              const Text(
                                'Clôture et rapprochement approuvés définitivement par le patron.',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.black54,
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
                          label: const Text('Approuver la clôture'),
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

                // Ligne de KPI Desktop
                if (isDesktop) ...[
                  Row(
                    children: [
                      Expanded(
                        child: _StatMiniCard(
                          label: 'Ventes conclues',
                          value: formatFcfa(totalSales),
                          sub: '${s.saleCount} vente(s)',
                          icon: Icons.trending_up,
                          color: Colors.green.shade700,
                        ),
                      ),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: _StatMiniCard(
                          label: 'Dépenses & Sorties',
                          value: formatFcfa(totalExpenses +
                              s.withdrawalsCash +
                              s.withdrawalsMomo),
                          sub: 'Dépenses + sorties',
                          icon: Icons.receipt_long_outlined,
                          color: Colors.deepOrange.shade700,
                        ),
                      ),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: _StatMiniCard(
                          label: 'Solde attendu',
                          value: formatFcfa(totalExpected),
                          sub: 'Calcul théorique',
                          icon: Icons.calculate_outlined,
                          color: Colors.indigo.shade700,
                        ),
                      ),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: _StatMiniCard(
                          label: 'Compté par caissier',
                          value: formatFcfa(totalCounted),
                          sub: 'Comptage à l\'aveugle',
                          icon: Icons.fact_check_outlined,
                          color: Colors.blueGrey.shade800,
                        ),
                      ),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: _StatMiniCard(
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
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.lg),
                ],

                // Contenu : 2 Colonnes sur Desktop vs 1 Colonne sur Mobile
                if (isDesktop)
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Colonne Gauche : Synthèse financière complète
                      Expanded(
                        flex: 6,
                        child: _buildFinancialCard(context, s, totalDiff),
                      ),
                      const SizedBox(width: AppSpacing.lg),
                      // Colonne Droite : Justifications, Arbitrage & Mouvements
                      Expanded(
                        flex: 5,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            if (s.justificationCategory != null ||
                                s.justificationNote != null)
                              _buildJustificationCard(s),
                            if (s.reviewNote?.isNotEmpty == true)
                              _buildReviewCard(s),
                            _buildMovementsCard(),
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
                    _buildJustificationCard(s),
                  ],
                  if (s.reviewNote?.isNotEmpty == true) ...[
                    const SizedBox(height: AppSpacing.md),
                    _buildReviewCard(s),
                  ],
                  if (_movements.isNotEmpty) ...[
                    const SizedBox(height: AppSpacing.md),
                    _buildMovementsCard(),
                  ],
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildFinancialCard(BuildContext context, CashSession s, int totalDiff) {
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
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              'Session ouverte par ${s.openedByName} le '
              '${AppDateFormatter.formatDateTime(DateTime.fromMillisecondsSinceEpoch(s.openedAt))}',
              style: const TextStyle(fontSize: 12, color: Colors.black54),
            ),
            if (s.submittedAt != null)
              Text(
                'Soumise le ${AppDateFormatter.formatDateTime(DateTime.fromMillisecondsSinceEpoch(s.submittedAt!))}',
                style: const TextStyle(fontSize: 12, color: Colors.black54),
              ),
            if (s.closedByName != null && s.closedAt != null)
              Text(
                'Clôturée le ${AppDateFormatter.formatDateTime(DateTime.fromMillisecondsSinceEpoch(s.closedAt!))} par ${s.closedByName}',
                style: const TextStyle(fontSize: 12, color: Colors.black54),
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
            _row('Fond initial espèces', s.openingCash),
            _row('Fond initial MoMo', s.openingMomo),
            const Divider(),
            _row('Ventes espèces', s.salesCash, positive: true),
            _row('Ventes MoMo', s.salesMomo, positive: true),
            _row('Dépenses espèces', s.expensesCash, negative: true),
            _row('Dépenses MoMo', s.expensesMomo, negative: true),
            _row('Entrées diverses espèces', s.depositsCash, positive: true),
            _row('Entrées diverses MoMo', s.depositsMomo, positive: true),
            _row('Retraits / Remises espèces', s.withdrawalsCash, negative: true),
            _row('Retraits / Remises MoMo', s.withdrawalsMomo, negative: true),
            _row('Nombre de ventes', s.saleCount, money: false),
            const Divider(height: AppSpacing.lg),
            _row('Attendu espèces (théorique)', s.expectedCash ?? 0, bold: true),
            _row('Attendu MoMo (théorique)', s.expectedMomo ?? 0, bold: true),
            _row('Compté espèces (réel)', s.countedCash ?? 0, bold: true),
            _row('Compté MoMo (réel)', s.countedMomo ?? 0, bold: true),
            const Divider(height: AppSpacing.md),
            _row(
              'Écart espèces',
              s.differenceCash ?? 0,
              bold: true,
              highlight: true,
            ),
            _row(
              'Écart Mobile Money',
              s.differenceMomo ?? 0,
              bold: true,
              highlight: true,
            ),
            _row(
              'Écart net global',
              totalDiff,
              bold: true,
              highlight: true,
            ),
            if (s.closingNote?.isNotEmpty == true) ...[
              const Divider(height: AppSpacing.md),
              const Text(
                'Note de clôture générale :',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
              ),
              const SizedBox(height: 2),
              Text(s.closingNote!),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildJustificationCard(CashSession s) {
    return Card(
      color: Colors.amber.shade50,
      margin: const EdgeInsets.only(bottom: AppSpacing.md),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.amber.shade300),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(Icons.warning_amber_rounded, color: Colors.amber.shade900),
                const SizedBox(width: AppSpacing.sm),
                Text(
                  'Justification de l\'écart de caisse',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: Colors.amber.shade900,
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
              const Text(
                'Explication fournie par l\'employé :',
                style: TextStyle(fontSize: 12, color: Colors.black54),
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

  Widget _buildReviewCard(CashSession s) {
    return Card(
      color: Colors.teal.shade50,
      margin: const EdgeInsets.only(bottom: AppSpacing.md),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.teal.shade300),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(Icons.check_circle_outline, color: Colors.teal.shade900),
                const SizedBox(width: AppSpacing.sm),
                Text(
                  'Décision du responsable',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: Colors.teal.shade900,
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

  Widget _buildMovementsCard() {
    if (_movements.isEmpty) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Mouvements manuels enregistrés',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: AppSpacing.sm),
              const Text(
                'Aucun mouvement manuel enregistré durant cette session.',
                style: TextStyle(color: Colors.black45, fontSize: 13),
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
                const Icon(Icons.swap_vert, color: Colors.blueGrey),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    'Mouvements manuels enregistrés',
                    style: Theme.of(context).textTheme.titleMedium,
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
                color: Colors.grey.shade50,
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
                  title:
                      Text('${m.movementType.label} · ${m.registerType.label}'),
                  subtitle: Text(m.note ?? 'Par ${m.createdByName}'),
                  trailing: Text(
                    formatFcfa(m.amount),
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _row(
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
      padding: const EdgeInsets.symmetric(vertical: 2.5),
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
          children: [
            CircleAvatar(
              radius: 18,
              backgroundColor: color.withValues(alpha: 0.12),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(height: 6),
            Text(
              label,
              style: TextStyle(fontSize: 11, color: Colors.grey.shade700),
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
                color: isAccent ? color : Colors.black87,
              ),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            Text(
              sub,
              style: const TextStyle(fontSize: 10, color: Colors.black45),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
