import 'package:flutter/material.dart';

import '../../../../app/di/injection_container.dart';
import '../../../../app/theme/app_tokens.dart';
import '../../domain/entities/auth_entities.dart';
import '../../domain/usecases/auth_usecases.dart';

class IdentityContextCard extends StatefulWidget {
  const IdentityContextCard({
    super.key,
    required this.session,
    required this.onChangeIdentity,
  });

  final AuthSession session;
  final VoidCallback onChangeIdentity;

  @override
  State<IdentityContextCard> createState() => _IdentityContextCardState();
}

class _IdentityContextCardState extends State<IdentityContextCard> {
  AuthIdentityContext? _identity;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadIdentity();
  }

  Future<void> _loadIdentity() async {
    try {
      final identity = await sl<GetIdentityContext>()();
      if (!mounted) return;
      setState(() {
        _identity = identity;
        _loading = false;
      });
    } on Object {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final identity = _identity;
    final organizationName =
        identity?.organizationName ?? widget.session.shop.name;
    final roleLabel = identity?.effectiveRoleLabel ?? widget.session.user.roleLabel;
    final globalRoleLabel = identity?.roleLabel ?? widget.session.user.roleLabel;
    final activeShopName =
        identity?.activeShopName ?? widget.session.shop.name;
    final shopCount = identity?.accessibleShopCount ?? 1;
    final showEffectiveRole =
        identity != null && identity.effectiveRole != identity.role;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: colorScheme.primaryContainer,
                  child: Icon(
                    shopCount > 1
                        ? Icons.domain_outlined
                        : Icons.store_outlined,
                    color: colorScheme.primary,
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Mon identité',
                        style: Theme.of(context).textTheme.labelLarge?.copyWith(
                              color: colorScheme.primary,
                            ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        organizationName,
                        style:
                            Theme.of(context).textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w600,
                                ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (_loading) ...[
              const SizedBox(height: AppSpacing.md),
              const LinearProgressIndicator(minHeight: 2),
            ] else ...[
              const SizedBox(height: AppSpacing.md),
              _InfoRow(
                icon: Icons.badge_outlined,
                label: 'Rôle',
                value: showEffectiveRole
                    ? '$roleLabel ($globalRoleLabel)'
                    : roleLabel,
              ),
              const SizedBox(height: AppSpacing.sm),
              _InfoRow(
                icon: Icons.store_mall_directory_outlined,
                label: 'Boutique active',
                value: activeShopName,
              ),
              if (shopCount > 1) ...[
                const SizedBox(height: AppSpacing.sm),
                _InfoRow(
                  icon: Icons.hub_outlined,
                  label: 'Boutiques accessibles',
                  value: '$shopCount',
                ),
                ...identity!.accessibleShops
                    .where((shop) => shop.accessRole != null)
                    .map(
                      (shop) => Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          '${shop.name} · ${shop.roleLabel ?? shop.accessRole}',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ),
                    ),
              ],
              const SizedBox(height: AppSpacing.md),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  onPressed: widget.onChangeIdentity,
                  icon: const Icon(Icons.switch_account_outlined),
                  label: const Text('Changer d\'identité'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 18, color: Theme.of(context).colorScheme.outline),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Text(
            label,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ),
        Text(
          value,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
        ),
      ],
    );
  }
}
