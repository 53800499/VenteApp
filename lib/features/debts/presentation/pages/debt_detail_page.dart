import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../app/di/injection_container.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_tokens.dart';
import '../../../../core/errors/exception_mapper.dart';
import '../../../../core/errors/failures.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../../shared/components/action_feedback.dart';
import '../../../../shared/enums/permission.dart';
import '../../../../shared/enums/user_role.dart';
import '../../../../shared/guards/permission_guard.dart';
import '../../../audit/presentation/pages/audit_entity_history_page.dart';
import '../../../auth/domain/entities/auth_entities.dart';
import '../../../sales/presentation/pages/sale_detail_page.dart';
import '../../domain/entities/debt_entities.dart';
import '../../domain/usecases/debt_usecases.dart';
import 'record_debt_payment_page.dart';

class DebtDetailPage extends StatefulWidget {
  const DebtDetailPage({
    super.key,
    required this.session,
    required this.debtId,
    this.customerName,
  });

  final AuthSession session;
  final int debtId;
  final String? customerName;

  @override
  State<DebtDetailPage> createState() => _DebtDetailPageState();
}

class _DebtDetailPageState extends State<DebtDetailPage> {
  DebtDetail? _detail;
  bool _loading = true;
  bool _forgiving = false;
  String? _error;

  bool get _canPay =>
      PermissionGuard.can(widget.session.user.permissions, Permission.debtsPayment) &&
      PermissionGuard.can(widget.session.user.permissions, Permission.paymentsCreate);

  bool get _canForgive =>
      widget.session.user.role == UserRole.owner &&
      PermissionGuard.can(widget.session.user.permissions, Permission.debtsForgive);

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final detail = await sl<GetDebtDetail>()(
        session: widget.session,
        debtId: widget.debtId,
      );
      if (!mounted) return;
      setState(() {
        _detail = detail;
        _loading = false;
      });
    } on Failure catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.message;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'Impossible de charger la dette.';
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final detail = _detail;
    final debt = detail?.debt;
    final title = debt?.receiptNumber != null
        ? 'Dette ${debt!.receiptNumber}'
        : 'Dette #${widget.debtId}';

    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        actions: [
          if (_canForgive && debt != null && debt.isRepayable && !_forgiving)
            PopupMenuButton<String>(
              onSelected: (value) {
                if (value == 'forgive') _forgiveDebt(debt);
              },
              itemBuilder: (context) => const [
                PopupMenuItem(
                  value: 'forgive',
                  child: Text('Pardonner la dette'),
                ),
              ],
            ),
        ],
      ),
      body: _buildBody(),
      bottomNavigationBar: _buildBottomBar(),
    );
  }

  Widget? _buildBottomBar() {
    final detail = _detail;
    if (detail == null || !detail.debt.isRepayable) return null;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_canPay)
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: _openPayment,
                  icon: const Icon(Icons.payments_outlined),
                  label: const Text('Enregistrer un paiement'),
                ),
              ),
            if (detail.debt.amountRemaining > 0) ...[
              const SizedBox(height: AppSpacing.sm),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: _sendReminder,
                  icon: const Icon(Icons.chat_outlined),
                  label: const Text('Rappel WhatsApp'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(_error!),
            const SizedBox(height: AppSpacing.md),
            FilledButton(onPressed: _load, child: const Text('Réessayer')),
          ],
        ),
      );
    }

    final detail = _detail!;
    final debt = detail.debt;
    final customerLabel =
        detail.customerName ?? widget.customerName ?? 'Client #${debt.customerId}';

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.all(AppSpacing.md),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          customerLabel,
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                      ),
                      _StatusChip(status: debt.status, isCritical: debt.isCritical),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.md),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(AppRadius.sm),
                    child: LinearProgressIndicator(
                      value: debt.repaymentProgress.clamp(0, 1),
                      minHeight: 10,
                      backgroundColor:
                          Theme.of(context).colorScheme.surfaceContainerHighest,
                      color: debt.isRepayable
                          ? AppColors.warning
                          : AppColors.success,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  _AmountRow(
                    label: 'Montant original',
                    value: formatFcfa(debt.originalAmount),
                  ),
                  _AmountRow(
                    label: 'Remboursé',
                    value: formatFcfa(debt.amountPaid),
                    color: AppColors.success,
                  ),
                  _AmountRow(
                    label: 'Solde restant',
                    value: formatFcfa(debt.amountRemaining),
                    emphasized: true,
                    color: debt.isRepayable ? AppColors.warning : null,
                  ),
                ],
              ),
            ),
          ),
          if (detail.forgiveness != null) ...[
            const SizedBox(height: AppSpacing.md),
            Card(
              color: AppColors.seed.withValues(alpha: 0.06),
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.md),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.volunteer_activism_outlined,
                          color: AppColors.seed,
                          size: 20,
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        Text(
                          'Dette pardonnée',
                          style:
                              Theme.of(context).textTheme.titleSmall?.copyWith(
                                    color: AppColors.seed,
                                    fontWeight: FontWeight.w700,
                                  ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    _AmountRow(
                      label: 'Montant annulé',
                      value: formatFcfa(detail.forgiveness!.forgivenAmount),
                      emphasized: true,
                      color: AppColors.seed,
                    ),
                    _AmountRow(
                      label: 'Date du pardon',
                      value: _formatDateTime(detail.forgiveness!.forgivenAt),
                    ),
                    if (detail.forgiveness!.forgivenByName != null)
                      _AmountRow(
                        label: 'Pardonnée par',
                        value: detail.forgiveness!.forgivenByName!,
                      ),
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      'Motif',
                      style: Theme.of(context).textTheme.labelMedium,
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(detail.forgiveness!.reason),
                  ],
                ),
              ),
            ),
          ],
          const SizedBox(height: AppSpacing.md),
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.calendar_today_outlined),
                  title: const Text('Date de création'),
                  trailing: Text(_formatDateTime(debt.createdAt)),
                ),
                if (debt.dueAt != null)
                  ListTile(
                    leading: const Icon(Icons.event_outlined),
                    title: const Text('Échéance'),
                    trailing: Text(_formatDateTime(debt.dueAt!)),
                  ),
                if (detail.daysWithoutPayment > 0 && debt.isRepayable)
                  ListTile(
                    leading: const Icon(Icons.hourglass_bottom_outlined),
                    title: const Text('Jours sans remboursement'),
                    trailing: Text('${detail.daysWithoutPayment} j.'),
                  ),
                if (debt.saleId != null)
                  ListTile(
                    leading: const Icon(Icons.receipt_long_outlined),
                    title: Text(
                      debt.receiptNumber != null
                          ? 'Vente ${debt.receiptNumber}'
                          : 'Vente d\'origine',
                    ),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => SaleDetailPage(
                          session: widget.session,
                          saleId: debt.saleId!,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              Expanded(
                child: Text(
                  'Historique des remboursements',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              TextButton.icon(
                onPressed: () {
                  ensureAuditDependencies();
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => AuditEntityHistoryPage(
                        session: widget.session,
                        entityTable: 'debts',
                        entityId: debt.id,
                      ),
                    ),
                  );
                },
                icon: const Icon(Icons.history, size: 18),
                label: const Text('Historique complet'),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          if (detail.payments.isEmpty)
            const Card(
              child: Padding(
                padding: EdgeInsets.all(AppSpacing.md),
                child: Text('Aucun remboursement enregistré.'),
              ),
            )
          else
            ...detail.payments.reversed.map(
              (payment) => Card(
                child: ListTile(
                  leading: CircleAvatar(
                    child: Icon(_methodIcon(payment.method)),
                  ),
                  title: Text(formatFcfa(payment.amount)),
                  subtitle: Text(
                    '${payment.method.label} · '
                    '${_formatDateTime(payment.createdAt)}'
                    '${payment.userName != null ? ' · ${payment.userName}' : ''}',
                  ),
                  trailing: payment.receiptNumber != null
                      ? Text(
                          payment.receiptNumber!,
                          style: Theme.of(context).textTheme.bodySmall,
                        )
                      : null,
                ),
              ),
            ),
        ],
      ),
    );
  }

  IconData _methodIcon(DebtRepaymentMethod method) => switch (method) {
        DebtRepaymentMethod.cash => Icons.payments_outlined,
        DebtRepaymentMethod.mtnMomo => Icons.phone_android_outlined,
        DebtRepaymentMethod.moovMoney => Icons.phone_android_outlined,
        DebtRepaymentMethod.other => Icons.more_horiz,
      };

  String _formatDateTime(int ms) {
    final dt = DateTime.fromMillisecondsSinceEpoch(ms);
    return '${dt.day.toString().padLeft(2, '0')}/'
        '${dt.month.toString().padLeft(2, '0')}/'
        '${dt.year} '
        '${dt.hour.toString().padLeft(2, '0')}:'
        '${dt.minute.toString().padLeft(2, '0')}';
  }

  Future<void> _openPayment() async {
    final detail = _detail;
    if (detail == null) return;

    final paid = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => RecordDebtPaymentPage(
          session: widget.session,
          debt: detail.debt,
          customerName:
              detail.customerName ?? widget.customerName ?? 'Client',
        ),
      ),
    );
    if (paid == true && mounted) {
      await _load();
      if (mounted) Navigator.of(context).pop(true);
    }
  }

  Future<void> _sendReminder() async {
    final detail = _detail;
    if (detail == null) return;

    final customerName =
        detail.customerName ?? widget.customerName ?? 'le client';
    final confirmed = await ActionFeedback.confirm(
      context: context,
      title: 'Envoyer un rappel ?',
      message:
          'Ouvrir WhatsApp pour envoyer un rappel de dette à $customerName ?',
      confirmLabel: 'Ouvrir WhatsApp',
    );
    if (confirmed != true || !mounted) return;

    try {
      final reminder = await sl<GetDebtDetailReminder>()(
        session: widget.session,
        debtId: widget.debtId,
      );
      final uri = Uri.parse(reminder.whatsappUrl);
      if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
        throw const ValidationFailure('Impossible d\'ouvrir WhatsApp.');
      }
    } on Failure catch (e) {
      if (!mounted) return;
      await ActionFeedback.showErrorDialog(
        context,
        title: 'Rappel impossible',
        message: friendlyErrorMessage(e),
      );
    } catch (_) {
      if (!mounted) return;
      await ActionFeedback.showErrorDialog(
        context,
        title: 'Rappel impossible',
        message: 'Impossible d\'ouvrir WhatsApp.',
      );
    }
  }

  Future<void> _forgiveDebt(Debt debt) async {
    final reason = await ActionFeedback.confirmWithReason(
      context: context,
      title: 'Pardonner la dette',
      hint: 'Motif (min. 10 caractères)',
      confirmLabel: 'Pardonner',
      minLength: 10,
    );
    if (reason == null || !mounted) return;

    setState(() => _forgiving = true);
    try {
      await sl<ForgiveDebt>()(
        session: widget.session,
        debtId: debt.id,
        reason: reason,
      );

      if (!mounted) return;
      await ActionFeedback.showSuccess(
        context: context,
        title: 'Dette pardonnée',
        message: 'La dette a été pardonnée avec succès.',
      );
      if (mounted) Navigator.of(context).pop(true);
    } on Failure catch (e) {
      if (!mounted) return;
      await ActionFeedback.showErrorDialog(
        context,
        title: 'Pardon impossible',
        message: friendlyErrorMessage(e),
      );
    } catch (e) {
      if (!mounted) return;
      await ActionFeedback.showErrorDialog(
        context,
        title: 'Pardon impossible',
        message: friendlyErrorMessage(e),
      );
    } finally {
      if (mounted) setState(() => _forgiving = false);
    }
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.status, required this.isCritical});

  final DebtStatus status;
  final bool isCritical;

  @override
  Widget build(BuildContext context) {
    final color = switch (status) {
      DebtStatus.forgiven => AppColors.seed,
      DebtStatus.paid => AppColors.success,
      DebtStatus.cancelled => Theme.of(context).colorScheme.outline,
      _ when isCritical => AppColors.danger,
      _ => AppColors.warning,
    };

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppRadius.sm),
      ),
      child: Text(
        isCritical && status.isRepayable ? 'Critique' : status.label,
        style: TextStyle(color: color, fontWeight: FontWeight.w600),
      ),
    );
  }
}

class _AmountRow extends StatelessWidget {
  const _AmountRow({
    required this.label,
    required this.value,
    this.emphasized = false,
    this.color,
  });

  final String label;
  final String value;
  final bool emphasized;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final style = emphasized
        ? Theme.of(context).textTheme.titleMedium
        : Theme.of(context).textTheme.bodyMedium;

    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.xs),
      child: Row(
        children: [
          Expanded(child: Text(label)),
          Text(
            value,
            style: style?.copyWith(
              fontWeight: emphasized ? FontWeight.w700 : FontWeight.w500,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
