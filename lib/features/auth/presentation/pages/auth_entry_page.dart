import 'package:flutter/material.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_tokens.dart';
import '../../../../core/responsive/breakpoints.dart';
import '../../../../core/responsive/responsive_builder.dart';
import '../../../../shared/components/ui_primitives.dart';

/// Choix initial : créer une boutique ou se connecter via WhatsApp.
class AuthEntryPage extends StatelessWidget {
  const AuthEntryPage({
    super.key,
    required this.onCreateShop,
    required this.onLogin,
    this.onPinLogin,
    this.localSetupAvailable = false,
  });

  final VoidCallback onCreateShop;
  final VoidCallback onLogin;
  final VoidCallback? onPinLogin;
  final bool localSetupAvailable;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: LayoutBuilder(
        builder: (context, constraints) {
          final isDesktop = Breakpoints.isDesktopWidth(constraints.maxWidth);

          if (isDesktop) {
            return _buildDesktopLayout(context);
          }

          return _buildMobileLayout(context);
        },
      ),
    );
  }

  Widget _buildDesktopLayout(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // --- VOLET GAUCHE : IDENTITÉ ARIKE & ATOUTS ---
        // Occupe l'intégralité de la section gauche, pleine hauteur, bord à bord
        Expanded(
          flex: 5,
          child: Container(
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  AppColors.lockGradientTop,
                  AppColors.lockGradientBottom,
                ],
              ),
              border: Border(
                right: BorderSide(
                  color: colorScheme.outlineVariant.withValues(alpha: 0.6),
                ),
              ),
            ),
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.xl,
                  vertical: AppSpacing.xl,
                ),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 440),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const AppLogo(size: 88),
                      const SizedBox(height: AppSpacing.xl),
                      Text(
                        'ARIKE VenteApp',
                        style: theme.textTheme.headlineMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.5,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        'Solution de caisse & gestion commerciale hors-ligne',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.xl),
                      const _FeatureBullet(
                        icon: Icons.wifi_off_rounded,
                        title: '100% Offline-First',
                        subtitle:
                            'Vendez, encaissez et gérez sans interruption même en cas de coupure Internet.',
                      ),
                      const SizedBox(height: AppSpacing.md),
                      const _FeatureBullet(
                        icon: Icons.inventory_2_outlined,
                        title: 'Maîtrise des Stocks',
                        subtitle:
                            'Alertes en temps réel contre les ruptures et dates de péremption.',
                      ),
                      const SizedBox(height: AppSpacing.md),
                      const _FeatureBullet(
                        icon: Icons.chat_outlined,
                        title: 'Dettes & Relances WhatsApp',
                        subtitle:
                            'Suivi transparent des crédits clients et rappels automatiques en un clic.',
                      ),
                      const SizedBox(height: AppSpacing.xl),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: colorScheme.surfaceContainerHighest.withValues(
                            alpha: 0.4,
                          ),
                          borderRadius: BorderRadius.circular(AppRadius.md),
                          border: Border.all(
                            color: colorScheme.outlineVariant.withValues(
                              alpha: 0.4,
                            ),
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.security_outlined,
                              size: 16,
                              color: colorScheme.primary,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Données chiffrées & sauvegardées localement sur ce poste',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: colorScheme.onSurfaceVariant,
                                  fontSize: 11,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),

        // --- VOLET DROIT : CARTES DE CHOIX ---
        // Occupe l'intégralité de la section droite, avec les cartes centrées
        Expanded(
          flex: 6,
          child: Container(
            color: colorScheme.surface,
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.xl,
                  vertical: AppSpacing.xl,
                ),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 460),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        'Comment utilisez-vous ARIKE ?',
                        style: theme.textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Créez une nouvelle boutique ou connectez-vous avec votre numéro WhatsApp.',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.xl),
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
                      if (localSetupAvailable && onPinLogin != null) ...[
                        const SizedBox(height: AppSpacing.md),
                        _EntryCard(
                          icon: Icons.pin_outlined,
                          title: 'Connexion par PIN',
                          description:
                              'Boutique déjà installée sur cet appareil — entrez votre code PIN.',
                          onTap: onPinLogin!,
                          accent: AppColors.seed,
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMobileLayout(BuildContext context) {
    return GradientBackground(
      child: SafeArea(
        child: ResponsivePage(
          maxWidth: Breakpoints.authMaxWidth,
          padding: EdgeInsets.zero,
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.lg,
              vertical: AppSpacing.md,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: AppSpacing.md),
                const Center(child: AppLogo(size: 80)),
                const SizedBox(height: AppSpacing.md),
                const PageHeader(
                  title: 'Comment utilisez-vous ARIKE ?',
                  subtitle:
                      'Créez une boutique ou connectez-vous avec votre numéro WhatsApp.',
                ),
                const SizedBox(height: AppSpacing.lg),
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
                if (localSetupAvailable && onPinLogin != null) ...[
                  const SizedBox(height: AppSpacing.md),
                  _EntryCard(
                    icon: Icons.pin_outlined,
                    title: 'Connexion par PIN',
                    description:
                        'Boutique déjà installée sur cet appareil — entrez votre code PIN.',
                    onTap: onPinLogin!,
                    accent: AppColors.seed,
                  ),
                ],
                const SizedBox(height: AppSpacing.lg),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _FeatureBullet extends StatelessWidget {
  const _FeatureBullet({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: colorScheme.primary.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(AppRadius.sm),
          ),
          child: Icon(icon, size: 20, color: colorScheme.primary),
        ),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ],
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
