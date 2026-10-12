import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../app/di/injection_container.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_tokens.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../../core/utils/date_formatter.dart';
import '../../../../shared/components/app_header_actions.dart';
import '../../../../shared/components/app_page_container.dart';
import '../../../../shared/components/empty_list_placeholder.dart';
import '../../../../shared/components/skeleton_loaders.dart';
import '../../../../shared/enums/permission.dart';
import '../../../../shared/enums/user_role.dart';
import '../../../../shared/guards/module_activity_guard.dart';
import '../../../../shared/guards/permission_guard.dart';
import '../../../auth/domain/entities/auth_entities.dart';
import '../../../auth/presentation/widgets/pin_pad.dart';
import '../../../help/presentation/widgets/module_help_button.dart';
import '../../domain/entities/cash_session_entities.dart';
import '../../domain/usecases/cash_session_usecases.dart';
import '../bloc/cash_sessions_bloc.dart';
import 'cash_session_detail_page.dart';

class CashSessionsPage extends StatelessWidget {
  const CashSessionsPage({super.key, required this.session});

  final AuthSession session;

  @override
  Widget build(BuildContext context) {
    ensureCashSessionDependencies();

    return ModuleActivityGuard(
      moduleKey: 'CASH_SESSIONS',
      session: session,
      moduleName: 'Gestion de Caisse',
      moduleIcon: Icons.point_of_sale_outlined,
      child: BlocProvider(
        create: (_) => CashSessionsBloc(
          findOpenSession: sl<FindOpenCashSession>(),
          listSessions: sl<ListCashSessions>(),
          getLiveTotals: sl<GetCashSessionLiveTotals>(),
          listMovements: sl<ListCashMovements>(),
          openSession: sl<OpenCashSession>(),
          closeSession: sl<CloseCashSession>(),
          submitClosing: sl<SubmitCashSessionClosing>(),
          approveSession: sl<ApproveCashSession>(),
          recordOwnerDrop: sl<RecordOwnerDrop>(),
          recordMovement: sl<RecordCashMovement>(),
          syncFromRemote: sl<SyncCashSessionsFromRemote>(),
          session: session,
          syncService: sl(),
        )..add(const CashSessionsLoadRequested()),
        child: const _CashSessionsView(),
      ),
    );
  }
}

class _CashSessionsView extends StatelessWidget {
  const _CashSessionsView();

  @override
  Widget build(BuildContext context) {
    final bloc = context.read<CashSessionsBloc>();
    final perms = bloc.session.user.permissions;
    final canOpen = PermissionGuard.can(perms, Permission.cashSessionsOpen);
    final canClose = PermissionGuard.can(perms, Permission.cashSessionsClose);
    final canAdjust = PermissionGuard.can(perms, Permission.cashSessionsAdjust);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Gestion de caisse'),
        actions: [
          const ModuleHelpButton(articleId: 'cash_sessions'),
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Actualiser',
            onPressed: () => context
                .read<CashSessionsBloc>()
                .add(const CashSessionsRefreshRequested()),
          ),
          const AppHeaderActions(),
        ],
      ),
      body: BlocConsumer<CashSessionsBloc, CashSessionsState>(
        listenWhen: (p, c) =>
            c.errorMessage != null && p.errorMessage != c.errorMessage,
        listener: (context, state) {
          final msg = state.errorMessage;
          if (msg != null) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(msg)),
            );
          }
        },
        builder: (context, state) {
          if (state.status == CashSessionsStatus.loading &&
              state.openSession == null &&
              state.history.isEmpty) {
            return const SaleListSkeleton();
          }

          return LayoutBuilder(
            builder: (context, constraints) {
              final isDesktop = constraints.maxWidth >= 940;

              return RefreshIndicator(
                onRefresh: () async {
                  context
                      .read<CashSessionsBloc>()
                      .add(const CashSessionsRefreshRequested());
                  await context.read<CashSessionsBloc>().stream.firstWhere(
                        (s) => !s.isRefreshing,
                      );
                },
                child: AppPageContainer(
                  child: SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.all(AppSpacing.md),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (state.isRefreshing)
                          const Padding(
                            padding: EdgeInsets.only(bottom: AppSpacing.sm),
                            child: LinearProgressIndicator(minHeight: 2),
                          ),

                        // Bannière KPI sur grand écran (Windows Desktop)
                        if (isDesktop && state.openSession != null) ...[
                          _DesktopKpiBanner(
                            session: state.openSession!,
                            totals: state.liveTotals,
                            movements: state.movements,
                          ),
                          const SizedBox(height: AppSpacing.lg),
                        ],

                        // Disposition Desktop à 2 colonnes vs Mobile à 1 colonne
                        if (isDesktop)
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Colonne gauche : Caisse active ou formulaire d'ouverture
                              Expanded(
                                flex: 6,
                                child: state.openSession != null
                                    ? _ActiveSessionCard(
                                        authSession: bloc.session,
                                        session: state.openSession!,
                                        totals: state.liveTotals,
                                        movements: state.movements,
                                        canAdjust: canAdjust,
                                        canClose: canClose,
                                        isSubmitting: state.isSubmitting,
                                        isDesktop: true,
                                      )
                                    : _OpenSessionCard(
                                        canOpen: canOpen,
                                        isDesktop: true,
                                      ),
                              ),
                              const SizedBox(width: AppSpacing.lg),
                              // Colonne droite : Historique des clôtures
                              Expanded(
                                flex: 5,
                                child: _DesktopHistoryPanel(
                                  history: state.history,
                                  session: bloc.session,
                                ),
                              ),
                            ],
                          )
                        else ...[
                          // Vue compacte (Mobile / tablette portrait)
                          if (state.openSession == null) ...[
                            _OpenSessionCard(canOpen: canOpen, isDesktop: false),
                            const SizedBox(height: AppSpacing.lg),
                          ] else ...[
                            _ActiveSessionCard(
                              authSession: bloc.session,
                              session: state.openSession!,
                              totals: state.liveTotals,
                              movements: state.movements,
                              canAdjust: canAdjust,
                              canClose: canClose,
                              isSubmitting: state.isSubmitting,
                              isDesktop: false,
                            ),
                            const SizedBox(height: AppSpacing.lg),
                          ],
                          Text(
                            'Historique des clôtures',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          const SizedBox(height: AppSpacing.sm),
                          if (state.history.isEmpty)
                            const Padding(
                              padding: EdgeInsets.symmetric(
                                vertical: AppSpacing.md,
                              ),
                              child: EmptyListPlaceholder(
                                icon: Icons.point_of_sale_outlined,
                                title: 'Aucune session enregistrée',
                              ),
                            )
                          else
                            ...state.history.map(
                              (row) => _HistoryTile(
                                row: row,
                                onTap: () => Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (_) => CashSessionDetailPage(
                                      session: bloc.session,
                                      sessionId: row.id,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ],
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

/// Bannière horizontale de synthèse financière pour grand écran (Windows)
class _DesktopKpiBanner extends StatelessWidget {
  const _DesktopKpiBanner({
    required this.session,
    required this.totals,
    required this.movements,
  });

  final CashSession session;
  final CashSessionLiveTotals? totals;
  final List<CashMovement> movements;

  @override
  Widget build(BuildContext context) {
    final t = totals;
    final openingTotal = session.openingCash + session.openingMomo;
    final salesTotal = (t?.salesCash ?? 0) + (t?.salesMomo ?? 0);
    final expensesTotal = (t?.expensesCash ?? 0) + (t?.expensesMomo ?? 0);
    final withdrawalsTotal =
        (t?.withdrawalsCash ?? 0) + (t?.withdrawalsMomo ?? 0);
    final expectedCash = session.openingCash +
        (t?.salesCash ?? 0) +
        (t?.depositsCash ?? 0) -
        (t?.expensesCash ?? 0) -
        (t?.withdrawalsCash ?? 0);
    final expectedMomo = session.openingMomo +
        (t?.salesMomo ?? 0) +
        (t?.depositsMomo ?? 0) -
        (t?.expensesMomo ?? 0) -
        (t?.withdrawalsMomo ?? 0);
    final expectedTotal = expectedCash + expectedMomo;

    return Row(
      children: [
        Expanded(
          child: _DesktopKpiCard(
            label: 'Fond initial',
            value: formatFcfa(openingTotal),
            subtitle: 'Espèces + MoMo',
            icon: Icons.savings_outlined,
            color: Colors.teal.shade700,
          ),
        ),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: _DesktopKpiCard(
            label: 'Ventes du shift',
            value: formatFcfa(salesTotal),
            subtitle: '${t?.saleCount ?? 0} vente(s) conclue(s)',
            icon: Icons.trending_up,
            color: Colors.green.shade700,
          ),
        ),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: _DesktopKpiCard(
            label: 'Dépenses & Sorties',
            value: formatFcfa(expensesTotal + withdrawalsTotal),
            subtitle: 'Dépenses, retraits, remises',
            icon: Icons.receipt_long_outlined,
            color: Colors.deepOrange.shade700,
          ),
        ),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: _DesktopKpiCard(
            label: 'Solde attendu global',
            value: formatFcfa(expectedTotal),
            subtitle: 'Espèces: ${formatFcfa(expectedCash)}',
            icon: Icons.account_balance_wallet_outlined,
            color: AppColors.seed,
            isHighlighted: true,
          ),
        ),
      ],
    );
  }
}

class _DesktopKpiCard extends StatelessWidget {
  const _DesktopKpiCard({
    required this.label,
    required this.value,
    required this.subtitle,
    required this.icon,
    required this.color,
    this.isHighlighted = false,
  });

  final String label;
  final String value;
  final String subtitle;
  final IconData icon;
  final Color color;
  final bool isHighlighted;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: isHighlighted ? 2 : 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: isHighlighted
            ? BorderSide(color: color.withValues(alpha: 0.5), width: 1.5)
            : BorderSide.none,
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Row(
          children: [
            CircleAvatar(
              radius: 24,
              backgroundColor: color.withValues(alpha: 0.12),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: Colors.grey.shade700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    value,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: isHighlighted ? color : Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: const TextStyle(fontSize: 11, color: Colors.black45),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Formulaire d'ouverture avec raccourcis de montants sur Windows
class _OpenSessionCard extends StatefulWidget {
  const _OpenSessionCard({required this.canOpen, required this.isDesktop});

  final bool canOpen;
  final bool isDesktop;

  @override
  State<_OpenSessionCard> createState() => _OpenSessionCardState();
}

class _OpenSessionCardState extends State<_OpenSessionCard> {
  final _cashCtrl = TextEditingController();
  final _momoCtrl = TextEditingController();

  static const _presets = [0, 20000, 50000, 100000];

  @override
  void dispose() {
    _cashCtrl.dispose();
    _momoCtrl.dispose();
    super.dispose();
  }

  void _submit() {
    final cash = int.tryParse(_cashCtrl.text.trim()) ?? 0;
    final momo = int.tryParse(_momoCtrl.text.trim()) ?? 0;
    context.read<CashSessionsBloc>().add(
          CashSessionOpenRequested(
            OpenCashSessionInput(openingCash: cash, openingMomo: momo),
          ),
        );
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: AppColors.seed.withValues(alpha: 0.12),
                  child: const Icon(Icons.lock_open, color: AppColors.seed),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Ouverture de caisse',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const Text(
                        'Saisissez le fond de caisse disponible pour débuter le service.',
                        style: TextStyle(fontSize: 13, color: Colors.black54),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const Divider(height: AppSpacing.xl),

            // Raccourcis de sélection rapide (très ergonomique sur Windows)
            Text(
              'Raccourcis fond espèces :',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
            ),
            const SizedBox(height: AppSpacing.xs),
            Wrap(
              spacing: AppSpacing.sm,
              children: _presets.map((val) {
                return ActionChip(
                  label: Text(val == 0 ? '0 F' : formatFcfa(val)),
                  onPressed: widget.canOpen
                      ? () => setState(() => _cashCtrl.text = '$val')
                      : null,
                );
              }).toList(),
            ),
            const SizedBox(height: AppSpacing.md),

            // Champs de saisie côte à côte sur Desktop
            if (widget.isDesktop)
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _cashCtrl,
                      enabled: widget.canOpen,
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      decoration: const InputDecoration(
                        labelText: 'Fond espèces (FCFA) *',
                        prefixIcon: Icon(Icons.payments_outlined),
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: TextField(
                      controller: _momoCtrl,
                      enabled: widget.canOpen,
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      decoration: const InputDecoration(
                        labelText: 'Fond Mobile Money (FCFA)',
                        prefixIcon: Icon(Icons.phone_android_outlined),
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                ],
              )
            else ...[
              TextField(
                controller: _cashCtrl,
                enabled: widget.canOpen,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: const InputDecoration(
                  labelText: 'Fond espèces (FCFA) *',
                  prefixIcon: Icon(Icons.payments_outlined),
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              TextField(
                controller: _momoCtrl,
                enabled: widget.canOpen,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: const InputDecoration(
                  labelText: 'Fond Mobile Money (FCFA)',
                  prefixIcon: Icon(Icons.phone_android_outlined),
                  border: OutlineInputBorder(),
                ),
              ),
            ],
            const SizedBox(height: AppSpacing.lg),
            FilledButton.icon(
              onPressed: widget.canOpen ? _submit : null,
              icon: const Icon(Icons.lock_open_outlined),
              label: const Text('Ouvrir la session de caisse'),
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(48),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Panneau d'historique dédié pour Windows avec recherche rapide
class _DesktopHistoryPanel extends StatefulWidget {
  const _DesktopHistoryPanel({
    required this.history,
    required this.session,
  });

  final List<CashSessionListRow> history;
  final AuthSession session;

  @override
  State<_DesktopHistoryPanel> createState() => _DesktopHistoryPanelState();
}

class _DesktopHistoryPanelState extends State<_DesktopHistoryPanel> {
  final _searchCtrl = TextEditingController();

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final query = _searchCtrl.text.trim().toLowerCase();
    final filtered = widget.history.where((row) {
      if (query.isEmpty) return true;
      return row.openedByName.toLowerCase().contains(query) ||
          row.status.label.toLowerCase().contains(query);
    }).toList();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const Icon(Icons.history, color: Colors.blueGrey),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    'Historique des sessions',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                Chip(
                  label: Text('${widget.history.length} clôture(s)'),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            TextField(
              controller: _searchCtrl,
              decoration: InputDecoration(
                hintText: 'Rechercher par caissier ou statut...',
                prefixIcon: const Icon(Icons.search, size: 20),
                isDense: true,
                border: const OutlineInputBorder(),
                suffixIcon: query.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, size: 18),
                        onPressed: () => setState(() => _searchCtrl.clear()),
                      )
                    : null,
              ),
              onChanged: (_) => setState(() {}),
            ),
            const Divider(height: AppSpacing.lg),
            if (filtered.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg),
                child: EmptyListPlaceholder(
                  icon: Icons.history_outlined,
                  title: query.isNotEmpty
                      ? 'Aucun résultat pour cette recherche'
                      : 'Aucune session enregistrée',
                ),
              )
            else
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 560),
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: filtered.length,
                  itemBuilder: (context, index) {
                    final row = filtered[index];
                    return _HistoryTile(
                      row: row,
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => CashSessionDetailPage(
                            session: widget.session,
                            sessionId: row.id,
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Carte de la session en cours avec affichage séparé Espèces / MoMo
class _ActiveSessionCard extends StatelessWidget {
  const _ActiveSessionCard({
    required this.authSession,
    required this.session,
    required this.totals,
    required this.movements,
    required this.canAdjust,
    required this.canClose,
    required this.isSubmitting,
    required this.isDesktop,
  });

  final AuthSession authSession;
  final CashSession session;
  final CashSessionLiveTotals? totals;
  final List<CashMovement> movements;
  final bool canAdjust;
  final bool canClose;
  final bool isSubmitting;
  final bool isDesktop;

  int get _expectedCash {
    final t = totals;
    if (t == null) return session.openingCash;
    return session.openingCash +
        t.salesCash +
        t.depositsCash -
        t.expensesCash -
        t.withdrawalsCash;
  }

  int get _expectedMomo {
    final t = totals;
    if (t == null) return session.openingMomo;
    return session.openingMomo +
        t.salesMomo +
        t.depositsMomo -
        t.expensesMomo -
        t.withdrawalsMomo;
  }

  @override
  Widget build(BuildContext context) {
    final ownerDrops = movements
        .where((m) => m.movementType == CashMovementType.ownerDrop)
        .fold<int>(0, (sum, m) => sum + m.amount);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // En-tête session
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: Colors.green.withValues(alpha: 0.15),
                  child: const Icon(Icons.point_of_sale, color: Colors.green),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Session de caisse active',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      Text(
                        'Responsable : ${session.openedByName}',
                        style: const TextStyle(fontSize: 13, color: Colors.black54),
                      ),
                    ],
                  ),
                ),
                Chip(
                  avatar: const Icon(Icons.access_time, size: 16),
                  label: Text(AppDateFormatter.formatDateTime(
                    DateTime.fromMillisecondsSinceEpoch(session.openedAt),
                  )),
                ),
              ],
            ),
            const Divider(height: AppSpacing.lg),

            // Décomposition visuelle distincte : Tiroir Espèces vs Comptes Mobile Money
            _buildRegisters(context, ownerDrops),

            if (movements.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.md),
              Text(
                'Mouvements manuels récents',
                style: Theme.of(context).textTheme.titleSmall,
              ),
              const SizedBox(height: 4),
              ...movements.take(4).map(
                    (m) => Card(
                      margin: const EdgeInsets.only(bottom: 4),
                      color: Colors.grey.shade50,
                      elevation: 0,
                      child: ListTile(
                        dense: true,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.sm,
                        ),
                        leading: Icon(
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
                        ),
                        title: Text(
                          '${m.movementType.label} · ${m.registerType.label}',
                          style: const TextStyle(fontWeight: FontWeight.w500),
                        ),
                        subtitle: Text(m.note ?? 'Aucune note'),
                        trailing: Text(
                          formatFcfa(m.amount),
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                  ),
            ],

            const SizedBox(height: AppSpacing.lg),

            // Barre d'actions Desktop / Mobile
            if (canAdjust) ...[
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: isSubmitting
                          ? null
                          : () => _showMovementDialog(context),
                      icon: const Icon(Icons.swap_vert),
                      label: const Text('Mouvement de caisse'),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: isSubmitting
                          ? null
                          : () => _showOwnerDropDialog(context),
                      icon: const Icon(Icons.payments_outlined),
                      label: const Text('Remise patron'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.indigo.shade800,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
            ],
            if (canClose)
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: isSubmitting
                      ? null
                      : () => _showCloseDialog(context),
                  icon: const Icon(Icons.lock_outline),
                  label: const Text('Clôturer la caisse & Rapprocher'),
                  style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(48),
                    backgroundColor: AppColors.seed,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildRegisters(BuildContext context, int ownerDrops) {
    final t = totals;

    final cashCard = _RegisterBox(
      title: 'Tiroir Espèces (Cash)',
      icon: Icons.payments_outlined,
      color: Colors.teal.shade700,
      lines: [
        _Line('Fond initial', session.openingCash),
        if (t != null) ...[
          _Line('Ventes espèces', t.salesCash, positive: true),
          _Line('Entrées manuelles', t.depositsCash, positive: true),
          _Line('Dépenses payées', t.expensesCash, negative: true),
          _Line('Retraits espèces', t.withdrawalsCash, negative: true),
          if (ownerDrops > 0)
            _Line('Remises patron', ownerDrops, negative: true),
        ],
      ],
      expectedLabel: 'Attendu espèces',
      expectedAmount: _expectedCash,
    );

    final momoCard = _RegisterBox(
      title: 'Comptes Mobile Money',
      icon: Icons.phone_android_outlined,
      color: Colors.amber.shade900,
      lines: [
        _Line('Fond initial MoMo', session.openingMomo),
        if (t != null) ...[
          _Line('Ventes MoMo', t.salesMomo, positive: true),
          _Line('Entrées MoMo', t.depositsMomo, positive: true),
          _Line('Dépenses MoMo', t.expensesMomo, negative: true),
          _Line('Retraits MoMo', t.withdrawalsMomo, negative: true),
        ],
      ],
      expectedLabel: 'Attendu MoMo',
      expectedAmount: _expectedMomo,
    );

    if (isDesktop) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: cashCard),
          const SizedBox(width: AppSpacing.md),
          Expanded(child: momoCard),
        ],
      );
    } else {
      return Column(
        children: [
          cashCard,
          const SizedBox(height: AppSpacing.sm),
          momoCard,
        ],
      );
    }
  }

  Future<void> _showOwnerDropDialog(BuildContext context) async {
    var register = CashRegisterType.cash;
    final amountCtrl = TextEditingController();
    final noteCtrl = TextEditingController();

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          title: const Text('Remise de fonds au patron'),
          content: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(
                    padding: const EdgeInsets.all(AppSpacing.sm),
                    decoration: BoxDecoration(
                      color: Colors.indigo.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.indigo.shade200),
                    ),
                    child: const Text(
                      'Enregistre un prélèvement direct par le propriétaire. '
                      'Ce montant est déduit de la caisse attendue sans impacter vos ventes ni les créances.',
                      style: TextStyle(fontSize: 12, color: Colors.black87),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  DropdownButtonFormField<CashRegisterType>(
                    initialValue: register,
                    decoration: const InputDecoration(
                      labelText: 'Support prélevé',
                      border: OutlineInputBorder(),
                    ),
                    items: [
                      CashRegisterType.cash,
                      CashRegisterType.mtnMomo,
                      CashRegisterType.moovMoney,
                      CashRegisterType.celtis,
                    ]
                        .map(
                          (r) => DropdownMenuItem(
                            value: r,
                            child: Text(r.label),
                          ),
                        )
                        .toList(),
                    onChanged: (v) => setLocal(() => register = v ?? register),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  TextField(
                    controller: amountCtrl,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    decoration: const InputDecoration(
                      labelText: 'Montant prélevé (FCFA) *',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.payments_outlined),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  TextField(
                    controller: noteCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Motif / observation (optionnel)',
                      hintText: 'Ex: Dépôt banque, courses, approvisionnement...',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Annuler'),
            ),
            FilledButton(
              onPressed: () {
                final amt = int.tryParse(amountCtrl.text.trim()) ?? 0;
                if (amt <= 0) return;
                Navigator.pop(ctx, true);
              },
              child: const Text('Valider le prélèvement'),
            ),
          ],
        ),
      ),
    );

    if (ok != true || !context.mounted) return;
    final amount = int.tryParse(amountCtrl.text.trim()) ?? 0;
    if (amount <= 0) return;

    context.read<CashSessionsBloc>().add(
          CashSessionOwnerDropRequested(
            RecordOwnerDropInput(
              amount: amount,
              registerType: register,
              note: noteCtrl.text.trim().isEmpty ? null : noteCtrl.text.trim(),
            ),
          ),
        );
  }

  Future<void> _showMovementDialog(BuildContext context) async {
    var type = CashMovementType.deposit;
    var register = CashRegisterType.cash;
    final amountCtrl = TextEditingController();
    final noteCtrl = TextEditingController();

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          title: const Text('Mouvement de caisse'),
          content: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 500),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SegmentedButton<CashMovementType>(
                    segments: const [
                      ButtonSegment(
                        value: CashMovementType.deposit,
                        label: Text('Entrée'),
                      ),
                      ButtonSegment(
                        value: CashMovementType.withdrawal,
                        label: Text('Dépense'),
                      ),
                      ButtonSegment(
                        value: CashMovementType.ownerDrop,
                        label: Text('Patron'),
                      ),
                      ButtonSegment(
                        value: CashMovementType.bankDeposit,
                        label: Text('Banque'),
                      ),
                    ],
                    selected: {type},
                    onSelectionChanged: (s) => setLocal(() => type = s.first),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  DropdownButtonFormField<CashRegisterType>(
                    initialValue: register,
                    decoration: const InputDecoration(
                      labelText: 'Support',
                      border: OutlineInputBorder(),
                    ),
                    items: CashRegisterType.values
                        .map(
                          (r) => DropdownMenuItem(
                            value: r,
                            child: Text(r.label),
                          ),
                        )
                        .toList(),
                    onChanged: (v) => setLocal(() => register = v ?? register),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  TextField(
                    controller: amountCtrl,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    decoration: const InputDecoration(
                      labelText: 'Montant (FCFA) *',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  TextField(
                    controller: noteCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Note / motif (optionnel)',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Annuler'),
            ),
            FilledButton(
              onPressed: () {
                final amt = int.tryParse(amountCtrl.text.trim()) ?? 0;
                if (amt <= 0) return;
                Navigator.pop(ctx, true);
              },
              child: const Text('Enregistrer'),
            ),
          ],
        ),
      ),
    );

    if (ok != true || !context.mounted) return;
    final amount = int.tryParse(amountCtrl.text.trim()) ?? 0;
    if (amount <= 0) return;

    if (type == CashMovementType.ownerDrop) {
      context.read<CashSessionsBloc>().add(
            CashSessionOwnerDropRequested(
              RecordOwnerDropInput(
                amount: amount,
                registerType: register,
                note: noteCtrl.text.trim().isEmpty ? null : noteCtrl.text.trim(),
              ),
            ),
          );
    } else {
      context.read<CashSessionsBloc>().add(
            CashMovementRecordRequested(
              RecordCashMovementInput(
                movementType: type,
                registerType: register,
                amount: amount,
                note: noteCtrl.text.trim().isEmpty ? null : noteCtrl.text.trim(),
              ),
            ),
          );
    }
  }

  Future<void> _showCloseDialog(BuildContext context) async {
    final cashCtrl = TextEditingController();
    final momoCtrl = TextEditingController();
    final noteCtrl = TextEditingController();
    final justificationNoteCtrl = TextEditingController();
    var justificationCategory = 'unconfirmed_payment';
    var ownerPin = '';
    var validateWithPinOnSite = false;
    final isOwner = authSession.user.role == UserRole.owner;

    final categories = const [
      ('unconfirmed_payment', 'Paiement Mobile Money non confirmé'),
      ('pending_transaction', 'Transaction client en attente'),
      ('entry_error', 'Erreur de saisie dans une vente'),
      ('unrecorded_expense', 'Dépense urgente non enregistrée'),
      ('network_fee', 'Frais de retrait Mobile Money déduits'),
      ('cash_breakage', 'Erreur de rendu de monnaie'),
      ('other', 'Autre motif (préciser ci-dessous)'),
    ];

    final result = await showDialog<_CloseDialogResult>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) {
          final isWide = MediaQuery.sizeOf(ctx).width >= 680;
          final countedCash = int.tryParse(cashCtrl.text.trim()) ?? 0;
          final countedMomo = int.tryParse(momoCtrl.text.trim()) ?? 0;
          final hasEnteredCount =
              cashCtrl.text.trim().isNotEmpty || momoCtrl.text.trim().isNotEmpty;

          final diffCash = countedCash - _expectedCash;
          final diffMomo = countedMomo - _expectedMomo;
          final totalDiff = diffCash + diffMomo;
          final hasDiscrepancy =
              hasEnteredCount && (diffCash != 0 || diffMomo != 0);

          final canSubmit = hasEnteredCount &&
              (!hasDiscrepancy ||
                  justificationNoteCtrl.text.trim().isNotEmpty);

          final canCloseDirect = canSubmit &&
              (isOwner ||
                  (validateWithPinOnSite && ownerPin.length >= 4));

          // Colonne Saisie physique
          final inputForm = Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                padding: const EdgeInsets.all(AppSpacing.sm),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.blue.shade200),
                ),
                child: const Text(
                  'Comptage à l\'aveugle : saisissez vos montants réels en espèces et Mobile Money. '
                  'Le système calculera automatiquement les écarts.',
                  style: TextStyle(fontSize: 12, color: Colors.blueGrey),
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              TextField(
                controller: cashCtrl,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: const InputDecoration(
                  labelText: 'Espèces réellement comptées (FCFA) *',
                  hintText: '0',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.payments_outlined),
                ),
                onChanged: (_) => setLocal(() {}),
              ),
              const SizedBox(height: AppSpacing.sm),
              TextField(
                controller: momoCtrl,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: const InputDecoration(
                  labelText: 'Mobile Money compté / vérifié (FCFA) *',
                  hintText: '0',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.phone_android_outlined),
                ),
                onChanged: (_) => setLocal(() {}),
              ),
              const SizedBox(height: AppSpacing.sm),
              TextField(
                controller: noteCtrl,
                decoration: const InputDecoration(
                  labelText: 'Note générale de clôture (optionnel)',
                  border: OutlineInputBorder(),
                ),
              ),
              if (!isOwner) ...[
                const SizedBox(height: AppSpacing.sm),
                SwitchListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Validation sur place par le patron'),
                  subtitle: const Text('Activer si le patron est au magasin'),
                  value: validateWithPinOnSite,
                  onChanged: (v) => setLocal(() => validateWithPinOnSite = v),
                ),
                if (validateWithPinOnSite) ...[
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    'Code PIN du patron (4 chiffres)',
                    style: Theme.of(ctx).textTheme.titleSmall,
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  PinPad(
                    filledCount: ownerPin.length,
                    maxLength: 6,
                    compact: true,
                    onDigit: (d) {
                      if (ownerPin.length >= 6) return;
                      setLocal(() => ownerPin += d);
                    },
                    onBackspace: () {
                      if (ownerPin.isEmpty) return;
                      setLocal(
                        () => ownerPin =
                            ownerPin.substring(0, ownerPin.length - 1),
                      );
                    },
                  ),
                ],
              ],
            ],
          );

          // Colonne Rapprochement & Justification
          final reconciliationPreview = Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (hasEnteredCount) ...[
                Container(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  decoration: BoxDecoration(
                    color: hasDiscrepancy
                        ? Colors.amber.shade50
                        : Colors.green.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: hasDiscrepancy
                          ? Colors.amber.shade400
                          : Colors.green.shade300,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        'Rapprochement théorique vs réel',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                          color: hasDiscrepancy
                              ? Colors.brown.shade800
                              : Colors.green.shade900,
                        ),
                      ),
                      const SizedBox(height: 6),
                      _miniRow(
                        'Espèces',
                        'Attendu : ${formatFcfa(_expectedCash)}',
                        diffCash,
                      ),
                      _miniRow(
                        'Mobile Money',
                        'Attendu : ${formatFcfa(_expectedMomo)}',
                        diffMomo,
                      ),
                      const Divider(height: 14),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Écart net global :',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                          Text(
                            totalDiff == 0
                                ? '0 FCFA (Équilibré)'
                                : '${totalDiff > 0 ? '+' : ''}${formatFcfa(totalDiff)}',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: totalDiff == 0
                                  ? Colors.green.shade700
                                  : totalDiff > 0
                                      ? Colors.blue.shade700
                                      : Colors.red.shade700,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ] else
                Container(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.grey.shade200),
                  ),
                  child: const Center(
                    child: Text(
                      'Saisissez les montants comptés à gauche pour révéler le rapprochement.',
                      style: TextStyle(color: Colors.black45, fontSize: 13),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
              if (hasDiscrepancy) ...[
                const SizedBox(height: AppSpacing.md),
                Text(
                  'Justification obligatoire de l\'écart',
                  style: Theme.of(ctx).textTheme.titleSmall?.copyWith(
                        color: Colors.red.shade700,
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const SizedBox(height: AppSpacing.xs),
                DropdownButtonFormField<String>(
                  initialValue: justificationCategory,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'Cause principale de l\'écart *',
                    border: OutlineInputBorder(),
                  ),
                  items: categories
                      .map(
                        (c) => DropdownMenuItem(
                          value: c.$1,
                          child: Text(
                            c.$2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      )
                      .toList(),
                  onChanged: (v) => setLocal(
                    () => justificationCategory = v ?? justificationCategory,
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                TextField(
                  controller: justificationNoteCtrl,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: 'Explication détaillée pour le patron *',
                    hintText:
                        'Précisez d\'où provient cette différence (n° transaction, client, contexte)...',
                    border: OutlineInputBorder(),
                  ),
                  onChanged: (_) => setLocal(() {}),
                ),
              ],
            ],
          );

          return AlertDialog(
            title: const Text('Clôture & Rapprochement'),
            content: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: isWide ? 760 : 420,
                maxHeight: isWide ? 560 : 600,
              ),
              child: SingleChildScrollView(
                child: isWide
                    ? Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(child: inputForm),
                          const SizedBox(width: AppSpacing.lg),
                          Expanded(child: reconciliationPreview),
                        ],
                      )
                    : Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          inputForm,
                          const SizedBox(height: AppSpacing.md),
                          reconciliationPreview,
                        ],
                      ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Annuler'),
              ),
              if (!isOwner && !validateWithPinOnSite)
                FilledButton.icon(
                  onPressed: canSubmit
                      ? () => Navigator.pop(
                            ctx,
                            _CloseDialogResult(
                              isSubmitOnly: true,
                              countedCash: countedCash,
                              countedMomo: countedMomo,
                              closingNote: noteCtrl.text.trim().isEmpty
                                  ? null
                                  : noteCtrl.text.trim(),
                              justificationCategory: hasDiscrepancy
                                  ? justificationCategory
                                  : null,
                              justificationNote: hasDiscrepancy
                                  ? justificationNoteCtrl.text.trim()
                                  : null,
                            ),
                          )
                      : null,
                  icon: const Icon(Icons.send_outlined),
                  label: const Text('Soumettre au patron'),
                )
              else
                FilledButton.icon(
                  onPressed: canCloseDirect
                      ? () => Navigator.pop(
                            ctx,
                            _CloseDialogResult(
                              isSubmitOnly: false,
                              countedCash: countedCash,
                              countedMomo: countedMomo,
                              closingNote: noteCtrl.text.trim().isEmpty
                                  ? null
                                  : noteCtrl.text.trim(),
                              ownerPin: isOwner ? null : ownerPin,
                              justificationCategory: hasDiscrepancy
                                  ? justificationCategory
                                  : null,
                              justificationNote: hasDiscrepancy
                                  ? justificationNoteCtrl.text.trim()
                                  : null,
                            ),
                          )
                      : null,
                  icon: const Icon(Icons.lock_outline),
                  label: const Text('Valider la clôture'),
                ),
            ],
          );
        },
      ),
    );

    if (result == null || !context.mounted) return;

    if (result.isSubmitOnly) {
      context.read<CashSessionsBloc>().add(
            CashSessionSubmitClosingRequested(
              SubmitCashSessionClosingInput(
                countedCash: result.countedCash,
                countedMomo: result.countedMomo,
                closingNote: result.closingNote,
                justificationCategory: result.justificationCategory,
                justificationNote: result.justificationNote,
              ),
            ),
          );
    } else {
      context.read<CashSessionsBloc>().add(
            CashSessionCloseRequested(
              CloseCashSessionInput(
                countedCash: result.countedCash,
                countedMomo: result.countedMomo,
                closingNote: result.closingNote,
                ownerPin: result.ownerPin,
                justificationCategory: result.justificationCategory,
                justificationNote: result.justificationNote,
              ),
            ),
          );
    }
  }

  static Widget _miniRow(String title, String subtitle, int diff) {
    final color = diff == 0
        ? Colors.green.shade700
        : diff > 0
            ? Colors.blue.shade700
            : Colors.red.shade700;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text('$title ($subtitle)', style: const TextStyle(fontSize: 12)),
          Text(
            diff == 0 ? '0 F' : '${diff > 0 ? '+' : ''}${formatFcfa(diff)}',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

/// Carte de décomposition pour un registre (Espèces ou Mobile Money)
class _RegisterBox extends StatelessWidget {
  const _RegisterBox({
    required this.title,
    required this.icon,
    required this.color,
    required this.lines,
    required this.expectedLabel,
    required this.expectedAmount,
  });

  final String title;
  final IconData icon;
  final Color color;
  final List<Widget> lines;
  final String expectedLabel;
  final int expectedAmount;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Entête de boîte
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.sm,
            ),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.08),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(11)),
            ),
            child: Row(
              children: [
                Icon(icon, color: color, size: 20),
                const SizedBox(width: AppSpacing.sm),
                Text(
                  title,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: color,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                ...lines,
                const Divider(height: 16),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.sm,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        expectedLabel,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: color,
                          fontSize: 13,
                        ),
                      ),
                      Text(
                        formatFcfa(expectedAmount),
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: color,
                          fontSize: 15,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CloseDialogResult {
  const _CloseDialogResult({
    required this.isSubmitOnly,
    required this.countedCash,
    required this.countedMomo,
    this.closingNote,
    this.ownerPin,
    this.justificationCategory,
    this.justificationNote,
  });

  final bool isSubmitOnly;
  final int countedCash;
  final int countedMomo;
  final String? closingNote;
  final String? ownerPin;
  final String? justificationCategory;
  final String? justificationNote;
}

class _Line extends StatelessWidget {
  const _Line(this.label, this.amount, {this.positive, this.negative});

  final String label;
  final int amount;
  final bool? positive;
  final bool? negative;

  @override
  Widget build(BuildContext context) {
    final isMoney = label != 'Nombre de ventes';
    final text = isMoney ? formatFcfa(amount) : '$amount';
    Color? color;
    if (positive == true && amount > 0) color = Colors.green.shade700;
    if (negative == true && amount > 0) color = Colors.red.shade700;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2.5),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 12.5,
                color: Colors.grey.shade800,
              ),
            ),
          ),
          Text(
            text,
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w500,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

class _HistoryTile extends StatelessWidget {
  const _HistoryTile({required this.row, required this.onTap});

  final CashSessionListRow row;
  final VoidCallback onTap;

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
    final diff = row.totalDifference;
    final diffColor = diff == 0
        ? Colors.green
        : diff > 0
            ? Colors.blue
            : Colors.red;
    final statusColor = _statusColor(row.status);

    return Card(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      elevation: 0.5,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: ListTile(
        onTap: onTap,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: 2,
        ),
        leading: CircleAvatar(
          backgroundColor: statusColor.withValues(alpha: 0.15),
          child: Icon(
            row.status == CashSessionStatus.open
                ? Icons.lock_open
                : row.status == CashSessionStatus.approved
                    ? Icons.verified_outlined
                    : row.status == CashSessionStatus.reviewRequired ||
                            row.status == CashSessionStatus.justified
                        ? Icons.pending_actions
                        : Icons.lock,
            color: statusColor,
            size: 20,
          ),
        ),
        title: Row(
          children: [
            Expanded(
              child: Text(
                AppDateFormatter.formatDate(
                  DateTime.fromMillisecondsSinceEpoch(row.openedAt),
                ),
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
              decoration: BoxDecoration(
                color: statusColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                row.status.label,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: statusColor,
                ),
              ),
            ),
          ],
        ),
        subtitle: Text(
          '${row.openedByName} · ${row.saleCount} vente(s)',
          style: const TextStyle(fontSize: 12),
        ),
        trailing: Text(
          diff == 0 ? '0 FCFA' : '${diff > 0 ? '+' : ''}${formatFcfa(diff)}',
          style: TextStyle(
            color: diffColor,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}
