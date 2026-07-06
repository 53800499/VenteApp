import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';

import '../../../../app/di/injection_container.dart';
import '../../../../app/theme/app_tokens.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../../shared/enums/permission.dart';
import '../../../../shared/guards/permission_guard.dart';
import '../../../auth/domain/entities/auth_entities.dart';
import '../../../../shared/enums/user_role.dart';
import '../../../auth/presentation/widgets/pin_pad.dart';
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

    return BlocProvider(
      create: (_) => CashSessionsBloc(
        findOpenSession: sl<FindOpenCashSession>(),
        listSessions: sl<ListCashSessions>(),
        getLiveTotals: sl<GetCashSessionLiveTotals>(),
        listMovements: sl<ListCashMovements>(),
        openSession: sl<OpenCashSession>(),
        closeSession: sl<CloseCashSession>(),
        recordMovement: sl<RecordCashMovement>(),
        syncFromRemote: sl<SyncCashSessionsFromRemote>(),
        session: session,
      )..add(const CashSessionsLoadRequested()),
      child: const _CashSessionsView(),
    );
  }
}

class _CashSessionsView extends StatelessWidget {
  const _CashSessionsView();

  @override
  Widget build(BuildContext context) {
    final bloc = context.read<CashSessionsBloc>();
    final perms = bloc.session.user.permissions;
    final canOpen =
        PermissionGuard.can(perms, Permission.cashSessionsOpen);
    final canClose =
        PermissionGuard.can(perms, Permission.cashSessionsClose);
    final canAdjust =
        PermissionGuard.can(perms, Permission.cashSessionsAdjust);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Gestion de caisse'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => context
                .read<CashSessionsBloc>()
                .add(const CashSessionsRefreshRequested()),
          ),
        ],
      ),
      body: BlocConsumer<CashSessionsBloc, CashSessionsState>(
        listenWhen: (p, c) => c.errorMessage != null && p.errorMessage != c.errorMessage,
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
            return const Center(child: CircularProgressIndicator());
          }

          return RefreshIndicator(
            onRefresh: () async {
              context
                  .read<CashSessionsBloc>()
                  .add(const CashSessionsRefreshRequested());
              await context.read<CashSessionsBloc>().stream.firstWhere(
                    (s) => !s.isRefreshing,
                  );
            },
            child: ListView(
              padding: const EdgeInsets.all(AppSpacing.md),
              children: [
                if (state.isRefreshing)
                  const LinearProgressIndicator(minHeight: 2),
                if (state.openSession == null) ...[
                  _OpenSessionCard(canOpen: canOpen),
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
                  ),
                  const SizedBox(height: AppSpacing.lg),
                ],
                Text(
                  'Historique des clôtures',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: AppSpacing.sm),
                if (state.history.isEmpty)
                  const Card(
                    child: Padding(
                      padding: EdgeInsets.all(AppSpacing.lg),
                      child: Text('Aucune session enregistrée.'),
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
            ),
          );
        },
      ),
    );
  }
}

class _OpenSessionCard extends StatefulWidget {
  const _OpenSessionCard({required this.canOpen});

  final bool canOpen;

  @override
  State<_OpenSessionCard> createState() => _OpenSessionCardState();
}

class _OpenSessionCardState extends State<_OpenSessionCard> {
  final _cashCtrl = TextEditingController();
  final _momoCtrl = TextEditingController();

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
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Ouverture de caisse',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: AppSpacing.sm),
            const Text(
              'Saisissez le fond de caisse du matin (espèces et Mobile Money).',
            ),
            const SizedBox(height: AppSpacing.md),
            TextField(
              controller: _cashCtrl,
              enabled: widget.canOpen,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: const InputDecoration(
                labelText: 'Fond espèces (FCFA)',
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
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            FilledButton.icon(
              onPressed: widget.canOpen ? _submit : null,
              icon: const Icon(Icons.lock_open_outlined),
              label: const Text('Ouvrir la caisse'),
            ),
          ],
        ),
      ),
    );
  }
}

class _ActiveSessionCard extends StatelessWidget {
  const _ActiveSessionCard({
    required this.authSession,
    required this.session,
    required this.totals,
    required this.movements,
    required this.canAdjust,
    required this.canClose,
    required this.isSubmitting,
  });

  final AuthSession authSession;
  final CashSession session;
  final CashSessionLiveTotals? totals;
  final List<CashMovement> movements;
  final bool canAdjust;
  final bool canClose;
  final bool isSubmitting;

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
    final t = totals;
    final dateFmt = DateFormat('dd/MM/yyyy HH:mm');

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const Icon(Icons.point_of_sale, color: Colors.green),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    'Session ouverte',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
                Chip(
                  label: Text(dateFmt.format(
                    DateTime.fromMillisecondsSinceEpoch(session.openedAt),
                  )),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            Text('Responsable : ${session.openedByName}'),
            const Divider(height: AppSpacing.lg),
            _Line('Fond initial espèces', session.openingCash),
            _Line('Fond initial MoMo', session.openingMomo),
            if (t != null) ...[
              _Line('Ventes espèces', t.salesCash, positive: true),
              _Line('Ventes MoMo', t.salesMomo, positive: true),
              _Line('Dépenses espèces', t.expensesCash, negative: true),
              _Line('Dépenses MoMo', t.expensesMomo, negative: true),
              _Line('Entrées espèces', t.depositsCash, positive: true),
              _Line('Entrées MoMo', t.depositsMomo, positive: true),
              _Line('Retraits espèces', t.withdrawalsCash, negative: true),
              _Line('Retraits MoMo', t.withdrawalsMomo, negative: true),
              _Line('Nombre de ventes', t.saleCount),
            ],
            const Divider(),
            _Line('Attendu espèces', _expectedCash, bold: true),
            _Line('Attendu MoMo', _expectedMomo, bold: true),
            if (movements.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.sm),
              Text(
                'Mouvements manuels',
                style: Theme.of(context).textTheme.titleSmall,
              ),
              ...movements.take(5).map(
                    (m) => ListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      leading: Icon(
                        m.movementType == CashMovementType.deposit
                            ? Icons.add_circle_outline
                            : Icons.remove_circle_outline,
                      ),
                      title: Text(
                        '${m.movementType.label} ${m.registerType.label}',
                      ),
                      subtitle: Text(m.note ?? ''),
                      trailing: Text(formatFcfa(m.amount)),
                    ),
                  ),
            ],
            const SizedBox(height: AppSpacing.md),
            Row(
              children: [
                if (canAdjust)
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: isSubmitting
                          ? null
                          : () => _showMovementDialog(context),
                      icon: const Icon(Icons.swap_vert),
                      label: const Text('Mouvement'),
                    ),
                  ),
                if (canAdjust && canClose)
                  const SizedBox(width: AppSpacing.sm),
                if (canClose)
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: isSubmitting
                          ? null
                          : () => _showCloseDialog(context),
                      icon: const Icon(Icons.lock_outline),
                      label: const Text('Clôturer'),
                    ),
                  ),
              ],
            ),
          ],
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
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SegmentedButton<CashMovementType>(
                segments: const [
                  ButtonSegment(
                    value: CashMovementType.deposit,
                    label: Text('Entrée'),
                  ),
                  ButtonSegment(
                    value: CashMovementType.withdrawal,
                    label: Text('Retrait'),
                  ),
                ],
                selected: {type},
                onSelectionChanged: (s) => setLocal(() => type = s.first),
              ),
              const SizedBox(height: AppSpacing.sm),
              DropdownButtonFormField<CashRegisterType>(
                value: register,
                decoration: const InputDecoration(labelText: 'Support'),
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
              TextField(
                controller: amountCtrl,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: const InputDecoration(labelText: 'Montant (FCFA)'),
              ),
              TextField(
                controller: noteCtrl,
                decoration: const InputDecoration(labelText: 'Note (optionnel)'),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Annuler'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Enregistrer'),
            ),
          ],
        ),
      ),
    );

    if (ok != true || !context.mounted) return;
    final amount = int.tryParse(amountCtrl.text.trim()) ?? 0;
    if (amount <= 0) return;

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

  Future<void> _showCloseDialog(BuildContext context) async {
    final cashCtrl = TextEditingController(text: '$_expectedCash');
    final momoCtrl = TextEditingController(text: '$_expectedMomo');
    final noteCtrl = TextEditingController();
    var ownerPin = '';
    final needsOwnerPin = authSession.user.role != UserRole.owner;

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          title: const Text('Clôture de caisse'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('Attendu espèces : ${formatFcfa(_expectedCash)}'),
                Text('Attendu MoMo : ${formatFcfa(_expectedMomo)}'),
                const SizedBox(height: AppSpacing.md),
                TextField(
                  controller: cashCtrl,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: const InputDecoration(
                    labelText: 'Espèces comptées',
                  ),
                ),
                TextField(
                  controller: momoCtrl,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: const InputDecoration(
                    labelText: 'MoMo compté',
                  ),
                ),
                TextField(
                  controller: noteCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Note de clôture (optionnel)',
                  ),
                ),
                if (needsOwnerPin) ...[
                  const SizedBox(height: AppSpacing.md),
                  Text(
                    'PIN du patron',
                    style: Theme.of(ctx).textTheme.titleSmall,
                  ),
                  const SizedBox(height: AppSpacing.sm),
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
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Annuler'),
            ),
            FilledButton(
              onPressed: () {
                if (needsOwnerPin && ownerPin.length < 4) return;
                Navigator.pop(ctx, true);
              },
              child: const Text('Valider la clôture'),
            ),
          ],
        ),
      ),
    );

    if (ok != true || !context.mounted) return;

    context.read<CashSessionsBloc>().add(
          CashSessionCloseRequested(
            CloseCashSessionInput(
              countedCash: int.tryParse(cashCtrl.text.trim()) ?? 0,
              countedMomo: int.tryParse(momoCtrl.text.trim()) ?? 0,
              closingNote:
                  noteCtrl.text.trim().isEmpty ? null : noteCtrl.text.trim(),
              ownerPin: needsOwnerPin ? ownerPin : null,
            ),
          ),
        );
  }
}

class _Line extends StatelessWidget {
  const _Line(this.label, this.amount, {this.positive, this.negative, this.bold});

  final String label;
  final int amount;
  final bool? positive;
  final bool? negative;
  final bool? bold;

  @override
  Widget build(BuildContext context) {
    final isMoney = label != 'Nombre de ventes';
    final text = isMoney ? formatFcfa(amount) : '$amount';
    Color? color;
    if (positive == true && amount > 0) color = Colors.green.shade700;
    if (negative == true && amount > 0) color = Colors.red.shade700;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Expanded(child: Text(label)),
          Text(
            text,
            style: TextStyle(
              fontWeight: bold == true ? FontWeight.bold : null,
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

  @override
  Widget build(BuildContext context) {
    final dateFmt = DateFormat('dd/MM/yyyy');
    final diff = row.totalDifference;
    final diffColor = diff == 0
        ? Colors.green
        : diff > 0
            ? Colors.blue
            : Colors.red;

    return Card(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: ListTile(
        onTap: onTap,
        leading: CircleAvatar(
          backgroundColor: diffColor.withValues(alpha: 0.15),
          child: Icon(
            row.status == CashSessionStatus.open
                ? Icons.lock_open
                : Icons.lock,
            color: diffColor,
            size: 20,
          ),
        ),
        title: Text(dateFmt.format(
          DateTime.fromMillisecondsSinceEpoch(row.openedAt),
        )),
        subtitle: Text(
          '${row.openedByName} · ${row.saleCount} vente(s)',
        ),
        trailing: Text(
          diff == 0 ? '0 FCFA' : '${diff > 0 ? '+' : ''}${formatFcfa(diff)}',
          style: TextStyle(
            color: diffColor,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}
