import 'package:flutter/material.dart';

import '../../../../app/di/injection_container.dart';
import '../../../../app/theme/app_tokens.dart';
import '../../../../core/errors/exception_mapper.dart';
import '../../../../shared/enums/user_role.dart';
import '../../../rbac/domain/usecases/rbac_usecases.dart';
import '../../domain/entities/user_entities.dart';

class AssignableRolesLoader {
  static Future<List<AssignableRole>> load() async {
    final roles = await sl<ListRoles>()();
    return roles
        .where((r) => r.code != UserRole.owner.code)
        .map((r) => AssignableRole(code: r.code, label: r.label))
        .toList();
  }
}

Future<AssignableRole?> showAssignableRolePicker({
  required BuildContext context,
  required String title,
  String? currentRoleCode,
}) async {
  List<AssignableRole> roles;
  try {
    roles = await AssignableRolesLoader.load();
  } catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(friendlyErrorMessage(e))),
      );
    }
    return null;
  }

  if (!context.mounted) return null;

  return showDialog<AssignableRole>(
    context: context,
    builder: (ctx) => SimpleDialog(
      title: Text(title),
      children: [
        SizedBox(
          height: 320,
          width: double.maxFinite,
          child: ListView(
            children: [
              for (final role in roles)
                if (role.code != currentRoleCode)
                  SimpleDialogOption(
                    onPressed: () => Navigator.pop(ctx, role),
                    child: Text(role.label),
                  ),
            ],
          ),
        ),
      ],
    ),
  );
}

class AssignableRoleDropdown extends StatefulWidget {
  const AssignableRoleDropdown({
    super.key,
    required this.value,
    required this.onChanged,
  });

  final String? value;
  final ValueChanged<String> onChanged;

  @override
  State<AssignableRoleDropdown> createState() => _AssignableRoleDropdownState();
}

class _AssignableRoleDropdownState extends State<AssignableRoleDropdown> {
  List<AssignableRole> _roles = const [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final roles = await AssignableRolesLoader.load();
      if (!mounted) return;
      setState(() {
        _roles = roles;
        _loading = false;
        if (widget.value == null && roles.isNotEmpty) {
          widget.onChanged(roles.first.code);
        }
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = friendlyErrorMessage(e);
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: AppSpacing.md),
        child: LinearProgressIndicator(),
      );
    }
    if (_error != null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
          TextButton(onPressed: _load, child: const Text('Réessayer')),
        ],
      );
    }
    if (_roles.isEmpty) {
      return const Text('Aucun rôle disponible.');
    }

    return DropdownButtonFormField<String>(
      initialValue: widget.value ?? _roles.first.code,
      decoration: const InputDecoration(labelText: 'Rôle'),
      items: [
        for (final role in _roles)
          DropdownMenuItem(
            value: role.code,
            child: Text(role.label),
          ),
      ],
      onChanged: (value) {
        if (value != null) widget.onChanged(value);
      },
    );
  }
}
