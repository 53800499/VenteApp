import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../app/di/injection_container.dart';
import '../../../app/theme/app_tokens.dart';
import '../../../features/auth/presentation/bloc/auth_bloc.dart';
import '../../../features/auth/presentation/widgets/pin_pad.dart';
import '../cloud_session_coordinator.dart';
import '../cloud_session_controller.dart';
import '../cloud_session_repair_service.dart';

/// Demande le code PIN pour rétablir la session cloud sans passer par WhatsApp.
Future<bool> showCloudSessionPinRepairDialog(BuildContext context) async {
  final pin = await showDialog<String>(
    context: context,
    barrierDismissible: true,
    builder: (dialogContext) => const _CloudSessionPinRepairDialog(),
  );
  if (pin == null || pin.length < 4 || !context.mounted) return false;

  final authState = context.read<AuthBloc>().state;
  if (authState is! AuthAuthenticated) return false;

  final session = authState.session;
  final repair = sl<CloudSessionRepairService>();
  final outcome = await repair.repairWithPin(
    pin: pin,
    serverShopId: session.shop.apiShopId,
    localShopId: session.shop.id,
    serverUserId: session.user.serverUserId,
  );

  if (!context.mounted) return false;

  final restored = outcome == CloudRepairOutcome.alreadyValid ||
      outcome == CloudRepairOutcome.refreshed ||
      outcome == CloudRepairOutcome.pinLogin;

  if (restored) {
    sl<CloudSessionCoordinator>().markCloudSessionValid();
    repair.clearAwaitingState();
    unawaited(sl<CloudSessionController>().refresh());
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Connexion au serveur rétablie.')),
    );
    return true;
  }

  final message = outcome == CloudRepairOutcome.offline
      ? 'Connexion internet requise pour rétablir la session serveur.'
      : 'Impossible de rétablir la session serveur. Vérifiez votre code PIN '
          'Réessayez ou utilisez la bannière de synchronisation.';
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  return false;
}

class _CloudSessionPinRepairDialog extends StatefulWidget {
  const _CloudSessionPinRepairDialog();

  @override
  State<_CloudSessionPinRepairDialog> createState() =>
      _CloudSessionPinRepairDialogState();
}

class _CloudSessionPinRepairDialogState
    extends State<_CloudSessionPinRepairDialog> {
  static const _minPinLength = 4;
  static const _maxPinLength = 6;
  String _pin = '';

  void _submit() {
    if (_pin.length < _minPinLength) return;
    Navigator.of(context).pop(_pin);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Rétablir la connexion serveur'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Saisissez votre code PIN pour renouveler la session cloud.',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: AppSpacing.md),
          PinPad(
            filledCount: _pin.length,
            maxLength: _maxPinLength,
            compact: true,
            onDigit: (digit) {
              if (_pin.length >= _maxPinLength) return;
              setState(() => _pin += digit);
              if (_pin.length >= _minPinLength && _pin.length == _maxPinLength) {
                _submit();
              }
            },
            onBackspace: () {
              if (_pin.isEmpty) return;
              setState(() => _pin = _pin.substring(0, _pin.length - 1));
            },
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Annuler'),
        ),
        FilledButton(
          onPressed: _pin.length >= _minPinLength ? _submit : null,
          child: const Text('Valider'),
        ),
      ],
    );
  }
}
