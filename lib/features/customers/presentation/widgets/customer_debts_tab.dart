import 'package:flutter/material.dart';

import '../../../../app/di/injection_container.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_tokens.dart';
import '../../../../core/errors/failures.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../../shared/enums/permission.dart';
import '../../../../shared/guards/permission_guard.dart';
import '../../../auth/domain/entities/auth_entities.dart';
import '../../../debts/domain/entities/debt_entities.dart';
import '../../../debts/domain/usecases/debt_usecases.dart';
import '../../../debts/presentation/pages/debt_detail_page.dart';
import '../../../debts/presentation/pages/forgiven_debts_page.dart';

/// Onglet Dettes de la fiche client (ECR-08).
class CustomerDebtsTab extends StatefulWidget {
  const CustomerDebtsTab({
    super.key,
    required this.session,
    required this.customerId,
    required this.customerName,
    this.onUpdated,
  });

  final AuthSession session;
  final int customerId;
  final String customerName;
  final VoidCallback? onUpdated;

  @override
  State<CustomerDebtsTab> createState() => _CustomerDebtsTabState();
}

class _CustomerDebtsTabState extends State<CustomerDebtsTab>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  List<Debt> _openDebts = const [];
  bool _loadingOpen = true;
  String? _openError;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadOpenDebts();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadOpenDebts() async {
    setState(() {
      _loadingOpen = true;
      _openError = null;
    });
    try {
      final debts = await sl<ListCustomerDebts>()(
        session: widget.session,
        customerId: widget.customerId,
        openOnly: true,
      );
      if (!mounted) return;
      setState(() {
        _openDebts = debts;
        _loadingOpen = false;
      });
    } on Failure catch (e) {
      if (!mounted) return;
      setState(() {
        _openError = e.message;
        _loadingOpen = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _openError = 'Impossible de charger les dettes.';
        _loadingOpen = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Ouvertes'),
            Tab(text: 'Pardonnées'),
          ],
        ),
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [
              _buildOpenDebtsTab(),
              ForgivenDebtsList(
                session: widget.session,
                customerId: widget.customerId,
                customerName: widget.customerName,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildOpenDebtsTab() {
    if (_loadingOpen) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_openError != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(_openError!),
            const SizedBox(height: AppSpacing.md),
            FilledButton(
              onPressed: _loadOpenDebts,
              child: const Text('Réessayer'),
            ),
          ],
        ),
      );
    }
    if (_openDebts.isEmpty) {
      return const Center(child: Text('Aucune dette ouverte pour ce client.'));
    }

    return RefreshIndicator(
      onRefresh: _loadOpenDebts,
      child: ListView.builder(
        padding: const EdgeInsets.all(AppSpacing.md),
        itemCount: _openDebts.length,
        itemBuilder: (context, index) {
          final debt = _openDebts[index];
          return Card(
            child: ListTile(
              title: Text(
                debt.receiptNumber != null
                    ? 'Vente ${debt.receiptNumber}'
                    : 'Dette #${debt.id}',
              ),
              subtitle: Text(
                'Payé : ${formatFcfa(debt.amountPaid)} / '
                '${formatFcfa(debt.originalAmount)}',
              ),
              trailing: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    formatFcfa(debt.amountRemaining),
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: debt.isCritical
                          ? AppColors.danger
                          : AppColors.warning,
                    ),
                  ),
                  if (debt.isCritical)
                    const Text(
                      'Critique',
                      style: TextStyle(fontSize: 11, color: AppColors.danger),
                    ),
                ],
              ),
              onTap: () => _openDetail(debt),
            ),
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

    final updated = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => DebtDetailPage(
          session: widget.session,
          debtId: debt.id,
          customerName: widget.customerName,
        ),
      ),
    );
    if (updated == true && mounted) {
      await _loadOpenDebts();
      widget.onUpdated?.call();
    }
  }
}
