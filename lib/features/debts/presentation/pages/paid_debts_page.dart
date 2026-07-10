import 'package:flutter/material.dart';

import '../../../../app/di/injection_container.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_tokens.dart';
import '../../../../core/errors/failures.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../../shared/components/empty_list_placeholder.dart';
import '../../../../shared/enums/permission.dart';
import '../../../../shared/guards/permission_guard.dart';
import '../../../auth/domain/entities/auth_entities.dart';
import '../../domain/entities/debt_entities.dart';
import '../../domain/usecases/debt_usecases.dart';
import 'debt_detail_page.dart';

class PaidDebtsPage extends StatelessWidget {
  const PaidDebtsPage({super.key, required this.session});

  final AuthSession session;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Dettes remboursées'),
      ),
      body: PaidDebtsList(session: session),
    );
  }
}

class PaidDebtsList extends StatefulWidget {
  const PaidDebtsList({
    super.key,
    required this.session,
    this.customerId,
    this.customerName,
    this.initialDebts,
    this.refreshToken = 0,
    this.localOnly = false,
  });

  final AuthSession session;
  final int? customerId;
  final String? customerName;
  final List<Debt>? initialDebts;
  final int refreshToken;
  /// Si vrai, ne recharge que depuis la base locale (pas d'appel serveur).
  final bool localOnly;

  @override
  State<PaidDebtsList> createState() => _PaidDebtsListState();
}

class _PaidDebtsListState extends State<PaidDebtsList> {
  List<Debt> _debts = const [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    if (widget.initialDebts != null) {
      _debts = widget.initialDebts!;
      _loading = false;
    } else {
      _load();
    }
  }

  @override
  void didUpdateWidget(covariant PaidDebtsList oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialDebts != oldWidget.initialDebts &&
        widget.initialDebts != null) {
      setState(() {
        _debts = widget.initialDebts!;
        _loading = false;
        _error = null;
      });
      return;
    }
    if (widget.refreshToken != oldWidget.refreshToken) {
      _load();
    }
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final debts = await sl<ListPaidDebts>()(
        session: widget.session,
        customerId: widget.customerId,
      );
      if (!mounted) return;
      setState(() {
        _debts = debts;
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
        _error = 'Impossible de charger les dettes remboursées.';
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
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
    if (_debts.isEmpty) {
      return EmptyListPlaceholder.refreshable(
        icon: Icons.check_circle_outline,
        title: 'Aucune dette remboursée',
        onRefresh: _load,
      );
    }

    final canReadDebts = PermissionGuard.can(
      widget.session.user.permissions,
      Permission.debtsRead,
    );

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.builder(
        padding: const EdgeInsets.all(AppSpacing.md),
        itemCount: _debts.length,
        itemBuilder: (context, index) {
          final debt = _debts[index];
          return _PaidDebtCard(
            debt: debt,
            showCustomerName: widget.customerId == null,
            canReadDebts: canReadDebts,
            onTap: () => _openDetail(debt),
          );
        },
      ),
    );
  }

  Future<void> _openDetail(Debt debt) async {
    if (!PermissionGuard.can(
      widget.session.user.permissions,
      Permission.debtsRead,
    )) {
      return;
    }

    final customerName =
        debt.customerName ?? widget.customerName ?? 'Client';

    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => DebtDetailPage(
          session: widget.session,
          debtId: debt.id,
          customerName: customerName,
        ),
      ),
    );
  }
}

class _PaidDebtCard extends StatelessWidget {
  const _PaidDebtCard({
    required this.debt,
    required this.showCustomerName,
    required this.canReadDebts,
    required this.onTap,
  });

  final Debt debt;
  final bool showCustomerName;
  final bool canReadDebts;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final title = debt.receiptNumber != null
        ? 'Vente ${debt.receiptNumber}'
        : 'Dette #${debt.id}';

    return Card(
      child: InkWell(
        onTap: canReadDebts ? onTap : null,
        borderRadius: BorderRadius.circular(AppRadius.md),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      title,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                    if (showCustomerName && debt.customerName != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        debt.customerName!,
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ],
                    const SizedBox(height: 4),
                    Text(
                      'Montant remboursé · ${formatFcfa(debt.amountPaid)}',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    formatFcfa(debt.originalAmount),
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: AppColors.success,
                        ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    debt.status.label,
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: AppColors.success,
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                ],
              ),
              if (canReadDebts) ...[
                const SizedBox(width: AppSpacing.xs),
                Icon(
                  Icons.chevron_right,
                  color: Theme.of(context).colorScheme.outline,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
