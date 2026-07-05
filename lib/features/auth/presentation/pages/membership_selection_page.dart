import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../app/theme/app_tokens.dart';
import '../../../../core/responsive/responsive_builder.dart';
import '../../../../shared/components/ui_primitives.dart';
import '../../domain/entities/auth_entities.dart';
import '../bloc/auth_bloc.dart';

/// Choix du contexte boutique après vérification WhatsApp.
class MembershipSelectionPage extends StatelessWidget {
  const MembershipSelectionPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AuthBloc, AuthState>(
      builder: (context, state) {
        if (state is! AuthMembershipSelection) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

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
                      title: 'Choisissez votre accès',
                      subtitle:
                          'Sélectionnez la boutique et le rôle avec lesquels vous souhaitez vous connecter.',
                    ),
                    if (state.errorMessage != null) ...[
                      const SizedBox(height: AppSpacing.md),
                      ErrorBanner(message: state.errorMessage!),
                    ],
                    const SizedBox(height: AppSpacing.lg),
                    Expanded(
                      child: ListView.separated(
                        itemCount: state.memberships.length,
                        separatorBuilder: (_, __) =>
                            const SizedBox(height: AppSpacing.sm),
                        itemBuilder: (context, index) {
                          final membership = state.memberships[index];
                          return _MembershipTile(
                            membership: membership,
                            enabled: !state.isSubmitting,
                            onTap: () => context.read<AuthBloc>().add(
                                  AuthMembershipSelected(
                                    shopId: membership.shopId,
                                    userId: membership.userId,
                                  ),
                                ),
                          );
                        },
                      ),
                    ),
                    if (state.isSubmitting)
                      const Padding(
                        padding: EdgeInsets.all(AppSpacing.md),
                        child: Center(child: CircularProgressIndicator()),
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

class _MembershipTile extends StatelessWidget {
  const _MembershipTile({
    required this.membership,
    required this.enabled,
    required this.onTap,
  });

  final AuthMembership membership;
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
                      membership.shopName,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      membership.roleLabel,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    if (membership.isDefault) ...[
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
              Icon(Icons.chevron_right, color: colorScheme.outline),
            ],
          ),
        ),
      ),
    );
  }
}
