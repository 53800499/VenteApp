import 'package:flutter/material.dart';
import '../../../../app/di/injection_container.dart';
import '../../../../shared/components/app_dropdown.dart';
import '../../../../shared/utils/module_labels.dart';
import '../../../../app/theme/app_tokens.dart';
import '../../../../core/utils/date_formatter.dart';
import '../../domain/entities/subscription_details.dart';
import '../../domain/services/subscription_controller.dart';
import '../../data/services/fedapay_remote_service.dart';
import '../../data/services/subscription_remote_service.dart';

enum BillingCycle { monthly, quarterly, yearly }

class SubscriptionPage extends StatefulWidget {
  final bool mandatoryGate;

  const SubscriptionPage({super.key, this.mandatoryGate = false});

  @override
  State<SubscriptionPage> createState() => _SubscriptionPageState();
}

class _SubscriptionPageState extends State<SubscriptionPage> {
  BillingCycle _billingCycle = BillingCycle.yearly;
  String _selectedProvider = 'MTN Mobile Money (FedaPay)';
  final _phoneController = TextEditingController(text: '');

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

    bool isCancelledByUser = false;

    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogCtx) => PopScope(
        canPop: false,
        child: AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.mobile_friendly, color: Colors.blue),
              SizedBox(width: 8),
              Expanded(
                child: Text('Paiement FedaPay Mobile Money'),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(),
              const SizedBox(height: 16),
              Text(
                'Demande de paiement transmise au ${_phoneController.text} ($_selectedProvider).\n\n'
                '📲 Veuillez entrer votre code secret sur le pop-up USSD apparu sur votre téléphone pour confirmer.',
                textAlign: TextAlign.center,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                isCancelledByUser = true;
                Navigator.pop(dialogCtx);
              },
              child: const Text('Fermer / Vérifier plus tard'),
            ),
          ],
        ),
      ),
    );

    final fedapayService = sl<FedaPayRemoteService>();
    final result = await fedapayService.initializePayment(
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

    if (!result.success) {
      if (mounted && Navigator.canPop(context)) {
        Navigator.pop(context);
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: Colors.red.shade700,
            content: Text('Échec FedaPay : ${result.message}'),
          ),
        );
      }
      return;
    }

    final txId = result.transactionId;
    if (txId != null) {
      // Boucle de vérification (Polling 45s max)
      for (int i = 0; i < 15; i++) {
        if (isCancelledByUser || !mounted) break;
        await Future<void>.delayed(const Duration(seconds: 3));
        if (isCancelledByUser || !mounted) break;

        final status = await fedapayService.checkTransactionStatus(txId);
        if (status == 'approved' || status == 'transferred') {
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
          return;
        } else if (status == 'declined' || status == 'canceled') {
          if (mounted && Navigator.canPop(context)) {
            Navigator.pop(context);
          }
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                backgroundColor: Colors.red.shade700,
                content: Text('Paiement FedaPay annulé ou refusé ($status).'),
              ),
            );
          }
          return;
        }
      }
    }

    if (mounted && Navigator.canPop(context) && !isCancelledByUser) {
      Navigator.pop(context);
    }

    if (mounted && !isCancelledByUser) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          duration: const Duration(seconds: 6),
          content: Text(
            'Demande FedaPay soumise pour $targetPlanName. Votre abonnement sera activé dès la confirmation du paiement.',
          ),
        ),
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

  double _getPlanPrice(String planCode) {
    final pkg = _packages.firstWhere(
      (p) => p['code']?.toString().toUpperCase() == planCode.toUpperCase(),
      orElse: () => <String, dynamic>{},
    );
    if (pkg.isEmpty) return 0.0;

    final monthlyPrice = (pkg['monthlyPrice'] as num?)?.toDouble() ?? (pkg['price'] as num?)?.toDouble() ?? 0.0;
    final annualPrice = (pkg['annualPrice'] as num?)?.toDouble() ?? (monthlyPrice * 10.0);

    return switch (_billingCycle) {
      BillingCycle.monthly => monthlyPrice,
      BillingCycle.quarterly => monthlyPrice * 3.0,
      BillingCycle.yearly => annualPrice,
    };
  }

  late SubscriptionDetails _details;
  List<Map<String, dynamic>> _paidOptions = [];
  List<Map<String, dynamic>> _packages = [];
  bool _isLoading = false;

  IconData _getOptionIcon(String code) {
    switch (code) {
      case 'EXTRA_SHOP':
        return Icons.store_outlined;
      case 'USER_PACK_5':
        return Icons.group_add_outlined;
      case 'AI_ASSISTANT':
        return Icons.auto_awesome;
      case 'FX_CHANGE':
        return Icons.currency_exchange;
      case 'INITIAL_TRAINING':
        return Icons.school_outlined;
      case 'PREMIUM_SUPPORT':
        return Icons.support_agent_outlined;
      default:
        return Icons.extension_outlined;
    }
  }

  @override
  void initState() {
    super.initState();
    ensureSubscriptionDependencies();
    _details = sl<SubscriptionController>().details;
    _loadSubscriptionFromDatabase();
  }

  Future<void> _loadSubscriptionFromDatabase({bool forceRefresh = false}) async {
    if (_packages.isEmpty && _paidOptions.isEmpty && mounted) {
      setState(() {
        _isLoading = true;
      });
    }

    await sl<SubscriptionController>().refreshFromRemote();
    List<Map<String, dynamic>> options = [];
    List<Map<String, dynamic>> pkgs = [];
    if (sl.isRegistered<SubscriptionRemoteService>()) {
      final remote = sl<SubscriptionRemoteService>();
      final res = await Future.wait([
        remote.fetchPaidOptions(forceRefresh: forceRefresh),
        remote.fetchPackages(forceRefresh: forceRefresh),
      ]);
      options = res[0];
      pkgs = res[1];
    }
    if (mounted) {
      setState(() {
        _isLoading = false;
        _details = sl<SubscriptionController>().details;
        _paidOptions = options;
        _packages = pkgs;
      });
    }
  }

  void _executePlanPayment({
    required String targetPlanCode,
    required String targetPlanName,
    required double price,
  }) async {
    final remoteService = sl.isRegistered<SubscriptionRemoteService>()
        ? sl<SubscriptionRemoteService>()
        : null;

    if (remoteService != null) {
      await remoteService.subscribe(
        planCode: targetPlanCode,
        durationDays: _durationDays,
        provider: _selectedProvider,
        paymentReference: 'FEDA-${DateTime.now().millisecondsSinceEpoch}',
        amount: price,
      );
      await sl<SubscriptionController>().refreshFromRemote();
    }

    if (mounted) {
      setState(() {
        _details = sl<SubscriptionController>().details;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Paiement de ${price.toStringAsFixed(0)} FCFA réussi via $_selectedProvider ! Le forfait $targetPlanName est actif.'),
          backgroundColor: Colors.green,
        ),
      );
    }
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
        capabilities: _details.capabilities,
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

  void _showChangePlanDialog(BuildContext context, String targetPlanCode, String targetPlanName, double price) async {
    final isCurrent = _details.planCode.toUpperCase() == targetPlanCode.toUpperCase();

    // 1. Cas du forfait permanent GRATUIT (0 FCFA)
    if (targetPlanCode.toUpperCase() == 'FREE') {
      if (isCurrent) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Vous êtes actuellement sur le forfait gratuit local ARIKE.')),
        );
        return;
      }

      showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
          title: const Row(
            children: [
              Icon(Icons.offline_bolt_outlined, color: Colors.amber),
              SizedBox(width: 8),
              Expanded(child: Text('Passer au Forfait Gratuit')),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Votre abonnement payant actuel reste pleinement actif jusqu\'au ${AppDateFormatter.formatDateLong(_details.expiresAt)}.',
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: AppSpacing.sm),
              const Text(
                'À la fin de cette période, votre compte basculera automatiquement sur le forfait gratuit (100% local, zéro frais à vie). Vos ventes et stocks resteront accessibles mais la sauvegarde Cloud cessera.',
                style: TextStyle(height: 1.35),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Annuler'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: Colors.amber.shade800),
              onPressed: () async {
                final messenger = ScaffoldMessenger.of(context);
                Navigator.pop(ctx);
                final remote = sl.isRegistered<SubscriptionRemoteService>() ? sl<SubscriptionRemoteService>() : null;
                if (remote != null) {
                  await remote.subscribe(planCode: 'FREE', durationDays: 3650, amount: 0);
                  await sl<SubscriptionController>().refreshFromRemote();
                  if (mounted) {
                    setState(() => _details = sl<SubscriptionController>().details);
                  }
                }
                messenger.showSnackBar(
                  const SnackBar(
                    content: Text('Votre passage au forfait gratuit a été enregistré avec succès.'),
                    backgroundColor: Colors.green,
                  ),
                );
              },
              child: const Text('Confirmer le passage en Gratuit'),
            ),
          ],
        ),
      );
      return;
    }

    // 2. Cas d'un forfait payant (Renouvellement ou Changement)
    showDialog<void>(
      context: context,
      builder: (ctx) {
        return FutureBuilder<Map<String, dynamic>?>(
          future: sl.isRegistered<SubscriptionRemoteService>()
              ? sl<SubscriptionRemoteService>().previewSwitch(targetPlanCode: targetPlanCode, durationDays: _durationDays)
              : null,
          builder: (dialogCtx, snapshot) {
            final preview = snapshot.data;
            final bonusDays = (preview?['bonusDays'] as num?)?.toInt() ?? 0;
            final transitionType = preview?['transitionType']?.toString() ?? (isCurrent ? 'RENEWAL' : 'UPGRADE');
            final message = preview?['message']?.toString() ??
                (isCurrent
                    ? 'Votre formule actuelle sera prolongée de $_billingCycleLabel sans interruption.'
                    : 'Votre nouveau forfait s\'activera immédiatement.');

            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
              title: Text(isCurrent ? 'Renouveler $targetPlanName' : 'Changer pour $targetPlanName'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (snapshot.connectionState == ConnectionState.waiting) ...[
                      const Center(
                        child: Padding(
                          padding: EdgeInsets.all(16),
                          child: CircularProgressIndicator(),
                        ),
                      ),
                    ] else ...[
                      // Badge de transition
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: transitionType == 'UPGRADE'
                              ? Colors.purple.shade50
                              : (transitionType == 'RENEWAL' ? Colors.blue.shade50 : Colors.amber.shade50),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: transitionType == 'UPGRADE'
                                ? Colors.purple.shade200
                                : (transitionType == 'RENEWAL' ? Colors.blue.shade200 : Colors.amber.shade200),
                          ),
                        ),
                        child: Text(
                          transitionType == 'UPGRADE'
                              ? '🚀 Montée en gamme (Upgrade immédiat)'
                              : (transitionType == 'RENEWAL'
                                  ? '🔄 Prolongation de forfait'
                                  : 'ℹ️ Changement de formule'),
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                            color: transitionType == 'UPGRADE'
                                ? Colors.purple.shade900
                                : (transitionType == 'RENEWAL' ? Colors.blue.shade900 : Colors.amber.shade900),
                          ),
                        ),
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      Text(message, style: const TextStyle(height: 1.4)),
                      if (bonusDays > 0) ...[
                        const SizedBox(height: AppSpacing.sm),
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.green.shade50,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.green.shade300),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.card_giftcard, size: 20, color: Colors.green.shade700),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  '+$bonusDays jours bonus offerts grâce au report de votre ancien forfait !',
                                  style: TextStyle(color: Colors.green.shade900, fontWeight: FontWeight.bold, fontSize: 12),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
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
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogCtx),
                  child: const Text('Annuler'),
                ),
                FilledButton(
                  onPressed: () {
                    Navigator.pop(dialogCtx);
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
            );
          },
        );
      },
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

    final statusBgColor = switch (_details.status.toUpperCase()) {
      'ACTIVE' || 'TRIAL' => Colors.green,
      'GRACE' || 'PENDING_ACTIVATION' => Colors.amber.shade800,
      'REVOKED' || 'SUSPENDED' || 'EXPIRED' => Colors.red.shade700,
      _ => Colors.blueGrey,
    };

    final statusIcon = switch (_details.status.toUpperCase()) {
      'ACTIVE' || 'TRIAL' => Icons.check_circle,
      'GRACE' || 'PENDING_ACTIVATION' => Icons.access_time_filled,
      'REVOKED' || 'SUSPENDED' || 'EXPIRED' => Icons.block,
      _ => Icons.info,
    };

    final bodyContent = RefreshIndicator(
      onRefresh: () => _loadSubscriptionFromDatabase(forceRefresh: true),
      child: ListView(
        padding: const EdgeInsets.all(AppSpacing.md),
        children: [
          if (_isLoading && _packages.isEmpty) ...[
            Card(
              margin: const EdgeInsets.only(bottom: AppSpacing.md),
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.xl),
                child: Column(
                  children: [
                    const CircularProgressIndicator(),
                    const SizedBox(height: AppSpacing.md),
                    Text(
                      'Chargement des offres et options ARIKE...',
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      'Vérification des tarifs et privilèges de votre boutique...',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: colorScheme.outline,
                          ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),
          ],
          if (_details.isRevoked) ...[
          Container(
            padding: const EdgeInsets.all(AppSpacing.md),
            margin: const EdgeInsets.only(bottom: AppSpacing.md),
            decoration: BoxDecoration(
              color: Colors.red.shade100,
              border: Border.all(color: Colors.red.shade700),
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
            child: Row(
              children: [
                Icon(Icons.block_rounded, color: Colors.red.shade900, size: 28),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    '🚫 Accès Révoqué : Votre licence a été révoquée par l\'administration. Veuillez souscrire à un forfait pour rétablir vos accès.',
                    style: TextStyle(
                      color: Colors.red.shade900,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ] else if (widget.mandatoryGate) ...[
          Container(
            padding: const EdgeInsets.all(AppSpacing.md),
            margin: const EdgeInsets.only(bottom: AppSpacing.md),
            decoration: BoxDecoration(
              color: Colors.amber.shade100,
              border: Border.all(color: Colors.amber.shade700),
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
            child: Row(
              children: [
                Icon(Icons.warning_amber_rounded, color: Colors.amber.shade900, size: 28),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    'Abonnement requis : Veuillez souscrire au moins au forfait ARIKE Essentiel pour commencer à utiliser le système.',
                    style: TextStyle(
                      color: Colors.amber.shade900,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
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
                    Expanded(
                      child: Column(
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
                            formatPlanName(_details.planName),
                            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: colorScheme.primary,
                                ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Chip(
                      avatar: Icon(statusIcon, color: Colors.white, size: 16),
                      label: Text(formatSubscriptionStatus(_details.status)),
                      backgroundColor: statusBgColor,
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
                  if (_details.grantedModules.isNotEmpty) ...[
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      'Modules débloqués :',
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            color: colorScheme.outline,
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: _details.grantedModules.map((m) {
                        return Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: colorScheme.primaryContainer.withValues(alpha: 0.3),
                            borderRadius: BorderRadius.circular(AppRadius.sm),
                            border: Border.all(color: colorScheme.primary.withValues(alpha: 0.2)),
                          ),
                          child: Text(
                            formatModuleName(m),
                            style: TextStyle(
                              fontSize: 11,
                              color: colorScheme.primary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ],
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
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Forfaits ARIKE',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(height: AppSpacing.sm),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Container(
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
                        label: 'Trimestriel',
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
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),

          if (_packages.isEmpty && !_isLoading)
            Container(
              padding: const EdgeInsets.all(AppSpacing.lg),
              margin: const EdgeInsets.only(bottom: AppSpacing.md),
              decoration: BoxDecoration(
                color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(AppRadius.md),
                border: Border.all(color: colorScheme.outlineVariant),
              ),
              child: Column(
                children: [
                  Icon(Icons.wifi_off_rounded, size: 36, color: colorScheme.outline),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    'Souscription en ligne indisponible hors ligne',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    'Votre forfait actuel reste actif localement. Pour renouveler votre offre ou souscrire à de nouvelles options via Mobile Money, reconnectez votre appareil à Internet.',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: colorScheme.outline,
                          height: 1.35,
                        ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  FilledButton.tonalIcon(
                    onPressed: () => _loadSubscriptionFromDatabase(forceRefresh: true),
                    icon: const Icon(Icons.refresh_rounded, size: 18),
                    label: const Text('Réessayer la connexion'),
                  ),
                ],
              ),
            ),

          // 🔄 Cartes de forfaits générées dynamiquement depuis la base de données
          ..._packages.map((pkg) {
            final code = pkg['code']?.toString() ?? '';
            final name = pkg['name']?.toString() ?? 'Formule';
            final isPopular = pkg['isPopular'] == true || code == 'PRO';
            final title = isPopular && !name.contains('⭐') ? '⭐ $name' : name;
            final maxUsers = pkg['maxUsers'] ?? 1;
            final maxStores = pkg['maxStores'] ?? pkg['maxShops'] ?? 1;
            final quotas = '$maxUsers Utilisateur${maxUsers > 1 ? 's' : ''} · $maxStores Boutique${maxStores > 1 ? 's' : ''}';
            final price = _getPlanPrice(code);
            final modules = (pkg['includedModules'] as List?)?.map((e) => e.toString()).toList() ?? [];

            return Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.sm),
              child: _PlanCard(
                title: title,
                price: price,
                billingSuffix: _billingSuffix,
                quotas: quotas,
                features: modules,
                isCurrent: _details.planCode == code,
                isPopular: isPopular,
                onSelect: () => _showChangePlanDialog(context, code, title, price),
              ),
            );
          }),
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
          ..._paidOptions.map((opt) {
            final title = opt['name']?.toString() ?? 'Option payante';
            final priceDisplay = opt['priceDisplay']?.toString() ?? '${opt['price']} FCFA';
            final description = opt['description']?.toString() ?? '';
            final code = opt['code']?.toString() ?? '';
            final price = (opt['price'] as num?)?.toDouble() ?? 0.0;
            final isGranted = _details.grantedModules.contains(title) || _details.grantedModules.contains(code);

            return Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.xs),
              child: _AddonCard(
                title: title,
                priceText: priceDisplay,
                subtitle: description,
                icon: _getOptionIcon(code),
                isGranted: isGranted,
                onAdd: () => _showMobileMoneyPaymentModal(
                  context,
                  targetPlanName: title,
                  price: price,
                  isAddon: true,
                ),
              ),
            );
          }),
          const SizedBox(height: AppSpacing.lg),

          // 💳 Carte 5: Historique des Abonnements, Paiements & Factures
          Card(
            elevation: 2,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.receipt_long, color: Theme.of(context).colorScheme.primary, size: 22),
                          const SizedBox(width: 8),
                          Text(
                            'Historique des abonnements',
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                          ),
                        ],
                      ),
                      IconButton(
                        onPressed: () => _loadSubscriptionFromDatabase(forceRefresh: true),
                        icon: const Icon(Icons.refresh, size: 20),
                        tooltip: 'Actualiser l\'historique',
                        visualDensity: VisualDensity.compact,
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  if (_details.paymentHistory.isEmpty) ...[
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.surfaceContainerLowest,
                        borderRadius: BorderRadius.circular(AppRadius.sm),
                        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant.withValues(alpha: 0.4)),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.history_toggle_off_rounded,
                            size: 38,
                            color: Theme.of(context).colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Aucune transaction enregistrée',
                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Vos renouvellements de forfaits et reçus de paiement Mobile Money s\'afficheront ici.',
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  ] else ...[
                    ..._details.paymentHistory.map(
                      (tx) => Card(
                        margin: const EdgeInsets.only(bottom: AppSpacing.xs),
                        elevation: 0,
                        color: Theme.of(context).colorScheme.surfaceContainerLowest,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(AppRadius.sm),
                          side: BorderSide(color: Theme.of(context).colorScheme.outlineVariant.withValues(alpha: 0.5)),
                        ),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(AppRadius.sm),
                          onTap: () => _showReceiptDialog(context, tx),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                            child: Row(
                              children: [
                                CircleAvatar(
                                  radius: 18,
                                  backgroundColor: tx.status.toUpperCase().contains('PAY')
                                      ? Colors.green.shade50
                                      : Colors.amber.shade50,
                                  child: Icon(
                                    tx.status.toUpperCase().contains('PAY')
                                        ? Icons.check_circle_outline
                                        : Icons.hourglass_top,
                                    color: tx.status.toUpperCase().contains('PAY')
                                        ? Colors.green.shade700
                                        : Colors.amber.shade800,
                                    size: 20,
                                  ),
                                ),
                                const SizedBox(width: AppSpacing.sm),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        '${tx.planName} — ${tx.amount.toStringAsFixed(0)} ${tx.currency}',
                                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        '${AppDateFormatter.formatDate(tx.date)} · ${tx.provider}',
                                        style: Theme.of(context).textTheme.bodySmall?.copyWith(fontSize: 11),
                                      ),
                                      if (tx.reference != null)
                                        Text(
                                          'Réf : ${tx.reference}',
                                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                                fontSize: 10,
                                                color: Theme.of(context).colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
                                              ),
                                        ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: AppSpacing.xs),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                      decoration: BoxDecoration(
                                        color: tx.status.toUpperCase().contains('PAY')
                                            ? Colors.green.shade100
                                            : Colors.amber.shade100,
                                        borderRadius: BorderRadius.circular(AppRadius.sm),
                                      ),
                                      child: Text(
                                        formatSubscriptionStatus(tx.status),
                                        style: TextStyle(
                                          color: tx.status.toUpperCase().contains('PAY')
                                              ? Colors.green.shade800
                                              : Colors.amber.shade900,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 10,
                                        ),
                                      ),
                                    ),
                                    if (tx.bonusDays > 0) ...[
                                      const SizedBox(height: 2),
                                      Text(
                                        '+${tx.bonusDays}j bonus',
                                        style: TextStyle(
                                          color: Colors.green.shade700,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 10,
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                                const SizedBox(width: 4),
                                const Icon(Icons.chevron_right, size: 18, color: Colors.grey),
                              ],
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
        ],
      ),
    );

    final scaffold = Scaffold(
      appBar: AppBar(
        title: const Text('Abonnement & Facturation ARIKE'),
        automaticallyImplyLeading: !widget.mandatoryGate,
      ),
      body: SizedBox(
        width: double.infinity,
        child: bodyContent,
      ),
    );

    return PopScope(
      canPop: !widget.mandatoryGate,
      child: scaffold,
    );
  }

  void _showReceiptDialog(BuildContext context, PaymentTransactionRecord tx) {
    final colorScheme = Theme.of(context).colorScheme;
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.lg)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.green.shade50,
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.receipt_long, color: Colors.green.shade700, size: 24),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Reçu de Paiement', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  Text('ARIKE SaaS Commercial', style: TextStyle(fontSize: 12, color: Colors.grey)),
                ],
              ),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Divider(),
              _buildReceiptRow('Référence :', tx.reference ?? tx.id),
              _buildReceiptRow('Date & Heure :', AppDateFormatter.formatDateLong(tx.date)),
              _buildReceiptRow('Formule / Plan :', tx.planName),
              if (tx.expiresAt != null)
                _buildReceiptRow('Période couverte :', 'Jusqu\'au ${AppDateFormatter.formatDate(tx.expiresAt!)}'),
              if (tx.bonusDays > 0)
                _buildReceiptRow('Report prorata :', '+${tx.bonusDays} jours bonus offerts'),
              _buildReceiptRow('Mode de règlement :', tx.provider),
              _buildReceiptRow('Statut :', tx.status, valueColor: Colors.green.shade800),
              const Divider(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Montant Réglé :', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  Text(
                    '${tx.amount.toStringAsFixed(0)} ${tx.currency}',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: colorScheme.primary),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.green.shade200),
                ),
                child: Row(
                  children: [
                    Icon(Icons.verified, size: 18, color: Colors.green.shade700),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Paiement certifié et synchronisé avec le serveur ARIKE.',
                        style: TextStyle(color: Colors.green.shade900, fontSize: 11, fontWeight: FontWeight.w500),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Fermer'),
          ),
        ],
      ),
    );
  }

  Widget _buildReceiptRow(String label, String value, {Color? valueColor}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              value,
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: valueColor),
              textAlign: TextAlign.end,
            ),
          ),
        ],
      ),
    );
  }
}

class _PlanCard extends StatelessWidget {
  const _PlanCard({
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
                Expanded(
                  child: Text(
                    title,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: isPopular ? colorScheme.primary : null,
                        ),
                  ),
                ),
                if (isCurrent)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.green.shade100,
                      borderRadius: BorderRadius.circular(AppRadius.sm),
                    ),
                    child: Text(
                      'ACTUEL',
                      style: TextStyle(
                        color: Colors.green.shade800,
                        fontWeight: FontWeight.bold,
                        fontSize: 10,
                      ),
                    ),
                  )
                else if (isPopular)
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
                      child: Text(formatModuleName(f), style: Theme.of(context).textTheme.bodySmall),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            SizedBox(
              width: double.infinity,
              child: isCurrent
                  ? (price == 0
                      ? OutlinedButton(
                          onPressed: null,
                          child: const Text('Votre Forfait Actuel'),
                        )
                      : OutlinedButton.icon(
                          onPressed: onSelect,
                          icon: const Icon(Icons.refresh),
                          label: const Text('Renouveler ce forfait'),
                        ))
                  : (price == 0
                      ? OutlinedButton(
                          onPressed: onSelect,
                          child: const Text('Basculer en Forfait Gratuit'),
                        )
                      : FilledButton(
                          onPressed: onSelect,
                          child: const Text('Choisir ce forfait'),
                        )),
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
