import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../features/auth/presentation/bloc/auth_bloc.dart';
import '../../../../shared/widgets/lock_button.dart';

/// Redirige vers la page de verrouillage PIN en plein écran (LockScreenPage)
/// au lieu d'ouvrir une boîte de dialogue modale.
Future<bool> showCloudSessionPinRepairDialog(BuildContext context) async {
  if (!context.mounted) return false;

  // Si on est dans une pile de navigation, on pousse la page de verrouillage PIN en plein écran
  try {
    final unlocked = await LockButton.lockSession(context);
    return unlocked == true;
  } catch (_) {
    // Fallback via le bloc d'authentification
    try {
      context.read<AuthBloc>().add(const AuthAppLockedRequested());
      return true;
    } catch (_) {
      return false;
    }
  }
}
