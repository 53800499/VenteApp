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

class RecoveryTokenPage extends StatefulWidget {
  const RecoveryTokenPage({super.key, required this.result});

  final SetupOwnerResult result;

  @override
  State<RecoveryTokenPage> createState() => _RecoveryTokenPageState();
}

class _RecoveryTokenPageState extends State<RecoveryTokenPage> {
  bool _copied = false;
  bool _acknowledged = false;

  SetupOwnerResult get _result => widget.result;

  Future<void> _copyToken() async {
    await Clipboard.setData(ClipboardData(text: _result.recoveryToken));
    if (!mounted) return;
    setState(() => _copied = true);
    await ActionFeedback.showSuccess(
      context: context,
      title: 'Jeton copié',
      message:
          'Collez-le dans un gestionnaire de mots de passe ou une note sûre, '
          'puis cochez la case pour continuer.',
    );
  }

  void _continue() {
    context.read<AuthBloc>().add(
          AuthLockScreenRequested(
            shopId: _result.shopId,
            canGoBack: false,
          ),
        );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final canContinue = _copied && _acknowledged;

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
                        'Étape obligatoire — sans ce jeton, un PIN oublié ou un '
                        'appareil perdu signifie la perte définitive de l\'accès. '
                        'Sauvegardez-le hors de l\'appareil avant de continuer.',
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
                            _result.message,
                            style: Theme.of(context)
                                .textTheme
                                .bodySmall
                                ?.copyWith(fontWeight: FontWeight.w500),
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
                      _result.recoveryToken,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            fontFamily: 'monospace',
                            letterSpacing: 0.5,
                          ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  OutlinedButton.icon(
                    onPressed: _copyToken,
                    icon: Icon(
                      _copied ? Icons.check_circle_outline : Icons.copy_outlined,
                    ),
                    label: Text(_copied ? 'Jeton copié' : 'Copier le jeton'),
                  ),
                  const Spacer(),
                  CheckboxListTile(
                    value: _acknowledged,
                    onChanged: _copied
                        ? (value) =>
                            setState(() => _acknowledged = value ?? false)
                        : null,
                    contentPadding: EdgeInsets.zero,
                    controlAffinity: ListTileControlAffinity.leading,
                    title: Text(
                      'J\'ai sauvegardé ce jeton en lieu sûr, hors de cet appareil.',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    subtitle: _copied
                        ? null
                        : Text(
                            'Copiez d\'abord le jeton pour activer cette case.',
                            style:
                                Theme.of(context).textTheme.bodySmall?.copyWith(
                                      color: colorScheme.outline,
                                    ),
                          ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  FilledButton(
                    onPressed: canContinue ? _continue : null,
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
