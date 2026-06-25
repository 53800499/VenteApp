import 'package:flutter/material.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_tokens.dart';

class StockGauge extends StatelessWidget {
  const StockGauge({
    super.key,
    required this.quantity,
    required this.alertThreshold,
    this.height = 10,
  });

  final int quantity;
  final int alertThreshold;
  final double height;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final maxRef = (alertThreshold * 3).clamp(1, 9999);
    final progress = (quantity / maxRef).clamp(0.0, 1.0);

    final color = quantity <= alertThreshold
        ? AppColors.warning
        : quantity <= alertThreshold * 2
            ? AppColors.secondary
            : AppColors.success;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(AppRadius.pill),
          child: LinearProgressIndicator(
            value: progress,
            minHeight: height,
            backgroundColor: colorScheme.surfaceContainerHighest,
            color: color,
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          'Seuil d\'alerte : $alertThreshold',
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    );
  }
}
