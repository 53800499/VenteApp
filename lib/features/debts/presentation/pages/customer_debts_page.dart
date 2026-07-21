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
import 'forgiven_debts_page.dart';
import 'paid_debts_page.dart';
import '../../../help/presentation/widgets/module_help_button.dart';

class CustomerDebtsPage extends StatefulWidget {
  const CustomerDebtsPage({
    super.key,
    required this.session,
    required this.customerId,
    required this.customerName,
  });

  final AuthSession session;
  final int customerId;
  final String customerName;

  @override
  State<CustomerDebtsPage> createState() => _CustomerDebtsPageState();
}

class _CustomerDebtsPageState extends State<CustomerDebtsPage>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  List<Debt> _openDebts = const [];
  bool _loadingOpen = true;
  String? _openError;
  int _debtsRefreshToken = 0;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
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
    return Scaffold(
      appBar: AppBar(
        title: Text('Dettes — ${widget.customerName}'),
        actions: const [ModuleHelpButton(articleId: 'debts')],
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Ouvertes'),
            Tab(text: 'Remboursées'),
            Tab(text: 'Pardonnées'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildOpenDebtsTab(),
          PaidDebtsList(
            session: widget.session,
            customerId: widget.customerId,
            customerName: widget.customerName,
            refreshToken: _debtsRefreshToken,
          ),
          ForgivenDebtsList(
            session: widget.session,
            customerId: widget.customerId,
            customerName: widget.customerName,
          ),
        ],
      ),
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
      return EmptyListPlaceholder.refreshable(
        icon: Icons.account_balance_wallet_outlined,
        title: 'Aucune dette ouverte pour ce client',
        onRefresh: _loadOpenDebts,
      );
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
      setState(() => _debtsRefreshToken++);
      if (mounted) Navigator.of(context).pop(true);
    }
  }
}
