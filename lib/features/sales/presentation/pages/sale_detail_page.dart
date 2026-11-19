import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../app/di/injection_container.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_tokens.dart';
import '../../../../core/errors/exception_mapper.dart';
import '../../../../core/errors/failures.dart';
import '../../../../core/responsive/breakpoints.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../../core/utils/date_formatter.dart';
import '../../../../shared/components/app_header_actions.dart';
import '../../../../shared/enums/permission.dart';
import '../../../../shared/enums/user_role.dart';
import '../../../../shared/guards/permission_guard.dart';
import '../../../auth/domain/entities/auth_entities.dart';
import '../../../customers/domain/entities/customer_entities.dart';
import '../../../customers/domain/usecases/customer_usecases.dart';
import '../../../customers/presentation/pages/customer_detail_page.dart';
import '../../domain/entities/sale_entities.dart';
import '../../domain/usecases/sale_usecases.dart';
import '../widgets/sale_feedback.dart';
import 'new_sale_page.dart';
import 'sale_receipt_page.dart';
import 'sale_replacement_page.dart';

class SaleDetailPage extends StatefulWidget {
  const SaleDetailPage({
    super.key,
    required this.session,
    required this.saleId,
  });

  final AuthSession session;
  final int saleId;

  @override
  State<SaleDetailPage> createState() => _SaleDetailPageState();
}

class _SaleDetailPageState extends State<SaleDetailPage> {
  Sale? _sale;
  Customer? _customer;
  List<SaleReplacement> _replacements = const [];
  String? _error;
  bool _loading = true;
  bool _cancelling = false;

  bool get _canCancel =>
      widget.session.user.role == UserRole.owner &&
      PermissionGuard.can(
        widget.session.user.permissions,
        Permission.salesCancel,
      );

  bool get _canReplace => PermissionGuard.can(
        widget.session.user.permissions,
        Permission.salesCreate,
      );

  bool get _canConvert => PermissionGuard.can(
        widget.session.user.permissions,
        Permission.salesCreate,
      );

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _refreshSale() async {
    try {
      final sale = await sl<GetSale>()(
        session: widget.session,
        saleId: widget.saleId,
      );

      Customer? customer;
      if (sale.customerId != null) {
        try {
          final detail = await sl<GetCustomer>()(
            session: widget.session,
            customerId: sale.customerId!,
          );
          customer = detail.customer;
        } catch (_) {
          // Si le profil client complet n'est pas résolu, le nom présent dans sale est utilisé
        }
      }

      final replacements = await sl<ListSaleReplacements>()(
        session: widget.session,
        saleId: widget.saleId,
      );

      if (mounted) {
        setState(() {
          _sale = sale;
          _customer = customer;
          _replacements = replacements;
          _error = null;
          _loading = false;
        });
      }
    } on Failure catch (e) {
      if (mounted) {
        setState(() {
          _error = friendlyErrorMessage(e);
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _error = 'Impossible de charger la vente.';
          _loading = false;
        });
      }
    }
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    await _refreshSale();
  }

  Future<void> _cancel() async {
    final reason = await SaleFeedback.confirmWithReason(
      context: context,
      title: 'Annuler la vente',
      hint: 'Motif (min. 5 caractères)',
      confirmLabel: 'Annuler la vente',
    );
    if (reason == null || !mounted) return;

    setState(() => _cancelling = true);
    try {
      await sl<CancelSale>()(
        session: widget.session,
        saleId: widget.saleId,
        reason: reason,
      );

      if (!mounted) return;
      await SaleFeedback.showSuccess(
        context: context,
        title: 'Vente annulée',
        message: 'La vente a été annulée avec succès.',
      );
      if (mounted) await _refreshSale();
    } on Failure catch (e) {
      if (mounted) {
        await SaleFeedback.showErrorDialog(
          context,
          title: 'Annulation impossible',
          message: e.message,
        );
      }
    } catch (_) {
      if (mounted) {
        await SaleFeedback.showErrorDialog(
          context,
          title: 'Annulation impossible',
          message: 'Échec de l\'annulation.',
        );
      }
    } finally {
      if (mounted) setState(() => _cancelling = false);
    }
  }

  Future<void> _callPhone(String phone) async {
    final clean = phone.replaceAll(RegExp(r'\s+'), '');
    final uri = Uri.parse('tel:$clean');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Impossible d\'appeler le $phone')),
      );
    }
  }

  void _copyToClipboard(String text, String label) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$label copié dans le presse-papier'),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Détail de la vente'),
        actions: [
          if (_sale != null)
            IconButton(
              icon: const Icon(Icons.receipt_long_outlined),
              tooltip: 'Voir le reçu',
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => SaleReceiptPage(
                    session: widget.session,
                    sale: _sale!,
                  ),
                ),
              ),
            ),
          const AppHeaderActions(),
        ],
      ),
      body: _loading
          ? const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: AppSpacing.md),
                  Text('Chargement de la transaction…'),
                ],
              ),
            )
          : _error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(AppSpacing.lg),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
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
              : _buildResponsiveContent(context, _sale!),
    );
  }

  Widget _buildResponsiveContent(BuildContext context, Sale sale) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isDesktop = Breakpoints.useDataTable(constraints.maxWidth);

        if (isDesktop) {
          return SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Colonne de gauche (60%) : En-tête, Articles vendus, Remplacements
                Expanded(
                  flex: 3,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _buildHeaderCard(sale, context),
                      const SizedBox(height: AppSpacing.md),
                      _buildItemsSection(sale, context, isDesktop: true),
                      if (_replacements.isNotEmpty) ...[
                        const SizedBox(height: AppSpacing.md),
                        _buildReplacementsSection(_replacements, context),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: AppSpacing.lg),
                // Colonne de droite (40%) : Client attaché, Encaissement, Actions
                Expanded(
                  flex: 2,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _buildCustomerCard(sale, _customer, context),
                      const SizedBox(height: AppSpacing.md),
                      _buildFinancialSummary(sale, context),
                      const SizedBox(height: AppSpacing.md),
                      _buildActionButtons(sale, context),
                    ],
                  ),
                ),
              ],
            ),
          );
        }

        // Vue Mobile & Tablettes étroites
        return ListView(
          padding: const EdgeInsets.all(AppSpacing.md),
          children: [
            _buildHeaderCard(sale, context),
            const SizedBox(height: AppSpacing.md),
            _buildCustomerCard(sale, _customer, context),
            const SizedBox(height: AppSpacing.md),
            _buildItemsSection(sale, context, isDesktop: false),
            const SizedBox(height: AppSpacing.md),
            _buildFinancialSummary(sale, context),
            if (_replacements.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.md),
              _buildReplacementsSection(_replacements, context),
            ],
            const SizedBox(height: AppSpacing.lg),
            _buildActionButtons(sale, context),
            const SizedBox(height: AppSpacing.xl),
          ],
        );
      },
    );
  }

  /// Carte d'en-tête : Référence complète, Statut, Date et Heure
  Widget _buildHeaderCard(Sale sale, BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final dt = DateTime.fromMillisecondsSinceEpoch(sale.createdAt);
    final dateStr = AppDateFormatter.formatDateTime(dt);
    final receipt = sale.receiptNumber ?? '#${sale.id}';

    final isQuick = sale.saleType == SaleType.quick;
    final isCancelled = sale.isCancelled;

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.md),
        side: BorderSide(color: scheme.outlineVariant.withValues(alpha: 0.6)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Badges de statut et type de vente
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.xs,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                // Badge Type de vente
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: isQuick
                        ? const Color(0xFFF59E0B).withValues(alpha: 0.15)
                        : scheme.primaryContainer.withValues(alpha: 0.4),
                    borderRadius: BorderRadius.circular(AppRadius.sm),
                    border: Border.all(
                      color: isQuick
                          ? const Color(0xFFF59E0B).withValues(alpha: 0.5)
                          : scheme.primary.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        isQuick ? Icons.flash_on_rounded : Icons.shopping_bag_outlined,
                        size: 14,
                        color: isQuick ? const Color(0xFFD97706) : scheme.primary,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        isQuick ? 'Vente Rapide' : 'Vente Standard',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: isQuick ? const Color(0xFFB45309) : scheme.primary,
                        ),
                      ),
                    ],
                  ),
                ),
                // Badge Statut
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: isCancelled
                        ? scheme.errorContainer.withValues(alpha: 0.4)
                        : const Color(0xFF10B981).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(AppRadius.sm),
                    border: Border.all(
                      color: isCancelled
                          ? scheme.error.withValues(alpha: 0.4)
                          : const Color(0xFF10B981).withValues(alpha: 0.5),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        isCancelled ? Icons.cancel_outlined : Icons.check_circle_outline_rounded,
                        size: 14,
                        color: isCancelled ? scheme.error : const Color(0xFF059669),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        isCancelled ? 'Annulée' : 'Complétée',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: isCancelled ? scheme.error : const Color(0xFF047857),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),

            // Référence de vente intégrale avec copie
            Text(
              'Référence de la vente',
              style: theme.textTheme.bodySmall?.copyWith(
                color: AppColors.onSurfaceMuted,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 2),
            Row(
              children: [
                Expanded(
                  child: SelectableText(
                    receipt,
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.3,
                      decoration: isCancelled ? TextDecoration.lineThrough : null,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.copy_rounded, size: 20),
                  tooltip: 'Copier la référence',
                  onPressed: () => _copyToClipboard(receipt, 'N° de reçu'),
                ),
              ],
            ),

            const SizedBox(height: AppSpacing.xs),
            // Horodatage
            Row(
              children: [
                Icon(Icons.calendar_today_outlined, size: 14, color: AppColors.onSurfaceMuted),
                const SizedBox(width: 6),
                Text(
                  dateStr,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: AppColors.onSurfaceMuted,
                    fontSize: 13,
                  ),
                ),
              ],
            ),

            if (isCancelled) ...[
              const SizedBox(height: AppSpacing.md),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(AppSpacing.sm),
                decoration: BoxDecoration(
                  color: scheme.errorContainer.withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                  border: Border.all(color: scheme.error.withValues(alpha: 0.3)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Motif d\'annulation :',
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: scheme.error,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      sale.cancelReason ?? 'Aucun motif renseigné',
                      style: theme.textTheme.bodyMedium?.copyWith(color: scheme.onErrorContainer),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// Carte Client Attaché : Profil complet, téléphone, solde dû et lien direct
  Widget _buildCustomerCard(Sale sale, Customer? customer, BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final hasCustomer = sale.customerId != null || customer != null || (sale.customerName?.isNotEmpty ?? false);
    final name = customer?.name ?? sale.customerName ?? 'Client inconnu';
    final phone = customer?.phone;
    final balanceDue = customer?.balanceDue ?? 0;

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.md),
        side: BorderSide(color: scheme.outlineVariant.withValues(alpha: 0.6)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.person_outline_rounded, color: scheme.primary, size: 20),
                const SizedBox(width: 8),
                Text(
                  'Client rattaché',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.2,
                  ),
                ),
                const Spacer(),
                if (sale.customerId != null)
                  TextButton.icon(
                    style: TextButton.styleFrom(
                      visualDensity: VisualDensity.compact,
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                    ),
                    icon: const Icon(Icons.open_in_new_rounded, size: 15),
                    label: const Text('Fiche client'),
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => CustomerDetailPage(
                          session: widget.session,
                          customerId: sale.customerId!,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const Divider(height: 16),
            if (!hasCustomer)
              Row(
                children: [
                  CircleAvatar(
                    radius: 20,
                    backgroundColor: scheme.surfaceContainerHighest,
                    child: Icon(Icons.person_off_outlined, color: AppColors.onSurfaceMuted),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Client au comptoir',
                          style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
                        ),
                        Text(
                          'Vente de passage sans compte client attaché.',
                          style: theme.textTheme.bodySmall?.copyWith(color: AppColors.onSurfaceMuted),
                        ),
                      ],
                    ),
                  ),
                ],
              )
            else
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 22,
                        backgroundColor: scheme.primaryContainer,
                        child: Text(
                          name.isNotEmpty ? name[0].toUpperCase() : 'C',
                          style: TextStyle(
                            color: scheme.onPrimaryContainer,
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                          ),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              name,
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            if (phone != null && phone.isNotEmpty) ...[
                              const SizedBox(height: 2),
                              Row(
                                children: [
                                  Icon(Icons.phone_outlined, size: 14, color: scheme.primary),
                                  const SizedBox(width: 4),
                                  Text(
                                    phone,
                                    style: theme.textTheme.bodyMedium?.copyWith(
                                      fontWeight: FontWeight.w500,
                                      color: scheme.onSurface,
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  InkWell(
                                    onTap: () => _callPhone(phone),
                                    child: Icon(Icons.call, size: 16, color: scheme.primary),
                                  ),
                                  const SizedBox(width: 8),
                                  InkWell(
                                    onTap: () => _copyToClipboard(phone, 'Numéro de téléphone'),
                                    child: Icon(Icons.copy, size: 14, color: AppColors.onSurfaceMuted),
                                  ),
                                ],
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                  if (customer?.address != null && customer!.address!.isNotEmpty) ...[
                    const SizedBox(height: AppSpacing.sm),
                    Row(
                      children: [
                        Icon(Icons.location_on_outlined, size: 14, color: AppColors.onSurfaceMuted),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            customer.address!,
                            style: theme.textTheme.bodySmall?.copyWith(color: AppColors.onSurfaceMuted),
                          ),
                        ),
                      ],
                    ),
                  ],
                  const SizedBox(height: AppSpacing.sm),
                  // État des dettes du client
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: 8),
                    decoration: BoxDecoration(
                      color: balanceDue > 0
                          ? const Color(0xFFF59E0B).withValues(alpha: 0.12)
                          : const Color(0xFF10B981).withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(AppRadius.sm),
                      border: Border.all(
                        color: balanceDue > 0
                            ? const Color(0xFFF59E0B).withValues(alpha: 0.4)
                            : const Color(0xFF10B981).withValues(alpha: 0.4),
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          balanceDue > 0 ? Icons.error_outline_rounded : Icons.check_circle_outline_rounded,
                          size: 16,
                          color: balanceDue > 0 ? const Color(0xFFD97706) : const Color(0xFF059669),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            balanceDue > 0
                                ? 'Dette globale en cours : ${formatFcfa(balanceDue)}'
                                : 'Compte client à jour (aucune dette)',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: balanceDue > 0 ? const Color(0xFFB45309) : const Color(0xFF047857),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  /// Section des articles vendus
  Widget _buildItemsSection(Sale sale, BuildContext context, {required bool isDesktop}) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    if (sale.saleType == SaleType.quick && sale.items.isEmpty) {
      return Card(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          side: BorderSide(color: scheme.outlineVariant.withValues(alpha: 0.6)),
        ),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFFF59E0B).withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.flash_on_rounded, color: Color(0xFFD97706), size: 24),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Vente directe rapide',
                      style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Montant forfaitaire encaissé sans ventilation produit ni déstockage unitaire.',
                      style: theme.textTheme.bodySmall?.copyWith(color: AppColors.onSurfaceMuted),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.md),
        side: BorderSide(color: scheme.outlineVariant.withValues(alpha: 0.6)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.inventory_2_outlined, color: scheme.primary, size: 20),
                const SizedBox(width: 8),
                Text(
                  'Articles vendus (${sale.items.length})',
                  style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
                ),
              ],
            ),
            const Divider(height: 20),
            if (isDesktop) ...[
              // En-tête de tableau pour Desktop
              Container(
                padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                decoration: BoxDecoration(
                  color: scheme.surfaceContainerHighest.withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                ),
                child: Row(
                  children: [
                    const Expanded(
                      flex: 4,
                      child: Text('Désignation', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                    ),
                    const Expanded(
                      flex: 2,
                      child: Text('P.U.', textAlign: TextAlign.right, style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                    ),
                    const Expanded(
                      flex: 2,
                      child: Text('Qté', textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                    ),
                    if (sale.discountAmount > 0 || sale.items.any((i) => i.discountAmount > 0))
                      const Expanded(
                        flex: 2,
                        child: Text('Remise', textAlign: TextAlign.right, style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                      ),
                    const Expanded(
                      flex: 3,
                      child: Text('Total', textAlign: TextAlign.right, style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 4),
              ...sale.items.map((item) {
                final qtyStr = item.quantity % 1 == 0 ? item.quantity.toInt().toString() : item.quantity.toString();
                return Container(
                  padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                  decoration: BoxDecoration(
                    border: Border(bottom: BorderSide(color: scheme.outlineVariant.withValues(alpha: 0.3))),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        flex: 4,
                        child: Text(
                          item.productName,
                          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                        ),
                      ),
                      Expanded(
                        flex: 2,
                        child: Text(
                          formatFcfa(item.unitPrice),
                          textAlign: TextAlign.right,
                          style: TextStyle(color: AppColors.onSurfaceMuted, fontSize: 13),
                        ),
                      ),
                      Expanded(
                        flex: 2,
                        child: Text(
                          qtyStr,
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                        ),
                      ),
                      if (sale.discountAmount > 0 || sale.items.any((i) => i.discountAmount > 0))
                        Expanded(
                          flex: 2,
                          child: Text(
                            item.discountAmount > 0 ? '-${formatFcfa(item.discountAmount)}' : '-',
                            textAlign: TextAlign.right,
                            style: TextStyle(
                              color: item.discountAmount > 0 ? const Color(0xFF10B981) : AppColors.onSurfaceMuted,
                              fontSize: 13,
                              fontWeight: item.discountAmount > 0 ? FontWeight.bold : FontWeight.normal,
                            ),
                          ),
                        ),
                      Expanded(
                        flex: 3,
                        child: Text(
                          formatFcfa(item.lineTotal),
                          textAlign: TextAlign.right,
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            color: scheme.primary,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }),
            ] else ...[
              // Liste de cartes pour Mobile
              ...sale.items.map((item) {
                final qtyStr = item.quantity % 1 == 0 ? item.quantity.toInt().toString() : item.quantity.toString();
                return Container(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  decoration: BoxDecoration(
                    border: Border(bottom: BorderSide(color: scheme.outlineVariant.withValues(alpha: 0.3))),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: scheme.primaryContainer.withValues(alpha: 0.5),
                          borderRadius: BorderRadius.circular(AppRadius.sm),
                        ),
                        child: Text(
                          '×$qtyStr',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                            color: scheme.onPrimaryContainer,
                          ),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              item.productName,
                              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                            ),
                            Text(
                              '${formatFcfa(item.unitPrice)} l\'unité',
                              style: TextStyle(color: AppColors.onSurfaceMuted, fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            formatFcfa(item.lineTotal),
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              color: scheme.primary,
                              fontSize: 14,
                            ),
                          ),
                          if (item.discountAmount > 0)
                            Text(
                              'Remise -${formatFcfa(item.discountAmount)}',
                              style: const TextStyle(
                                color: Color(0xFF10B981),
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                );
              }),
            ],
          ],
        ),
      ),
    );
  }

  /// Récapitulatif financier et règlement
  Widget _buildFinancialSummary(Sale sale, BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.md),
        side: BorderSide(color: scheme.outlineVariant.withValues(alpha: 0.6)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.payments_outlined, color: scheme.primary, size: 20),
                const SizedBox(width: 8),
                Text(
                  'Règlement & Encaissement',
                  style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
                ),
              ],
            ),
            const Divider(height: 20),
            _buildAmountRow('Sous-total', formatFcfa(sale.subtotal)),
            if (sale.discountAmount > 0) ...[
              const SizedBox(height: 6),
              _buildAmountRow(
                'Remise globale',
                '-${formatFcfa(sale.discountAmount)}',
                color: const Color(0xFF10B981),
              ),
            ],
            const Divider(height: 16),
            _buildAmountRow(
              'Total net à payer',
              formatFcfa(sale.totalAmount),
              isBold: true,
              fontSize: 17,
              color: scheme.primary,
            ),
            const SizedBox(height: AppSpacing.md),

            // Mode de paiement principal
            Container(
              padding: const EdgeInsets.all(AppSpacing.sm),
              decoration: BoxDecoration(
                color: scheme.surfaceContainerHighest.withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(AppRadius.sm),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      Icon(Icons.credit_card_rounded, size: 16, color: scheme.primary),
                      const SizedBox(width: 8),
                      Text(
                        'Mode principal :',
                        style: TextStyle(color: AppColors.onSurfaceMuted, fontSize: 13),
                      ),
                      const Spacer(),
                      Text(
                        sale.paymentMethod.label,
                        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                      ),
                    ],
                  ),
                  if (sale.amountCash > 0) ...[
                    const SizedBox(height: 6),
                    _buildSubPaymentRow('Espèces', formatFcfa(sale.amountCash)),
                  ],
                  if (sale.amountMomo > 0) ...[
                    const SizedBox(height: 6),
                    _buildSubPaymentRow('Mobile Money', formatFcfa(sale.amountMomo)),
                  ],
                  if (sale.amountCredit > 0) ...[
                    const SizedBox(height: 6),
                    _buildSubPaymentRow(
                      'Crédit / Dette',
                      formatFcfa(sale.amountCredit),
                      color: const Color(0xFFD97706),
                      isBold: true,
                    ),
                  ],
                ],
              ),
            ),

            if (sale.note != null && sale.note!.trim().isNotEmpty) ...[
              const SizedBox(height: AppSpacing.md),
              Text(
                'Note / Remarque :',
                style: theme.textTheme.labelMedium?.copyWith(color: AppColors.onSurfaceMuted),
              ),
              const SizedBox(height: 2),
              Text(sale.note!, style: theme.textTheme.bodyMedium),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildAmountRow(
    String label,
    String value, {
    bool isBold = false,
    double fontSize = 14,
    Color? color,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontWeight: isBold ? FontWeight.w700 : FontWeight.w500,
            fontSize: fontSize,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontWeight: isBold ? FontWeight.w800 : FontWeight.w600,
            fontSize: fontSize,
            color: color,
          ),
        ),
      ],
    );
  }

  Widget _buildSubPaymentRow(String label, String value, {Color? color, bool isBold = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(' · $label', style: TextStyle(fontSize: 12, color: AppColors.onSurfaceMuted)),
        Text(
          value,
          style: TextStyle(fontSize: 12, fontWeight: isBold ? FontWeight.bold : FontWeight.w600, color: color),
        ),
      ],
    );
  }

  /// Section des remplacements d'articles
  Widget _buildReplacementsSection(List<SaleReplacement> replacements, BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.md),
        side: BorderSide(color: scheme.outlineVariant.withValues(alpha: 0.6)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.swap_horiz_rounded, color: scheme.primary, size: 20),
                const SizedBox(width: 8),
                Text(
                  'Remplacements enregistrés (${replacements.length})',
                  style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
                ),
              ],
            ),
            const Divider(height: 16),
            ...replacements.map((rx) {
              final dt = DateTime.fromMillisecondsSinceEpoch(rx.replacedAt);
              final dateStr = AppDateFormatter.formatDateTime(dt);
              return Container(
                margin: const EdgeInsets.only(bottom: AppSpacing.sm),
                padding: const EdgeInsets.all(AppSpacing.sm),
                decoration: BoxDecoration(
                  color: scheme.surfaceContainerHighest.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(rx.number, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                        Text(dateStr, style: TextStyle(color: AppColors.onSurfaceMuted, fontSize: 12)),
                      ],
                    ),
                    const SizedBox(height: 4),
                    ...rx.items.map((i) => Padding(
                          padding: const EdgeInsets.only(top: 2),
                          child: Text(
                            '${i.returnedProductName ?? 'Produit'} (×${i.quantityReturned}) → ${i.issuedProductName ?? 'Produit'} (×${i.quantityIssued})',
                            style: theme.textTheme.bodySmall,
                          ),
                        )),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  /// Boîte d'actions : Reçu, Remplacement, Conversion, Annulation
  Widget _buildActionButtons(Sale sale, BuildContext context) {
    final theme = Theme.of(context);
    final isCancelled = sale.isCancelled;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Bouton Reçu / Ticket
        FilledButton.icon(
          icon: const Icon(Icons.receipt_long_rounded),
          label: const Text('Voir le ticket de caisse'),
          onPressed: () => Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => SaleReceiptPage(
                session: widget.session,
                sale: sale,
              ),
            ),
          ),
        ),
        if (!isCancelled) ...[
          if (sale.saleType == SaleType.standard && sale.items.isNotEmpty && _canReplace) ...[
            const SizedBox(height: AppSpacing.sm),
            OutlinedButton.icon(
              icon: const Icon(Icons.swap_horiz_rounded),
              label: const Text('Remplacer des articles'),
              onPressed: _cancelling ? null : _openReplacement,
            ),
          ],
          if (sale.saleType == SaleType.quick && sale.items.isEmpty && _canConvert) ...[
            const SizedBox(height: AppSpacing.sm),
            OutlinedButton.icon(
              icon: const Icon(Icons.transform_rounded),
              label: const Text('Convertir en vente standard'),
              onPressed: _cancelling ? null : () => _openConversion(sale),
            ),
          ],
          if (_canCancel) ...[
            const SizedBox(height: AppSpacing.sm),
            TextButton.icon(
              icon: const Icon(Icons.cancel_outlined),
              label: _cancelling ? SaleFeedback.inlineLoader() : const Text('Annuler cette transaction'),
              style: TextButton.styleFrom(
                foregroundColor: theme.colorScheme.error,
              ),
              onPressed: _cancelling ? null : _cancel,
            ),
          ],
        ],
      ],
    );
  }

  Future<void> _openReplacement() async {
    final sale = _sale;
    if (sale == null) return;
    final done = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => SaleReplacementPage(
          session: widget.session,
          sale: sale,
        ),
      ),
    );
    if (done == true && mounted) await _refreshSale();
  }

  Future<void> _openConversion(Sale sale) async {
    final confirmed = await SaleFeedback.confirm(
      context: context,
      title: 'Convertir en vente standard',
      message: 'Répartir ${formatFcfa(sale.totalAmount)} en produits pour la vente ${sale.receiptNumber ?? '#${sale.id}'} ?',
    );
    if (confirmed != true || !mounted) return;

    final converted = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => NewSalePage(
          session: widget.session,
          conversion: QuickSaleConversion(
            saleId: sale.id,
            targetTotal: sale.totalAmount,
            receiptLabel: sale.receiptNumber,
          ),
        ),
      ),
    );
    if (converted == true && mounted) {
      await _refreshSale();
      if (!mounted) return;
      await SaleFeedback.showSuccess(
        context: context,
        title: 'Conversion réussie',
        message: 'La vente rapide a été convertie en vente standard.',
      );
    }
  }
}
