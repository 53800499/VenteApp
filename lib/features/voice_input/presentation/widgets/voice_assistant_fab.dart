import 'package:flutter/material.dart';

import '../../../../app/di/injection_container.dart';
import '../../../../app/theme/app_tokens.dart';
import '../../../auth/domain/entities/auth_entities.dart';
import '../../data/voice_input_preferences.dart';
import '../services/voice_assistant_coordinator.dart';

/// FAB assistant vocal (micro).
class VoiceAssistantFab extends StatelessWidget {
  const VoiceAssistantFab({
    super.key,
    required this.session,
    this.heroTag = 'voice_assistant_fab',
  });

  final AuthSession session;
  final Object heroTag;

  @override
  Widget build(BuildContext context) {
    ensureVoiceInputDependencies();
    if (!sl<VoiceInputPreferences>().isEnabled) {
      return const SizedBox.shrink();
    }

    return FloatingActionButton.small(
      heroTag: heroTag,
      tooltip: 'Assistant vocal ARIKE',
      onPressed: () {
        VoiceAssistantCoordinator(
          session: session,
          context: context,
        ).start();
      },
      child: const Icon(Icons.mic),
    );
  }
}

/// Micro empilé **au-dessus** des FAB d'action de la page (coin bas-droit).
class VoiceAwareFabColumn extends StatelessWidget {
  const VoiceAwareFabColumn({
    super.key,
    required this.session,
    this.actionButtons = const [],
    this.heroTag = 'voice_assistant_fab_page',
  });

  final AuthSession session;
  final List<Widget> actionButtons;
  final Object heroTag;

  @override
  Widget build(BuildContext context) {
    ensureVoiceInputDependencies();
    final voiceOn = sl<VoiceInputPreferences>().isEnabled;
    if (!voiceOn && actionButtons.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        if (voiceOn) VoiceAssistantFab(session: session, heroTag: heroTag),
        for (var i = 0; i < actionButtons.length; i++) ...[
          if (voiceOn || i > 0) const SizedBox(height: AppSpacing.sm),
          actionButtons[i],
        ],
      ],
    );
  }
}
