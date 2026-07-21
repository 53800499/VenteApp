import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../app/di/injection_container.dart';
import '../../../../app/theme/app_tokens.dart';
import '../../../../core/network/widgets/offline_mode_banner.dart';
import '../../../../shared/components/ui_primitives.dart';
import '../../../auth/domain/entities/auth_entities.dart';
import '../../data/datasources/local/notifications_local_datasource.dart';
import '../../domain/usecases/notification_usecases.dart';
import '../bloc/notification_settings_bloc.dart';
import '../../../help/presentation/widgets/module_help_button.dart';

class NotificationSettingsPage extends StatelessWidget {
  const NotificationSettingsPage({super.key, required this.session});

  final AuthSession session;

  @override
  Widget build(BuildContext context) {
    ensureNotificationsDependencies();

    return BlocProvider(
      create: (_) => NotificationSettingsBloc(
        getPreferences: sl<GetNotificationPreferences>(),
        updatePreferences: sl<UpdateNotificationPreferences>(),
        shopId: session.shop.id,
      )..add(const NotificationSettingsLoadRequested()),
      child: const _NotificationSettingsView(),
    );
  }
}

class _NotificationSettingsView extends StatelessWidget {
  const _NotificationSettingsView();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Alertes'),
        actions: const [ModuleHelpButton(articleId: 'notifications')],
      ),
      body: Column(
        children: [
          const OfflineModeBanner(
            onlinePreferredMessage: OfflineModeBanner.adminCacheMessage,
          ),
          Expanded(
            child: BlocBuilder<NotificationSettingsBloc, NotificationSettingsState>(
        builder: (context, state) {
          final prefs = state.preferences;

          if (prefs == null) {
            if (state.status == NotificationSettingsStatus.failure) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(state.errorMessage ?? 'Erreur de chargement'),
                      const SizedBox(height: AppSpacing.md),
                      FilledButton(
                        onPressed: () => context
                            .read<NotificationSettingsBloc>()
                            .add(const NotificationSettingsLoadRequested()),
                        child: const Text('Réessayer'),
                      ),
                    ],
                  ),
                ),
              );
            }
            return const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: AppSpacing.md),
                  Text('Chargement des préférences…'),
                ],
              ),
            );
          }

          final debtDays =
              NotificationsLocalDatasource.normalizeDebtReminderDays(
            prefs.debtReminderDays,
          );

          return SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Notifications intelligentes',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    'Alertes 100 % locales — aucune connexion requise (RG-NOTIF-01).',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  if (state.isSaving) ...[
                    const SizedBox(height: AppSpacing.sm),
                    const LinearProgressIndicator(),
                  ],
                  if (state.errorMessage != null) ...[
                    const SizedBox(height: AppSpacing.sm),
                    ErrorBanner(message: state.errorMessage!),
                  ],
                  const SizedBox(height: AppSpacing.lg),
                  const _SectionTitle(title: 'Stock'),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Stock faible (N-01)'),
                    subtitle: Text(
                      'Seuil global : ${prefs.defaultAlertThreshold} unités',
                    ),
                    value: prefs.enableStockAlerts,
                    onChanged: state.isSaving
                        ? null
                        : (v) => context
                            .read<NotificationSettingsBloc>()
                            .add(NotificationSettingsStockToggled(v)),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  const _SectionTitle(title: 'Dettes'),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Rappels dette (N-02)'),
                    subtitle:
                        const Text('Maximum 3 rappels par jour (RG-NOTIF-03)'),
                    value: prefs.enableDebtReminders,
                    onChanged: state.isSaving
                        ? null
                        : (v) => context
                            .read<NotificationSettingsBloc>()
                            .add(NotificationSettingsDebtToggled(v)),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    'Délai sans paiement',
                    style: Theme.of(context).textTheme.bodyLarge,
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  DropdownButtonFormField<int>(
                    key: ValueKey(debtDays),
                    initialValue: debtDays,
                    decoration: const InputDecoration(
                      labelText: 'Nombre de jours',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    items: NotificationsLocalDatasource.debtReminderDayOptions
                        .map(
                          (d) => DropdownMenuItem(
                            value: d,
                            child: Text('$d jours'),
                          ),
                        )
                        .toList(),
                    onChanged: state.isSaving
                        ? null
                        : (value) {
                            if (value == null) return;
                            context.read<NotificationSettingsBloc>().add(
                                  NotificationSettingsDebtDaysChanged(value),
                                );
                          },
                  ),
                  const SizedBox(height: AppSpacing.md),
                  const _SectionTitle(title: 'Résumé'),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Résumé du jour (N-03)'),
                    subtitle: const Text(
                      'Uniquement si des ventes ont été faites (RG-NOTIF-04)',
                    ),
                    value: prefs.enableDailySummary,
                    onChanged: state.isSaving
                        ? null
                        : (v) => context
                            .read<NotificationSettingsBloc>()
                            .add(NotificationSettingsSummaryToggled(v)),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    'Heure du résumé',
                    style: Theme.of(context).textTheme.bodyLarge,
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    prefs.dailySummaryTime,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: OutlinedButton.icon(
                      onPressed: !prefs.enableDailySummary || state.isSaving
                          ? null
                          : () =>
                              _pickSummaryTime(context, prefs.dailySummaryTime),
                      icon: const Icon(Icons.schedule, size: 18),
                      label: const Text('Modifier'),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  const _SectionTitle(title: 'Autres'),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Sauvegarde recommandée (N-05)'),
                    subtitle: const Text('Si dernière sauvegarde > 7 jours'),
                    value: prefs.enableBackupReminder,
                    onChanged: state.isSaving
                        ? null
                        : (v) => context
                            .read<NotificationSettingsBloc>()
                            .add(NotificationSettingsBackupToggled(v)),
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Bonne journée (N-06)'),
                    subtitle: const Text('Record de CA du mois'),
                    value: prefs.enableGoodDayAlert,
                    onChanged: state.isSaving
                        ? null
                        : (v) => context
                            .read<NotificationSettingsBloc>()
                            .add(NotificationSettingsGoodDayToggled(v)),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(AppSpacing.md),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(
                            Icons.sync_problem_outlined,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                          const SizedBox(width: AppSpacing.md),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Conflits de sync (N-07)',
                                  style: Theme.of(context).textTheme.titleSmall,
                                ),
                                const SizedBox(height: AppSpacing.xs),
                                Text(
                                  'Toujours actif — non désactivable (RG-NOTIF-06)',
                                  style: Theme.of(context).textTheme.bodySmall,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _pickSummaryTime(BuildContext context, String current) async {
    final parts = current.split(':');
    final initial = TimeOfDay(
      hour: int.tryParse(parts.first) ?? 20,
      minute: int.tryParse(parts.length > 1 ? parts[1] : '0') ?? 0,
    );
    final picked = await showTimePicker(
      context: context,
      initialTime: initial,
      helpText: 'Heure du résumé (fuseau Bénin)',
    );
    if (picked == null || !context.mounted) return;

    final formatted =
        '${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}';
    context.read<NotificationSettingsBloc>().add(
          NotificationSettingsSummaryTimeChanged(formatted),
        );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w600,
          ),
    );
  }
}
