import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../app/di/injection_container.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_tokens.dart';
import '../../../../core/responsive/breakpoints.dart';
import '../../../../core/responsive/responsive_builder.dart';
import '../../../../core/responsive/screen_type.dart';
import '../../../../shared/enums/permission.dart';
import '../../../../shared/enums/user_role.dart';
import '../../../../shared/guards/permission_guard.dart';
import '../../../auth/domain/entities/auth_entities.dart';
import '../../../auth/presentation/bloc/auth_bloc.dart';
import '../../../shop/presentation/widgets/shop_switcher_sheet.dart';
import '../../../inventory/presentation/pages/product_list_page.dart';
import '../../../shop/presentation/pages/more_page.dart';
import '../../../../shared/components/coming_soon_placeholder.dart';
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
  bool _lowStockFilter = false;
  int _stockTabKey = 0;

  void _showComingSoon(String label) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$label — bientôt disponible')),
    );
  }

  void _openLowStockProducts() {
    setState(() {
      _currentIndex = 2;
      _lowStockFilter = true;
      _stockTabKey++;
    });
  }

  void _onTabSelected(int index) {
    setState(() {
      _currentIndex = index;
      if (index != 2) _lowStockFilter = false;
    });
    if (index == 0) {
      context.read<DashboardBloc>().add(const DashboardRefreshRequested());
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final canSwitchShop = widget.session.user.role == UserRole.owner ||
        PermissionGuard.can(
          widget.session.user.permissions,
          Permission.shopsSwitch,
        );

    return BlocProvider(
      create: (_) => DashboardBloc(
        getDashboard: sl(),
        session: widget.session,
      ),
      child: ResponsiveBuilder(
        builder: (context, screenType) {
          final useRail = Breakpoints.useNavigationRail(screenType);
          final content = _ShellContent(
            session: widget.session,
            currentIndex: _currentIndex,
            stockTabKey: _stockTabKey,
            lowStockFilter: _lowStockFilter,
            onLowStockTap: _openLowStockProducts,
          );

          if (useRail) {
            return Scaffold(
              body: Row(
                children: [
                  NavigationRail(
                    selectedIndex: _currentIndex,
                    extended: screenType == ScreenType.expanded,
                    minWidth: Breakpoints.navigationRailWidth(screenType),
                    minExtendedWidth: 200,
                    labelType: screenType == ScreenType.expanded
                        ? NavigationRailLabelType.all
                        : NavigationRailLabelType.selected,
                    indicatorColor: colorScheme.primaryContainer,
                    onDestinationSelected: _onTabSelected,
                    leading: Padding(
                      padding: const EdgeInsets.only(top: AppSpacing.sm),
                      child: _ShellAvatar(
                        label: widget.session.shop.name,
                        size: screenType == ScreenType.expanded ? 48 : 40,
                      ),
                    ),
                    destinations: const [
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
                    ],
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
                        ),
                        Expanded(child: content),
                      ],
                    ),
                  ),
                ],
              ),
            );
          }

          return Scaffold(
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
                ),
                Expanded(child: content),
              ],
            ),
            bottomNavigationBar: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (_currentIndex == 0)
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
                        onPressed: () => _showComingSoon('Nouvelle vente'),
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
                      selectedIndex: _currentIndex,
                      backgroundColor: Colors.transparent,
                      elevation: 0,
                      indicatorColor: colorScheme.primaryContainer,
                      onDestinationSelected: _onTabSelected,
                      destinations: const [
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
                      ],
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
    required this.stockTabKey,
    required this.lowStockFilter,
    required this.onLowStockTap,
  });

  final AuthSession session;
  final int currentIndex;
  final int stockTabKey;
  final bool lowStockFilter;
  final VoidCallback onLowStockTap;

  @override
  Widget build(BuildContext context) {
    return ResponsivePage(
      padding: EdgeInsets.zero,
      child: IndexedStack(
        index: currentIndex,
        children: [
          DashboardPage(session: session, onLowStockTap: onLowStockTap),
          const ComingSoonPlaceholder(
            icon: Icons.point_of_sale_outlined,
            title: 'Ventes',
            description: 'Historique et nouvelle vente',
          ),
          ProductListPage(
            key: ValueKey('stock-$stockTabKey'),
            session: session,
            initialLowStockOnly: lowStockFilter,
          ),
          const ComingSoonPlaceholder(
            icon: Icons.people_outline,
            title: 'Clients',
            description: 'Fiches clients et dettes',
          ),
          MorePage(session: session),
        ],
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
  });

  final String shopName;
  final String userName;
  final String roleLabel;
  final bool canSwitchShop;
  final VoidCallback? onSwitchShop;
  final VoidCallback onLock;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final horizontalPadding = Breakpoints.horizontalPadding(context.screenType);

    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(
        horizontalPadding,
        compact ? MediaQuery.paddingOf(context).top + AppSpacing.sm : AppSpacing.md,
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
          IconButton.filledTonal(
            onPressed: onLock,
            icon: const Icon(Icons.lock_outline_rounded),
            tooltip: 'Verrouiller',
          ),
        ],
      ),
    );
  }
}
