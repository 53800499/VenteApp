import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../app/di/injection_container.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_tokens.dart';
import '../../../../core/auth/widgets/cloud_session_notice.dart';
import '../../../../core/responsive/breakpoints.dart';
import '../../../../core/responsive/responsive_builder.dart';
import '../../../../core/responsive/screen_type.dart';
import '../../../../shared/enums/permission.dart';
import '../../../../shared/enums/user_role.dart';
import '../../../../shared/guards/permission_guard.dart';
import '../../../auth/domain/entities/auth_entities.dart';
import '../../../auth/presentation/bloc/auth_bloc.dart';
import '../../../shop/presentation/widgets/shop_switcher_sheet.dart';
import '../../../../core/network/widgets/offline_mode_banner.dart';
import '../../../../core/sync/widgets/sync_status_indicator.dart';
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
import '../../../voice_input/presentation/widgets/voice_assistant_fab.dart';
import '../bloc/dashboard_bloc.dart';
import 'dashboard_page.dart';

class HomeShellPage extends StatefulWidget {
  const HomeShellPage({super.key, required this.session});

  final AuthSession session;

  @override
  State<HomeShellPage> createState() => _HomeShellPageState();
}

class _HomeShellPageState extends State<HomeShellPage> {
  int _currentIndex = 0;
  FxWorkspaceModeController? _fxWorkspace;
  bool _fxWorkspaceReady = false;

  bool get _canViewFx => PermissionGuard.can(
        widget.session.user.permissions,
        Permission.fxExchangeRead,
      );

  bool get _useFxPrimary =>
      _canViewFx && (_fxWorkspace?.useFxPrimaryShell ?? false);

  @override
  void initState() {
    super.initState();
    try {
      ensureFxExchangeDependencies();
      final workspace = sl<FxWorkspaceModeController>();
      _fxWorkspace = workspace;
      workspace.addListener(_onFxWorkspaceChanged);
    } catch (_) {}
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await _bootstrapNotifications();
      await _loadFxWorkspaceMode();
      if (mounted) {
        await maybeShowCloudSessionStartupNotice(context);
      }
    });
  }

  @override
  void dispose() {
    _fxWorkspace?.removeListener(_onFxWorkspaceChanged);
    super.dispose();
  }

  void _onFxWorkspaceChanged() {
    if (!mounted) return;
    setState(() => _currentIndex = 0);
  }

  Future<void> _loadFxWorkspaceMode() async {
    final workspace = _fxWorkspace;
    if (workspace == null) {
      if (mounted) setState(() => _fxWorkspaceReady = true);
      return;
    }
    try {
      final shopId = widget.session.shop.id;
      final enabled = await sl<IsFxModuleEnabled>()(shopId: shopId);
      final primary = await sl<GetFxPrimaryWorkspace>()(shopId: shopId);
      workspace.apply(primary: primary, moduleEnabled: enabled);
    } catch (_) {}
    if (mounted) setState(() => _fxWorkspaceReady = true);
  }

  Future<void> _bootstrapNotifications() async {
    ensureNotificationsDependencies();
    if (mounted) {
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
  }

  void _openNewSale(BuildContext context) {
    Navigator.of(context)
        .push(
      MaterialPageRoute(
        builder: (_) => NewSalePage(session: widget.session),
      ),
    )
        .then((created) async {
      if (created != true || !context.mounted) return;
      context.read<CustomerListBloc>().add(
            const CustomerListLocalRefreshRequested(),
          );
      context.read<SaleListBloc>().add(const SaleListLocalRefreshRequested());
      context.read<ProductListBloc>().add(
            const ProductListLocalRefreshRequested(),
          );
      context.read<DashboardBloc>().add(const DashboardRefreshRequested());
      await sl<NotificationOrchestrator>().processPending(
        shopId: widget.session.shop.id,
      );
      if (!mounted) return;
      setState(() => _currentIndex = _useFxPrimary ? 0 : 1);
    });
  }

  void _openSalesTab() {
    setState(() => _currentIndex = _useFxPrimary ? 2 : 1);
  }

  void _openFxExchange(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => FxExchangePage(session: widget.session),
      ),
    );
  }

  void _openLowStockProducts(BuildContext context) {
    if (_useFxPrimary) {
      setState(() => _currentIndex = 2);
      return;
    }
    setState(() => _currentIndex = 2);
    context.read<ProductListBloc>().add(const ProductListLowStockToggled(true));
  }

  void _openDebtors(BuildContext context) {
    if (_useFxPrimary) {
      setState(() => _currentIndex = 1);
      context.read<CustomerListBloc>().add(
            const CustomerListShowDebtorsToggled(true),
          );
      return;
    }
    setState(() => _currentIndex = 3);
    context.read<ProductListBloc>().add(const ProductListLowStockToggled(false));
    context.read<CustomerListBloc>().add(
          const CustomerListShowDebtorsToggled(true),
        );
  }

  void _onTabSelected(BuildContext context, int index) {
    setState(() {
      _currentIndex = index;
      if (!_useFxPrimary) {
        if (index != 2) {
          context.read<ProductListBloc>().add(
                const ProductListLowStockToggled(false),
              );
        }
        if (index != 3) {
          context.read<CustomerListBloc>().add(
                const CustomerListShowDebtorsToggled(false),
              );
        }
      } else if (index != 1) {
        context.read<CustomerListBloc>().add(
              const CustomerListShowDebtorsToggled(false),
            );
      }
    });
    if (!_useFxPrimary && index == 0) {
      context.read<DashboardBloc>().add(const DashboardRefreshRequested());
    }
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
    final railDestinations = useFx
        ? const [
            NavigationRailDestination(
              icon: Icon(Icons.currency_exchange),
              selectedIcon: Icon(Icons.currency_exchange),
              label: Text('Change'),
            ),
            NavigationRailDestination(
              icon: Icon(Icons.people_outline),
              selectedIcon: Icon(Icons.people_rounded),
              label: Text('Clients'),
            ),
            NavigationRailDestination(
              icon: Icon(Icons.more_horiz),
              selectedIcon: Icon(Icons.more_horiz),
              label: Text('Plus'),
            ),
          ]
        : const [
            NavigationRailDestination(
              icon: Icon(Icons.home_outlined),
              selectedIcon: Icon(Icons.home_rounded),
              label: Text('Accueil'),
            ),
            NavigationRailDestination(
              icon: Icon(Icons.point_of_sale_outlined),
              selectedIcon: Icon(Icons.point_of_sale_rounded),
              label: Text('Ventes'),
            ),
            NavigationRailDestination(
              icon: Icon(Icons.inventory_2_outlined),
              selectedIcon: Icon(Icons.inventory_2_rounded),
              label: Text('Stock'),
            ),
            NavigationRailDestination(
              icon: Icon(Icons.people_outline),
              selectedIcon: Icon(Icons.people_rounded),
              label: Text('Clients'),
            ),
            NavigationRailDestination(
              icon: Icon(Icons.more_horiz),
              selectedIcon: Icon(Icons.more_horiz),
              label: Text('Plus'),
            ),
          ];

    final safeIndex = _currentIndex.clamp(0, destinations.length - 1);

    return MultiBlocProvider(
      providers: [
        BlocProvider(
          create: (_) => DashboardBloc(
            getDashboard: sl(),
            session: widget.session,
            syncService: sl(),
          )..add(const DashboardLoadRequested()),
        ),
        BlocProvider(
          create: (_) => SaleListBloc(
            listSales: sl(),
            repository: sl(),
            syncPolicy: sl(),
            session: widget.session,
            syncService: sl(),
          )..add(const SaleListLoadRequested()),
        ),
        BlocProvider(
          create: (_) => CustomerListBloc(
            listCustomers: sl(),
            listDebtors: sl(),
            repository: sl(),
            saleRepository: sl(),
            syncPolicy: sl(),
            session: widget.session,
            syncService: sl(),
          )..add(const CustomerListLoadRequested()),
        ),
        BlocProvider(
          create: (_) => ProductListBloc(
            listProducts: sl(),
            listCategories: sl(),
            repository: sl(),
            syncPolicy: sl(),
            session: widget.session,
            syncService: sl(),
          )..add(const ProductListLoadRequested()),
        ),
      ],
      child: ResponsiveBuilder(
        builder: (context, screenType) {
          final useRail = Breakpoints.useNavigationRail(screenType);
          final content = !_fxWorkspaceReady
              ? const Center(child: CircularProgressIndicator())
              : _ShellContent(
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
            return Scaffold(
              floatingActionButton: _showShellVoiceFab(safeIndex, useFx)
                  ? VoiceAssistantFab(session: widget.session)
                  : null,
              floatingActionButtonLocation:
                  FloatingActionButtonLocation.endFloat,
              body: Row(
                children: [
                  NavigationRail(
                    selectedIndex: safeIndex,
                    extended: screenType == ScreenType.expanded,
                    minWidth: Breakpoints.navigationRailWidth(screenType),
                    minExtendedWidth: 200,
                    labelType: screenType == ScreenType.expanded
                        ? NavigationRailLabelType.all
                        : NavigationRailLabelType.selected,
                    indicatorColor: colorScheme.primaryContainer,
                    onDestinationSelected: (index) =>
                        _onTabSelected(context, index),
                    leading: Padding(
                      padding: const EdgeInsets.only(top: AppSpacing.sm),
                      child: _ShellAvatar(
                        label: widget.session.shop.name,
                        size: screenType == ScreenType.expanded ? 48 : 40,
                      ),
                    ),
                    destinations: railDestinations,
                  ),
                  const VerticalDivider(width: 1),
                  Expanded(
                    child: Column(
                      children: [
                        _ShellHeader(
                          shopName: widget.session.shop.name,
                          userName: widget.session.user.name,
                          roleLabel: widget.session.user.roleLabel,
                          canSwitchShop: canSwitchShop,
                          onSwitchShop: canSwitchShop
                              ? () => ShopSwitcherSheet.show(
                                    context,
                                    widget.session,
                                  )
                              : null,
                          onLock: () => context
                              .read<AuthBloc>()
                              .add(const AuthAppLockedRequested()),
                          compact: false,
                          session: widget.session,
                          helpArticleId: _helpArticleForTab(safeIndex, useFx),
                        ),
                        const OfflineModeBanner(showWhenSynced: true),
                        Expanded(child: content),
                      ],
                    ),
                  ),
                ],
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

    return ResponsivePage(
      padding: EdgeInsets.zero,
      child: IndexedStack(
        index: currentIndex.clamp(0, pages.length - 1),
        children: pages,
      ),
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
          IconButton.filledTonal(
            onPressed: onLock,
            icon: const Icon(Icons.lock_outline_rounded),
            tooltip: 'Verrouiller',
          ),
          SyncStatusIndicator(session: session),
        ],
      ),
    );
  }
}
