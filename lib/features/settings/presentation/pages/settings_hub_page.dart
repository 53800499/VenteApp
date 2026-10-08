import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../app/theme/app_tokens.dart';
import '../../../../shared/components/app_header_actions.dart';
import '../../../auth/domain/entities/auth_entities.dart';
import '../../../notifications/presentation/pages/notification_settings_page.dart';
import '../bloc/settings_bloc.dart';
import 'categories/about_support_settings_page.dart';
import 'categories/appearance_settings_page.dart';
import 'categories/cash_register_settings_page.dart';
import 'categories/company_shops_settings_page.dart';
import 'categories/debts_credit_settings_page.dart';
import 'categories/orders_deliveries_settings_page.dart';
import 'categories/procurement_settings_page.dart';
import 'categories/products_stock_settings_page.dart';
import 'categories/receipts_printer_settings_page.dart';
import 'categories/sales_settings_page.dart';
import 'categories/security_device_settings_page.dart';
import 'categories/subscription_plan_settings_page.dart';
import 'categories/sync_backup_settings_page.dart';
import 'categories/team_access_settings_page.dart';

class SettingsHubPage extends StatefulWidget {
  const SettingsHubPage({
    super.key,
    required this.session,
    required this.canWrite,
  });

  final AuthSession session;
  final bool canWrite;

  @override
  State<SettingsHubPage> createState() => _SettingsHubPageState();
}

class _SettingsHubPageState extends State<SettingsHubPage> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  bool _matchesSearch(String title, String subtitle, List<String> tags) {
    if (_searchQuery.isEmpty) return true;
    final query = _searchQuery.toLowerCase();
    if (title.toLowerCase().contains(query)) return true;
    if (subtitle.toLowerCase().contains(query)) return true;
    for (final tag in tags) {
      if (tag.toLowerCase().contains(query)) return true;
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Paramètres ARIKE'),
        actions: const [AppHeaderActions()],
      ),
      body: SafeArea(
        child: SizedBox(
          width: double.infinity,
          child: Column(
              children: [
                // Search Bar header
                Padding(
                  padding: const EdgeInsets.all(AppSpacing.md),
              child: TextField(
                controller: _searchController,
                onChanged: (val) => setState(() => _searchQuery = val.trim()),
                decoration: InputDecoration(
                  hintText: 'Rechercher une option (ex: ticket, PIN, stock...)',
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: _searchQuery.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear),
                          onPressed: () {
                            _searchController.clear();
                            setState(() => _searchQuery = '');
                          },
                        )
                      : null,
                  filled: true,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppRadius.lg),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.md,
                    vertical: AppSpacing.sm,
                  ),
                ),
              ),
            ),

            // Content List
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
                children: [
                  // GROUP 1: ENTREPRISE
                  _buildGroupHeader(context, 'ENTREPRISE', Icons.corporate_fare_outlined),
                  _buildCategoryTile(
                    context,
                    icon: Icons.business_outlined,
                    title: 'Entreprise & boutiques',
                    subtitle: 'Profil, logo, coordonnées, devises & réseau de boutiques',
                    tags: ['profil', 'logo', 'nom', 'adresse', 'boutique', 'ifu', 'rccm', 'devise'],
                    onTap: () => _openPage(
                      CompanyShopsSettingsPage(
                        session: widget.session,
                        canWrite: widget.canWrite,
                      ),
                    ),
                  ),
                  _buildCategoryTile(
                    context,
                    icon: Icons.people_alt_outlined,
                    title: 'Équipe & accès',
                    subtitle: 'Utilisateurs, employés, rôles, permissions et shop_access',
                    tags: ['utilisateur', 'employé', 'rôle', 'permission', 'accès', 'sécurité'],
                    onTap: () => _openPage(
                      TeamAccessSettingsPage(session: widget.session),
                    ),
                  ),

                  const SizedBox(height: AppSpacing.md),

                  // GROUP 2: ACTIVITÉ
                  _buildGroupHeader(context, 'ACTIVITÉ', Icons.assessment_outlined),
                  _buildCategoryTile(
                    context,
                    icon: Icons.shopping_cart_outlined,
                    title: 'Ventes',
                    subtitle: 'Comportement caisse, modif prix, remises, ventes à crédit',
                    tags: ['caisse', 'prix', 'remise', 'crédit', 'annulation', 'ticket'],
                    onTap: () => _openPage(
                      SalesSettingsPage(
                        session: widget.session,
                        canWrite: widget.canWrite,
                      ),
                    ),
                  ),
                  _buildCategoryTile(
                    context,
                    icon: Icons.inventory_2_outlined,
                    title: 'Produits & stock',
                    subtitle: 'Stock négatif, seuil d\'alerte par défaut, valorisation FIFO',
                    tags: ['stock', 'alerte', 'fifo', 'marge', 'variante', 'perte'],
                    onTap: () => _openPage(
                      ProductsStockSettingsPage(
                        session: widget.session,
                        canWrite: widget.canWrite,
                      ),
                    ),
                  ),
                  _buildCategoryTile(
                    context,
                    icon: Icons.assignment_outlined,
                    title: 'Commandes & livraisons',
                    subtitle: 'Workflow prépa, livraisons partielles, remplacements',
                    tags: ['commande', 'livraison', 'refus', 'remplacement', 'chauffeur'],
                    onTap: () => _openPage(
                      OrdersDeliveriesSettingsPage(
                        session: widget.session,
                        canWrite: widget.canWrite,
                      ),
                    ),
                  ),
                  _buildCategoryTile(
                    context,
                    icon: Icons.local_shipping_outlined,
                    title: 'Achats & fournisseurs',
                    subtitle: 'Validation réceptions, calcul PUMP, dettes fournisseurs',
                    tags: ['achat', 'fournisseur', 'réception', 'pump', 'coût'],
                    onTap: () => _openPage(
                      ProcurementSettingsPage(
                        session: widget.session,
                        canWrite: widget.canWrite,
                      ),
                    ),
                  ),
                  _buildCategoryTile(
                    context,
                    icon: Icons.handshake_outlined,
                    title: 'Dettes & crédits',
                    subtitle: 'Plafonds de crédit, relances, blocage impayés, remises',
                    tags: ['dette', 'crédit', 'plafond', 'échéance', 'remise'],
                    onTap: () => _openPage(
                      DebtsCreditSettingsPage(
                        session: widget.session,
                        canWrite: widget.canWrite,
                      ),
                    ),
                  ),
                  _buildCategoryTile(
                    context,
                    icon: Icons.point_of_sale_outlined,
                    title: 'Caisse',
                    subtitle: 'Ouverture/clôture obligatoire, écarts tolérés, solde initial',
                    tags: ['caisse', 'écart', 'clôture', 'solde', 'retrait', 'dépôt'],
                    onTap: () => _openPage(
                      CashRegisterSettingsPage(
                        session: widget.session,
                        canWrite: widget.canWrite,
                      ),
                    ),
                  ),

                  const SizedBox(height: AppSpacing.md),

                  // GROUP 3: APPLICATION
                  _buildGroupHeader(context, 'APPLICATION', Icons.phone_android_outlined),
                  _buildCategoryTile(
                    context,
                    icon: Icons.receipt_long_outlined,
                    title: 'Reçus & impression',
                    subtitle: 'Formats (58mm, 80mm, A4), message bas de reçu, QR Code',
                    tags: ['reçu', 'ticket', 'imprimante', 'format', 'logo', 'qr'],
                    onTap: () => _openPage(
                      ReceiptsPrinterSettingsPage(
                        session: widget.session,
                        canWrite: widget.canWrite,
                      ),
                    ),
                  ),
                  _buildCategoryTile(
                    context,
                    icon: Icons.notifications_outlined,
                    title: 'Notifications & alertes',
                    subtitle: 'Alertes stock faible, dettes à échéance, résumé du jour',
                    tags: ['notification', 'alerte', 'stock', 'dette', 'rappel'],
                    onTap: () => _openPage(
                      NotificationSettingsPage(session: widget.session),
                    ),
                  ),
                  _buildCategoryTile(
                    context,
                    icon: Icons.cloud_sync_outlined,
                    title: 'Synchronisation & sauvegarde',
                    subtitle: 'Sync Cloud, export base locale, Google Drive',
                    tags: ['sync', 'cloud', 'sauvegarde', 'drive', 'offline'],
                    onTap: () => _openPage(
                      SyncBackupSettingsPage(
                        session: widget.session,
                        canWrite: widget.canWrite,
                      ),
                    ),
                  ),
                  _buildCategoryTile(
                    context,
                    icon: Icons.shield_outlined,
                    title: 'Sécurité & appareils',
                    subtitle: 'Code PIN, biométrie, temporisation, appareils connectés',
                    tags: ['pin', 'sécurité', 'biométrie', 'verrou', 'appareil', 'session'],
                    onTap: () => _openPage(
                      SecurityDeviceSettingsPage(
                        session: widget.session,
                        canWrite: widget.canWrite,
                      ),
                    ),
                  ),
                  _buildCategoryTile(
                    context,
                    icon: Icons.palette_outlined,
                    title: 'Apparence & utilisation',
                    subtitle: 'Thème clair/sombre, langue, assistant vocal, formats',
                    tags: ['thème', 'sombre', 'langue', 'voix', 'format'],
                    onTap: () => _openPage(
                      AppearanceSettingsPage(session: widget.session),
                    ),
                  ),

                  const SizedBox(height: AppSpacing.md),

                  // GROUP 4: COMPTE
                  _buildGroupHeader(context, 'COMPTE', Icons.account_circle_outlined),
                  _buildCategoryTile(
                    context,
                    icon: Icons.workspace_premium_outlined,
                    title: 'Mon forfait',
                    subtitle: 'ARIKE Pro / Starter, boutiques & utilisateurs utilisés',
                    tags: ['forfait', 'abonnement', 'licence', 'module', 'facture'],
                    onTap: () => _openPage(
                      SubscriptionPlanSettingsPage(session: widget.session),
                    ),
                  ),
                  _buildCategoryTile(
                    context,
                    icon: Icons.help_outline_rounded,
                    title: 'Aide & assistance',
                    subtitle: 'Guides pas à pas, diagnostic, support WhatsApp',
                    tags: ['aide', 'guide', 'support', 'whatsapp', 'tuto'],
                    onTap: () => _openPage(
                      AboutSupportSettingsPage(session: widget.session),
                    ),
                  ),

                  const SizedBox(height: AppSpacing.xl),
                ],
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

  Widget _buildGroupHeader(BuildContext context, String title, IconData icon) {
    if (_searchQuery.isNotEmpty) return const SizedBox.shrink();
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(
        top: AppSpacing.sm,
        bottom: AppSpacing.xs,
        left: 4,
      ),
      child: Row(
        children: [
          Icon(icon, size: 16, color: theme.colorScheme.primary),
          const SizedBox(width: AppSpacing.xs),
          Text(
            title,
            style: theme.textTheme.labelLarge?.copyWith(
              color: theme.colorScheme.primary,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.1,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryTile(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required List<String> tags,
    required VoidCallback onTap,
  }) {
    if (!_matchesSearch(title, subtitle, tags)) {
      return const SizedBox.shrink();
    }

    final theme = Theme.of(context);

    return Card(
      margin: const EdgeInsets.only(bottom: AppSpacing.xs),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.md),
        side: BorderSide(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
        ),
      ),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: theme.colorScheme.primaryContainer.withValues(alpha: 0.6),
          child: Icon(icon, size: 22, color: theme.colorScheme.onPrimaryContainer),
        ),
        title: Text(
          title,
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        subtitle: Text(
          subtitle,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        trailing: const Icon(Icons.chevron_right, size: 20),
        onTap: onTap,
      ),
    );
  }

  void _openPage(Widget page) {
    try {
      final settingsBloc = context.read<SettingsBloc>();
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => BlocProvider.value(
            value: settingsBloc,
            child: page,
          ),
        ),
      );
    } catch (_) {
      Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => page),
      );
    }
  }
}
