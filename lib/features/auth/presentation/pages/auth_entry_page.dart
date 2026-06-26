import 'package:flutter/material.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_tokens.dart';
import '../../../../core/responsive/responsive_builder.dart';
import '../../../../shared/components/ui_primitives.dart';

/// Choix initial : créer une boutique ou se connecter via WhatsApp.
class AuthEntryPage extends StatelessWidget {
  const AuthEntryPage({
    super.key,
    required this.onCreateShop,
    required this.onLogin,
  });

  final VoidCallback onCreateShop;
  final VoidCallback onLogin;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: GradientBackground(
        child: SafeArea(
          child: ResponsivePage(
            child: Column(
              children: [
                const SizedBox(height: AppSpacing.xl),
                const PageHeader(
                  icon: Icons.storefront_outlined,
                  title: 'Comment utilisez-vous VenteApp ?',
                  subtitle:
                      'Créez une boutique ou connectez-vous avec votre numéro WhatsApp.',
                ),
                const Spacer(),
                _EntryCard(
                  icon: Icons.add_business_outlined,
                  title: 'Créer une boutique',
                  description:
                      'Nouveau patron : configurez votre boutique. Connexion internet requise.',
                  onTap: onCreateShop,
                ),
                const SizedBox(height: AppSpacing.md),
                _EntryCard(
                  icon: Icons.chat_outlined,
                  title: 'Se connecter',
                  description:
                      'Déjà un compte ? Recevez un code sur WhatsApp. Le PIN sert au verrouillage local.',
                  onTap: onLogin,
                  accent: AppColors.secondary,
                ),
                const SizedBox(height: AppSpacing.xl),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _EntryCard extends StatelessWidget {
  const _EntryCard({
    required this.icon,
    required this.title,
    required this.description,
    required this.onTap,
    this.accent,
  });

  final IconData icon;
  final String title;
  final String description;
  final VoidCallback onTap;
  final Color? accent;

  @override
  Widget build(BuildContext context) {
    final color = accent ?? Theme.of(context).colorScheme.primary;

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                ),
                child: Icon(icon, color: color, size: 28),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      description,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: AppColors.onSurfaceMuted,
                          ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, color: color),
            ],
          ),
        ),
      ),
    );
  }
}
