import 'package:flutter/material.dart';

import '../../../../shared/components/adaptive_modal.dart';

/// Utilitaires et composants avec confirmation obligatoire pour les paramètres d'ARIKE.
class SettingsConfirmation {
  const SettingsConfirmation._();

  /// Affiche une modale de confirmation avant d'exécuter une action dans les paramètres.
  static Future<bool> confirm(
    BuildContext context, {
    required String title,
    required String message,
    String confirmLabel = 'Confirmer',
    String cancelLabel = 'Annuler',
    IconData icon = Icons.tune_rounded,
    bool isDestructive = false,
  }) {
    return showAdaptiveConfirm(
      context: context,
      title: title,
      message: message,
      confirmLabel: confirmLabel,
      cancelLabel: cancelLabel,
      icon: icon,
      destructive: isDestructive,
    );
  }
}

/// [SwitchListTile] sécurisé qui demande une confirmation systématique avant basculement.
class SettingsSwitchListTile extends StatelessWidget {
  const SettingsSwitchListTile({
    super.key,
    required this.value,
    required this.onChanged,
    required this.title,
    this.subtitle,
    this.secondary,
    this.contentPadding,
    this.confirmationTitle,
    this.confirmationMessage,
    this.isDestructiveOnDisable = false,
  });

  final bool value;
  final ValueChanged<bool>? onChanged;
  final Widget title;
  final Widget? subtitle;
  final Widget? secondary;
  final EdgeInsetsGeometry? contentPadding;
  final String? confirmationTitle;
  final String? confirmationMessage;
  final bool isDestructiveOnDisable;

  String _defaultMessage(bool targetVal) {
    if (targetVal) {
      return 'Souhaitez-vous activer cette option ? Cette modification prendra effet immédiatement.';
    } else {
      return 'Souhaitez-vous désactiver cette option ? Cette modification prendra effet immédiatement.';
    }
  }

  @override
  Widget build(BuildContext context) {
    return SwitchListTile(
      value: value,
      title: title,
      subtitle: subtitle,
      secondary: secondary,
      contentPadding: contentPadding,
      onChanged: onChanged == null
          ? null
          : (targetVal) async {
              final ok = await SettingsConfirmation.confirm(
                context,
                title: confirmationTitle ?? 'Confirmer la modification',
                message: confirmationMessage ?? _defaultMessage(targetVal),
                confirmLabel: 'Oui, modifier',
                cancelLabel: 'Annuler',
                icon: targetVal ? Icons.check_circle_outline_rounded : Icons.power_settings_new_rounded,
                isDestructive: !targetVal && isDestructiveOnDisable,
              );
              if (ok) {
                onChanged!(targetVal);
              }
            },
    );
  }
}

/// [RadioListTile] sécurisé qui demande une confirmation systématique avant changement d'option.
class SettingsRadioListTile<T> extends StatelessWidget {
  const SettingsRadioListTile({
    super.key,
    required this.value,
    required this.groupValue,
    required this.onChanged,
    required this.title,
    this.subtitle,
    this.secondary,
    this.contentPadding,
    this.confirmationTitle,
    this.confirmationMessage,
  });

  final T value;
  final T? groupValue;
  final ValueChanged<T>? onChanged;
  final Widget title;
  final Widget? subtitle;
  final Widget? secondary;
  final EdgeInsetsGeometry? contentPadding;
  final String? confirmationTitle;
  final String? confirmationMessage;

  @override
  Widget build(BuildContext context) {
    return RadioListTile<T>(
      value: value,
      groupValue: groupValue,
      title: title,
      subtitle: subtitle,
      secondary: secondary,
      contentPadding: contentPadding,
      onChanged: onChanged == null
          ? null
          : (targetVal) async {
              if (targetVal == null || targetVal == groupValue) return;
              final ok = await SettingsConfirmation.confirm(
                context,
                title: confirmationTitle ?? 'Changer de configuration',
                message: confirmationMessage ??
                    'Souhaitez-vous appliquer ce nouveau choix ? Ce réglage sera immédiatement pris en compte.',
                confirmLabel: 'Appliquer',
                cancelLabel: 'Conserver l\'actuel',
                icon: Icons.check_circle_outline_rounded,
              );
              if (ok) {
                onChanged!(targetVal);
              }
            },
    );
  }
}
