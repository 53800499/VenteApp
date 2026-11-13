import 'package:flutter/material.dart';

import '../../app/di/injection_container.dart';
import '../../app/theme/app_tokens.dart';
import 'ui_scale_controller.dart';

/// Boîte de dialogue rapide permettant d'ajuster la taille de police
/// directement depuis la barre latérale ou n'importe quel écran.
class UiScaleQuickDialog extends StatelessWidget {
  const UiScaleQuickDialog({super.key});

  static Future<void> show(BuildContext context) {
    return showDialog<void>(
      context: context,
      builder: (context) => const UiScaleQuickDialog(),
    );
  }

  @override
  Widget build(BuildContext context) {
    ensureUiScaleDependencies();
    final scaleController = sl<UiScaleController>();
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: ListenableBuilder(
            listenable: scaleController,
            builder: (context, _) {
              final currentScale = scaleController.scaleFactor;
              final currentPct = scaleController.percentage;

              return Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: colorScheme.primary.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(AppRadius.sm),
                        ),
                        child: Icon(
                          Icons.format_size_rounded,
                          size: 22,
                          color: colorScheme.primary,
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm + 4),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Taille de police globale',
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              'Ajuste immédiatement la barre latérale et l\'application',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: colorScheme.primaryContainer,
                          borderRadius: BorderRadius.circular(AppRadius.pill),
                        ),
                        child: Text(
                          '$currentPct%',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                            color: colorScheme.primary,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.md),

                  // Aperçu rapide
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(AppSpacing.sm + 4),
                    decoration: BoxDecoration(
                      color: colorScheme.surfaceContainerHighest
                          .withValues(alpha: 0.35),
                      borderRadius: BorderRadius.circular(AppRadius.sm),
                      border: Border.all(
                        color: colorScheme.outlineVariant.withValues(alpha: 0.4),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Aperçu de lecture :',
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: colorScheme.primary,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '🛒 Ventes & Caisse · Stock & Produits',
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Text(
                          'Facture N° 1024 · 45 000 FCFA · Reçu client validé',
                          style: theme.textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),

                  // Préréglages
                  Text(
                    'Tailles rapides :',
                    style: theme.textTheme.labelMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    children: [
                      _QuickChip(
                        label: '100% (Normal)',
                        isSelected: (currentScale - 1.00).abs() < 0.02,
                        onTap: () => scaleController.setScaleFactor(1.00),
                      ),
                      _QuickChip(
                        label: '115% (Grand)',
                        isSelected: (currentScale - 1.15).abs() < 0.02,
                        isRecommended: true,
                        onTap: () => scaleController.setScaleFactor(1.15),
                      ),
                      _QuickChip(
                        label: '125% (Très grand)',
                        isSelected: (currentScale - 1.25).abs() < 0.02,
                        onTap: () => scaleController.setScaleFactor(1.25),
                      ),
                      _QuickChip(
                        label: '140% (Max)',
                        isSelected: (currentScale - 1.40).abs() < 0.02,
                        onTap: () => scaleController.setScaleFactor(1.40),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.md),

                  // Curseur
                  Row(
                    children: [
                      const Icon(Icons.text_fields_rounded, size: 16),
                      Expanded(
                        child: Slider(
                          value: currentScale,
                          min: UiScaleController.minScale,
                          max: UiScaleController.maxScale,
                          divisions: 13,
                          label: '$currentPct%',
                          onChanged: (val) => scaleController.setScaleFactor(val),
                        ),
                      ),
                      const Icon(Icons.text_fields_rounded, size: 24),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.sm),

                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      if (!scaleController.isDefault)
                        TextButton(
                          onPressed: () => scaleController.reset(),
                          child: const Text('Rétablir (100%)'),
                        )
                      else
                        const SizedBox.shrink(),
                      FilledButton(
                        onPressed: () => Navigator.of(context).pop(),
                        child: const Text('Terminé'),
                      ),
                    ],
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _QuickChip extends StatelessWidget {
  const _QuickChip({
    required this.label,
    required this.isSelected,
    required this.onTap,
    this.isRecommended = false,
  });

  final String label;
  final bool isSelected;
  final VoidCallback onTap;
  final bool isRecommended;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (_) => onTap(),
      labelStyle: TextStyle(
        fontSize: 12,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
        color: isSelected
            ? colorScheme.primary
            : (isRecommended ? colorScheme.primary : colorScheme.onSurface),
      ),
      selectedColor: colorScheme.primaryContainer.withValues(alpha: 0.6),
      avatar: isRecommended && !isSelected
          ? Icon(Icons.star_rounded, size: 14, color: colorScheme.primary)
          : null,
      side: BorderSide(
        color: isSelected
            ? colorScheme.primary
            : (isRecommended
                ? colorScheme.primary.withValues(alpha: 0.5)
                : colorScheme.outlineVariant.withValues(alpha: 0.4)),
      ),
    );
  }
}

