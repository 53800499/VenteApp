import 'package:flutter/material.dart';
import '../../../../app/theme/app_tokens.dart';
import '../pages/subscription_page.dart';

class ModuleUpsellDialog extends StatelessWidget {
  const ModuleUpsellDialog({
    super.key,
    required this.moduleName,
    required this.requiredPlanName,
    required this.currentPlanName,
  });

  final String moduleName;
  final String requiredPlanName;
  final String currentPlanName;

  static Future<void> show(
    BuildContext context, {
    required String moduleName,
    required String requiredPlanName,
    required String currentPlanName,
  }) {
    return showDialog<void>(
      context: context,
      builder: (dialogCtx) => ModuleUpsellDialog(
        moduleName: moduleName,
        requiredPlanName: requiredPlanName,
        currentPlanName: currentPlanName,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return AlertDialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppSpacing.md),
      ),
      title: Row(
        children: [
          Icon(Icons.lock_outline, color: colorScheme.primary),
          const SizedBox(width: AppSpacing.xs),
          Expanded(
            child: Text(
              moduleName,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Ce module nécessite le forfait $requiredPlanName.',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: AppSpacing.sm),
          Container(
            padding: const EdgeInsets.all(AppSpacing.sm),
            decoration: BoxDecoration(
              color: colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(AppRadius.sm),
            ),
            child: Row(
              children: [
                const Icon(Icons.info_outline, size: 18),
                const SizedBox(width: AppSpacing.xs),
                Expanded(
                  child: Text(
                    'Votre forfait actuel : $currentPlanName',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Fermer'),
        ),
        FilledButton.icon(
          onPressed: () {
            Navigator.of(context).pop();
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => const SubscriptionPage(),
              ),
            );
          },
          icon: const Icon(Icons.workspace_premium),
          label: const Text('Voir les forfaits'),
        ),
      ],
    );
  }
}
