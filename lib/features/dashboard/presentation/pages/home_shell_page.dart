import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../app/di/injection_container.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_tokens.dart';
import '../../../../core/auth/widgets/cloud_session_notice.dart';
import '../../../../core/responsive/breakpoints.dart';
import '../../../../core/responsive/responsive_builder.dart';
import '../../../../shared/enums/permission.dart';
import '../../../../shared/enums/user_role.dart';
import '../../../../shared/guards/permission_guard.dart';
import '../../../auth/domain/entities/auth_entities.dart';
import '../../../auth/presentation/bloc/auth_bloc.dart';
import '../../../shop/presentation/widgets/shop_switcher_sheet.dart';
import '../../../../core/network/widgets/offline_mode_banner.dart';
import '../../../../core/sync/sync_service.dart';
import '../../../../core/sync/sync_snapshot.dart';
import '../../../../core/sync/widgets/sync_status_indicator.dart';
import '../../../../shared/widgets/header_lock_button.dart';
import '../../../../core/notifications/notification_orchestrator.dart';
import '../../../../core/notifications/notification_permission_prompter.dart';
import '../../../sales/presentation/bloc/sale_list_bloc.dart';
import '../../../sales/presentation/pages/new_sale_page.dart';
import '../../../sales/presentation/pages/sale_list_page.dart';
import '../../../inventory/presentation/bloc/product_list_bloc.dart';
import '../../../inventory/presentation/pages/product_list_page.dart';
import '../../../customers/presentation/bloc/customer_list_bloc.dart';
import '../../../customers/presentation/pages/customer_list_page.dart';
import '../../../shop/presentation/pages/more_page.dart';
import '../../../fx_exchange/presentation/fx_workspace_mode_controller.dart';
import '../../../fx_exchange/presentation/pages/fx_exchange_page.dart';
import '../../../fx_exchange/domain/usecases/fx_exchange_usecases.dart';
import '../../../help/presentation/widgets/module_help_button.dart';
import '../../../subscription/domain/services/subscription_controller.dart';
import '../../../subscription/presentation/pages/subscription_page.dart';
import '../../../subscription/presentation/widgets/data_security_upgrade_modal.dart';
import '../../../voice_input/presentation/widgets/voice_assistant_fab.dart';
import '../../../audit/presentation/pages/audit_journal_page.dart';
import '../../../calculators/presentation/pages/calculators_page.dart';
import '../../../cash_sessions/presentation/pages/cash_sessions_page.dart';
import '../../../expenses/presentation/pages/expenses_page.dart';
import '../../../procurement/presentation/pages/procurement_page.dart';
import '../../../rbac/presentation/pages/roles_catalog_page.dart';
import '../../../reports/presentation/pages/reports_page.dart';
import '../../../sales_analysis/presentation/pages/sales_analysis_page.dart';
import '../../../sales_orders/presentation/pages/sales_orders_page.dart';
import '../../../settings/presentation/pages/settings_page.dart';
import '../../../shop/presentation/pages/shop_list_page.dart';
import '../../../stock_transfer/presentation/pages/stock_transfer_page.dart';
import '../../../users/presentation/pages/user_list_page.dart';
import '../bloc/dashboard_bloc.dart';
import '../models/sidebar_destination.dart';
import '../widgets/desktop_breadcrumb_header.dart';
import '../widgets/desktop_sidebar.dart';
import 'dashboard_page.dart';

class HomeShellPage extends StatefulWidget {
  const HomeShellPage({super.key, required this.session});

  final AuthSession session;

  @override
  State<HomeShellPage> createState() => _HomeShellPageState();
}

class _HomeShellPageState extends State<HomeShellPage> {
  int _currentIndex = 0;
  SidebarDestination _activeDestination = SidebarDestination.dashboard;
  FxWorkspaceModeController? _fxWorkspace;

  bool get _canViewFx => PermissionGuard.can(
        widget.session.user.permissions,
        Permission.fxExchangeRead,
      );

  bool get _useFxPrimary =>
      _canViewFx && (_fxWorkspace?.useFxPrimaryShell ?? false);

  SubscriptionController? _subController;

  late final DashboardBloc _dashboardBloc;
  late final SaleListBloc _saleListBloc;
  late final CustomerListBloc _customerListBloc;
  late final ProductListBloc _productListBloc;

  final _dashboardNavKey = GlobalKey<NavigatorState>();
  final _salesNavKey = GlobalKey<NavigatorState>();
  final _inventoryNavKey = GlobalKey<NavigatorState>();
  final _customersNavKey = GlobalKey<NavigatorState>();

  @override
  void initState() {
    super.initState();
    sl<SyncService>().scheduleSync(
      shopId: widget.session.shop.id,
      trigger: SyncTrigger.appStarted,
    );
    _dashboardBloc = DashboardBloc(
      getDashboard: sl(),
      session: widget.session,
      syncService: sl(),
    )..add(const DashboardLoadRequested());

    _saleListBloc = SaleListBloc(
      listSales: sl(),
      repository: sl(),
      syncPolicy: sl(),
      session: widget.session,
      syncService: sl(),
    )..add(const SaleListLoadRequested());

    _customerListBloc = CustomerListBloc(
      listCustomers: sl(),
      listDebtors: sl(),
      repository: sl(),
      saleRepository: sl(),
      syncPolicy: sl(),
      session: widget.session,
      syncService: sl(),
    )..add(const CustomerListLoadRequested());

    _productListBloc = ProductListBloc(
      listProducts: sl(),
      listCategories: sl(),
      repository: sl(),
      syncPolicy: sl(),
      session: widget.session,
      syncService: sl(),
    )..add(const ProductListLoadRequested());

    try {
      ensureFxExchangeDependencies();
      final workspace = sl<FxWorkspaceModeController>();
      _fxWorkspace = workspace;
      workspace.addListener(_onFxWorkspaceChanged);
    } catch (_) {}
    try {
      ensureSubscriptionDependencies();
      final subCtrl = sl<SubscriptionController>();
      _subController = subCtrl;
      subCtrl.addListener(_onSubscriptionChanged);
    } catch (_) {}
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await _bootstrapNotifications();
      await _loadFxWorkspaceMode();
      if (mounted) {
        await maybeShowCloudSessionStartupNotice(context);
        await _verifyMandatorySubscription();
      }
    });
  }

  void _onSubscriptionChanged() {
    if (!mounted) return;
    final controller = _subController;
    if (controller != null && (!controller.details.isActive || controller.details.isRevoked)) {
      _verifyMandatorySubscription();
    }
  }

  Future<void> _verifyMandatorySubscription() async {
    ensureSubscriptionDependencies();
    final controller = sl<SubscriptionController>();
    await controller.refreshFromRemote();
    if ((!controller.details.isActive || controller.details.isRevoked) && mounted) {
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => const SubscriptionPage(mandatoryGate: true),
        ),
      );
    } else if (controller.details.isDataAtRisk && mounted) {
      // Sensibilisation pédagogique obligatoire : invite l'utilisateur local à passer à un forfait sécurisé
      await DataSecurityUpgradeModal.show(context);
    }
  }

  @override
  void dispose() {
    _fxWorkspace?.removeListener(_onFxWorkspaceChanged);
    _subController?.removeListener(_onSubscriptionChanged);
    _dashboardBloc.close();
    _saleListBloc.close();
    _customerListBloc.close();
    _productListBloc.close();
    super.dispose();
  }

  void _onFxWorkspaceChanged() {
    if (!mounted) return;
    setState(() {
      _currentIndex = 0;
      _activeDestination = SidebarDestination.dashboard;
    });
  }

  Future<void> _loadFxWorkspaceMode() async {
    final workspace = _fxWorkspace;
    if (workspace == null) return;
    try {
      final shopId = widget.session.shop.id;
      final enabled = await sl<IsFxModuleEnabled>()(shopId: shopId);
      final primary = await sl<GetFxPrimaryWorkspace>()(shopId: shopId);
      workspace.apply(primary: primary, moduleEnabled: enabled);
      // Le listener _onFxWorkspaceChanged déclenchera un setState si le mode change.
    } catch (_) {}
  }

  Future<void> _bootstrapNotifications() async {
    try {
      ensureNotificationsDependencies();
      if (mounted && !kIsWeb && !Platform.isWindows) {
        await NotificationPermissionPrompter().maybePrompt(context);
      }
      final orchestrator = sl<NotificationOrchestrator>();
      orchestrator.bindShop(widget.session.shop.id);
      await orchestrator.processPending(shopId: widget.session.shop.id);
      if (!mounted) return;
      final link = orchestrator.deepLinks.consumePending();
      if (link != null) {
        orchestrator.deepLinks.handle(context, link, widget.session);
      }
    } catch (e) {
      debugPrint('Notification bootstrap error: $e');
    }
  }

  void _openNewSale(BuildContext context) {
    final isDesktop = Breakpoints.isDesktopWidth(MediaQuery.sizeOf(context).width);
    if (isDesktop) {
      _onSidebarDestinationSelected(SidebarDestination.sales);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _salesNavKey.currentState?.push(
          MaterialPageRoute(
            builder: (_) => NewSalePage(session: widget.session),
          ),
        ).then((created) async {
          if (created != true) return;
          _customerListBloc.add(const CustomerListLocalRefreshRequested());
          _saleListBloc.add(const SaleListLocalRefreshRequested());
          _productListBloc.add(const ProductListLocalRefreshRequested());
          _dashboardBloc.add(const DashboardRefreshRequested());
          try {
            await sl<NotificationOrchestrator>().processPending(
              shopId: widget.session.shop.id,
            );
          } catch (_) {}
        });
      });
      return;
    }

    Navigator.of(context)
        .push(
      MaterialPageRoute(
        builder: (_) => NewSalePage(session: widget.session),
      ),
    )
        .then((created) async {
      if (created != true) return;
      _customerListBloc.add(
            const CustomerListLocalRefreshRequested(),
          );
      _saleListBloc.add(const SaleListLocalRefreshRequested());
      _productListBloc.add(
            const ProductListLocalRefreshRequested(),
          );
      _dashboardBloc.add(const DashboardRefreshRequested());
      try {
        await sl<NotificationOrchestrator>().processPending(
          shopId: widget.session.shop.id,
        );
      } catch (_) {}
      if (!mounted) return;
      _onSidebarDestinationSelected(
        _useFxPrimary ? SidebarDestination.dashboard : SidebarDestination.sales,
      );
    });
  }

  void _openSalesTab() {
    _onSidebarDestinationSelected(SidebarDestination.sales);
  }

  void _openFxExchange(BuildContext context) {
    _onSidebarDestinationSelected(SidebarDestination.fxExchange);
  }

  void _openLowStockProducts(BuildContext context) {
    _onSidebarDestinationSelected(SidebarDestination.inventory);
    if (!_useFxPrimary) {
      _productListBloc.add(const ProductListLowStockToggled(true));
    }
  }

  void _openDebtors(BuildContext context) {
    _onSidebarDestinationSelected(SidebarDestination.customers);
    _customerListBloc.add(
          const CustomerListShowDebtorsToggled(true),
        );
  }

  void _onTabSelected(BuildContext context, int index) {
    setState(() {
      _currentIndex = index;
      if (!_useFxPrimary) {
        _activeDestination = switch (index) {
          0 => SidebarDestination.dashboard,
          1 => SidebarDestination.sales,
          2 => SidebarDestination.inventory,
          3 => SidebarDestination.customers,
          _ => SidebarDestination.dashboard,
        };
        if (index != 2) {
          _productListBloc.add(const ProductListLowStockToggled(false));
        }
        if (index != 3) {
          _customerListBloc.add(const CustomerListShowDebtorsToggled(false));
        }
        if (index == 0) {
          _dashboardBloc.add(const DashboardRefreshRequested());
        }
      } else {
        _activeDestination = switch (index) {
          0 => SidebarDestination.dashboard,
          1 => SidebarDestination.customers,
          _ => SidebarDestination.dashboard,
        };
        if (index != 1) {
          _customerListBloc.add(const CustomerListShowDebtorsToggled(false));
        }
      }
    });
  }

  void _onSidebarDestinationSelected(SidebarDestination destination) {
    setState(() {
      _activeDestination = destination;
      if (destination == SidebarDestination.dashboard) {
        _currentIndex = 0;
      } else if (destination == SidebarDestination.sales) {
        _currentIndex = _useFxPrimary ? 0 : 1;
      } else if (destination == SidebarDestination.inventory) {
        _currentIndex = 2;
      } else if (destination == SidebarDestination.customers) {
        _currentIndex = _useFxPrimary ? 1 : 3;
      }

      if (!_useFxPrimary) {
        if (destination != SidebarDestination.inventory) {
          _productListBloc.add(
                const ProductListLowStockToggled(false),
              );
        }
        if (destination != SidebarDestination.customers) {
          _customerListBloc.add(
                const CustomerListShowDebtorsToggled(false),
              );
        }
      } else if (destination != SidebarDestination.customers) {
        _customerListBloc.add(
              const CustomerListShowDebtorsToggled(false),
            );
      }
    });

    if (!_useFxPrimary && destination == SidebarDestination.dashboard) {
      _dashboardBloc.add(const DashboardRefreshRequested());
    }
  }

  Widget _buildDestinationWidget(SidebarDestination destination) {
    return switch (destination) {
      SidebarDestination.dashboard => _SubpageNavigator(
          key: const ValueKey('desktop_dashboard'),
          navigatorKey: _dashboardNavKey,
          child: DashboardPage(
            session: widget.session,
            onLowStockTap: () => _openLowStockProducts(context),
            onNewSaleTap: () => _openNewSale(context),
            onSalesHistoryTap: _openSalesTab,
            onDebtorsTap: () => _openDebtors(context),
            onFxExchangeTap: _canViewFx ? () => _openFxExchange(context) : null,
          ),
        ),
      SidebarDestination.sales => _SubpageNavigator(
          key: const ValueKey('desktop_sales'),
          navigatorKey: _salesNavKey,
          child: SaleListPage(session: widget.session),
        ),
      SidebarDestination.inventory => _SubpageNavigator(
          key: const ValueKey('desktop_inventory'),
          navigatorKey: _inventoryNavKey,
          child: ProductListPage(session: widget.session),
        ),
      SidebarDestination.customers => _SubpageNavigator(
          key: const ValueKey('desktop_customers'),
          navigatorKey: _customersNavKey,
          child: CustomerListPage(session: widget.session),
        ),
      SidebarDestination.cashSessions => _SubpageNavigator(
          key: const ValueKey('cashSessions'),
          child: CashSessionsPage(session: widget.session),
        ),
      SidebarDestination.expenses => _SubpageNavigator(
          key: const ValueKey('expenses'),
          child: ExpensesPage(session: widget.session),
        ),
      SidebarDestination.procurement => _SubpageNavigator(
          key: const ValueKey('procurement'),
          child: ProcurementPage(session: widget.session),
        ),
      SidebarDestination.salesOrders => _SubpageNavigator(
          key: const ValueKey('salesOrders'),
          child: SalesOrdersPage(session: widget.session),
        ),
      SidebarDestination.stockTransfer => _SubpageNavigator(
          key: const ValueKey('stockTransfer'),
          child: StockTransferPage(session: widget.session),
        ),
      SidebarDestination.reports => _SubpageNavigator(
          key: const ValueKey('reports'),
          child: ReportsPage(session: widget.session),
        ),
      SidebarDestination.salesAnalysis => _SubpageNavigator(
          key: const ValueKey('salesAnalysis'),
          child: SalesAnalysisPage(session: widget.session),
        ),
      SidebarDestination.calculators => _SubpageNavigator(
          key: const ValueKey('calculators'),
          child: CalculatorsPage(session: widget.session),
        ),
      SidebarDestination.fxExchange => _SubpageNavigator(
          key: const ValueKey('fxExchange'),
          child: FxExchangePage(session: widget.session),
        ),
      SidebarDestination.users => _SubpageNavigator(
          key: const ValueKey('users'),
          child: UserListPage(session: widget.session),
        ),
      SidebarDestination.roles => _SubpageNavigator(
          key: const ValueKey('roles'),
          child: RolesCatalogPage(session: widget.session),
        ),
      SidebarDestination.shops => _SubpageNavigator(
          key: const ValueKey('shops'),
          child: ShopListPage(session: widget.session),
        ),
      SidebarDestination.subscription => const _SubpageNavigator(
          key: ValueKey('subscription'),
          child: SubscriptionPage(),
        ),
      SidebarDestination.settings => _SubpageNavigator(
          key: const ValueKey('settings'),
          child: SettingsPage(session: widget.session),
        ),
      SidebarDestination.audit => _SubpageNavigator(
          key: const ValueKey('audit'),
          child: AuditJournalPage(session: widget.session),
        ),
    };
  }

  Widget _buildDesktopContent() {
    final isCore = _activeDestination == SidebarDestination.dashboard ||
        _activeDestination == SidebarDestination.sales ||
        _activeDestination == SidebarDestination.inventory ||
        _activeDestination == SidebarDestination.customers;

    if (!isCore) {
      return _buildDestinationWidget(_activeDestination);
    }

    final coreIndex = switch (_activeDestination) {
      SidebarDestination.dashboard => 0,
      SidebarDestination.sales => 1,
      SidebarDestination.inventory => 2,
      SidebarDestination.customers => 3,
      _ => 0,
    };

    return IndexedStack(
      index: coreIndex,
      children: [
        _buildDestinationWidget(SidebarDestination.dashboard),
        _buildDestinationWidget(SidebarDestination.sales),
        _buildDestinationWidget(SidebarDestination.inventory),
        _buildDestinationWidget(SidebarDestination.customers),
      ],
    );
  }

  /// Guide module pour l'onglet courant (null = déjà couvert ailleurs ou Plus).
  String? _helpArticleForTab(int index, bool useFx) {
    if (useFx) {
      return switch (index) {
        1 => 'customers',
        _ => null, // Change a son bouton ; Plus a Aide & guides
      };
    }
    return switch (index) {
      0 => 'dashboard',
      1 => 'sales',
      2 => 'inventory',
      3 => 'customers',
      _ => null,
    };
  }

  /// Ventes / Stock / Clients empilent déjà le micro au-dessus de leur FAB.
  bool _showShellVoiceFab(int index, bool useFx) {
    if (useFx) {
      // 0 Change, 1 Clients (FAB page), 2 Plus
      return index != 1;
    }
    // 0 Accueil, 1 Ventes, 2 Stock, 3 Clients, 4 Plus
    return index == 0 || index == 4;
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final canSwitchShop = widget.session.user.role == UserRole.owner ||
        PermissionGuard.can(
          widget.session.user.permissions,
          Permission.shopsSwitch,
        );
    final useFx = _useFxPrimary;
    final destinations = useFx
        ? const [
            NavigationDestination(
              icon: Icon(Icons.currency_exchange),
              selectedIcon: Icon(Icons.currency_exchange),
              label: 'Change',
            ),
            NavigationDestination(
              icon: Icon(Icons.people_outline),
              selectedIcon: Icon(Icons.people_rounded),
              label: 'Clients',
            ),
            NavigationDestination(
              icon: Icon(Icons.more_horiz),
              selectedIcon: Icon(Icons.more_horiz),
              label: 'Plus',
            ),
          ]
        : const [
            NavigationDestination(
              icon: Icon(Icons.home_outlined),
              selectedIcon: Icon(Icons.home_rounded),
              label: 'Accueil',
            ),
            NavigationDestination(
              icon: Icon(Icons.point_of_sale_outlined),
              selectedIcon: Icon(Icons.point_of_sale_rounded),
              label: 'Ventes',
            ),
            NavigationDestination(
              icon: Icon(Icons.inventory_2_outlined),
              selectedIcon: Icon(Icons.inventory_2_rounded),
              label: 'Stock',
            ),
            NavigationDestination(
              icon: Icon(Icons.people_outline),
              selectedIcon: Icon(Icons.people_rounded),
              label: 'Clients',
            ),
            NavigationDestination(
              icon: Icon(Icons.more_horiz),
              selectedIcon: Icon(Icons.more_horiz),
              label: 'Plus',
            ),
          ];

    final safeIndex = _currentIndex.clamp(0, destinations.length - 1);

    return MultiBlocProvider(
      providers: [
        BlocProvider.value(value: _dashboardBloc),
        BlocProvider.value(value: _saleListBloc),
        BlocProvider.value(value: _customerListBloc),
        BlocProvider.value(value: _productListBloc),
      ],
      child: ResponsiveBuilder(
        builder: (context, screenType) {
          final useRail = Breakpoints.useNavigationRail(screenType);
          // Affichage immédiat (Cache-First) : on ne bloque plus l'UI pendant
          // le chargement du mode FX. _fxWorkspaceReady passe à true en arrière-
          // plan et setState() met à jour silencieusement si le mode change.
          final content = _ShellContent(
                  session: widget.session,
                  currentIndex: safeIndex,
                  useFxPrimary: useFx,
                  showFxShortcut: _canViewFx &&
                      (_fxWorkspace?.moduleEnabled ?? false) &&
                      !(_fxWorkspace?.primary ?? false),
                  onLowStockTap: () => _openLowStockProducts(context),
                  onDebtorsTap: () => _openDebtors(context),
                  onNewSaleTap: () => _openNewSale(context),
                  onSalesHistoryTap: _openSalesTab,
                  onFxExchangeTap: () => _openFxExchange(context),
                );

          if (useRail) {
            return PopScope(
              canPop: false,
              onPopInvokedWithResult: (didPop, result) {
                if (didPop) return;
                final activeNav = switch (_activeDestination) {
                  SidebarDestination.dashboard => _dashboardNavKey.currentState,
                  SidebarDestination.sales => _salesNavKey.currentState,
                  SidebarDestination.inventory => _inventoryNavKey.currentState,
                  SidebarDestination.customers => _customersNavKey.currentState,
                  _ => null,
                };
                if (activeNav != null && activeNav.canPop()) {
                  activeNav.pop();
                  return;
                }
                if (_activeDestination != SidebarDestination.dashboard) {
                  _onSidebarDestinationSelected(SidebarDestination.dashboard);
                }
              },
              child: Scaffold(
                floatingActionButton: _showShellVoiceFab(safeIndex, useFx)
                    ? VoiceAssistantFab(session: widget.session)
                    : null,
                floatingActionButtonLocation:
                    FloatingActionButtonLocation.endFloat,
                body: Row(
                  children: [
                    DesktopSidebar(
                      session: widget.session,
                      activeDestination: _activeDestination,
                      onDestinationSelected: _onSidebarDestinationSelected,
                      onNewSale: () => _openNewSale(context),
                      useFxPrimary: useFx,
                    ),
                    Expanded(
                      child: Column(
                        children: [
                          DesktopBreadcrumbHeader(
                            session: widget.session,
                            activeDestination: _activeDestination,
                            onNavigateHome: () => _onSidebarDestinationSelected(
                              SidebarDestination.dashboard,
                            ),
                            onLock: () => context
                                .read<AuthBloc>()
                                .add(const AuthAppLockedRequested()),
                            helpArticleId: _activeDestination.helpArticleId,
                            useFxPrimary: useFx,
                          ),
                          const OfflineModeBanner(showWhenSynced: true),
                          Expanded(child: _buildDesktopContent()),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          }

          return Scaffold(
            floatingActionButton: _showShellVoiceFab(safeIndex, useFx)
                ? VoiceAssistantFab(session: widget.session)
                : null,
            floatingActionButtonLocation:
                FloatingActionButtonLocation.endFloat,
            body: Column(
              children: [
                _ShellHeader(
                  shopName: widget.session.shop.name,
                  userName: widget.session.user.name,
                  roleLabel: widget.session.user.roleLabel,
                  canSwitchShop: canSwitchShop,
                  onSwitchShop: canSwitchShop
                      ? () => ShopSwitcherSheet.show(context, widget.session)
                      : null,
                  onLock: () => context
                      .read<AuthBloc>()
                      .add(const AuthAppLockedRequested()),
                  compact: true,
                  session: widget.session,
                  helpArticleId: _helpArticleForTab(safeIndex, useFx),
                ),
                const OfflineModeBanner(showWhenSynced: true),
                Expanded(child: content),
              ],
            ),
            bottomNavigationBar: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (!useFx && safeIndex == 0)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(
                      AppSpacing.md,
                      AppSpacing.sm,
                      AppSpacing.md,
                      AppSpacing.xs,
                    ),
                    child: SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: () => _openNewSale(context),
                        icon: const Icon(Icons.add_rounded),
                        label: const Text('Nouvelle vente'),
                      ),
                    ),
                  ),
                Container(
                  decoration: BoxDecoration(
                    color: AppColors.surfaceCard,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.06),
                        blurRadius: 12,
                        offset: const Offset(0, -2),
                      ),
                    ],
                  ),
                  child: SafeArea(
                    top: false,
                    child: NavigationBar(
                      selectedIndex: safeIndex,
                      backgroundColor: Colors.transparent,
                      elevation: 0,
                      indicatorColor: colorScheme.primaryContainer,
                      onDestinationSelected: (index) =>
                          _onTabSelected(context, index),
                      destinations: destinations,
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _ShellContent extends StatelessWidget {
  const _ShellContent({
    required this.session,
    required this.currentIndex,
    required this.useFxPrimary,
    required this.showFxShortcut,
    required this.onLowStockTap,
    required this.onDebtorsTap,
    required this.onNewSaleTap,
    required this.onSalesHistoryTap,
    required this.onFxExchangeTap,
  });

  final AuthSession session;
  final int currentIndex;
  final bool useFxPrimary;
  final bool showFxShortcut;
  final VoidCallback onLowStockTap;
  final VoidCallback onDebtorsTap;
  final VoidCallback onNewSaleTap;
  final VoidCallback onSalesHistoryTap;
  final VoidCallback onFxExchangeTap;

  @override
  Widget build(BuildContext context) {
    final pages = useFxPrimary
        ? [
            FxExchangePage(session: session, embeddedInShell: true),
            CustomerListPage(session: session),
            MorePage(session: session),
          ]
        : [
            DashboardPage(
              session: session,
              onLowStockTap: onLowStockTap,
              onNewSaleTap: onNewSaleTap,
              onSalesHistoryTap: onSalesHistoryTap,
              onDebtorsTap: onDebtorsTap,
              onFxExchangeTap: showFxShortcut ? onFxExchangeTap : null,
            ),
            SaleListPage(session: session),
            ProductListPage(session: session),
            CustomerListPage(session: session),
            MorePage(session: session),
          ];

    return IndexedStack(
      index: currentIndex.clamp(0, pages.length - 1),
      children: pages,
    );
  }
}

class _ShellAvatar extends StatelessWidget {
  const _ShellAvatar({required this.label, required this.size});

  final String label;
  final double size;

  @override
  Widget build(BuildContext context) {
    final initial =
        label.isNotEmpty ? label.characters.first.toUpperCase() : '?';

    return Container(
      width: size,
      height: size,
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          colors: [AppColors.heroGradientStart, AppColors.heroGradientEnd],
        ),
      ),
      child: Center(
        child: Text(
          initial,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w800,
              ),
        ),
      ),
    );
  }
}

class _ShellHeader extends StatelessWidget {
  const _ShellHeader({
    required this.shopName,
    required this.userName,
    required this.roleLabel,
    required this.canSwitchShop,
    required this.onLock,
    required this.compact,
    this.onSwitchShop,
    this.session,
    this.helpArticleId,
  });

  final String shopName;
  final String userName;
  final String roleLabel;
  final bool canSwitchShop;
  final VoidCallback? onSwitchShop;
  final VoidCallback onLock;
  final bool compact;
  final AuthSession? session;
  final String? helpArticleId;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final horizontalPadding = Breakpoints.horizontalPadding(context.screenType);

    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(
        horizontalPadding,
        compact
            ? MediaQuery.paddingOf(context).top + AppSpacing.sm
            : AppSpacing.md,
        horizontalPadding,
        AppSpacing.md,
      ),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        border: Border(
          bottom: BorderSide(
            color: colorScheme.outlineVariant.withValues(alpha: 0.5),
          ),
        ),
      ),
      child: Row(
        children: [
          if (compact) ...[
            _ShellAvatar(label: shopName, size: 44),
            const SizedBox(width: AppSpacing.sm + 4),
          ],
          Expanded(
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: onSwitchShop,
                borderRadius: BorderRadius.circular(AppRadius.sm),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              shopName,
                              style: Theme.of(context).textTheme.titleMedium,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            Text(
                              '$userName · $roleLabel',
                              style: Theme.of(context).textTheme.bodySmall,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      if (canSwitchShop) ...[
                        const SizedBox(width: AppSpacing.xs),
                        Icon(
                          Icons.unfold_more_rounded,
                          size: 20,
                          color: colorScheme.primary,
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
          if (helpArticleId != null)
            ModuleHelpButton(articleId: helpArticleId!),
          HeaderLockButton(
            onLock: onLock,
            filledTonal: true,
          ),
          SyncStatusIndicator(session: session),
        ],
      ),
    );
  }
}

class _SubpageNavigator extends StatelessWidget {
  const _SubpageNavigator({
    super.key,
    required this.child,
    this.navigatorKey,
  });

  final Widget child;
  final GlobalKey<NavigatorState>? navigatorKey;

  @override
  Widget build(BuildContext context) {
    return Navigator(
      key: navigatorKey,
      onGenerateRoute: (settings) {
        return MaterialPageRoute(
          settings: settings,
          builder: (_) => child,
        );
      },
    );
  }
}
