import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../app/di/injection_container.dart';
import '../../../../app/theme/app_tokens.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../auth/domain/entities/auth_entities.dart';
import '../../../calculators/presentation/models/calculation_intent.dart';
import '../../../sales_analysis/domain/usecases/sales_analysis_usecases.dart';
import '../../../sales_analysis/presentation/utils/sales_analysis_formatters.dart';
import '../../domain/entities/sale_entities.dart';
import '../../domain/entities/sale_pricing_entities.dart';
import '../../../../shared/components/empty_list_placeholder.dart';
import '../../../../shared/components/ui_primitives.dart';
import '../../../../shared/components/app_header_actions.dart';
import '../bloc/new_sale_bloc.dart';
import '../widgets/sale_feedback.dart';
import '../../../help/presentation/widgets/module_help_button.dart';
import '../../../voice_input/domain/entities/voice_draft.dart';
import '../../../voice_input/domain/entities/voice_navigation_seeds.dart';
import '../../../voice_input/domain/services/voice_intent_parser.dart';
import '../../../voice_input/presentation/cubit/voice_input_cubit.dart';
import '../../../voice_input/presentation/widgets/voice_capture_button.dart';
import 'sale_receipt_page.dart';
import '../../../../shared/components/adaptive_modal.dart';

/// Page de création d'une vente.
///
/// [TabBar] + [IndexedStack] : le [TabController] pilote l'index ;
/// chaque enfant de la pile doit recevoir des contraintes bornées
/// ([StackFit.expand] + [SizedBox.expand]).
class NewSalePage extends StatefulWidget {
  const NewSalePage({
    super.key,
    required this.session,
    this.conversion,
    this.calculationIntent,
    this.voiceSeed,
    this.startGuidedVoiceSale = false,
  });

  final AuthSession session;
  final QuickSaleConversion? conversion;
  final CalculationIntent? calculationIntent;
  final VoiceSaleSeed? voiceSeed;

  /// Démarre le guide vocal : produit → quantité → prix → panier.
  final bool startGuidedVoiceSale;

  @override
  State<NewSalePage> createState() => _NewSalePageState();
}

class _NewSalePageState extends State<NewSalePage>
    with SingleTickerProviderStateMixin {
  int _step = 0;
  late final TabController _tabController;
  final _searchController = TextEditingController();
  final _searchFocusNode = FocusNode();
  bool _isGridView = true;
  NewSaleBloc? _saleBloc;
  bool _guidedVoiceStarted = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(_onTabIndexChanged);
  }

  void _onTabIndexChanged() {
    if (_tabController.indexIsChanging) return;
    setState(() {});
  }

  @override
  void dispose() {
    _saleBloc?.add(const NewSaleDraftAbandonRequested());
    _tabController.removeListener(_onTabIndexChanged);
    _tabController.dispose();
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ensureVoiceInputDependencies();
    return BlocProvider(
      create: (_) {
        _saleBloc = NewSaleBloc(
        listProducts: sl(),
        listCustomers: sl(),
        createStandardSale: sl(),
        createCustomer: sl(),
        settingsLocal: sl(),
        customerPrices: sl(),
        convertQuickSale: sl(),
        conversion: widget.conversion,
        calculationIntent: widget.calculationIntent,
        findOpenCashSession: sl(),
        formDraftStorage: sl(),
        session: widget.session,
      )..add(const NewSaleLoadRequested());
        return _saleBloc!;
      },
      child: BlocProvider(
        create: (_) => sl<VoiceInputCubit>(),
        child: BlocListener<NewSaleBloc, NewSaleState>(
        listenWhen: (prev, curr) =>
            prev.creatingCustomer && !curr.creatingCustomer,
        listener: (context, state) async {
          if (state.errorMessage != null) {
            await SaleFeedback.showErrorDialog(
              context,
              title: 'Création impossible',
              message: state.errorMessage!,
            );
            if (context.mounted) {
              context.read<NewSaleBloc>().add(const NewSaleErrorDismissed());
            }
          } else {
            await SaleFeedback.showSuccess(
              context: context,
              title: 'Client ajouté',
              message: 'Le nouveau client a été sélectionné pour la vente.',
            );
          }
        },
        child: BlocListener<NewSaleBloc, NewSaleState>(
        listenWhen: (prev, curr) {
          if (prev.status != curr.status) return true;
          if (curr.errorMessage != null &&
              prev.errorMessage != curr.errorMessage &&
              curr.status == NewSaleStatus.ready &&
              !(prev.creatingCustomer && !curr.creatingCustomer)) {
            return true;
          }
          return false;
        },
        listener: (context, state) async {
          if (state.status == NewSaleStatus.success &&
              state.createdSale != null) {
            final sale = state.createdSale!;
            await SaleFeedback.showSaleRegistered(context, sale: sale);
            if (!context.mounted) return;
            await Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => SaleReceiptPage(
                  session: widget.session,
                  sale: sale,
                ),
              ),
            );
            if (context.mounted) Navigator.of(context).pop(true);
            return;
          }

          if (state.errorMessage != null &&
              state.status == NewSaleStatus.ready) {
            await SaleFeedback.showErrorDialog(
              context,
              title: 'Action impossible',
              message: state.errorMessage!,
            );
            if (context.mounted) {
              context.read<NewSaleBloc>().add(const NewSaleErrorDismissed());
            }
          }
        },
        child: BlocListener<NewSaleBloc, NewSaleState>(
          listenWhen: (prev, curr) =>
              widget.calculationIntent != null &&
              prev.status != NewSaleStatus.ready &&
              curr.status == NewSaleStatus.ready &&
              curr.cart.isNotEmpty,
          listener: (context, state) {
            if (_tabController.index != 1) {
              _tabController.animateTo(1);
            }
          },
          child: BlocListener<NewSaleBloc, NewSaleState>(
            listenWhen: (prev, curr) =>
                widget.voiceSeed != null &&
                prev.status != NewSaleStatus.ready &&
                curr.status == NewSaleStatus.ready,
            listener: (context, state) {
              final seed = widget.voiceSeed;
              if (seed == null) return;
              _applyVoiceSeed(context, state, seed);
            },
            child: BlocListener<NewSaleBloc, NewSaleState>(
              listenWhen: (prev, curr) =>
                  widget.startGuidedVoiceSale &&
                  !_guidedVoiceStarted &&
                  prev.status != NewSaleStatus.ready &&
                  curr.status == NewSaleStatus.ready,
              listener: (context, state) {
                _guidedVoiceStarted = true;
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (!context.mounted) return;
                  _runGuidedVoiceSale(context);
                });
              },
              child: BlocBuilder<NewSaleBloc, NewSaleState>(
            builder: (context, state) {
              return Scaffold(
                resizeToAvoidBottomInset: true,
                appBar: AppBar(
                  title: Text(
                    widget.conversion != null
                        ? 'Convertir en vente standard'
                        : widget.calculationIntent != null
                            ? 'Vente depuis calculateur'
                            : (_step == 0 ? 'Nouvelle vente' : 'Paiement'),
                  ),
                  actions: [
                    VoiceCaptureButton(
                      expectedKind: VoiceIntentKind.sale,
                      onCapture: () => _runGuidedVoiceSale(context),
                    ),
                    const ModuleHelpButton(articleId: 'sales'),
                    const AppHeaderActions(),
                  ],
                ),
                body: Column(
                  children: [
                    const VoiceListeningBanner(),
                    Expanded(child: _buildBody(context, state)),
                  ],
                ),
              );
            },
          ),
          ),
          ),
        ),
      ),
      ),
      ),
    );
  }

  void _applyVoiceSeed(
    BuildContext context,
    NewSaleState saleState,
    VoiceSaleSeed seed,
  ) {
    final bloc = context.read<NewSaleBloc>();
    final effective = seed.effectiveLines;
    if (effective.isEmpty) {
      if (seed.customerId != null) {
        bloc.add(NewSaleCustomerSelected(seed.customerId));
      }
      return;
    }
    for (final line in effective) {
      final productId = line.productId;
      if (productId == null) continue;
      SaleProductOption? product;
      for (final p in saleState.products) {
        if (p.id == productId) {
          product = p;
          break;
        }
      }
      if (product == null) continue;
      bloc.add(NewSaleLineRemoved(productId));
      final qty = (line.quantity ?? 1).clamp(1, product.quantityInStock);
      bloc.add(NewSaleProductAdded(product, quantity: qty));
      if (line.unitPrice != null && line.unitPrice! > 0) {
        bloc.add(
          NewSaleLineUnitPriceChanged(
            productId: productId,
            unitPrice: line.unitPrice!,
          ),
        );
      }
    }
    if (seed.customerId != null) {
      bloc.add(NewSaleCustomerSelected(seed.customerId));
    }
    if (_tabController.index != 1) {
      _tabController.animateTo(1);
    }
  }

  Future<void> _runGuidedVoiceSale(BuildContext context) async {
    final cubit = context.read<VoiceInputCubit>();
    final parser = VoiceIntentParser();
    const formatHint =
        'Dites : produit Sac quantité 20\n'
        'ou : produit Sac quantité 20 prix 3000\n'
        'ou : produit Sac prix 3000 quantité 20\n'
        '(sans prix → prix boutique)';

    while (context.mounted) {
      final saleState = context.read<NewSaleBloc>().state;
      final catalogProducts = saleState.products
          .map(
            (p) => VoiceCatalogProduct(
              id: p.id,
              name: p.name,
              priceSell: p.priceSell,
              quantityInStock: p.quantityInStock,
            ),
          )
          .toList();

      final spoken = await showVoiceWorkflowPromptDialog(
        context: context,
        cubit: cubit,
        question: 'Ligne de vente',
        details: formatHint,
      );
      cubit.reset();
      if (!context.mounted || spoken == null || spoken.trim().isEmpty) return;

      final structured = parser.parseStructuredSaleLine(spoken);
      if (structured == null) {
        await showVoiceAssistantFailureDialog(
          context,
          message: 'Format non reconnu.\n\n$formatHint',
          kind: VoiceIntentKind.sale,
        );
        continue;
      }

      final catalog =
          parser.matchProductByName(structured.productQuery, catalogProducts);
      SaleProductOption? product;
      if (catalog != null) {
        for (final p in saleState.products) {
          if (p.id == catalog.id) {
            product = p;
            break;
          }
        }
      }
      if (product == null) {
        await showVoiceAssistantFailureDialog(
          context,
          message:
              'Produit introuvable : « ${structured.productQuery} ».',
          kind: VoiceIntentKind.sale,
        );
        continue;
      }
      if (structured.quantity > product.quantityInStock) {
        await showVoiceAssistantFailureDialog(
          context,
          message:
              'Stock insuffisant (${product.quantityInStock}) pour '
              '${product.name}.',
          kind: VoiceIntentKind.sale,
        );
        continue;
      }

      final unitPrice = structured.unitPrice ?? product.priceSell;
      _applyLineToCart(
        context,
        product: product,
        quantity: structured.quantity,
        unitPrice: unitPrice,
      );

      if (!context.mounted) return;
      final more = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => AlertDialog(
          title: const Text('ARIKE Assistant'),
          content: Text(
            '${product!.name} × ${structured.quantity} ajouté '
            '(${formatFcfa(unitPrice)}'
            '${structured.unitPrice == null ? ' — prix boutique' : ''}).\n\n'
            'Ajouter un autre produit ?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('C’est tout'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Ajouter un autre'),
            ),
          ],
        ),
      );
      if (more != true) break;
    }
  }

  void _applyLineToCart(
    BuildContext context, {
    required SaleProductOption product,
    required int quantity,
    required int unitPrice,
  }) {
    final bloc = context.read<NewSaleBloc>();
    bloc.add(NewSaleLineRemoved(product.id));
    final qty = quantity.clamp(1, product.quantityInStock);
    bloc.add(NewSaleProductAdded(product, quantity: qty));
    bloc.add(
      NewSaleLineUnitPriceChanged(
        productId: product.id,
        unitPrice: unitPrice,
      ),
    );
    if (_tabController.index != 1) {
      _tabController.animateTo(1);
    }
  }

  void _quickAddProduct(BuildContext context, SaleProductOption product) {
    if (product.quantityInStock <= 0) {
      SaleFeedback.showErrorMessage(
        context,
        'Stock épuisé pour « ${product.name} ».',
      );
      return;
    }
    context.read<NewSaleBloc>().add(
          NewSaleProductAdded(product, quantity: 1),
        );
  }

  void _onBarcodeSubmitted(
    BuildContext context,
    NewSaleState state,
    String rawQuery,
  ) {
    final query = rawQuery.trim();
    if (query.isEmpty) return;

    // Chercher correspondance exacte de nom ou correspondance unique
    final exactMatch = state.products.where(
      (p) => p.name.trim().toLowerCase() == query.toLowerCase(),
    ).toList();

    SaleProductOption? target;
    if (exactMatch.length == 1) {
      target = exactMatch.first;
    } else if (state.filteredProducts.length == 1) {
      target = state.filteredProducts.first;
    }

    if (target != null) {
      if (target.quantityInStock <= 0) {
        SaleFeedback.showErrorMessage(
          context,
          'Stock épuisé pour « ${target.name} ».',
        );
        return;
      }
      _quickAddProduct(context, target);
      _searchController.clear();
      context.read<NewSaleBloc>().add(const NewSaleSearchChanged(''));
      _searchFocusNode.requestFocus();
    } else if (state.filteredProducts.isEmpty) {
      SaleFeedback.showErrorMessage(
        context,
        'Aucun produit correspondant à « $query ».',
      );
    }
  }

  Future<void> _confirmClearCart(
    BuildContext context,
    NewSaleState state,
  ) async {
    if (state.cart.isEmpty) return;
    final confirmed = await SaleFeedback.confirm(
      context: context,
      title: 'Vider le panier',
      message: 'Voulez-vous retirer tous les articles du panier en cours ?',
    );
    if (confirmed == true && context.mounted) {
      final bloc = context.read<NewSaleBloc>();
      for (final line in state.cart) {
        bloc.add(NewSaleLineRemoved(line.productId));
      }
    }
  }

  Future<void> _confirmSubmit(BuildContext context, NewSaleState state) async {
    if (state.cart.isEmpty) {
      SaleFeedback.showErrorMessage(
        context,
        'Ajoutez au moins un produit au panier.',
      );
      return;
    }

    final conversion = widget.conversion;
    if (conversion != null && state.subtotal != conversion.targetTotal) {
      SaleFeedback.showErrorMessage(
        context,
        'Le panier doit totaliser exactement ${formatFcfa(conversion.targetTotal)}.',
      );
      return;
    }

    if (state.paymentMethod == PaymentMethod.credit &&
        state.selectedCustomerId == null) {
      SaleFeedback.showErrorMessage(
        context,
        'Veuillez sélectionner un client pour enregistrer une vente à crédit.',
      );
      return;
    }

    if (state.paymentMethod == PaymentMethod.mixed &&
        state.mixedRemaining != 0) {
      SaleFeedback.showErrorMessage(
        context,
        'Veuillez équilibrer la répartition du paiement mixte (reste ${formatFcfa(state.mixedRemaining)}).',
      );
      return;
    }

    final confirmed = await SaleFeedback.confirm(
      context: context,
      title:
          conversion != null ? 'Confirmer la conversion' : 'Confirmer la vente',
      message: conversion != null
          ? 'Convertir ${conversion.receiptLabel ?? 'la vente'} '
              'pour ${formatFcfa(state.subtotal)} ?'
          : 'Enregistrer ${formatFcfa(state.subtotal)} '
              'en ${state.paymentMethod.label} ?',
    );
    if (confirmed == true && context.mounted) {
      context.read<NewSaleBloc>().add(const NewSaleSubmitRequested());
    }
  }

  Widget _buildBody(BuildContext context, NewSaleState state) {
    if (state.status == NewSaleStatus.loading && state.products.isEmpty) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: AppSpacing.md),
            Text('Chargement des produits…'),
          ],
        ),
      );
    }

    if (!state.cashSessionOpen) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.point_of_sale_outlined,
                  size: 48, color: Theme.of(context).colorScheme.error),
              const SizedBox(height: AppSpacing.md),
              Text(
                'Caisse fermée',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: AppSpacing.sm),
              const Text(
                'Ouvrez la caisse depuis Plus → Gestion de caisse '
                'avant d\'enregistrer une vente.',
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    return _buildSaleFlow(context, state);
  }

  Widget _buildSaleFlow(BuildContext context, NewSaleState state) {
    if (state.status == NewSaleStatus.failure) {
      return _ErrorBody(
        message: state.errorMessage ?? 'Erreur de chargement',
        onRetry: () =>
            context.read<NewSaleBloc>().add(const NewSaleLoadRequested()),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final isDesktop = constraints.maxWidth >= 840;

        // Bannières contextuelles communes (conversion, estimation calculatrice, erreur)
        final topBanners = [
          if (widget.conversion != null)
            Material(
              color: Theme.of(context).colorScheme.primaryContainer,
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.md),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      widget.conversion!.receiptLabel ??
                          'Vente #${widget.conversion!.saleId}',
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      'Montant à répartir : ${formatFcfa(widget.conversion!.targetTotal)}',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      state.subtotal == widget.conversion!.targetTotal
                          ? 'Panier complet ✓'
                          : state.subtotal > widget.conversion!.targetTotal
                              ? 'Dépassement : ${formatFcfa(state.subtotal - widget.conversion!.targetTotal)}'
                              : 'Reste à ajouter : ${formatFcfa(widget.conversion!.targetTotal - state.subtotal)}',
                      style: TextStyle(
                        color: state.subtotal == widget.conversion!.targetTotal
                            ? Colors.green.shade700
                            : Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          if (widget.calculationIntent != null && widget.conversion == null)
            Material(
              color: Theme.of(context).colorScheme.secondaryContainer,
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.md),
                child: Text(
                  'Estimation : ${widget.calculationIntent!.productName} × '
                  '${widget.calculationIntent!.saleQuantity} '
                  '(prérempli dans le panier)',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ),
            ),
          if (state.errorMessage != null)
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md,
                vertical: AppSpacing.sm,
              ),
              child: ErrorBanner(message: state.errorMessage!),
            ),
        ];

        final loadingOverlay = state.status == NewSaleStatus.loading
            ? const ColoredBox(
                color: Color(0x66000000),
                child: Center(
                  child: Card(
                    child: Padding(
                      padding: EdgeInsets.all(AppSpacing.lg),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          CircularProgressIndicator(),
                          SizedBox(height: AppSpacing.sm),
                          Text('Actualisation…'),
                        ],
                      ),
                    ),
                  ),
                ),
              )
            : const SizedBox.shrink();

        // --- AFFICHAGE DESKTOP (2 Colonnes POS) ---
        if (isDesktop) {
          return _DesktopPosWorkspace(
            state: state,
            searchController: _searchController,
            searchFocusNode: _searchFocusNode,
            isGridView: _isGridView,
            onToggleView: (val) => setState(() => _isGridView = val),
            onProductSelected: (p) => _quickAddProduct(context, p),
            onSearchSubmitted: (q) => _onBarcodeSubmitted(context, state, q),
            onClearCart: () => _confirmClearCart(context, state),
            onCheckout: () => _confirmSubmit(context, state),
            topBanners: topBanners,
            loadingOverlay: loadingOverlay,
            conversion: widget.conversion,
          );
        }

        // --- AFFICHAGE MOBILE (Onglets classiques) ---
        return Stack(
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                ...topBanners,
                if (_step == 0)
                  Material(
                    color: Theme.of(context).colorScheme.surface,
                    child: TabBar(
                      controller: _tabController,
                      tabs: [
                        const Tab(text: 'Produits'),
                        Tab(
                          text: state.cart.isEmpty
                              ? 'Panier'
                              : 'Panier (${state.cart.length})',
                        ),
                      ],
                    ),
                  ),
                Expanded(
                  child: widget.conversion != null || _step == 0
                      ? IndexedStack(
                          index: _tabController.index,
                          sizing: StackFit.expand,
                          children: [
                            SizedBox.expand(
                              child: _ProductList(
                                state: state,
                                searchController: _searchController,
                              ),
                            ),
                            SizedBox.expand(
                              child: _CartPanel(state: state),
                            ),
                          ],
                        )
                      : _PaymentStep(state: state),
                ),
                _BottomBar(
                  step: _step,
                  state: state,
                  isConversion: widget.conversion != null,
                  targetTotal: widget.conversion?.targetTotal,
                  onBack: () => setState(() => _step = 0),
                  onNext: () {
                    if (widget.conversion != null) {
                      if (state.cart.isEmpty) {
                        SaleFeedback.showErrorMessage(
                          context,
                          'Ajoutez au moins un produit.',
                        );
                        _tabController.animateTo(1);
                        return;
                      }
                      if (state.subtotal != widget.conversion!.targetTotal) {
                        SaleFeedback.showErrorMessage(
                          context,
                          'Le panier doit totaliser '
                          '${formatFcfa(widget.conversion!.targetTotal)}.',
                        );
                        return;
                      }
                      _confirmSubmit(context, state);
                      return;
                    }
                    if (state.cart.isEmpty) {
                      SaleFeedback.showErrorMessage(
                        context,
                        'Ajoutez au moins un produit.',
                      );
                      _tabController.animateTo(1);
                      return;
                    }
                    setState(() => _step = 1);
                  },
                  onSubmit: () => _confirmSubmit(context, state),
                ),
              ],
            ),
            if (state.status == NewSaleStatus.loading) loadingOverlay,
          ],
        );
      },
    );
  }
}

class _ErrorBody extends StatelessWidget {
  const _ErrorBody({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: AppSpacing.md),
            FilledButton(onPressed: onRetry, child: const Text('Réessayer')),
          ],
        ),
      ),
    );
  }
}

Future<void> _handleEditUnitPrice(BuildContext context, CartLine line) async {
  final updated = await showDialog<int>(
    context: context,
    builder: (dialogContext) => _UnitPriceEditDialog(line: line),
  );
  if (updated == null || !context.mounted) return;

  final bloc = context.read<NewSaleBloc>();
  ensureSalesAnalysisDependencies();
  final range = await sl<GetProductSoldPriceRange>()(
    shopId: bloc.session.shop.id,
    productId: line.productId,
  );

  if (!context.mounted) return;

  if (isUnusuallyLowPrice(enteredPrice: updated, range: range)) {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        icon: Icon(
          Icons.warning_amber_rounded,
          color: Theme.of(ctx).colorScheme.error,
        ),
        title: const Text('Prix inhabituel'),
        content: Text(
          unusualPriceMessage(
            productName: line.productName,
            enteredPrice: updated,
            range: range,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Corriger'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Continuer'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
  }

  bloc.add(
    NewSaleLineUnitPriceChanged(
      productId: line.productId,
      unitPrice: updated,
    ),
  );
}

Future<void> _handleCreateCustomer(BuildContext context) async {
  final bloc = context.read<NewSaleBloc>();

  final result = await showAdaptiveAppModal<_NewCustomerSheetResult>(
    context: context,
    title: 'Nouveau client',
    icon: Icons.person_add_alt_1_outlined,
    maxWidth: 480,
    builder: (ctx) => const _CreateCustomerSheet(),
  );

  if (result != null && context.mounted) {
    bloc.add(
      NewSaleCreateCustomerRequested(
        name: result.name,
        phone: result.phone,
      ),
    );
  }
}

class _DesktopPosWorkspace extends StatelessWidget {
  const _DesktopPosWorkspace({
    required this.state,
    required this.searchController,
    required this.searchFocusNode,
    required this.isGridView,
    required this.onToggleView,
    required this.onProductSelected,
    required this.onSearchSubmitted,
    required this.onClearCart,
    required this.onCheckout,
    required this.topBanners,
    required this.loadingOverlay,
    this.conversion,
  });

  final NewSaleState state;
  final TextEditingController searchController;
  final FocusNode searchFocusNode;
  final bool isGridView;
  final ValueChanged<bool> onToggleView;
  final ValueChanged<SaleProductOption> onProductSelected;
  final ValueChanged<String> onSearchSubmitted;
  final VoidCallback onClearCart;
  final VoidCallback onCheckout;
  final List<Widget> topBanners;
  final Widget loadingOverlay;
  final QuickSaleConversion? conversion;

  @override
  Widget build(BuildContext context) {
    return Focus(
      autofocus: true,
      onKeyEvent: (node, event) {
        if (event is KeyDownEvent) {
          if (event.logicalKey == LogicalKeyboardKey.f1) {
            searchFocusNode.requestFocus();
            searchController.selection = TextSelection(
              baseOffset: 0,
              extentOffset: searchController.text.length,
            );
            return KeyEventResult.handled;
          }
          if (event.logicalKey == LogicalKeyboardKey.f2) {
            if (state.cart.isNotEmpty) {
              onCheckout();
              return KeyEventResult.handled;
            }
          }
          if (event.logicalKey == LogicalKeyboardKey.escape) {
            if (searchController.text.isNotEmpty) {
              searchController.clear();
              context.read<NewSaleBloc>().add(const NewSaleSearchChanged(''));
              return KeyEventResult.handled;
            }
          }
        }
        return KeyEventResult.ignored;
      },
      child: Stack(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ...topBanners,
              Expanded(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Volet Gauche : Catalogue et recherche
                    Expanded(
                      flex: 6,
                      child: _DesktopProductCatalog(
                        state: state,
                        searchController: searchController,
                        searchFocusNode: searchFocusNode,
                        isGridView: isGridView,
                        onToggleView: onToggleView,
                        onProductSelected: onProductSelected,
                        onSearchSubmitted: onSearchSubmitted,
                      ),
                    ),
                    const VerticalDivider(width: 1),
                    // Volet Droit : Panier direct & Règlement
                    Expanded(
                      flex: 4,
                      child: _DesktopTicketPanel(
                        state: state,
                        onClearCart: onClearCart,
                        onCheckout: onCheckout,
                        isConversion: conversion != null,
                        targetTotal: conversion?.targetTotal,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (state.status == NewSaleStatus.loading) loadingOverlay,
        ],
      ),
    );
  }
}

class _KeyboardShortcutPill extends StatelessWidget {
  const _KeyboardShortcutPill({
    required this.label,
    required this.description,
  });

  final String label;
  final String description;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(AppRadius.xs),
        border: Border.all(
          color: cs.outlineVariant.withValues(alpha: 0.6),
          width: 0.8,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
            decoration: BoxDecoration(
              color: cs.surface,
              borderRadius: BorderRadius.circular(3),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.08),
                  blurRadius: 1,
                  offset: const Offset(0, 1),
                ),
              ],
            ),
            child: Text(
              label,
              style: TextStyle(
                fontFamily: 'monospace',
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: cs.primary,
              ),
            ),
          ),
          const SizedBox(width: 5),
          Text(
            description,
            style: TextStyle(
              fontSize: 11,
              color: cs.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

class _DesktopProductCatalog extends StatelessWidget {
  const _DesktopProductCatalog({
    required this.state,
    required this.searchController,
    required this.searchFocusNode,
    required this.isGridView,
    required this.onToggleView,
    required this.onProductSelected,
    required this.onSearchSubmitted,
  });

  final NewSaleState state;
  final TextEditingController searchController;
  final FocusNode searchFocusNode;
  final bool isGridView;
  final ValueChanged<bool> onToggleView;
  final ValueChanged<SaleProductOption> onProductSelected;
  final ValueChanged<String> onSearchSubmitted;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final products = state.filteredProducts;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // En-tête : Raccourcis clavier & Compteur
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.md,
            AppSpacing.sm,
            AppSpacing.md,
            0,
          ),
          child: Row(
            children: [
              const _KeyboardShortcutPill(label: 'F1', description: 'Recherche'),
              const SizedBox(width: AppSpacing.sm),
              const _KeyboardShortcutPill(label: 'Entrée', description: 'Scanner / Ajout'),
              const SizedBox(width: AppSpacing.sm),
              const _KeyboardShortcutPill(label: 'F2', description: 'Encaisser'),
              const Spacer(),
              Text(
                '${products.length} produit(s) affiché(s)',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: cs.outline,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.sm),

        // Barre d'outils : Recherche / Code-barres & Switcher Grille/Liste
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: searchController,
                  focusNode: searchFocusNode,
                  decoration: InputDecoration(
                    prefixIcon: const Icon(Icons.search_rounded),
                    suffixIcon: searchController.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear_rounded, size: 18),
                            onPressed: () {
                              searchController.clear();
                              context
                                  .read<NewSaleBloc>()
                                  .add(const NewSaleSearchChanged(''));
                            },
                          )
                        : null,
                    hintText: 'Rechercher un produit, code-barres (F1)…',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppRadius.sm),
                    ),
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.md,
                      vertical: 10,
                    ),
                  ),
                  onChanged: (q) =>
                      context.read<NewSaleBloc>().add(NewSaleSearchChanged(q)),
                  onSubmitted: onSearchSubmitted,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              SegmentedButton<bool>(
                segments: const [
                  ButtonSegment(
                    value: true,
                    icon: Icon(Icons.grid_view_rounded, size: 18),
                    tooltip: 'Affichage Grille POS',
                  ),
                  ButtonSegment(
                    value: false,
                    icon: Icon(Icons.view_headline_rounded, size: 18),
                    tooltip: 'Affichage Liste compacte',
                  ),
                ],
                selected: {isGridView},
                onSelectionChanged: (set) => onToggleView(set.first),
                showSelectedIcon: false,
                style: const ButtonStyle(
                  visualDensity: VisualDensity.compact,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ),
            ],
          ),
        ),

        // Sélecteur de grille tarifaire (si activé pour l'enseigne)
        if (state.pricingTiersEnabled) ...[
          const SizedBox(height: AppSpacing.xs),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
            child: SegmentedButton<SalePricingTier>(
              segments: SalePricingTier.values
                  .map(
                    (tier) => ButtonSegment(
                      value: tier,
                      label: Text(tier.label),
                    ),
                  )
                  .toList(),
              selected: {state.selectedPricingTier},
              onSelectionChanged: (selection) {
                context.read<NewSaleBloc>().add(
                      NewSalePricingTierChanged(selection.first),
                    );
              },
              showSelectedIcon: false,
              style: const ButtonStyle(
                visualDensity: VisualDensity.compact,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
            ),
          ),
        ],

        const SizedBox(height: AppSpacing.xs),

        // Zone de produits (Grille ou Liste)
        Expanded(
          child: products.isEmpty
              ? state.products.isEmpty
                  ? EmptyListPlaceholder.refreshable(
                      icon: Icons.inventory_2_outlined,
                      title: 'Aucun produit disponible',
                      subtitle:
                          'Ajoutez des produits dans l’Inventaire, puis actualisez.',
                      onRefresh: () async {
                        context
                            .read<NewSaleBloc>()
                            .add(const NewSaleLoadRequested());
                        await context.read<NewSaleBloc>().stream.firstWhere(
                              (s) =>
                                  s.status == NewSaleStatus.ready ||
                                  s.status == NewSaleStatus.failure,
                            );
                      },
                    )
                  : const EmptyListPlaceholder(
                      embedded: true,
                      icon: Icons.search_off_outlined,
                      title: 'Aucun produit ne correspond à votre recherche',
                    )
              : RefreshIndicator(
                  onRefresh: () async {
                    context
                        .read<NewSaleBloc>()
                        .add(const NewSaleLoadRequested());
                    await context.read<NewSaleBloc>().stream.firstWhere(
                          (s) =>
                              s.status == NewSaleStatus.ready ||
                              s.status == NewSaleStatus.failure,
                        );
                  },
                  child: isGridView
                      ? GridView.builder(
                          physics: const AlwaysScrollableScrollPhysics(),
                          padding: const EdgeInsets.all(AppSpacing.md),
                          gridDelegate:
                              const SliverGridDelegateWithMaxCrossAxisExtent(
                            maxCrossAxisExtent: 210,
                            mainAxisSpacing: 10,
                            crossAxisSpacing: 10,
                            childAspectRatio: 0.84,
                          ),
                          itemCount: products.length,
                          itemBuilder: (context, index) {
                            final product = products[index];
                            final inCartIndex = state.cart
                                .indexWhere((l) => l.productId == product.id);
                            final inCart = inCartIndex >= 0
                                ? state.cart[inCartIndex]
                                : null;
                            final outOfStock = product.quantityInStock <= 0;
                            final unitPrice = product.catalogPrice(
                              state.selectedPricingTier,
                            );

                            return _DesktopProductGridCard(
                              product: product,
                              unitPrice: unitPrice,
                              inCartQuantity: inCart?.quantity ?? 0,
                              outOfStock: outOfStock,
                              onTap: () => onProductSelected(product),
                            );
                          },
                        )
                      : ListView.separated(
                          physics: const AlwaysScrollableScrollPhysics(),
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppSpacing.md,
                            vertical: AppSpacing.xs,
                          ),
                          itemCount: products.length,
                          separatorBuilder: (context, index) =>
                              const SizedBox(height: 6),
                          itemBuilder: (context, index) {
                            final product = products[index];
                            final inCartIndex = state.cart
                                .indexWhere((l) => l.productId == product.id);
                            final inCart = inCartIndex >= 0
                                ? state.cart[inCartIndex]
                                : null;
                            final outOfStock = product.quantityInStock <= 0;
                            final unitPrice = product.catalogPrice(
                              state.selectedPricingTier,
                            );

                            return _DesktopProductListRow(
                              product: product,
                              unitPrice: unitPrice,
                              inCartQuantity: inCart?.quantity ?? 0,
                              outOfStock: outOfStock,
                              onTap: () => onProductSelected(product),
                            );
                          },
                        ),
                ),
        ),
      ],
    );
  }
}

class _DesktopProductGridCard extends StatelessWidget {
  const _DesktopProductGridCard({
    required this.product,
    required this.unitPrice,
    required this.inCartQuantity,
    required this.outOfStock,
    required this.onTap,
  });

  final SaleProductOption product;
  final int unitPrice;
  final int inCartQuantity;
  final bool outOfStock;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Card(
      elevation: 0,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.sm),
        side: BorderSide(
          color: inCartQuantity > 0
              ? cs.primary.withValues(alpha: 0.5)
              : cs.outlineVariant.withValues(alpha: 0.6),
          width: inCartQuantity > 0 ? 1.5 : 1.0,
        ),
      ),
      color: outOfStock
          ? cs.surfaceContainerHighest.withValues(alpha: 0.3)
          : inCartQuantity > 0
              ? cs.primaryContainer.withValues(alpha: 0.08)
              : cs.surface,
      child: InkWell(
        onTap: outOfStock ? null : onTap,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.sm),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Zone visuelle supérieure : Icône, Badge Stock et Badge Panier
              Container(
                height: 56,
                decoration: BoxDecoration(
                  color: outOfStock
                      ? cs.surfaceContainerHighest.withValues(alpha: 0.5)
                      : cs.secondaryContainer.withValues(alpha: 0.35),
                  borderRadius: BorderRadius.circular(AppRadius.xs),
                ),
                child: Stack(
                  children: [
                    Center(
                      child: Icon(
                        Icons.inventory_2_outlined,
                        size: 26,
                        color: outOfStock
                            ? cs.outline
                            : cs.primary.withValues(alpha: 0.75),
                      ),
                    ),
                    // Badge Stock
                    Positioned(
                      top: 4,
                      left: 4,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: outOfStock
                              ? cs.errorContainer
                              : product.quantityInStock <= 5
                                  ? Colors.amber.shade100
                                  : Colors.green.shade50,
                          borderRadius: BorderRadius.circular(AppRadius.pill),
                          border: Border.all(
                            color: outOfStock
                                ? cs.error.withValues(alpha: 0.5)
                                : product.quantityInStock <= 5
                                    ? Colors.amber.shade700
                                    : Colors.green.shade600,
                            width: 0.5,
                          ),
                        ),
                        child: Text(
                          outOfStock
                              ? 'Épuisé'
                              : 'Stk: ${product.quantityInStock}',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: outOfStock
                                ? cs.error
                                : product.quantityInStock <= 5
                                    ? Colors.amber.shade900
                                    : Colors.green.shade800,
                          ),
                        ),
                      ),
                    ),
                    // Badge quantité dans panier
                    if (inCartQuantity > 0)
                      Positioned(
                        top: 4,
                        right: 4,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 7,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: cs.primary,
                            borderRadius:
                                BorderRadius.circular(AppRadius.pill),
                          ),
                          child: Text(
                            '× $inCartQuantity',
                            style: TextStyle(
                              color: cs.onPrimary,
                              fontWeight: FontWeight.bold,
                              fontSize: 11,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 8),

              // Nom du produit
              Expanded(
                child: Text(
                  product.name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    height: 1.25,
                  ),
                ),
              ),

              // Prix et Action rapide
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      formatFcfa(unitPrice),
                      style: theme.textTheme.titleSmall?.copyWith(
                        color: cs.primary,
                        fontWeight: FontWeight.w700,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Icon(
                    outOfStock
                        ? Icons.block_outlined
                        : inCartQuantity > 0
                            ? Icons.add_circle
                            : Icons.add_circle_outline,
                    size: 22,
                    color: outOfStock
                        ? cs.outline
                        : inCartQuantity > 0
                            ? cs.primary
                            : cs.onSurfaceVariant,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DesktopProductListRow extends StatelessWidget {
  const _DesktopProductListRow({
    required this.product,
    required this.unitPrice,
    required this.inCartQuantity,
    required this.outOfStock,
    required this.onTap,
  });

  final SaleProductOption product;
  final int unitPrice;
  final int inCartQuantity;
  final bool outOfStock;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Card(
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.xs),
        side: BorderSide(
          color: inCartQuantity > 0
              ? cs.primary.withValues(alpha: 0.4)
              : cs.outlineVariant.withValues(alpha: 0.5),
        ),
      ),
      color: outOfStock
          ? cs.surfaceContainerHighest.withValues(alpha: 0.3)
          : inCartQuantity > 0
              ? cs.primaryContainer.withValues(alpha: 0.08)
              : cs.surface,
      child: InkWell(
        onTap: outOfStock ? null : onTap,
        borderRadius: BorderRadius.circular(AppRadius.xs),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.sm,
            vertical: AppSpacing.xs,
          ),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: cs.secondaryContainer.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(AppRadius.xs),
                ),
                child: Icon(
                  Icons.inventory_2_outlined,
                  size: 20,
                  color: cs.primary,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      product.name,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Text(
                          outOfStock
                              ? 'Rupture'
                              : 'Stock ${product.quantityInStock}',
                          style: TextStyle(
                            fontSize: 11,
                            color: outOfStock
                                ? cs.error
                                : product.quantityInStock <= 5
                                    ? Colors.amber.shade900
                                    : Colors.green.shade800,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        if (inCartQuantity > 0) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 1,
                            ),
                            decoration: BoxDecoration(
                              color: cs.primary,
                              borderRadius:
                                  BorderRadius.circular(AppRadius.pill),
                            ),
                            child: Text(
                              'Panier: $inCartQuantity',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: cs.onPrimary,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Text(
                formatFcfa(unitPrice),
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: cs.primary,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              IconButton(
                visualDensity: VisualDensity.compact,
                icon: Icon(
                  outOfStock
                      ? Icons.block_outlined
                      : Icons.add_shopping_cart_rounded,
                  size: 20,
                  color: outOfStock ? cs.outline : cs.primary,
                ),
                tooltip: 'Ajouter au panier',
                onPressed: outOfStock ? null : onTap,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DesktopTicketPanel extends StatelessWidget {
  const _DesktopTicketPanel({
    required this.state,
    required this.onClearCart,
    required this.onCheckout,
    required this.isConversion,
    this.targetTotal,
  });

  final NewSaleState state;
  final VoidCallback onClearCart;
  final VoidCallback onCheckout;
  final bool isConversion;
  final int? targetTotal;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final cart = state.cart;

    return Material(
      color: cs.surfaceContainerLowest,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 1. Zone Client (Fixée en haut)
          Container(
            padding: const EdgeInsets.all(AppSpacing.sm),
            decoration: BoxDecoration(
              color: cs.surface,
              border: Border(
                bottom: BorderSide(
                  color: cs.outlineVariant.withValues(alpha: 0.5),
                ),
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<int?>(
                    isDense: true,
                    decoration: InputDecoration(
                      labelText: 'Client',
                      prefixIcon: const Icon(Icons.person_outline_rounded, size: 20),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(AppRadius.sm),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 8,
                      ),
                      isDense: true,
                    ),
                    key: ValueKey('desktop-customer-${state.selectedCustomerId}'),
                    initialValue: state.selectedCustomerId,
                    items: [
                      const DropdownMenuItem<int?>(
                        value: null,
                        child: Text(
                          'Client au comptoir (Anonyme)',
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      ...state.customers.map(
                        (c) => DropdownMenuItem<int?>(
                          value: c.id,
                          child: Text(
                            c.phone != null
                                ? '${c.name} (${c.phone})'
                                : c.name,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                    ],
                    onChanged: (id) => context.read<NewSaleBloc>().add(
                          NewSaleCustomerSelected(id),
                        ),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                IconButton.filledTonal(
                  tooltip: 'Créer un nouveau client',
                  icon: state.creatingCustomer
                      ? SaleFeedback.inlineLoader(size: 16)
                      : const Icon(Icons.person_add_outlined, size: 20),
                  onPressed: state.creatingCustomer
                      ? null
                      : () => _handleCreateCustomer(context),
                ),
              ],
            ),
          ),

          // 2. En-tête Ticket en cours
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.md,
              AppSpacing.sm,
              AppSpacing.md,
              AppSpacing.xs,
            ),
            child: Row(
              children: [
                Icon(
                  Icons.receipt_long_rounded,
                  color: cs.primary,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(
                  'Ticket en cours',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 7,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: cs.secondaryContainer,
                    borderRadius: BorderRadius.circular(AppRadius.pill),
                  ),
                  child: Text(
                    '${cart.length}',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: cs.onSecondaryContainer,
                    ),
                  ),
                ),
                const Spacer(),
                if (cart.isNotEmpty)
                  TextButton.icon(
                    style: TextButton.styleFrom(
                      foregroundColor: cs.error,
                      visualDensity: VisualDensity.compact,
                    ),
                    icon: const Icon(Icons.delete_sweep_outlined, size: 18),
                    label: const Text('Vider'),
                    onPressed: onClearCart,
                  ),
              ],
            ),
          ),

          // 3. Liste scrollable des lignes du panier
          Expanded(
            child: cart.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(AppSpacing.lg),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.shopping_cart_outlined,
                            size: 44,
                            color: cs.outlineVariant,
                          ),
                          const SizedBox(height: AppSpacing.sm),
                          Text(
                            'Le ticket est vide',
                            style: theme.textTheme.titleSmall?.copyWith(
                              color: cs.onSurfaceVariant,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Cliquez sur un produit à gauche ou scannez un code-barres.',
                            textAlign: TextAlign.center,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: cs.outline,
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.md,
                      vertical: AppSpacing.xs,
                    ),
                    itemCount: cart.length,
                    separatorBuilder: (context, index) =>
                        const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      final line = cart[index];
                      return Card(
                        elevation: 0,
                        margin: EdgeInsets.zero,
                        color: cs.surface,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(AppRadius.sm),
                          side: BorderSide(
                            color: cs.outlineVariant.withValues(alpha: 0.6),
                          ),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(AppSpacing.sm),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(
                                    child: Text(
                                      line.productName,
                                      style: theme.textTheme.bodyMedium
                                          ?.copyWith(
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                  IconButton(
                                    visualDensity: VisualDensity.compact,
                                    padding: EdgeInsets.zero,
                                    constraints: const BoxConstraints(
                                      minWidth: 28,
                                      minHeight: 28,
                                    ),
                                    icon: Icon(
                                      Icons.close_rounded,
                                      size: 18,
                                      color: cs.outline,
                                    ),
                                    tooltip: 'Retirer',
                                    onPressed: () => context
                                        .read<NewSaleBloc>()
                                        .add(NewSaleLineRemoved(line.productId)),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              Row(
                                children: [
                                  // Prix unitaire (modifiable si permission)
                                  InkWell(
                                    onTap: state.canOverridePrice
                                        ? () => _handleEditUnitPrice(
                                              context,
                                              line,
                                            )
                                        : null,
                                    borderRadius:
                                        BorderRadius.circular(AppRadius.xs),
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 2,
                                        horizontal: 4,
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Text(
                                            formatFcfa(line.unitPrice),
                                            style: TextStyle(
                                              fontSize: 13,
                                              fontWeight: FontWeight.w600,
                                              color: state.canOverridePrice
                                                  ? cs.primary
                                                  : cs.onSurfaceVariant,
                                              decoration:
                                                  state.canOverridePrice
                                                      ? TextDecoration.underline
                                                      : null,
                                            ),
                                          ),
                                          if (state.canOverridePrice) ...[
                                            const SizedBox(width: 3),
                                            Icon(
                                              Icons.edit_outlined,
                                              size: 13,
                                              color: cs.primary,
                                            ),
                                          ],
                                        ],
                                      ),
                                    ),
                                  ),
                                  const Spacer(),
                                  // Stepper quantité
                                  _QuantityInput(
                                    value: line.quantity,
                                    maxQuantity: line.stockAvailable,
                                    onChanged: (quantity) => context
                                        .read<NewSaleBloc>()
                                        .add(
                                          NewSaleLineQuantityChanged(
                                            productId: line.productId,
                                            quantity: quantity,
                                          ),
                                        ),
                                  ),
                                  const SizedBox(width: AppSpacing.sm),
                                  // Total ligne
                                  SizedBox(
                                    width: 75,
                                    child: Text(
                                      formatFcfa(line.quantity * line.unitPrice),
                                      textAlign: TextAlign.end,
                                      style: theme.textTheme.titleSmall
                                          ?.copyWith(
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),

          // 4. Volet de Règlement et Encaissement (Fixé en bas)
          Container(
            decoration: BoxDecoration(
              color: cs.surface,
              border: Border(
                top: BorderSide(
                  color: cs.outlineVariant.withValues(alpha: 0.7),
                ),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 6,
                  offset: const Offset(0, -2),
                ),
              ],
            ),
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                // Mode de paiement sous forme de Chips
                Text(
                  'Mode de règlement',
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: cs.outline,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 6),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: PaymentMethod.values.map((method) {
                      final isSelected = state.paymentMethod == method;
                      return Padding(
                        padding: const EdgeInsets.only(right: 6),
                        child: ChoiceChip(
                          label: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                switch (method) {
                                  PaymentMethod.cash =>
                                    Icons.payments_outlined,
                                  PaymentMethod.mtnMomo =>
                                    Icons.phone_android_rounded,
                                  PaymentMethod.moovMoney =>
                                    Icons.phone_iphone_rounded,
                                  PaymentMethod.credit =>
                                    Icons.credit_card_rounded,
                                  PaymentMethod.mixed =>
                                    Icons.call_split_rounded,
                                },
                                size: 16,
                                color: isSelected
                                    ? cs.onPrimary
                                    : cs.onSurfaceVariant,
                              ),
                              const SizedBox(width: 4),
                              Text(method.label),
                            ],
                          ),
                          selected: isSelected,
                          onSelected: (selected) {
                            if (selected) {
                              context.read<NewSaleBloc>().add(
                                    NewSalePaymentMethodChanged(method),
                                  );
                            }
                          },
                          showCheckmark: false,
                          visualDensity: VisualDensity.compact,
                        ),
                      );
                    }).toList(),
                  ),
                ),

                // Alerte crédit si client non sélectionné
                if (state.paymentMethod == PaymentMethod.credit &&
                    state.selectedCustomerId == null) ...[
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.sm,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.amber.shade50,
                      borderRadius: BorderRadius.circular(AppRadius.xs),
                      border: Border.all(color: Colors.amber.shade400),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.warning_amber_rounded,
                          size: 16,
                          color: Colors.amber.shade900,
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            'Vente à crédit : sélectionnez un client ci-dessus.',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.amber.shade900,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],

                // Détail montant paiement mixte
                if (state.paymentMethod == PaymentMethod.mixed) ...[
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: _AmountField(
                          label: 'Espèces',
                          value: state.mixedAmountCash,
                          onChanged: (v) => context.read<NewSaleBloc>().add(
                                NewSaleMixedAmountsChanged(amountCash: v),
                              ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: _AmountField(
                          label: 'MoMo',
                          value: state.mixedAmountMomo,
                          onChanged: (v) => context.read<NewSaleBloc>().add(
                                NewSaleMixedAmountsChanged(amountMomo: v),
                              ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: _AmountField(
                          label: 'Crédit',
                          value: state.mixedAmountCredit,
                          onChanged: (v) => context.read<NewSaleBloc>().add(
                                NewSaleMixedAmountsChanged(amountCredit: v),
                              ),
                        ),
                      ),
                    ],
                  ),
                  Text(
                    state.mixedRemaining == 0
                        ? 'Répartition complète ✓'
                        : 'Reste à répartir : ${formatFcfa(state.mixedRemaining)}',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: state.mixedRemaining == 0
                          ? Colors.green.shade700
                          : cs.error,
                    ),
                  ),
                ],

                const Divider(height: 16),

                // Montant Total
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Net à payer',
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: cs.onSurfaceVariant,
                      ),
                    ),
                    Text(
                      formatFcfa(state.subtotal),
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: cs.primary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.sm),

                // Bouton ENCAISSER
                SizedBox(
                  height: 48,
                  child: FilledButton.icon(
                    style: FilledButton.styleFrom(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppRadius.sm),
                      ),
                    ),
                    icon: state.status == NewSaleStatus.submitting
                        ? SaleFeedback.inlineLoader()
                        : const Icon(
                            Icons.point_of_sale_rounded,
                            size: 20,
                          ),
                    label: Text(
                      isConversion
                          ? 'VALIDER LA CONVERSION · ${formatFcfa(state.subtotal)}'
                          : 'ENCAISSER (F2) · ${formatFcfa(state.subtotal)}',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        letterSpacing: 0.3,
                      ),
                    ),
                    onPressed: state.cart.isEmpty ||
                            state.status == NewSaleStatus.submitting
                        ? null
                        : onCheckout,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ProductList extends StatelessWidget {
  const _ProductList({
    required this.state,
    required this.searchController,
  });

  final NewSaleState state;
  final TextEditingController searchController;

  @override
  Widget build(BuildContext context) {
    final products = state.filteredProducts;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.md,
            AppSpacing.sm,
            AppSpacing.md,
            0,
          ),
          child: TextField(
            controller: searchController,
            decoration: const InputDecoration(
              prefixIcon: Icon(Icons.search),
              hintText: 'Rechercher un produit…',
              border: OutlineInputBorder(),
              isDense: true,
            ),
            onChanged: (q) =>
                context.read<NewSaleBloc>().add(NewSaleSearchChanged(q)),
          ),
        ),
        if (state.pricingTiersEnabled) ...[
          const SizedBox(height: AppSpacing.sm),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
            child: SegmentedButton<SalePricingTier>(
              segments: SalePricingTier.values
                  .map(
                    (tier) => ButtonSegment(
                      value: tier,
                      label: Text(tier.label),
                    ),
                  )
                  .toList(),
              selected: {state.selectedPricingTier},
              onSelectionChanged: (selection) {
                context.read<NewSaleBloc>().add(
                      NewSalePricingTierChanged(selection.first),
                    );
              },
            ),
          ),
        ],
        Expanded(
          child: products.isEmpty
              ? state.products.isEmpty
                  ? EmptyListPlaceholder.refreshable(
                      icon: Icons.inventory_2_outlined,
                      title: 'Aucun produit disponible',
                      subtitle:
                          'Ajoutez des produits dans Inventaire, puis actualisez',
                      onRefresh: () async {
                        context
                            .read<NewSaleBloc>()
                            .add(const NewSaleLoadRequested());
                        await context.read<NewSaleBloc>().stream.firstWhere(
                              (s) =>
                                  s.status == NewSaleStatus.ready ||
                                  s.status == NewSaleStatus.failure,
                            );
                      },
                    )
                  : EmptyListPlaceholder(
                      embedded: true,
                      icon: Icons.search_off_outlined,
                      title: 'Aucun produit ne correspond à votre recherche',
                    )
              : RefreshIndicator(
                  onRefresh: () async {
                    context
                        .read<NewSaleBloc>()
                        .add(const NewSaleLoadRequested());
                    await context.read<NewSaleBloc>().stream.firstWhere(
                          (s) =>
                              s.status == NewSaleStatus.ready ||
                              s.status == NewSaleStatus.failure,
                        );
                  },
                  child: ListView.builder(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.all(AppSpacing.sm),
                    itemCount: products.length,
                    itemBuilder: (context, index) {
                      final product = products[index];
                      final inCartIndex = state.cart
                          .indexWhere((l) => l.productId == product.id);
                      final inCart =
                          inCartIndex >= 0 ? state.cart[inCartIndex] : null;
                      final outOfStock = product.quantityInStock <= 0;
                      return Card(
                        key: ValueKey('product-${product.id}'),
                        color: outOfStock
                            ? Theme.of(context)
                                .colorScheme
                                .surfaceContainerHighest
                                .withValues(alpha: 0.5)
                            : null,
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(
                            AppSpacing.md,
                            AppSpacing.sm,
                            AppSpacing.sm,
                            AppSpacing.sm,
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      product.name,
                                      style: Theme.of(context)
                                          .textTheme
                                          .titleMedium,
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      outOfStock
                                          ? '${formatFcfa(product.catalogPrice(state.selectedPricingTier))} · Rupture de stock'
                                          : '${formatFcfa(product.catalogPrice(state.selectedPricingTier))} · Stock ${product.quantityInStock}',
                                      style:
                                          Theme.of(context).textTheme.bodySmall,
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: AppSpacing.sm),
                              _ProductCartControls(
                                product: product,
                                cartLine: inCart,
                                outOfStock: outOfStock,
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
        ),
      ],
    );
  }
}

class _CartPanel extends StatelessWidget {
  const _CartPanel({required this.state});

  final NewSaleState state;

  List<CartLine> get cart => state.cart;
  int get total => state.subtotal;

  Future<void> _editUnitPrice(BuildContext context, CartLine line) =>
      _handleEditUnitPrice(context, line);

  @override
  Widget build(BuildContext context) {
    if (cart.isEmpty) {
      return LayoutBuilder(
        builder: (context, constraints) {
          return SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: constraints.maxHeight),
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  child: Text(
                    'Panier vide\nAjoutez des produits depuis l\'onglet Produits.',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyLarge,
                  ),
                ),
              ),
            ),
          );
        },
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.all(AppSpacing.sm),
            itemCount: cart.length,
            itemBuilder: (context, index) {
              final line = cart[index];
              return Card(
                key: ValueKey('cart-${line.productId}'),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.md,
                    AppSpacing.sm,
                    AppSpacing.sm,
                    AppSpacing.sm,
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              line.productName,
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                            const SizedBox(height: 2),
                            InkWell(
                              onTap: state.canOverridePrice
                                  ? () => _editUnitPrice(context, line)
                                  : null,
                              child: Text(
                                line.usedRememberedPrice
                                    ? '${formatFcfa(line.unitPrice)} / unité · dernier prix client'
                                    : line.isManualPrice
                                        ? '${formatFcfa(line.unitPrice)} / unité · prix modifié'
                                        : '${formatFcfa(line.unitPrice)} / unité',
                                style: Theme.of(context)
                                    .textTheme
                                    .bodySmall
                                    ?.copyWith(
                                      color: state.canOverridePrice
                                          ? Theme.of(context)
                                              .colorScheme
                                              .primary
                                          : null,
                                      decoration: state.canOverridePrice
                                          ? TextDecoration.underline
                                          : null,
                                    ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      _QuantityInput(
                        value: line.quantity,
                        maxQuantity: line.stockAvailable,
                        onChanged: (quantity) =>
                            context.read<NewSaleBloc>().add(
                                  NewSaleLineQuantityChanged(
                                    productId: line.productId,
                                    quantity: quantity,
                                  ),
                                ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
        ColoredBox(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Text(
              'Total panier : ${formatFcfa(total)}',
              style: Theme.of(context).textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
          ),
        ),
      ],
    );
  }
}

class _UnitPriceEditDialog extends StatefulWidget {
  const _UnitPriceEditDialog({required this.line});

  final CartLine line;

  @override
  State<_UnitPriceEditDialog> createState() => _UnitPriceEditDialogState();
}

class _UnitPriceEditDialogState extends State<_UnitPriceEditDialog> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: '${widget.line.unitPrice}');
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final value = int.tryParse(_controller.text.trim());
    if (value == null || value <= 0) return;
    Navigator.pop(context, value);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Prix — ${widget.line.productName}'),
      content: TextField(
        controller: _controller,
        autofocus: true,
        keyboardType: TextInputType.number,
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        decoration: InputDecoration(
          labelText: 'Prix unitaire (FCFA)',
          helperText: 'Catalogue : ${formatFcfa(widget.line.catalogUnitPrice)}',
        ),
        onSubmitted: (_) => _submit(),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Annuler'),
        ),
        FilledButton(
          onPressed: _submit,
          child: const Text('Appliquer'),
        ),
      ],
    );
  }
}

class _PaymentStep extends StatelessWidget {
  const _PaymentStep({required this.state});

  final NewSaleState state;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.md),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Text(
              'Total à payer : ${formatFcfa(state.subtotal)}',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        Text('Mode de paiement', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: AppSpacing.sm),
        ...PaymentMethod.values.map(
          (method) => RadioListTile<PaymentMethod>(
            title: Text(method.label),
            value: method,
            groupValue: state.paymentMethod,
            onChanged: (value) {
              if (value == null) return;
              context.read<NewSaleBloc>().add(
                    NewSalePaymentMethodChanged(value),
                  );
            },
          ),
        ),
        if (state.paymentMethod == PaymentMethod.mixed) ...[
          const SizedBox(height: AppSpacing.sm),
          _AmountField(
            label: 'Espèces (FCFA)',
            value: state.mixedAmountCash,
            onChanged: (v) => context.read<NewSaleBloc>().add(
                  NewSaleMixedAmountsChanged(amountCash: v),
                ),
          ),
          _AmountField(
            label: 'Mobile Money (FCFA)',
            value: state.mixedAmountMomo,
            onChanged: (v) => context.read<NewSaleBloc>().add(
                  NewSaleMixedAmountsChanged(amountMomo: v),
                ),
          ),
          _AmountField(
            label: 'Crédit (FCFA)',
            value: state.mixedAmountCredit,
            onChanged: (v) => context.read<NewSaleBloc>().add(
                  NewSaleMixedAmountsChanged(amountCredit: v),
                ),
          ),
          Text(
            state.mixedRemaining == 0
                ? 'Répartition complète ✓'
                : 'Reste à répartir : ${formatFcfa(state.mixedRemaining)}',
            style: TextStyle(
              color: state.mixedRemaining == 0
                  ? Colors.green.shade700
                  : Theme.of(context).colorScheme.error,
            ),
          ),
        ],
        const SizedBox(height: AppSpacing.lg),
        SizedBox(
          width: MediaQuery.sizeOf(context).width - 2 * AppSpacing.md,
          child: Row(
            children: [
              Text('Client', style: Theme.of(context).textTheme.titleMedium),
              const Spacer(),
              TextButton.icon(
                onPressed: state.creatingCustomer
                    ? null
                    : () => _showCreateCustomerSheet(context),
                icon: state.creatingCustomer
                    ? SaleFeedback.inlineLoader(size: 16)
                    : const Icon(Icons.person_add_outlined),
                label: Text(
                  state.creatingCustomer ? 'Création…' : 'Nouveau',
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        if (state.customers.isEmpty)
          const Text(
            'Aucun client disponible.',
          )
        else
          DropdownButtonFormField<int?>(
            decoration: const InputDecoration(
              labelText: 'Sélectionner un client',
              border: OutlineInputBorder(),
            ),
            initialValue: state.selectedCustomerId,
            items: [
              const DropdownMenuItem<int?>(
                value: null,
                child: Text('Aucun client (vente anonyme)'),
              ),
              ...state.customers.map(
                (c) => DropdownMenuItem<int?>(
                  value: c.id,
                  child: Text(
                    c.phone != null ? '${c.name} (${c.phone})' : c.name,
                  ),
                ),
              ),
            ],
            onChanged: (id) => context.read<NewSaleBloc>().add(
                  NewSaleCustomerSelected(id),
                ),
          ),
      ],
    );
  }

  Future<void> _showCreateCustomerSheet(BuildContext context) =>
      _handleCreateCustomer(context);
}

class _NewCustomerSheetResult {
  const _NewCustomerSheetResult({required this.name, this.phone});

  final String name;
  final String? phone;
}

class _CreateCustomerSheet extends StatefulWidget {
  const _CreateCustomerSheet();

  @override
  State<_CreateCustomerSheet> createState() => _CreateCustomerSheetState();
}

class _CreateCustomerSheetState extends State<_CreateCustomerSheet> {
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  void _submit() {
    final name = _nameController.text.trim();
    if (name.length < 2) return;
    final phone = _phoneController.text.trim();
    Navigator.pop(
      context,
      _NewCustomerSheetResult(
        name: name,
        phone: phone.isEmpty ? null : phone,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: _nameController,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'Nom *',
            border: OutlineInputBorder(),
            prefixIcon: Icon(Icons.person_outline),
          ),
          textCapitalization: TextCapitalization.words,
          onSubmitted: (_) => _submit(),
        ),
        const SizedBox(height: AppSpacing.md),
        TextField(
          controller: _phoneController,
          decoration: const InputDecoration(
            labelText: 'Téléphone (recommandé)',
            border: OutlineInputBorder(),
            prefixIcon: Icon(Icons.phone_outlined),
          ),
          keyboardType: TextInputType.phone,
          onSubmitted: (_) => _submit(),
        ),
        const SizedBox(height: AppSpacing.lg),
        FilledButton.icon(
          onPressed: _submit,
          icon: const Icon(Icons.check),
          label: const Text('Enregistrer le client'),
        ),
      ],
    );
  }
}

class _QuantityInput extends StatefulWidget {
  const _QuantityInput({
    this.value,
    required this.maxQuantity,
    this.onChanged,
    this.showPlusButton = true,
    this.allowRemove = true,
    super.key,
  });

  /// Si null, la quantité est gérée localement (sans rebuild parent).
  final int? value;
  final int maxQuantity;
  final ValueChanged<int>? onChanged;
  final bool showPlusButton;
  final bool allowRemove;

  @override
  State<_QuantityInput> createState() => _QuantityInputState();
}

class _QuantityInputState extends State<_QuantityInput> {
  late final TextEditingController _controller;
  late final FocusNode _focusNode;
  var _localValue = 1;
  var _editing = false;

  bool get _isControlled => widget.value != null;

  int get _displayValue => widget.value ?? _localValue;

  int commitAndRead() {
    _commit();
    return _displayValue;
  }

  @override
  void initState() {
    super.initState();
    _localValue = widget.value ?? 1;
    _controller = TextEditingController(text: '$_localValue');
    _focusNode = FocusNode();
    _focusNode.addListener(_onFocusChange);
  }

  void _onFocusChange() {
    if (!_focusNode.hasFocus && _editing) {
      _commit();
    }
  }

  @override
  void didUpdateWidget(covariant _QuantityInput oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_isControlled &&
        !_editing &&
        widget.value != oldWidget.value &&
        widget.value != null) {
      _controller.text = '${widget.value}';
    }
  }

  @override
  void dispose() {
    _focusNode.removeListener(_onFocusChange);
    _focusNode.dispose();
    _controller.dispose();
    super.dispose();
  }

  void _apply(int quantity) {
    if (quantity <= 0) {
      if (widget.allowRemove) {
        widget.onChanged?.call(0);
      } else if (!_isControlled) {
        setState(() => _localValue = 1);
        _controller.text = '1';
      }
      return;
    }

    final clamped = quantity.clamp(1, widget.maxQuantity);
    if (_isControlled) {
      widget.onChanged?.call(clamped);
    } else {
      setState(() => _localValue = clamped);
      _controller.text = '$clamped';
    }
  }

  void _commit() {
    final text = _controller.text.trim();
    if (text.isEmpty) {
      _controller.text = '$_displayValue';
      setState(() => _editing = false);
      return;
    }
    final parsed = int.tryParse(text) ?? _displayValue;
    _apply(parsed);
    setState(() => _editing = false);
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          visualDensity: VisualDensity.compact,
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
          icon: const Icon(Icons.remove_circle_outline),
          onPressed: _displayValue <= 1
              ? (widget.allowRemove ? () => _apply(0) : null)
              : () => _apply(_displayValue - 1),
        ),
        SizedBox(
          width: 52,
          child: TextField(
            controller: _controller,
            focusNode: _focusNode,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium,
            decoration: const InputDecoration(
              isDense: true,
              contentPadding: EdgeInsets.symmetric(horizontal: 4, vertical: 8),
              border: OutlineInputBorder(),
            ),
            onTap: () => setState(() => _editing = true),
            onSubmitted: (_) => _commit(),
            onChanged: (_) => _editing = true,
          ),
        ),
        if (widget.showPlusButton)
          IconButton(
            visualDensity: VisualDensity.compact,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
            icon: const Icon(Icons.add_circle_outline),
            onPressed: _displayValue >= widget.maxQuantity
                ? null
                : () => _apply(_displayValue + 1),
          ),
      ],
    );
  }
}

class _ProductCartControls extends StatefulWidget {
  const _ProductCartControls({
    required this.product,
    required this.cartLine,
    required this.outOfStock,
  });

  final SaleProductOption product;
  final CartLine? cartLine;
  final bool outOfStock;

  @override
  State<_ProductCartControls> createState() => _ProductCartControlsState();
}

class _ProductCartControlsState extends State<_ProductCartControls> {
  final _pendingQtyKey = GlobalKey<_QuantityInputState>();

  void _addToCart() {
    final qty = _pendingQtyKey.currentState?.commitAndRead() ?? 1;
    context.read<NewSaleBloc>().add(
          NewSaleProductAdded(widget.product, quantity: qty),
        );
  }

  @override
  Widget build(BuildContext context) {
    final cartLine = widget.cartLine;
    if (cartLine != null) {
      return _QuantityInput(
        value: cartLine.quantity,
        maxQuantity: cartLine.stockAvailable,
        onChanged: (quantity) => context.read<NewSaleBloc>().add(
              NewSaleLineQuantityChanged(
                productId: widget.product.id,
                quantity: quantity,
              ),
            ),
      );
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _QuantityInput(
          key: _pendingQtyKey,
          maxQuantity: widget.product.quantityInStock,
          showPlusButton: false,
          allowRemove: false,
        ),
        IconButton(
          visualDensity: VisualDensity.compact,
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
          icon: const Icon(Icons.add_shopping_cart_outlined),
          tooltip: 'Ajouter au panier',
          onPressed: widget.outOfStock ? null : _addToCart,
        ),
      ],
    );
  }
}

class _AmountField extends StatefulWidget {
  const _AmountField({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final int value;
  final ValueChanged<int> onChanged;

  @override
  State<_AmountField> createState() => _AmountFieldState();
}

class _AmountFieldState extends State<_AmountField> {
  late final TextEditingController _controller;
  late final FocusNode _focusNode;

  @override
  void initState() {
    super.initState();
    _focusNode = FocusNode();
    _controller = TextEditingController(text: _textForValue(widget.value));
  }

  @override
  void didUpdateWidget(covariant _AmountField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.value == oldWidget.value) return;

    final current = int.tryParse(_controller.text) ?? 0;
    if (widget.value != current && !_focusNode.hasFocus) {
      _controller.text = _textForValue(widget.value);
    }
  }

  String _textForValue(int value) => value > 0 ? '$value' : '';

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: TextFormField(
        controller: _controller,
        focusNode: _focusNode,
        decoration: InputDecoration(
          labelText: widget.label,
          border: const OutlineInputBorder(),
        ),
        keyboardType: TextInputType.number,
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        onChanged: (text) {
          final parsed = int.tryParse(text) ?? 0;
          if (parsed != widget.value) {
            widget.onChanged(parsed);
          }
        },
      ),
    );
  }
}

class _BottomBar extends StatelessWidget {
  const _BottomBar({
    required this.step,
    required this.state,
    required this.onBack,
    required this.onNext,
    required this.onSubmit,
    this.isConversion = false,
    this.targetTotal,
  });

  final int step;
  final NewSaleState state;
  final VoidCallback onBack;
  final VoidCallback onNext;
  final VoidCallback onSubmit;
  final bool isConversion;
  final int? targetTotal;

  static final _actionStyle = FilledButton.styleFrom(
    minimumSize: const Size(0, 44),
    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
  );

  @override
  Widget build(BuildContext context) {
    final submitting = state.status == NewSaleStatus.submitting;

    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Row(
          children: [
            if (step == 1)
              TextButton(
                onPressed: submitting ? null : onBack,
                child: const Text('Retour'),
              ),
            if (!isConversion && step == 0 && state.cart.isNotEmpty) ...[
              Expanded(
                child: Text(
                  formatFcfa(state.subtotal),
                  style: Theme.of(context).textTheme.titleMedium,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ] else
              const Spacer(),
            FilledButton(
              style: _actionStyle,
              onPressed: submitting
                  ? null
                  : (isConversion
                      ? onNext
                      : (step == 0 ? onNext : onSubmit)),
              child: submitting
                  ? SaleFeedback.inlineLoader()
                  : Text(
                      isConversion
                          ? 'Valider la conversion'
                          : (step == 0 ? 'Paiement' : 'Valider la vente'),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
