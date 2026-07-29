import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../core/sync/widgets/sync_status_indicator.dart';
import '../../features/auth/domain/entities/auth_entities.dart';
import '../../features/auth/presentation/bloc/auth_bloc.dart';

/// Composant d'actions d'en-tête unifié (Bouton Lock + Icône Cloud Sync).
/// Affiché dans les AppBars sur toutes les pages pour garantir la cohérence UX post-PIN.
class AppHeaderActions extends StatelessWidget {
  const AppHeaderActions({
    super.key,
    this.session,
    this.showLock = true,
  });

  final AuthSession? session;
  final bool showLock;

  @override
  Widget build(BuildContext context) {
    AuthSession? activeSession = session;
    if (activeSession == null) {
      try {
        final authState = context.read<AuthBloc>().state;
        if (authState is AuthAuthenticated) {
          activeSession = authState.session;
        }
      } catch (_) {}
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (showLock)
          IconButton(
            onPressed: () {
              try {
                context.read<AuthBloc>().add(const AuthAppLockedRequested());
              } catch (_) {}
            },
            icon: const Icon(Icons.lock_outline_rounded),
            tooltip: 'Verrouiller',
          ),
        SyncStatusIndicator(session: activeSession),
      ],
    );
  }
}
