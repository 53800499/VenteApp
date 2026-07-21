import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../app/di/injection_container.dart';
import '../../../../app/theme/app_tokens.dart';
import '../../../../core/network/widgets/offline_mode_banner.dart';
import '../../../../core/utils/benin_day_range.dart';
import '../../../../shared/components/empty_list_placeholder.dart';
import '../../../../shared/enums/permission.dart';
import '../../../../shared/guards/permission_guard.dart';
import '../../../auth/domain/entities/auth_entities.dart';
import '../../domain/entities/audit_entities.dart';
import '../bloc/audit_journal_bloc.dart';
import '../services/audit_pdf_exporter.dart';
import '../widgets/audit_feedback.dart';
import '../../../help/presentation/widgets/module_help_button.dart';
import 'audit_detail_page.dart';

class AuditJournalPage extends StatelessWidget {
  const AuditJournalPage({super.key, required this.session});

  final AuthSession session;

  bool get _canExport => PermissionGuard.can(
        session.user.permissions,
        Permission.auditRead,
      );

  @override
  Widget build(BuildContext context) {
    ensureAuditDependencies();

    return BlocProvider(
      create: (_) => AuditJournalBloc(
        listAuditLogs: sl(),
        getFilterOptions: sl(),
        exportAuditLogs: sl(),
        pdfExporter: sl(),
        session: session,
      )..add(const AuditJournalLoadRequested()),
      child: _AuditJournalView(canExport: _canExport),
    );
  }
}

class _AuditJournalView extends StatelessWidget {
  const _AuditJournalView({required this.canExport});

  final bool canExport;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Journal d\'audit'),
        actions: [
          const ModuleHelpButton(articleId: 'audit'),
          if (canExport)
            BlocBuilder<AuditJournalBloc, AuditJournalState>(
              buildWhen: (p, c) => p.isExporting != c.isExporting,
              builder: (context, state) {
                return IconButton(
                  tooltip: 'Exporter en PDF',
                  onPressed: state.isExporting
                      ? null
                      : () => context
                          .read<AuditJournalBloc>()
                          .add(const AuditJournalExportRequested()),
                  icon: state.isExporting
                      ? AuditFeedback.inlineLoader()
                      : const Icon(Icons.picture_as_pdf_outlined),
                );
              },
            ),
          IconButton(
            tooltip: 'Filtres',
            onPressed: () => _openFilters(context),
            icon: const Icon(Icons.filter_list),
          ),
        ],
      ),
      body: Column(
        children: [
          const OfflineModeBanner(
            onlinePreferredMessage: OfflineModeBanner.adminCacheMessage,
          ),
          BlocBuilder<AuditJournalBloc, AuditJournalState>(
            buildWhen: (p, c) => p.hasActiveFilters != c.hasActiveFilters,
            builder: (context, state) {
              if (!state.hasActiveFilters) return const SizedBox.shrink();
              return Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.md,
                  AppSpacing.sm,
                  AppSpacing.md,
                  0,
                ),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: InputChip(
                    label: const Text('Filtres actifs'),
                    deleteIcon: const Icon(Icons.close, size: 18),
                    onDeleted: () => context
                        .read<AuditJournalBloc>()
                        .add(const AuditJournalFiltersCleared()),
                  ),
                ),
              );
            },
          ),
          BlocConsumer<AuditJournalBloc, AuditJournalState>(
            listenWhen: (p, c) =>
                p.errorMessage != c.errorMessage ||
                p.exportErrorMessage != c.exportErrorMessage ||
                (p.exportSuccess != c.exportSuccess && c.exportSuccess),
            listener: (context, state) async {
              if (state.errorMessage != null) {
                AuditFeedback.showErrorMessage(context, state.errorMessage!);
              }
              if (state.exportErrorMessage != null) {
                AuditFeedback.showErrorMessage(
                  context,
                  state.exportErrorMessage!,
                );
              }
              if (state.exportSuccess) {
                await AuditFeedback.showSuccess(
                  context: context,
                  title: 'Journal exporté',
                  message:
                      'Choisissez une application de partage pour le fichier.',
                );
              }
            },
            builder: (context, state) {
              if (state.status == AuditJournalStatus.loading &&
                  state.items.isEmpty) {
                return const Expanded(
                  child: Center(child: CircularProgressIndicator()),
                );
              }

              if (state.status == AuditJournalStatus.failure &&
                  state.items.isEmpty) {
                return Expanded(
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.all(AppSpacing.lg),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.history_toggle_off,
                            size: 48,
                            color: Theme.of(context).colorScheme.outline,
                          ),
                          const SizedBox(height: AppSpacing.md),
                          Text(
                            state.errorMessage ??
                                'Impossible de charger le journal.',
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: AppSpacing.md),
                          FilledButton.icon(
                            onPressed: () => context
                                .read<AuditJournalBloc>()
                                .add(const AuditJournalLoadRequested()),
                            icon: const Icon(Icons.refresh),
                            label: const Text('Réessayer'),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }

              return Expanded(
                child: RefreshIndicator(
                  onRefresh: () async {
                    context
                        .read<AuditJournalBloc>()
                        .add(const AuditJournalLoadRequested());
                    await context.read<AuditJournalBloc>().stream.firstWhere(
                          (s) =>
                              s.status != AuditJournalStatus.loading ||
                              s.items.isNotEmpty,
                        );
                  },
                  child: _JournalList(state: state),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Future<void> _openFilters(BuildContext context) async {
    final bloc = context.read<AuditJournalBloc>();
    final state = bloc.state;
    final options = state.filterOptions;
    if (options == null) return;

    String? module = state.query.module;
    String? action = state.query.action;
    int? from = state.query.from;
    int? to = state.query.to;

    final result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                left: AppSpacing.md,
                right: AppSpacing.md,
                top: AppSpacing.md,
                bottom: MediaQuery.viewInsetsOf(ctx).bottom + AppSpacing.lg,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'Filtrer le journal',
                      style: Theme.of(ctx).textTheme.titleLarge,
                    ),
                    const SizedBox(height: AppSpacing.md),
                    DropdownButtonFormField<String?>(
                      initialValue: module,
                      decoration: const InputDecoration(
                        labelText: 'Module',
                        border: OutlineInputBorder(),
                      ),
                      items: [
                        const DropdownMenuItem<String?>(
                          value: null,
                          child: Text('Tous'),
                        ),
                        ...options.modules.map(
                          (m) => DropdownMenuItem(
                            value: m.code,
                            child: Text(m.label),
                          ),
                        ),
                      ],
                      onChanged: (v) => setModalState(() => module = v),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    DropdownButtonFormField<String?>(
                      initialValue: action,
                      decoration: const InputDecoration(
                        labelText: 'Action',
                        border: OutlineInputBorder(),
                      ),
                      items: [
                        const DropdownMenuItem<String?>(
                          value: null,
                          child: Text('Toutes'),
                        ),
                        ...options.actions.map(
                          (a) => DropdownMenuItem(
                            value: a.code,
                            child: Text(a.label),
                          ),
                        ),
                      ],
                      onChanged: (v) => setModalState(() => action = v),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Période'),
                      subtitle: Text(
                        from == null && to == null
                            ? 'Toutes dates'
                            : '${from != null ? formatBeninDate(from) : '…'} → '
                                '${to != null ? formatBeninDate(to) : '…'}',
                      ),
                      trailing: const Icon(Icons.date_range),
                      onTap: () async {
                        final range = await showDateRangePicker(
                          context: ctx,
                          firstDate: DateTime(2020),
                          lastDate: DateTime.now().add(const Duration(days: 1)),
                        );
                        if (range != null) {
                          setModalState(() {
                            from = range.start.millisecondsSinceEpoch;
                            to = range.end
                                    .add(const Duration(days: 1))
                                    .millisecondsSinceEpoch -
                                1;
                          });
                        }
                      },
                    ),
                    const SizedBox(height: AppSpacing.md),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () {
                              Navigator.pop(ctx, false);
                              bloc.add(const AuditJournalFiltersCleared());
                            },
                            child: const Text('Effacer'),
                          ),
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        Expanded(
                          child: FilledButton(
                            onPressed: () => Navigator.pop(ctx, true),
                            child: const Text('Appliquer'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );

    if (result == true && context.mounted) {
      bloc.add(
        AuditJournalFiltersChanged(
          state.query.copyWith(
            module: module,
            action: action,
            from: from,
            to: to,
            clearModule: module == null,
            clearAction: action == null,
            clearFrom: from == null,
            clearTo: to == null,
          ),
        ),
      );
    }
  }
}

class _JournalList extends StatelessWidget {
  const _JournalList({required this.state});

  final AuditJournalState state;

  @override
  Widget build(BuildContext context) {
    if (state.items.isEmpty) {
      return EmptyListPlaceholder(
        embedded: true,
        icon: Icons.fact_check_outlined,
        title: 'Aucune entrée dans le journal',
      );
    }

    return ListView.separated(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(AppSpacing.md),
      itemCount: state.items.length + (state.hasMore ? 1 : 0),
      separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.sm),
      itemBuilder: (context, index) {
        if (index >= state.items.length) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: state.isLoadingMore
                  ? const CircularProgressIndicator()
                  : TextButton(
                      onPressed: () => context
                          .read<AuditJournalBloc>()
                          .add(const AuditJournalLoadMoreRequested()),
                      child: const Text('Charger plus'),
                    ),
            ),
          );
        }

        final item = state.items[index];
        return _AuditLogTile(item: item);
      },
    );
  }
}

class _AuditLogTile extends StatelessWidget {
  const _AuditLogTile({required this.item});

  final AuditLogItem item;

  @override
  Widget build(BuildContext context) {
    final session = context.read<AuditJournalBloc>().session;
    final colorScheme = Theme.of(context).colorScheme;

    return Card(
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: colorScheme.secondaryContainer,
          child: Icon(Icons.history, color: colorScheme.onSecondaryContainer),
        ),
        title: Text(item.actionLabel),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('${item.moduleLabel} · ${formatAuditDateTime(item.createdAt)}'),
            if (item.userName != null) Text(item.userName!),
            if (item.reason != null && item.reason!.isNotEmpty)
              Text(
                item.reason!,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodySmall,
              ),
          ],
        ),
        trailing: item.hasDiff
            ? Icon(Icons.compare_arrows, color: colorScheme.primary)
            : const Icon(Icons.chevron_right),
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => AuditDetailPage(
              session: session,
              logId: item.id,
            ),
          ),
        ),
      ),
    );
  }
}
