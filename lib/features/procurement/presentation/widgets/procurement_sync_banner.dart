import 'package:flutter/material.dart';

import '../../../../app/theme/app_tokens.dart';
import '../../domain/entities/procurement_sync_entities.dart';
import '../pages/procurement_sync_panel_page.dart';
import 'procurement_sync_scope.dart';

/// Bannière informative sync (non bloquante) en tête du module appro.
class ProcurementSyncBanner extends StatelessWidget {
  const ProcurementSyncBanner({super.key, required this.shopId});

  final int shopId;

  @override
  Widget build(BuildContext context) {
    final overview = ProcurementSyncScope.overviewOf(context);
    if (!overview.hasIssues || overview.bannerMessage == null) {
      return const SizedBox.shrink();
    }

    final scheme = Theme.of(context).colorScheme;
    final isError = overview.errorCount > 0;

    return Material(
      color: isError
          ? scheme.errorContainer.withValues(alpha: 0.55)
          : scheme.tertiaryContainer.withValues(alpha: 0.65),
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => ProcurementSyncPanelPage(shopId: shopId),
            ),
          );
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.sm,
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                isError ? Icons.info_outline : Icons.cloud_upload_outlined,
                size: 20,
                color: isError ? scheme.onErrorContainer : scheme.onTertiaryContainer,
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  overview.bannerMessage!,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: isError
                            ? scheme.onErrorContainer
                            : scheme.onTertiaryContainer,
                        height: 1.35,
                      ),
                ),
              ),
              Icon(
                Icons.chevron_right,
                color: isError ? scheme.onErrorContainer : scheme.onTertiaryContainer,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
