import 'package:flutter/material.dart';

import '../../../../../app/di/injection_container.dart';
import '../../../../../app/theme/app_tokens.dart';
import '../../../../../core/theme/ui_scale_controller.dart';
import '../../../../../shared/components/app_page_container.dart';
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
  bool _voiceInputEnabled = true;

  @override
  void initState() {
    super.initState();
    ensureVoiceInputDependencies();
    ensureUiScaleDependencies();
    _voiceInputEnabled = sl<VoiceInputPreferences>().isEnabled;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final scaleController = sl<UiScaleController>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Apparence & Utilisation'),
      ),
      body: AppPageContainer(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Bannière de présentation
              Container(
                padding: const EdgeInsets.all(AppSpacing.md),
                decoration: BoxDecoration(
                  color: colorScheme.primaryContainer.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(AppRadius.md),
                  border: Border.all(
                    color: colorScheme.primary.withValues(alpha: 0.2),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.palette_outlined,
                      size: 32,
                      color: colorScheme.primary,
                    ),
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
                            'Taille de police Windows, thème de l\'interface, langue et assistant vocal.',
                            style: theme.textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.lg),

              // SECTION : TAILLE DES ÉCRITURES / POLICE (NOUVELLE FONCTIONNALITÉ)
              ListenableBuilder(
                listenable: scaleController,
                builder: (context, _) {
                  final currentScale = scaleController.scaleFactor;
                  final currentPct = scaleController.percentage;

                  return Card(
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppRadius.md),
                      side: BorderSide(
                        color: colorScheme.outlineVariant.withValues(alpha: 0.5),
                      ),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(AppSpacing.lg),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: colorScheme.primary.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(AppRadius.sm),
                                ),
                                child: Icon(
                                  Icons.format_size_rounded,
                                  size: 22,
                                  color: colorScheme.primary,
                                ),
                              ),
                              const SizedBox(width: AppSpacing.sm + 4),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Taille de police globale (Application & Barre latérale)',
                                      style: theme.textTheme.titleMedium?.copyWith(
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    Text(
                                      'Agrandit toutes les écritures de l\'application : barre latérale, menus de navigation, tableaux de ventes, stocks et factures. Idéal pour Windows.',
                                      style: theme.textTheme.bodySmall?.copyWith(
                                        color: colorScheme.onSurfaceVariant,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: colorScheme.primaryContainer,
                                  borderRadius: BorderRadius.circular(AppRadius.pill),
                                  border: Border.all(
                                    color: colorScheme.primary.withValues(alpha: 0.4),
                                  ),
                                ),
                                child: Text(
                                  '$currentPct%',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                    color: colorScheme.primary,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: AppSpacing.md),

                          // Aperçu visuel en direct
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(AppSpacing.md),
                            decoration: BoxDecoration(
                              color: colorScheme.surfaceContainerHighest
                                  .withValues(alpha: 0.35),
                              borderRadius: BorderRadius.circular(AppRadius.sm),
                              border: Border.all(
                                color: colorScheme.outlineVariant
                                    .withValues(alpha: 0.4),
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Icon(
                                      Icons.visibility_outlined,
                                      size: 15,
                                      color: colorScheme.primary,
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      'Aperçu en direct ($currentPct%)',
                                      style: theme.textTheme.labelMedium?.copyWith(
                                        color: colorScheme.primary,
                                        fontWeight: FontWeight.w700,
                                        fontSize: 11,
                                        letterSpacing: 0.5,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'Barre latérale : 🛒 Ventes & Caisse · 📦 Stock & Produits',
                                  style: theme.textTheme.titleSmall?.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Tableau de bord : 15 ventes · Chiffre d\'affaires 350 000 FCFA',
                                  style: theme.textTheme.bodyMedium,
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'Facture N° 2026-0042 · Client Comptant · Caisse Principale',
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: colorScheme.onSurfaceVariant,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: AppSpacing.md),

                          // Boutons de préréglages rapides
                          Text(
                            'Préréglages recommandés :',
                            style: theme.textTheme.labelMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: AppSpacing.xs),
                          Wrap(
                            spacing: 8,
                            runSpacing: 6,
                            children: [
                              _PresetChip(
                                label: 'Compact (90%)',
                                scale: 0.90,
                                isSelected: (currentScale - 0.90).abs() < 0.02,
                                onSelected: () => scaleController.setScaleFactor(0.90),
                              ),
                              _PresetChip(
                                label: 'Normal (100%)',
                                scale: 1.00,
                                isSelected: (currentScale - 1.00).abs() < 0.02,
                                onSelected: () => scaleController.setScaleFactor(1.00),
                              ),
                              _PresetChip(
                                label: 'Grand (115%) — Recommandé',
                                scale: 1.15,
                                isSelected: (currentScale - 1.15).abs() < 0.02,
                                isRecommended: true,
                                onSelected: () => scaleController.setScaleFactor(1.15),
                              ),
                              _PresetChip(
                                label: 'Très grand (130%)',
                                scale: 1.30,
                                isSelected: (currentScale - 1.30).abs() < 0.02,
                                onSelected: () => scaleController.setScaleFactor(1.30),
                              ),
                              _PresetChip(
                                label: 'Maximum (145%)',
                                scale: 1.45,
                                isSelected: (currentScale - 1.45).abs() < 0.02,
                                onSelected: () => scaleController.setScaleFactor(1.45),
                              ),
                            ],
                          ),
                          const SizedBox(height: AppSpacing.md),

                          // Curseur d'ajustement précis
                          Row(
                            children: [
                              const Icon(Icons.text_fields_rounded, size: 16),
                              Expanded(
                                child: Slider(
                                  value: currentScale,
                                  min: UiScaleController.minScale,
                                  max: UiScaleController.maxScale,
                                  divisions: 13,
                                  label: '$currentPct%',
                                  onChanged: (val) =>
                                      scaleController.setScaleFactor(val),
                                ),
                              ),
                              const Icon(Icons.text_fields_rounded, size: 24),
                            ],
                          ),

                          if (!scaleController.isDefault) ...[
                            Align(
                              alignment: Alignment.centerRight,
                              child: TextButton.icon(
                                onPressed: () => scaleController.reset(),
                                icon: const Icon(Icons.refresh_rounded, size: 16),
                                label: const Text('Rétablir la taille normale (100%)'),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(height: AppSpacing.lg),

              // Thème visuel
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
                          ButtonSegment(
                            value: ThemeMode.light,
                            icon: Icon(Icons.light_mode),
                            label: Text('Clair'),
                          ),
                          ButtonSegment(
                            value: ThemeMode.dark,
                            icon: Icon(Icons.dark_mode),
                            label: Text('Sombre'),
                          ),
                          ButtonSegment(
                            value: ThemeMode.system,
                            icon: Icon(Icons.settings_brightness),
                            label: Text('Système'),
                          ),
                        ],
                        selected: {_themeMode},
                        onSelectionChanged: (set) =>
                            setState(() => _themeMode = set.first),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.lg),

              // Langue et saisie vocale
              Card(
                child: Column(
                  children: [
                    const ListTile(
                      leading: Icon(Icons.language_outlined),
                      title: Text('Langue de l\'application'),
                      subtitle: Text('Français (Défaut)'),
                      trailing: Chip(label: Text('FR')),
                    ),
                    const Divider(height: 1),
                    SwitchListTile(
                      secondary: const Icon(Icons.mic_outlined),
                      title: const Text('Assistant d\'entrée vocale ARIKE'),
                      subtitle: const Text(
                        'Permet la saisie rapide de produits et prix par la voix',
                      ),
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
      ),
    );
  }
}

class _PresetChip extends StatelessWidget {
  const _PresetChip({
    required this.label,
    required this.scale,
    required this.isSelected,
    required this.onSelected,
    this.isRecommended = false,
  });

  final String label;
  final double scale;
  final bool isSelected;
  final VoidCallback onSelected;
  final bool isRecommended;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (_) => onSelected(),
      labelStyle: TextStyle(
        fontSize: 12,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
        color: isSelected
            ? colorScheme.primary
            : (isRecommended
                ? colorScheme.primary
                : colorScheme.onSurface),
      ),
      selectedColor: colorScheme.primaryContainer.withValues(alpha: 0.6),
      avatar: isRecommended && !isSelected
          ? Icon(Icons.star_rounded, size: 14, color: colorScheme.primary)
          : null,
      side: BorderSide(
        color: isSelected
            ? colorScheme.primary
            : (isRecommended
                ? colorScheme.primary.withValues(alpha: 0.5)
                : colorScheme.outlineVariant.withValues(alpha: 0.4)),
        width: isSelected || isRecommended ? 1.0 : 0.5,
      ),
      backgroundColor: isRecommended
          ? colorScheme.primaryContainer.withValues(alpha: 0.2)
          : null,
    );
  }
}
