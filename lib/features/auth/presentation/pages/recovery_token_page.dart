import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_tokens.dart';
import '../../../../core/responsive/breakpoints.dart';
import '../../../../core/responsive/responsive_builder.dart';
import '../../../../shared/components/action_feedback.dart';
import '../../../../shared/components/ui_primitives.dart';
import '../../domain/entities/auth_entities.dart';
import '../bloc/auth_bloc.dart';

class RecoveryTokenPage extends StatelessWidget {
  const RecoveryTokenPage({super.key, required this.result});

  final SetupOwnerResult result;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return PopScope(
      canPop: false,
      child: Scaffold(
        body: GradientBackground(
          child: SafeArea(
            child: ResponsivePage(
              maxWidth: Breakpoints.authMaxWidth,
              padding: const EdgeInsets.all(AppSpacing.lg),
              expandHeight: true,
              child: ResponsiveScrollColumn(
                children: [
                  const SizedBox(height: AppSpacing.md),
                  const PageHeader(
                    icon: Icons.shield_outlined,
                    title: 'Fichier de récupération',
                    subtitle:
                        'Étape 1 sur 2 — conservez ce jeton hors de l\'appareil. '
                        'Ensuite, vous saisirez votre PIN pour ouvrir l\'application.',
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  Container(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    decoration: BoxDecoration(
                      color: colorScheme.errorContainer.withValues(alpha: 0.35),
                      borderRadius: BorderRadius.circular(AppRadius.sm),
                      border: Border.all(
                        color: AppColors.warning.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.warning_amber_rounded,
                          color: AppColors.warning,
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        Expanded(
                          child: Text(
                            result.message,
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                  fontWeight: FontWeight.w500,
                                ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  Text(
                    'Votre jeton',
                    style: Theme.of(context).textTheme.labelLarge,
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Container(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    decoration: BoxDecoration(
                      color: colorScheme.surface,
                      borderRadius: BorderRadius.circular(AppRadius.md),
                      border: Border.all(color: colorScheme.outlineVariant),
                    ),
                    child: SelectableText(
                      result.recoveryToken,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            fontFamily: 'monospace',
                            letterSpacing: 0.5,
                          ),
                    ),
                  ),
                  const Spacer(),
                  OutlinedButton.icon(
                    onPressed: () async {
                      await Clipboard.setData(
                        ClipboardData(text: result.recoveryToken),
                      );
                      if (!context.mounted) return;
                      await ActionFeedback.showSuccess(
                        context: context,
                        title: 'Jeton copié',
                        message:
                            'Le jeton a été copié dans le presse-papiers.',
                      );
                    },
                    icon: const Icon(Icons.copy_outlined),
                    label: const Text('Copier le jeton'),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  FilledButton(
                    onPressed: () => context.read<AuthBloc>().add(
                          AuthLockScreenRequested(
                            shopId: result.shopId,
                            canGoBack: false,
                          ),
                        ),
                    child: const Text('Continuer — saisir mon PIN'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
