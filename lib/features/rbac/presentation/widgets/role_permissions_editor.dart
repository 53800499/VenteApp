import 'package:flutter/material.dart';

import '../../../../app/theme/app_tokens.dart';
import '../../domain/entities/rbac_entities.dart';

class RolePermissionsEditor extends StatelessWidget {
  const RolePermissionsEditor({
    super.key,
    required this.catalog,
    required this.selected,
    required this.onChanged,
    this.readOnly = false,
  });

  final PermissionsCatalog catalog;
  final Map<String, RolePermissionEffect> selected;
  final ValueChanged<Map<String, RolePermissionEffect>> onChanged;
  final bool readOnly;

  @override
  Widget build(BuildContext context) {
    final byModule = <String, List<PermissionCatalogItem>>{};
    for (final item in catalog.permissions) {
      byModule.putIfAbsent(item.module, () => []).add(item);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final module in catalog.modules)
          if (byModule[module.code]?.isNotEmpty == true) ...[
            Text(
              module.label,
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: AppSpacing.xs),
            Card(
              child: Column(
                children: [
                  for (final item in byModule[module.code]!)
                    CheckboxListTile(
                      dense: true,
                      controlAffinity: ListTileControlAffinity.leading,
                      value: selected[item.code] == RolePermissionEffect.allow,
                      onChanged: readOnly
                          ? null
                          : (checked) {
                              final next = Map<String, RolePermissionEffect>.from(
                                selected,
                              );
                              if (checked == true) {
                                next[item.code] = RolePermissionEffect.allow;
                              } else {
                                next.remove(item.code);
                              }
                              onChanged(next);
                            },
                      title: Text(item.label),
                      subtitle: Text(
                        item.code,
                        style: const TextStyle(fontSize: 11),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
          ],
      ],
    );
  }

  static List<RolePermissionGrant> toGrants(
    Map<String, RolePermissionEffect> selected,
  ) {
    return [
      for (final entry in selected.entries)
        RolePermissionGrant(
          permissionCode: entry.key,
          effect: entry.value,
        ),
    ];
  }

  static Map<String, RolePermissionEffect> fromGrants(
    List<RolePermissionGrant> grants,
  ) {
    return {
      for (final grant in grants) grant.permissionCode: grant.effect,
    };
  }
}
