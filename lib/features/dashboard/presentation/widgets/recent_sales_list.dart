import 'package:flutter/material.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_tokens.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../domain/entities/dashboard_entities.dart';

class RecentSalesList extends StatelessWidget {
  const RecentSalesList({super.key, required this.sales});

  final List<DashboardRecentSale> sales;

  @override
  Widget build(BuildContext context) {
    if (sales.isEmpty) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg,
            vertical: AppSpacing.xl,
          ),
          child: Column(
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Theme.of(context)
                      .colorScheme
                      .primaryContainer
                      .withValues(alpha: 0.5),
                ),
                child: Icon(
                  Icons.shopping_bag_outlined,
                  size: 32,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              Text(
                'Aucune vente aujourd\'hui',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                'Vos ventes du jour apparaîtront ici',
                style: Theme.of(context).textTheme.bodySmall,
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    return Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.md,
              AppSpacing.md,
              AppSpacing.md,
              AppSpacing.sm,
            ),
            child: Row(
              children: [
                Text(
                  'Dernières ventes',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const Spacer(),
                Icon(
                  Icons.schedule,
                  size: 16,
                  color: AppColors.onSurfaceMuted,
                ),
              ],
            ),
          ),
          ...sales.asMap().entries.map((entry) {
            final sale = entry.value;
            final isLast = entry.key == sales.length - 1;

            return Column(
              children: [
                ListTile(
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.md,
                  ),
                  leading: Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: _colorForMode(sale.paymentMode)
                          .withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      _iconForMode(sale.paymentMode),
                      size: 22,
                      color: _colorForMode(sale.paymentMode),
                    ),
                  ),
                  title: Text(
                    formatFcfa(sale.totalAmount),
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                  subtitle: Text(
                    [
                      _labelForMode(sale.paymentMode),
                      if (sale.customerName != null) sale.customerName!,
                      _formatTime(sale.createdAt),
                    ].join(' · '),
                  ),
                  trailing: Icon(
                    Icons.chevron_right,
                    color: Theme.of(context).colorScheme.outline,
                  ),
                ),
                if (!isLast) const Divider(height: 1, indent: 72),
              ],
            );
          }),
          const SizedBox(height: AppSpacing.sm),
        ],
      ),
    );
  }

  Color _colorForMode(String mode) {
    return switch (mode) {
      'momo' => const Color(0xFF1565C0),
      'credit' => AppColors.warning,
      'mixed' => const Color(0xFF6A1B9A),
      _ => AppColors.seed,
    };
  }

  IconData _iconForMode(String mode) {
    return switch (mode) {
      'momo' => Icons.phone_android_outlined,
      'credit' => Icons.schedule_outlined,
      'mixed' => Icons.payments_outlined,
      _ => Icons.payments_outlined,
    };
  }

  String _labelForMode(String mode) {
    return switch (mode) {
      'momo' => 'MoMo',
      'credit' => 'Crédit',
      'mixed' => 'Mixte',
      _ => 'Espèces',
    };
  }

  String _formatTime(int timestampMs) {
    final time = DateTime.fromMillisecondsSinceEpoch(timestampMs);
    final h = time.hour.toString().padLeft(2, '0');
    final m = time.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }
}
