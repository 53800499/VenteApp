import 'package:flutter/material.dart';

import '../../../../../app/di/injection_container.dart';
import '../../../../../app/theme/app_tokens.dart';
import '../../../../auth/domain/entities/auth_entities.dart';
import '../../../../voice_input/data/voice_input_preferences.dart';

class AppearanceSettingsPage extends StatefulWidget {
  const AppearanceSettingsPage({
    super.key,
    required this.session,
  });

  final AuthSession session;

  @override
  State<AppearanceSettingsPage> createState() => _AppearanceSettingsPageState();
}

class _AppearanceSettingsPageState extends State<AppearanceSettingsPage> {
  ThemeMode _themeMode = ThemeMode.system;
  String _language = 'fr';
  bool _voiceInputEnabled = true;

  @override
  void initState() {
    super.initState();
    ensureVoiceInputDependencies();
    _voiceInputEnabled = sl<VoiceInputPreferences>().isEnabled;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Apparence & Utilisation'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                color: theme.colorScheme.primaryContainer.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(AppRadius.md),
                border: Border.all(
                  color: theme.colorScheme.primary.withValues(alpha: 0.2),
                ),
              ),
              child: Row(
                children: [
                  Icon(Icons.palette_outlined, size: 32, color: theme.colorScheme.primary),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Préférences d\'affichage & ergonomie',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          'Thème de l\'interface, langue, assistant vocal et formats numériques.',
                          style: theme.textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.lg),

            Card(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Thème visuel', style: theme.textTheme.titleMedium),
                    const SizedBox(height: AppSpacing.sm),
                    SegmentedButton<ThemeMode>(
                      segments: const [
                        ButtonSegment(value: ThemeMode.light, icon: Icon(Icons.light_mode), label: Text('Clair')),
                        ButtonSegment(value: ThemeMode.dark, icon: Icon(Icons.dark_mode), label: Text('Sombre')),
                        ButtonSegment(value: ThemeMode.system, icon: Icon(Icons.settings_brightness), label: Text('Système')),
                      ],
                      selected: {_themeMode},
                      onSelectionChanged: (set) => setState(() => _themeMode = set.first),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.lg),

            Card(
              child: Column(
                children: [
                  ListTile(
                    leading: const Icon(Icons.language_outlined),
                    title: const Text('Langue de l\'application'),
                    subtitle: const Text('Français (Défaut)'),
                    trailing: const Chip(label: Text('FR')),
                  ),
                  const Divider(height: 1),
                  SwitchListTile(
                    secondary: const Icon(Icons.mic_outlined),
                    title: const Text('Assistant d\'entrée vocale ARIKE'),
                    subtitle: const Text('Permet la saisie rapide de produits et prix par la voix'),
                    value: _voiceInputEnabled,
                    onChanged: (val) {
                      setState(() => _voiceInputEnabled = val);
                      sl<VoiceInputPreferences>().setEnabled(val);
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
