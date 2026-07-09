import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../app/di/injection_container.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_tokens.dart';
import '../../../../core/errors/exception_mapper.dart';
import '../../../../core/errors/failures.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../../shared/components/empty_list_placeholder.dart';
import '../../../../shared/enums/permission.dart';
import '../../../../shared/guards/permission_guard.dart';
import '../../../audit/presentation/pages/audit_entity_history_page.dart';
import '../../../auth/domain/entities/auth_entities.dart';
import '../../../debts/domain/entities/debt_entities.dart';
import '../../../debts/domain/usecases/debt_usecases.dart';
import '../../../debts/presentation/pages/record_debt_payment_page.dart';
import '../../../sales/presentation/pages/sale_detail_page.dart';
import '../../../sales_analysis/presentation/widgets/customer_price_habits_section.dart';
import '../../domain/entities/customer_entities.dart';
import '../../domain/usecases/customer_usecases.dart';
import '../widgets/customer_debts_tab.dart';
import '../widgets/customer_feedback.dart';
import 'customer_form_page.dart';

class CustomerDetailPage extends StatefulWidget {
  const CustomerDetailPage({
    super.key,
    required this.session,
    required this.customerId,
  });

  final AuthSession session;
  final int customerId;

  @override
  State<CustomerDetailPage> createState() => _CustomerDetailPageState();
}

class _CustomerDetailPageState extends State<CustomerDetailPage>
    with SingleTickerProviderStateMixin {
  Customer? _customer;
  List<CustomerSaleSummary> _sales = const [];
  List<Debt> _debts = const [];
  bool _loading = true;
  bool _archiving = false;
  String? _error;
  late final TabController _tabController;

  bool get _canWrite => PermissionGuard.can(
        widget.session.user.permissions,
        Permission.customersWrite,
      );

  bool get _canArchive => PermissionGuard.can(
        widget.session.user.permissions,
        Permission.customersArchive,
      );

  bool get _canPayDebt =>
      PermissionGuard.can(widget.session.user.permissions, Permission.debtsPayment) &&
      PermissionGuard.can(widget.session.user.permissions, Permission.paymentsCreate);

  bool get _canViewAudit => PermissionGuard.can(
        widget.session.user.permissions,
        Permission.auditRead,
      );

  bool get _canViewSales => PermissionGuard.can(
        widget.session.user.permissions,
        Permission.salesRead,
      );

  bool get _isHomeShop =>
      _customer != null && _customer!.shopId == widget.session.shop.id;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _load();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final detail = await sl<GetCustomer>()(
        session: widget.session,
        customerId: widget.customerId,
      );
      if (!mounted) return;
      setState(() {
        _customer = detail.customer;
        _sales = detail.sales;
        _debts = detail.debts;
        _loading = false;
      });
    } on Failure catch (e) {
      if (!mounted) return;
      setState(() {
        _error = friendlyErrorMessage(e);
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'Impossible de charger le client.';
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final customer = _customer;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Fiche client'),
        actions: [
          if (_canWrite && customer != null && !customer.isArchived && _isHomeShop)
            IconButton(
              icon: const Icon(Icons.edit_outlined),
              onPressed: _edit,
            ),
          if (_canArchive && customer != null && !customer.isArchived && _isHomeShop)
            IconButton(
              icon: _archiving
                  ? CustomerFeedback.inlineLoader(size: 18)
                  : const Icon(Icons.archive_outlined),
              onPressed: _archiving ? null : _archive,
            ),
        ],
      ),
      body: _buildBody(),
      floatingActionButton: _buildFab(),
    );
  }

  Widget? _buildFab() {
    final customer = _customer;
    if (customer == null || _loading || _error != null) return null;
    if (customer.hasDebt && _canPayDebt) {
      return FloatingActionButton.extended(
        onPressed: _recordPayment,
        icon: const Icon(Icons.payments_outlined),
        label: const Text('Enregistrer un paiement'),
      );
    }
    if (customer.hasDebt && customer.phone != null) {
      return FloatingActionButton.extended(
        onPressed: _sendReminder,
        icon: const Icon(Icons.chat_outlined),
        label: const Text('Rappel WhatsApp'),
      );
    }
    return null;
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: AppSpacing.md),
            Text('Chargement du client…'),
          ],
        ),
      );
    }
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(_error!, textAlign: TextAlign.center),
              const SizedBox(height: AppSpacing.md),
              FilledButton(onPressed: _load, child: const Text('Réessayer')),
            ],
          ),
        ),
      );
    }

    final customer = _customer!;

    return Column(
      children: [
        _buildHeader(customer),
        _buildBalanceCard(customer),
        TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Achats'),
            Tab(text: 'Dettes'),
            Tab(text: 'Infos'),
          ],
        ),
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [
              _buildPurchasesTab(),
              CustomerDebtsTab(
                session: widget.session,
                customerId: widget.customerId,
                customerName: customer.name,
                initialDebts: _debts,
                onUpdated: _load,
              ),
              _buildInfosTab(customer),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildHeader(Customer customer) {
    final initials = customer.name
        .trim()
        .split(RegExp(r'\s+'))
        .where((p) => p.isNotEmpty)
        .take(2)
        .map((p) => p[0].toUpperCase())
        .join();

    return Card(
      margin: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.md,
        AppSpacing.md,
        AppSpacing.sm,
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CircleAvatar(
              radius: 32,
              backgroundColor:
                  Theme.of(context).colorScheme.primaryContainer,
              child: Text(
                initials.isEmpty ? '?' : initials,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      color: Theme.of(context).colorScheme.onPrimaryContainer,
                      fontWeight: FontWeight.w700,
                    ),
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    customer.name,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  if (customer.isFromOtherShop(widget.session.shop.id))
                    Text(
                      'Client partagé',
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            color: Theme.of(context).colorScheme.primary,
                          ),
                    ),
                  if (customer.phone != null) ...[
                    const SizedBox(height: AppSpacing.xs),
                    Row(
                      children: [
                        const Icon(Icons.phone_outlined, size: 16),
                        const SizedBox(width: AppSpacing.xs),
                        Expanded(child: Text(customer.phone!)),
                      ],
                    ),
                  ],
                  if (customer.address != null &&
                      customer.address!.trim().isNotEmpty) ...[
                    const SizedBox(height: AppSpacing.xs),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.location_on_outlined, size: 16),
                        const SizedBox(width: AppSpacing.xs),
                        Expanded(child: Text(customer.address!)),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBalanceCard(Customer customer) {
    if (!customer.hasDebt) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
      child: Card(
        color: customer.isCriticalDebt
            ? AppColors.danger.withValues(alpha: 0.08)
            : AppColors.warning.withValues(alpha: 0.08),
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
                      'Solde dû',
                      style: Theme.of(context).textTheme.labelLarge,
                    ),
                    Text(
                      formatFcfa(customer.balanceDue),
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                            color: customer.isCriticalDebt
                                ? AppColors.danger
                                : AppColors.warning,
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                    Text(
                      '${customer.openDebtsCount} dette(s) ouverte(s)',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              if (_canPayDebt)
                FilledButton.icon(
                  onPressed: _recordPayment,
                  style: FilledButton.styleFrom(
                    minimumSize: const Size(0, 44),
                  ),
                  icon: const Icon(Icons.payments_outlined),
                  label: const Text('Payer'),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPurchasesTab() {
    if (_sales.isEmpty) {
      return RefreshIndicator(
        onRefresh: _load,
        child: EmptyListPlaceholder(
          embedded: true,
          icon: Icons.receipt_long_outlined,
          title: 'Aucune vente enregistrée pour ce client',
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.builder(
        padding: const EdgeInsets.all(AppSpacing.md),
        itemCount: _sales.length,
        itemBuilder: (context, index) {
          final sale = _sales[index];
          return Card(
            child: InkWell(
              onTap: _canViewSales
                  ? () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => SaleDetailPage(
                            session: widget.session,
                            saleId: sale.id,
                          ),
                        ),
                      )
                  : null,
              borderRadius: BorderRadius.circular(12),
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
                            sale.receiptNumber ?? 'Vente #${sale.id}',
                            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            [
                              _formatDate(sale.createdAt),
                              if (sale.shopName != null) sale.shopName,
                            ].join(' · '),
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Text(
                      formatFcfa(sale.totalAmount),
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                    if (_canViewSales) ...[
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
        },
      ),
    );
  }

  Widget _buildInfosTab(Customer customer) {
    final lastVisit = customer.lifetimeLastActivityAt ?? customer.lastActivityAt;

    return ListView(
      padding: const EdgeInsets.all(AppSpacing.md),
      children: [
        if (customer.phoneWarning != null)
          Card(
            color: AppColors.warning.withValues(alpha: 0.1),
            child: ListTile(
              leading: const Icon(Icons.warning_amber_outlined),
              title: Text(customer.phoneWarning!),
            ),
          ),
        if (customer.isShared)
          Card(
            color: Theme.of(context).colorScheme.primaryContainer.withValues(
                  alpha: 0.35,
                ),
            child: const ListTile(
              leading: Icon(Icons.share_outlined),
              title: Text('Client partagé'),
              subtitle: Text(
                'Visible dans toutes les boutiques du même patron.',
              ),
            ),
          ),
        _InfoCard(
          title: 'Coordonnées',
          children: [
            _InfoRow(label: 'Nom', value: customer.name),
            _InfoRow(label: 'Téléphone', value: customer.phone ?? '—'),
            _InfoRow(
              label: 'Adresse',
              value: customer.address?.trim().isNotEmpty == true
                  ? customer.address!
                  : '—',
            ),
            if (customer.note != null && customer.note!.isNotEmpty)
              _InfoRow(label: 'Note', value: customer.note!),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        _InfoCard(
          title: 'Statistiques (cette boutique)',
          children: [
            _InfoRow(
              label: 'Solde dû',
              value: formatFcfa(customer.balanceDue),
              emphasized: customer.hasDebt,
              danger: customer.isCriticalDebt,
            ),
            _InfoRow(
              label: 'Dettes ouvertes',
              value: '${customer.openDebtsCount}',
            ),
            _InfoRow(
              label: 'Achats',
              value:
                  '${customer.purchaseCount} · ${formatFcfa(customer.totalPurchases)}',
            ),
            _InfoRow(
              label: 'Dernière visite',
              value: customer.lastActivityAt != null
                  ? _formatDate(customer.lastActivityAt!)
                  : '—',
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        _InfoCard(
          title: 'Toutes les boutiques (lifetime)',
          children: [
            _InfoRow(
              label: 'Achats totaux',
              value:
                  '${customer.lifetimePurchaseCount} · ${formatFcfa(customer.lifetimeTotalPurchases)}',
            ),
            _InfoRow(
              label: 'Dernière visite',
              value: lastVisit != null ? _formatDate(lastVisit) : '—',
            ),
          ],
        ),
        if (_canViewSales) ...[
          const SizedBox(height: AppSpacing.lg),
          CustomerPriceHabitsSection(
            session: widget.session,
            customerId: widget.customerId,
          ),
        ],
        if (_canViewAudit) ...[
          const SizedBox(height: AppSpacing.md),
          Card(
            child: ListTile(
              leading: const Icon(Icons.history_outlined),
              title: const Text('Historique d\'audit'),
              subtitle: const Text('Modifications et actions sur ce client'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => AuditEntityHistoryPage(
                    session: widget.session,
                    entityTable: 'customers',
                    entityId: widget.customerId,
                  ),
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }

  String _formatDate(int ms) {
    final dt = DateTime.fromMillisecondsSinceEpoch(ms);
    return '${dt.day.toString().padLeft(2, '0')}/'
        '${dt.month.toString().padLeft(2, '0')}/'
        '${dt.year}';
  }

  Future<void> _recordPayment() async {
    try {
      final debts = await sl<ListCustomerDebts>()(
        session: widget.session,
        customerId: widget.customerId,
        openOnly: true,
      );
      if (!mounted || debts.isEmpty) {
        if (mounted) _tabController.animateTo(1);
        return;
      }

      final Debt debt;
      if (debts.length == 1) {
        debt = debts.first;
      } else {
        final picked = await showDialog<Debt>(
          context: context,
          builder: (ctx) => SimpleDialog(
            title: const Text('Choisir une dette'),
            children: [
              for (final d in debts)
                SimpleDialogOption(
                  onPressed: () => Navigator.pop(ctx, d),
                  child: Text(
                    '${d.receiptNumber ?? 'Dette #${d.id}'} — '
                    '${formatFcfa(d.amountRemaining)}',
                  ),
                ),
            ],
          ),
        );
        if (picked == null || !mounted) return;
        debt = picked;
      }

      final paid = await Navigator.of(context).push<bool>(
        MaterialPageRoute(
          builder: (_) => RecordDebtPaymentPage(
            session: widget.session,
            debt: debt,
            customerName: _customer?.name ?? '',
          ),
        ),
      );
      if (paid == true && mounted) await _load();
    } on Failure catch (e) {
      if (!mounted) return;
      await CustomerFeedback.showErrorDialog(
        context,
        title: 'Paiement impossible',
        message: friendlyErrorMessage(e),
      );
    }
  }

  Future<void> _edit() async {
    final updated = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => CustomerFormPage(
          session: widget.session,
          customer: _customer,
        ),
      ),
    );
    if (updated == true && mounted) {
      await _load();
    }
  }

  Future<void> _archive() async {
    final confirmed = await CustomerFeedback.confirm(
      context: context,
      title: 'Archiver ce client ?',
      message:
          'Le client sera masqué des listes actives. '
          'L\'historique des ventes et dettes est conservé.',
      confirmLabel: 'Archiver',
      isDestructive: true,
    );
    if (confirmed != true || !mounted) return;

    setState(() => _archiving = true);
    try {
      await sl<ArchiveCustomer>()(
        session: widget.session,
        customerId: widget.customerId,
      );
      if (!mounted) return;
      await CustomerFeedback.showSuccess(
        context: context,
        title: 'Client archivé',
        message: 'Le client a été masqué des listes actives.',
      );
      if (mounted) Navigator.of(context).pop(true);
    } on Failure catch (e) {
      if (!mounted) return;
      await CustomerFeedback.showErrorDialog(
        context,
        title: 'Archivage impossible',
        message: friendlyErrorMessage(e),
      );
    } catch (_) {
      if (!mounted) return;
      await CustomerFeedback.showErrorDialog(
        context,
        title: 'Archivage impossible',
        message: 'Impossible d\'archiver ce client.',
      );
    } finally {
      if (mounted) setState(() => _archiving = false);
    }
  }

  Future<void> _sendReminder() async {
    final customer = _customer;
    if (customer == null) return;

    try {
      final reminder = await sl<GetDebtReminder>()(
        session: widget.session,
        customerId: widget.customerId,
      );

      final messageController = TextEditingController(text: reminder.message);
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Message WhatsApp'),
          content: SingleChildScrollView(
            child: TextField(
              controller: messageController,
              decoration: const InputDecoration(
                labelText: 'Message',
                border: OutlineInputBorder(),
              ),
              maxLines: 5,
              autofocus: true,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Annuler'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Envoyer'),
            ),
          ],
        ),
      );
      if (confirmed != true || !mounted) {
        messageController.dispose();
        return;
      }

      final message = messageController.text.trim();
      messageController.dispose();

      if (message.isEmpty) {
        await CustomerFeedback.showErrorDialog(
          context,
          title: 'Message vide',
          message: 'Saisissez un message avant d\'ouvrir WhatsApp.',
        );
        return;
      }

      final digits = reminder.whatsappUrl.contains('wa.me/')
          ? reminder.whatsappUrl.split('wa.me/').last.split('?').first
          : null;
      final uri = digits != null
          ? Uri.parse(
              'https://wa.me/$digits?text=${Uri.encodeComponent(message)}',
            )
          : Uri.parse(reminder.whatsappUrl);

      if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
        throw const ValidationFailure('Impossible d\'ouvrir WhatsApp.');
      }
    } on Failure catch (e) {
      if (!mounted) return;
      await CustomerFeedback.showErrorDialog(
        context,
        title: 'Rappel impossible',
        message: friendlyErrorMessage(e),
      );
    } catch (_) {
      if (!mounted) return;
      await CustomerFeedback.showErrorDialog(
        context,
        title: 'Rappel impossible',
        message: 'Impossible d\'ouvrir WhatsApp.',
      );
    }
  }
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: AppSpacing.sm),
            ...children,
          ],
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.label,
    required this.value,
    this.emphasized = false,
    this.danger = false,
  });

  final String label;
  final String value;
  final bool emphasized;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    final style = emphasized
        ? Theme.of(context).textTheme.titleMedium?.copyWith(
              color: danger ? AppColors.danger : null,
              fontWeight: FontWeight.w600,
            )
        : Theme.of(context).textTheme.bodyMedium;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
      child: Row(
        children: [
          Expanded(child: Text(label)),
          Text(value, style: style),
        ],
      ),
    );
  }
}
