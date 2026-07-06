import 'package:flutter/material.dart';

import '../../../../app/theme/app_tokens.dart';
import '../../../../core/errors/exception_mapper.dart';
import '../../../../core/errors/failures.dart';
import '../../../../core/responsive/responsive_builder.dart';
import '../../../../shared/components/action_feedback.dart';
import '../../../../shared/components/empty_list_placeholder.dart';
import '../../../../shared/components/ui_primitives.dart';
import '../../../../shared/enums/permission.dart';
import '../../../../shared/guards/permission_guard.dart';
import '../../../auth/domain/entities/auth_entities.dart';
import '../../../auth/domain/usecases/auth_usecases.dart';
import '../widgets/settings_feedback.dart';
import '../../../../app/di/injection_container.dart';

/// Sessions cloud actives — style WhatsApp Web (GET /auth/devices).
class ConnectedDevicesPage extends StatefulWidget {
  const ConnectedDevicesPage({super.key, required this.session});

  final AuthSession session;

  @override
  State<ConnectedDevicesPage> createState() => _ConnectedDevicesPageState();
}

class _ConnectedDevicesPageState extends State<ConnectedDevicesPage> {
  final _listDevices = sl<ListDeviceSessions>();
  final _revokeDevice = sl<RevokeDeviceSession>();

  bool _shopScope = false;
  bool _loading = true;
  String? _error;
  List<DeviceSession> _devices = const [];

  bool get _canViewShopScope => PermissionGuard.can(
        widget.session.user.permissions,
        Permission.usersRead,
      );

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final devices = await _listDevices(shopScope: _shopScope);
      if (!mounted) return;
      setState(() {
        _devices = devices;
        _loading = false;
      });
    } on Failure catch (e) {
      if (!mounted) return;
      setState(() {
        _error = friendlyErrorMessage(e);
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = friendlyErrorMessage(e);
        _loading = false;
      });
    }
  }

  Future<void> _revoke(DeviceSession device) async {
    if (device.isCurrent) {
      await SettingsFeedback.showErrorDialog(
        context,
        title: 'Action impossible',
        message: 'Vous ne pouvez pas révoquer l\'appareil en cours d\'utilisation.',
      );
      return;
    }

    final confirmed = await SettingsFeedback.confirm(
      context: context,
      title: 'Révoquer cet appareil ?',
      message:
          '« ${device.displayName} » (${device.userName}) sera déconnecté du cloud '
          'à la prochaine synchronisation.',
    );
    if (confirmed != true || !mounted) return;

    try {
      await ActionFeedback.runWithBlockingLoader(
        context: context,
        message: 'Révocation…',
        action: () => _revokeDevice(device.id),
      );
      if (!mounted) return;
      await SettingsFeedback.showSuccess(
        context: context,
        title: 'Appareil révoqué',
        message: 'La session cloud a été fermée.',
      );
      await _load();
    } on Failure catch (e) {
      if (!mounted) return;
      await SettingsFeedback.showErrorDialog(
        context,
        title: 'Révocation impossible',
        message: friendlyErrorMessage(e),
      );
    } catch (e) {
      if (!mounted) return;
      await SettingsFeedback.showErrorDialog(
        context,
        title: 'Révocation impossible',
        message: friendlyErrorMessage(e),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Appareils connectés'),
        actions: [
          IconButton(
            onPressed: _loading ? null : _load,
            icon: const Icon(Icons.refresh_outlined),
            tooltip: 'Actualiser',
          ),
        ],
      ),
      body: ResponsivePage(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (_canViewShopScope) ...[
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Toute la boutique'),
                subtitle: const Text(
                  'Afficher les sessions de tous les employés (patron).',
                ),
                value: _shopScope,
                onChanged: _loading
                    ? null
                    : (value) {
                        setState(() => _shopScope = value);
                        _load();
                      },
              ),
              const SizedBox(height: AppSpacing.md),
            ],
            Expanded(child: _buildBody()),
          ],
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ErrorBanner(message: _error!),
            const SizedBox(height: AppSpacing.md),
            FilledButton(
              onPressed: _load,
              child: const Text('Réessayer'),
            ),
          ],
        ),
      );
    }
    if (_devices.isEmpty) {
      return EmptyListPlaceholder.refreshable(
        icon: Icons.devices_outlined,
        title: 'Aucun appareil connecté au cloud',
        onRefresh: _load,
      );
    }

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.separated(
        itemCount: _devices.length,
        separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.sm),
        itemBuilder: (context, index) {
          final device = _devices[index];
          return Card(
            child: ListTile(
              leading: Icon(
                Icons.smartphone_outlined,
                color: device.isCurrent
                    ? Theme.of(context).colorScheme.primary
                    : null,
              ),
              title: Text(device.displayName),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(device.userName),
                  Text(
                    'Vu ${_formatRelative(device.lastSeenAt)}',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
              trailing: device.isCurrent
                  ? Chip(
                      label: Text(
                        'Cet appareil',
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onPrimaryContainer,
                          fontSize: 12,
                        ),
                      ),
                      backgroundColor:
                          Theme.of(context).colorScheme.primaryContainer,
                      visualDensity: VisualDensity.compact,
                    )
                  : TextButton(
                      onPressed: () => _revoke(device),
                      child: const Text('Révoquer'),
                    ),
            ),
          );
        },
      ),
    );
  }

  String _formatRelative(int epochMs) {
    final then = DateTime.fromMillisecondsSinceEpoch(epochMs);
    final diff = DateTime.now().difference(then);
    if (diff.inMinutes < 1) return 'à l\'instant';
    if (diff.inHours < 1) return 'il y a ${diff.inMinutes} min';
    if (diff.inDays < 1) return 'il y a ${diff.inHours} h';
    if (diff.inDays == 1) return 'hier';
    return 'il y a ${diff.inDays} j';
  }
}
