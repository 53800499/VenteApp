import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../app/theme/app_tokens.dart';
import '../../../../core/responsive/responsive_builder.dart';
import '../../../../shared/components/ui_primitives.dart';
import '../../domain/entities/auth_entities.dart';
import '../bloc/auth_bloc.dart';

/// Liste des boutiques du patron après connexion PIN.
class ShopSelectionPage extends StatelessWidget {
  const ShopSelectionPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AuthBloc, AuthState>(
      builder: (context, state) {
        if (state is! AuthShopSelection) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        final shops = state.shops.activeShops;

        return Scaffold(
          body: GradientBackground(
            child: SafeArea(
              child: ResponsivePage(
                expandHeight: true,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SizedBox(height: AppSpacing.lg),
                    const PageHeader(
                      icon: Icons.store_mall_directory_outlined,
                      title: 'Choisissez votre boutique',
                      subtitle:
                          'Sélectionnez la boutique avec laquelle vous souhaitez travailler.',
                    ),
                    if (state.errorMessage != null) ...[
                      const SizedBox(height: AppSpacing.md),
                      ErrorBanner(message: state.errorMessage!),
                    ],
                    const SizedBox(height: AppSpacing.lg),
                    Expanded(
                      child: ListView.separated(
                        itemCount: shops.length,
                        separatorBuilder: (_, __) =>
                            const SizedBox(height: AppSpacing.sm),
                        itemBuilder: (context, index) {
                          final shop = shops[index];
                          return _ShopTile(
                            shop: shop,
                            enabled: !state.isSubmitting,
                            onTap: () => context.read<AuthBloc>().add(
                                  AuthShopSelected(shopId: shop.id),
                                ),
                          );
                        },
                      ),
                    ),
                    if (state.isSubmitting)
                      const Padding(
                        padding: EdgeInsets.all(AppSpacing.md),
                        child: Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              CircularProgressIndicator(),
                              SizedBox(height: AppSpacing.md),
                              Text('Changement de boutique en cours…'),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _ShopTile extends StatelessWidget {
  const _ShopTile({
    required this.shop,
    required this.enabled,
    required this.onTap,
  });

  final OwnedShop shop;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: enabled ? onTap : null,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Row(
            children: [
              CircleAvatar(
                backgroundColor: colorScheme.primaryContainer,
                child: Icon(Icons.store, color: colorScheme.primary),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      shop.name,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                    if (shop.address != null && shop.address!.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        shop.address!,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                    if (shop.isDefault) ...[
                      const SizedBox(height: 4),
                      Text(
                        'Boutique par défaut',
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                              color: colorScheme.primary,
                            ),
                      ),
                    ],
                  ],
                ),
              ),
              if (shop.isCurrent)
                Icon(Icons.check_circle, color: colorScheme.primary)
              else
                Icon(Icons.chevron_right, color: colorScheme.outline),
            ],
          ),
        ),
      ),
    );
  }
}
