import 'package:flutter/material.dart';
import '../../../../app/di/injection_container.dart';
import '../../../../shared/components/app_dropdown.dart';
import '../../../../app/theme/app_tokens.dart';
import '../../../../core/utils/date_formatter.dart';
import '../../domain/entities/subscription_details.dart';
import '../../domain/services/subscription_controller.dart';
import '../../data/services/fedapay_remote_service.dart';

enum BillingCycle { monthly, quarterly, yearly }

class SubscriptionPage extends StatefulWidget {
  const SubscriptionPage({super.key});

  @override
  State<SubscriptionPage> createState() => _SubscriptionPageState();
}

class _SubscriptionPageState extends State<SubscriptionPage> {
  BillingCycle _billingCycle = BillingCycle.yearly;
  String _selectedProvider = 'MTN Mobile Money (FedaPay)';
  final _phoneController = TextEditingController(text: '61000000');

  @override
  void dispose() {
    _phoneController.dispose();
    super.dispose();
  }

  void _processFedaPayOrLocalPayment({
    required String targetPlanName,
    required double price,
    String? targetPlanCode,
    bool isAddon = false,
  }) async {
    final mode = switch (_selectedProvider) {
      'Moov Money (FedaPay)' => 'moov',
      'Celtiis (FedaPay)' => 'celtiis',
      'Carte Visa / Mastercard (FedaPay)' => 'card',
      _ => 'mtn',
    };

    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogCtx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.payment, color: Colors.blue),
            SizedBox(width: 8),
            Text('Paiement FedaPay'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 16),
            Text(
              'Demande de paiement envoyée au ${_phoneController.text} ($_selectedProvider)...\n\nVeuillez valider le message USSD reçu sur votre téléphone.',
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );

    final fedapayService = sl<FedaPayRemoteService>();
    await fedapayService.initializePayment(
      amount: price,
      description: isAddon
          ? 'Option $targetPlanName'
          : 'Abonnement $targetPlanName ($_billingCycleLabel)',
      phoneNumber: _phoneController.text,
      mode: mode,
      planCode: targetPlanCode,
      durationDays: _durationDays,
      addonCode: isAddon ? targetPlanName : null,
    );

    if (mounted && Navigator.canPop(context)) {
      Navigator.pop(context);
    }

    if (isAddon) {
      _executeAddonPayment(addonTitle: targetPlanName, price: price);
    } else if (targetPlanCode != null) {
      _executePlanPayment(
        targetPlanCode: targetPlanCode,
        targetPlanName: targetPlanName,
        price: price,
      );
    }
  }

  String get _billingCycleLabel => switch (_billingCycle) {
        BillingCycle.monthly => 'Mensuel',
        BillingCycle.quarterly => 'Trimestriel',
        BillingCycle.yearly => 'Annuel',
      };

  String get _billingSuffix => switch (_billingCycle) {
        BillingCycle.monthly => ' / mois',
        BillingCycle.quarterly => ' / 3 mois',
        BillingCycle.yearly => ' / an',
      };

  int get _durationDays => switch (_billingCycle) {
        BillingCycle.monthly => 30,
        BillingCycle.quarterly => 90,
        BillingCycle.yearly => 365,
      };

  double _getPlanPrice(String planCode) => switch (planCode) {
        'STARTER' => switch (_billingCycle) {
            BillingCycle.monthly => 1000,
            BillingCycle.quarterly => 3000,
            BillingCycle.yearly => 10000,
          },
        'ESSENTIEL' => switch (_billingCycle) {
            BillingCycle.monthly => 2500,
            BillingCycle.quarterly => 7500,
            BillingCycle.yearly => 25000,
          },
        'PRO' => switch (_billingCycle) {
            BillingCycle.monthly => 5000,
            BillingCycle.quarterly => 15000,
            BillingCycle.yearly => 50000,
          },
        'BUSINESS' => switch (_billingCycle) {
            BillingCycle.monthly => 15000,
            BillingCycle.quarterly => 45000,
            BillingCycle.yearly => 150000,
          },
        _ => 0,
      };

  late SubscriptionDetails _details;

  @override
  void initState() {
    super.initState();
    _details = SubscriptionDetails(
      planCode: 'PRO',
      planName: '⭐ ARIKE Pro',
      status: 'ACTIVE',
      startedAt: DateTime(2026, 7, 30),
      expiresAt: DateTime(2027, 7, 30),
      graceUntil: DateTime(2027, 8, 6),
      autoRenew: false,
      grantedModules: const [
        'Vente & Encaissement',
        'Stock Avancé',
        'Dépenses & Charges',
        'Approvisionnements & Commandes',
        'Bureau de Change FX',
        'Assistant Vocal ARIKE',
        'Statistiques & Analyses',
      ],
      maxUsers: 10,
      maxShops: 5,
      currentUsersCount: 3,
      currentShopsCount: 2,
      paymentHistory: [
        PaymentTransactionRecord(
          id: 'tx_pay_2026_9942',
          date: DateTime(2026, 7, 30),
          planName: 'ARIKE Pro Annuel',
          amount: 50000,
          currency: 'FCFA',
          provider: 'MTN Mobile Money',
          status: 'PAYÉ',
        ),
        PaymentTransactionRecord(
          id: 'tx_pay_2025_1102',
          date: DateTime(2025, 7, 30),
          planName: 'ARIKE Essentiel Annuel',
          amount: 25000,
          currency: 'FCFA',
          provider: 'Wave',
          status: 'PAYÉ',
        ),
      ],
    );
    ensureSubscriptionDependencies();
    sl<SubscriptionController>().updateSubscription(_details);
  }

  void _executePlanPayment({
    required String targetPlanCode,
    required String targetPlanName,
    required double price,
  }) {
    List<String> modules;
    int maxUsers;
    int maxShops;

    switch (targetPlanCode) {
      case 'STARTER':
        modules = ['Vente & Encaissement', 'Gestion de Stock simple', 'Fichier Clients & Dettes simples', 'Mode 100% Offline'];
        maxUsers = 1;
        maxShops = 1;
        break;
      case 'ESSENTIEL':
        modules = [
          'Vente & Encaissement',
          'Stock avancé & Alertes rupture',
          'Dépenses & Charges de caisse',
          'Approvisionnements & Commandes clients',
          'Rapports de ventes quotidiens',
          'Mode 100% Offline',
        ];
        maxUsers = 3;
        maxShops = 2;
        break;
      case 'PRO':
        modules = [
          'Vente & Encaissement',
          'Stock Avancé',
          'Dépenses & Charges',
          'Approvisionnements & Commandes',
          'Bureau de Change FX',
          'Assistant Vocal ARIKE',
          'Transferts de stock inter-boutiques',
          'Analyses & Statistiques avancées',
          'Mode 100% Offline',
        ];
        maxUsers = 10;
        maxShops = 5;
        break;
      case 'BUSINESS':
      default:
        modules = [
          'Vente & Encaissement',
          'Stock Avancé',
          'Dépenses & Charges',
          'Approvisionnements & Commandes',
          'Bureau de Change FX',
          'Assistant Vocal ARIKE',
          'Transferts de stock inter-boutiques',
          'Analyses & Statistiques avancées',
          'Multi-entreprises & Distributeurs',
          'Accès API dédiée & Export complet',
          'Mode 100% Offline',
        ];
        maxUsers = 999;
        maxShops = 999;
        break;
    }

    final newTx = PaymentTransactionRecord(
      id: 'tx_pay_${DateTime.now().millisecondsSinceEpoch.toString().substring(5)}',
      date: DateTime.now(),
      planName: '$targetPlanName ($_billingCycleLabel)',
      amount: price,
      currency: 'FCFA',
      provider: _selectedProvider,
      status: 'PAYÉ',
    );

    final durationDays = _durationDays;
    final now = DateTime.now();
    final baseDate = _details.expiresAt.isAfter(now) ? _details.expiresAt : now;
    final newExpiresAt = baseDate.add(Duration(days: durationDays));
    final newGraceUntil = newExpiresAt.add(const Duration(days: 7));

    setState(() {
      _details = SubscriptionDetails(
        planCode: targetPlanCode,
        planName: targetPlanName,
        status: 'ACTIVE',
        startedAt: now,
        expiresAt: newExpiresAt,
        graceUntil: newGraceUntil,
        autoRenew: false,
        grantedModules: modules,
        maxUsers: maxUsers,
        maxShops: maxShops,
        currentUsersCount: _details.currentUsersCount,
        currentShopsCount: _details.currentShopsCount,
        paymentHistory: [newTx, ..._details.paymentHistory],
      );
    });

    ensureSubscriptionDependencies();
    sl<SubscriptionController>().updateSubscription(_details);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Paiement de ${price.toStringAsFixed(0)} FCFA réussi via $_selectedProvider ! Le forfait $targetPlanName est actif.'),
        backgroundColor: Colors.green,
      ),
    );
  }

  void _executeAddonPayment({
    required String addonTitle,
    required double price,
  }) {
    final updatedModules = List<String>.from(_details.grantedModules);
    if (!updatedModules.contains(addonTitle)) {
      updatedModules.add(addonTitle);
    }

    final newTx = PaymentTransactionRecord(
      id: 'tx_addon_${DateTime.now().millisecondsSinceEpoch.toString().substring(5)}',
      date: DateTime.now(),
      planName: 'Option à la carte : $addonTitle',
      amount: price,
      currency: 'FCFA',
      provider: _selectedProvider,
      status: 'PAYÉ',
    );

    setState(() {
      _details = SubscriptionDetails(
        planCode: _details.planCode,
        planName: _details.planName,
        status: _details.status,
        startedAt: _details.startedAt,
        expiresAt: _details.expiresAt,
        graceUntil: _details.graceUntil,
        autoRenew: _details.autoRenew,
        grantedModules: updatedModules,
        maxUsers: _details.maxUsers,
        maxShops: _details.maxShops,
        currentUsersCount: _details.currentUsersCount,
        currentShopsCount: _details.currentShopsCount,
        paymentHistory: [newTx, ..._details.paymentHistory],
      );
    });

    ensureSubscriptionDependencies();
    sl<SubscriptionController>().updateSubscription(_details);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Module "$addonTitle" débloqué et activé avec succès via $_selectedProvider !'),
        backgroundColor: Colors.green,
      ),
    );
  }

  void _showChangePlanDialog(BuildContext context, String targetPlanCode, String targetPlanName, double price) {
    final isCurrent = _details.planCode == targetPlanCode;
    final isUpgrade = targetPlanCode == 'PRO' || targetPlanCode == 'BUSINESS';

    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(isCurrent ? 'Renouveler $targetPlanName' : 'Changer pour $targetPlanName'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                isCurrent
                    ? 'Renouvellement d\'abonnement :'
                    : (isUpgrade ? 'Montée en gamme (Upgrade immédiat) :' : 'Changement de formule (Downgrade) :'),
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                isCurrent
                    ? 'Votre abonnement sera prolongé de $_billingCycleLabel.'
                    : (isUpgrade
                        ? 'Votre nouveau forfait s\'activera immédiatement dès confirmation du paiement.'
                        : 'Votre formule actuelle reste active jusqu\'au ${AppDateFormatter.formatDateLong(_details.expiresAt)}. Le nouveau tarif s\'appliquera à l\'échéance.'),
              ),
              const SizedBox(height: AppSpacing.md),
              Text(
                'Tarif : ${price.toStringAsFixed(0)} FCFA$_billingSuffix',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(ctx);
              _showMobileMoneyPaymentModal(
                context,
                targetPlanName: targetPlanName,
                price: price,
                targetPlanCode: targetPlanCode,
                isAddon: false,
              );
            },
            child: const Text('Payer via Mobile Money'),
          ),
        ],
      ),
    );
  }

  void _showMobileMoneyPaymentModal(
    BuildContext context, {
    required String targetPlanName,
    required double price,
    String? targetPlanCode,
    bool isAddon = false,
  }) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.md)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (modalContext, setModalState) => SafeArea(
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              AppSpacing.md,
              AppSpacing.md,
              AppSpacing.md,
              MediaQuery.of(modalContext).viewInsets.bottom + AppSpacing.md,
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isAddon ? 'Paiement Option — $targetPlanName' : 'Paiement Mobile Money — $targetPlanName',
                    style: Theme.of(modalContext).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    isAddon
                        ? 'Montant à régler : ${price.toStringAsFixed(0)} FCFA / mois'
                        : 'Montant à régler : ${price.toStringAsFixed(0)} FCFA ($_billingCycleLabel)',
                    style: TextStyle(
                      color: Theme.of(modalContext).colorScheme.primary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  AppDropdown<String>(
                    labelText: 'Moyen de paiement (FedaPay / Mobile Money)',
                    hintText: 'Sélectionner un moyen de paiement',
                    items: const [
                      'MTN Mobile Money (FedaPay)',
                      'Moov Money (FedaPay)',
                      'Celtiis (FedaPay)',
                      'Carte Visa / Mastercard (FedaPay)',
                    ],
                    initialItem: _selectedProvider,
                    onChanged: (val) {
                      if (val != null) setModalState(() => _selectedProvider = val);
                    },
                  ),
                  const SizedBox(height: AppSpacing.md),
                  TextField(
                    controller: _phoneController,
                    keyboardType: TextInputType.phone,
                    decoration: const InputDecoration(
                      labelText: 'Numéro Mobile Money (Bénin / UOA)',
                      hintText: 'Ex: 61000000 ou 97000000',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.phone_android),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: () {
                        Navigator.pop(ctx);
                        _processFedaPayOrLocalPayment(
                          targetPlanName: targetPlanName,
                          price: price,
                          targetPlanCode: targetPlanCode,
                          isAddon: isAddon,
                        );
                      },
                      icon: const Icon(Icons.payment),
                      label: const Text('Payer via FedaPay'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Abonnement & Facturation ARIKE'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.md),
        children: [
          // 📡 Bannière Offline-First Value Proposition
          Container(
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [colorScheme.primaryContainer, colorScheme.surfaceContainerHighest],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
            child: Row(
              children: [
                Icon(Icons.wifi_off_rounded, color: colorScheme.primary, size: 28),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Fonctionne 100% Hors-Ligne',
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Même sans connexion internet ni réseau, votre boutique continue d\'encaisser et de gérer son stock.',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.md),

          // 🟢 Carte 1: Carte de Forfait Actuel
          Card(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Votre forfait actuel',
                            style: Theme.of(context).textTheme.labelMedium?.copyWith(
                                  color: colorScheme.outline,
                                ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            _details.planName,
                            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: colorScheme.primary,
                                ),
                          ),
                        ],
                      ),
                      Chip(
                        avatar: const Icon(Icons.check_circle, color: Colors.white, size: 16),
                        label: Text(_details.status),
                        backgroundColor: Colors.green,
                        labelStyle: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  const Divider(height: AppSpacing.lg),
                  Row(
                    children: [
                      const Icon(Icons.calendar_today_outlined, size: 18),
                      const SizedBox(width: AppSpacing.xs),
                      Text('Expire le : ${AppDateFormatter.formatDateLong(_details.expiresAt)}'),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  const Row(
                    children: [
                      Icon(Icons.autorenew_outlined, size: 18),
                      SizedBox(width: AppSpacing.xs),
                      Text('Renouvellement : Manuel'),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.md),

          // 📊 Carte 2: Utilisation des Quotas
          Card(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Consommation des Quotas',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  _QuotaBar(
                    label: 'Utilisateurs',
                    current: _details.currentUsersCount,
                    max: _details.maxUsers,
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  _QuotaBar(
                    label: 'Boutiques',
                    current: _details.currentShopsCount,
                    max: _details.maxShops,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.lg),

          // 🔄 Section 3: Catalogue des Forfaits Adaptés au Marché
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Forfaits ARIKE',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              // Bascule 3 Périodes: Mensuel / Trimestriel / Annuel
              Container(
                padding: const EdgeInsets.all(2),
                decoration: BoxDecoration(
                  color: colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(AppRadius.md),
                ),
                child: Row(
                  children: [
                    _BillingCycleTab(
                      label: 'Mensuel',
                      selected: _billingCycle == BillingCycle.monthly,
                      onTap: () => setState(() => _billingCycle = BillingCycle.monthly),
                    ),
                    _BillingCycleTab(
                      label: 'Trimestriel (3 mois)',
                      selected: _billingCycle == BillingCycle.quarterly,
                      onTap: () => setState(() => _billingCycle = BillingCycle.quarterly),
                    ),
                    _BillingCycleTab(
                      label: 'Annuel (-20%)',
                      selected: _billingCycle == BillingCycle.yearly,
                      onTap: () => setState(() => _billingCycle = BillingCycle.yearly),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),

          // 1. ARIKE Starter
          _PlanCard(
            title: 'ARIKE Starter',
            price: _getPlanPrice('STARTER'),
            billingSuffix: _billingSuffix,
            quotas: '1 Utilisateur · 1 Appareil · 1 Boutique',
            features: const [
              'Gestion des Ventes & Encaissement',
              'Gestion de Stock simple',
              'Fichier Clients & Dettes simples',
              'Mode 100% Offline',
            ],
            isCurrent: _details.planCode == 'STARTER',
            onSelect: () => _showChangePlanDialog(context, 'STARTER', 'ARIKE Starter', _getPlanPrice('STARTER')),
          ),
          const SizedBox(height: AppSpacing.sm),

          // 2. ARIKE Essentiel
          _PlanCard(
            title: 'ARIKE Essentiel',
            price: _getPlanPrice('ESSENTIEL'),
            billingSuffix: _billingSuffix,
            quotas: '3 Utilisateurs · 2 Boutiques',
            features: const [
              'Tout le plan Starter',
              'Stock avancé & Alertes rupture',
              'Dépenses & Charges de caisse',
              'Approvisionnements & Commandes clients',
              'Rapports de ventes quotidiens',
            ],
            isCurrent: _details.planCode == 'ESSENTIEL',
            onSelect: () => _showChangePlanDialog(context, 'ESSENTIEL', 'ARIKE Essentiel', _getPlanPrice('ESSENTIEL')),
          ),
          const SizedBox(height: AppSpacing.sm),

          // 3. ⭐ ARIKE Pro
          _PlanCard(
            title: '⭐ ARIKE Pro',
            price: _getPlanPrice('PRO'),
            billingSuffix: _billingSuffix,
            quotas: '10 Utilisateurs · 5 Boutiques',
            features: const [
              'Tout le plan Essentiel',
              'Bureau de Change FX (Devises)',
              'Assistant Vocal ARIKE',
              'Transferts de stock inter-boutiques',
              'Analyses & Statistiques avancées',
            ],
            isCurrent: _details.planCode == 'PRO',
            isPopular: true,
            onSelect: () => _showChangePlanDialog(context, 'PRO', '⭐ ARIKE Pro', _getPlanPrice('PRO')),
          ),
          const SizedBox(height: AppSpacing.sm),

          // 4. ARIKE Business
          _PlanCard(
            title: 'ARIKE Business',
            price: _getPlanPrice('BUSINESS'),
            billingSuffix: _billingSuffix,
            quotas: 'Utilisateurs & Boutiques Illimités',
            features: const [
              'Tout le plan Pro',
              'Multi-entreprises & Distributeurs',
              'Accès API dédiée & Export complet',
              'Support prioritaire 24/7 & Configuration sur-mesure',
            ],
            isCurrent: _details.planCode == 'BUSINESS',
            onSelect: () => _showChangePlanDialog(context, 'BUSINESS', 'ARIKE Business', _getPlanPrice('BUSINESS')),
          ),
          const SizedBox(height: AppSpacing.lg),

          // ➕ Section 4: Options À la Carte (Add-ons)
          Text(
            'Options & Modules à la carte',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'Personnalisez votre abonnement selon vos besoins réels sans nécessairement payer le forfait supérieur.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: AppSpacing.sm),
          _AddonCard(
            title: 'Statistiques & Analyses',
            priceText: '1 500 FCFA / mois',
            subtitle: 'Calcul du bénéfice net réel, graphiques d’analyse & top ventes',
            icon: Icons.insights_outlined,
            isGranted: _details.grantedModules.contains('Statistiques & Analyses'),
            onAdd: () => _showMobileMoneyPaymentModal(
              context,
              targetPlanName: 'Statistiques & Analyses',
              price: 1500,
              isAddon: true,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          _AddonCard(
            title: 'Dépenses & Charges',
            priceText: '1 000 FCFA / mois',
            subtitle: 'Gestion des charges d’exploitation, caisse & frais récurrents',
            icon: Icons.payments_outlined,
            isGranted: _details.grantedModules.contains('Dépenses & Charges'),
            onAdd: () => _showMobileMoneyPaymentModal(
              context,
              targetPlanName: 'Dépenses & Charges',
              price: 1000,
              isAddon: true,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          _AddonCard(
            title: 'Approvisionnement & Commandes',
            priceText: '1 000 FCFA / mois',
            subtitle: 'Bons de commande fournisseurs, réceptions & livraisons clients',
            icon: Icons.local_shipping_outlined,
            isGranted: _details.grantedModules.contains('Approvisionnement & Commandes'),
            onAdd: () => _showMobileMoneyPaymentModal(
              context,
              targetPlanName: 'Approvisionnement & Commandes',
              price: 1000,
              isAddon: true,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          _AddonCard(
            title: 'Transferts Inter-boutiques',
            priceText: '1 500 FCFA / mois',
            subtitle: 'Expédition & réception de mouvements de stock multi-boutiques',
            icon: Icons.swap_horiz_outlined,
            isGranted: _details.grantedModules.contains('Transferts Inter-boutiques'),
            onAdd: () => _showMobileMoneyPaymentModal(
              context,
              targetPlanName: 'Transferts Inter-boutiques',
              price: 1500,
              isAddon: true,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          _AddonCard(
            title: 'Bureau de Change FX',
            priceText: '1 500 FCFA / mois',
            subtitle: 'Calculateur de change, gestion devises & reçu cambiste',
            icon: Icons.currency_exchange,
            isGranted: _details.grantedModules.contains('Bureau de Change FX'),
            onAdd: () => _showMobileMoneyPaymentModal(
              context,
              targetPlanName: 'Bureau de Change FX',
              price: 1500,
              isAddon: true,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          _AddonCard(
            title: 'Assistant Vocal ARIKE',
            priceText: '2 000 FCFA / mois',
            subtitle: 'Saisie vocale intelligente de vente et de stock',
            icon: Icons.mic_rounded,
            isGranted: _details.grantedModules.contains('Assistant Vocal ARIKE'),
            onAdd: () => _showMobileMoneyPaymentModal(
              context,
              targetPlanName: 'Assistant Vocal ARIKE',
              price: 2000,
              isAddon: true,
            ),
          ),
          const SizedBox(height: AppSpacing.lg),

          // 💳 Carte 5: Historique des Paiements
          Card(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Historique des paiements & factures',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  ..._details.paymentHistory.map(
                    (tx) => Padding(
                      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
                      child: Row(
                        children: [
                          const CircleAvatar(
                            child: Icon(Icons.receipt_long, size: 20),
                          ),
                          const SizedBox(width: AppSpacing.sm),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '${tx.planName} — ${tx.amount.toStringAsFixed(0)} ${tx.currency}',
                                  style: const TextStyle(fontWeight: FontWeight.bold),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  '${AppDateFormatter.formatDate(tx.date)} via ${tx.provider}',
                                  style: Theme.of(context).textTheme.bodySmall,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: AppSpacing.xs),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.green.shade100,
                              borderRadius: BorderRadius.circular(AppRadius.sm),
                            ),
                            child: Text(
                              tx.status,
                              style: const TextStyle(
                                color: Colors.green,
                                fontWeight: FontWeight.bold,
                                fontSize: 11,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PlanCard extends StatelessWidget {
  const _PlanCard({
    super.key,
    required this.title,
    required this.price,
    required this.billingSuffix,
    required this.quotas,
    required this.features,
    required this.isCurrent,
    this.isPopular = false,
    required this.onSelect,
  });

  final String title;
  final double price;
  final String billingSuffix;
  final String quotas;
  final List<String> features;
  final bool isCurrent;
  final bool isPopular;
  final VoidCallback onSelect;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Card(
      elevation: isPopular ? 4 : 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.md),
        side: isPopular
            ? BorderSide(color: colorScheme.primary, width: 2)
            : BorderSide.none,
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: isPopular ? colorScheme.primary : null,
                      ),
                ),
                if (isPopular)
                  Chip(
                    label: const Text('Populaire'),
                    backgroundColor: colorScheme.primaryContainer,
                    labelStyle: TextStyle(
                      color: colorScheme.primary,
                      fontWeight: FontWeight.bold,
                      fontSize: 11,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: AppSpacing.xs),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '${price.toStringAsFixed(0)} FCFA',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                Text(
                  billingSuffix,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              quotas,
              style: TextStyle(
                color: colorScheme.primary,
                fontWeight: FontWeight.w600,
                fontSize: 12,
              ),
            ),
            const Divider(height: AppSpacing.md),
            ...features.map(
              (f) => Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(
                  children: [
                    const Icon(Icons.check, size: 16, color: Colors.green),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(f, style: Theme.of(context).textTheme.bodySmall),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            SizedBox(
              width: double.infinity,
              child: isCurrent
                  ? OutlinedButton.icon(
                      onPressed: onSelect,
                      icon: const Icon(Icons.refresh),
                      label: const Text('Renouveler ce forfait'),
                    )
                  : FilledButton(
                      onPressed: onSelect,
                      child: const Text('Choisir ce forfait'),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AddonCard extends StatelessWidget {
  const _AddonCard({
    required this.title,
    required this.priceText,
    required this.subtitle,
    required this.icon,
    required this.isGranted,
    required this.onAdd,
  });

  final String title;
  final String priceText;
  final String subtitle;
  final IconData icon;
  final bool isGranted;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.sm),
        child: Row(
          children: [
            CircleAvatar(
              backgroundColor: isGranted ? Colors.green.shade100 : colorScheme.secondaryContainer,
              child: Icon(icon, color: isGranted ? Colors.green.shade800 : colorScheme.secondary),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          title,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: AppSpacing.xs),
                      Text(
                        priceText,
                        style: TextStyle(
                          color: isGranted ? Colors.green.shade700 : colorScheme.primary,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: Theme.of(context).textTheme.bodySmall,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.xs),
            if (isGranted)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                  border: Border.all(color: Colors.green),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.check_circle, size: 14, color: Colors.green),
                    SizedBox(width: 4),
                    Text(
                      'Actif',
                      style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold, fontSize: 11),
                    ),
                  ],
                ),
              )
            else
              OutlinedButton(
                style: OutlinedButton.styleFrom(
                  minimumSize: Size.zero,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                onPressed: onAdd,
                child: const Text('+ Ajouter'),
              ),
          ],
        ),
      ),
    );
  }
}

class _QuotaBar extends StatelessWidget {
  const _QuotaBar({
    required this.label,
    required this.current,
    required this.max,
  });

  final String label;
  final int current;
  final int max;

  @override
  Widget build(BuildContext context) {
    final ratio = max > 0 ? (current / max).clamp(0.0, 1.0) : 0.0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
            Text('$current / $max'),
          ],
        ),
        const SizedBox(height: 4),
        LinearProgressIndicator(
          value: ratio,
          minHeight: 8,
          borderRadius: BorderRadius.circular(4),
          backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
        ),
      ],
    );
  }
}

class _BillingCycleTab extends StatelessWidget {
  const _BillingCycleTab({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(AppRadius.sm),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.sm),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: selected ? colorScheme.primary : Colors.transparent,
            borderRadius: BorderRadius.circular(AppRadius.sm),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: selected ? Colors.white : colorScheme.onSurface,
              fontWeight: FontWeight.bold,
              fontSize: 11,
            ),
          ),
        ),
      ),
    );
  }
}
