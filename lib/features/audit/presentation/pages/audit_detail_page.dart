import 'dart:convert';

import 'package:flutter/material.dart';

import '../../../../app/di/injection_container.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_tokens.dart';
import '../../../../core/errors/exception_mapper.dart';
import '../../../../core/responsive/responsive_builder.dart';
import '../../../auth/domain/entities/auth_entities.dart';
import '../../domain/entities/audit_entities.dart';
import '../../domain/usecases/audit_usecases.dart';
import '../services/audit_pdf_exporter.dart';
import '../services/audit_value_presenter.dart';
import 'audit_entity_history_page.dart';

class AuditDetailPage extends StatefulWidget {
  const AuditDetailPage({
    super.key,
    required this.session,
    required this.logId,
  });

  final AuthSession session;
  final int logId;

  @override
  State<AuditDetailPage> createState() => _AuditDetailPageState();
}

class _AuditDetailPageState extends State<AuditDetailPage> {
  late Future<AuditLogDetail> _future;
  static const _presenter = AuditValuePresenter();
  bool _exporting = false;

  @override
  void initState() {
    super.initState();
    ensureAuditDependencies();
    _future = sl<GetAuditLogDetail>()(
      shopId: widget.session.shop.id,
      id: widget.logId,
    );
  }

  Future<void> _exportEntry(AuditLogDetail detail) async {
    if (_exporting) return;
    setState(() => _exporting = true);
    try {
      await const AuditPdfExporter().sharePdf(
        shopName: widget.session.shop.name,
        export: AuditExportResult(
          entries: [detail],
          total: 1,
          shopId: widget.session.shop.id,
          exportedAt: DateTime.now().millisecondsSinceEpoch,
          pdfHint: '',
        ),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(friendlyErrorMessage(error))),
      );
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Détail audit'),
        actions: [
          FutureBuilder<AuditLogDetail>(
            future: _future,
            builder: (context, snapshot) {
              final detail = snapshot.data;
              if (detail == null) return const SizedBox.shrink();
              return IconButton(
                tooltip: 'Exporter en PDF',
                onPressed: _exporting ? null : () => _exportEntry(detail),
                icon: _exporting
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.picture_as_pdf_outlined),
              );
            },
          ),
        ],
      ),
      body: FutureBuilder<AuditLogDetail>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(friendlyErrorMessage(snapshot.error!)),
                    const SizedBox(height: AppSpacing.md),
                    FilledButton(
                      onPressed: () {
                        setState(() {
                          _future = sl<GetAuditLogDetail>()(
                            shopId: widget.session.shop.id,
                            id: widget.logId,
                          );
                        });
                      },
                      child: const Text('Réessayer'),
                    ),
                  ],
                ),
              ),
            );
          }

          final detail = snapshot.data!;
          final diffs = _presenter.diff(
            before: detail.oldValue,
            after: detail.newValue,
          );
          final hasOnlyAfter =
              detail.oldValue == null && detail.newValue != null;
          final hasOnlyBefore =
              detail.oldValue != null && detail.newValue == null;

          return ResponsivePage(
            child: ListView(
              padding: const EdgeInsets.all(AppSpacing.md),
              children: [
                _HeaderCard(detail: detail, presenter: _presenter),
                const SizedBox(height: AppSpacing.md),
                if (detail.reason != null && detail.reason!.isNotEmpty)
                  _Section(
                    title: 'Motif',
                    child: Text(detail.reason!),
                  ),
                if (diffs.isNotEmpty) ...[
                  const SizedBox(height: AppSpacing.md),
                  _Section(
                    title: 'Modifications',
                    child: _DiffList(diffs: diffs),
                  ),
                ] else if (hasOnlyAfter) ...[
                  const SizedBox(height: AppSpacing.md),
                  _Section(
                    title: 'Données enregistrées',
                    child: _KeyValueList(
                      rows: _presenter.rowsFrom(detail.newValue!),
                    ),
                  ),
                ] else if (hasOnlyBefore) ...[
                  const SizedBox(height: AppSpacing.md),
                  _Section(
                    title: 'Données précédentes',
                    child: _KeyValueList(
                      rows: _presenter.rowsFrom(detail.oldValue!),
                    ),
                  ),
                ],
                if (detail.oldValue != null || detail.newValue != null) ...[
                  const SizedBox(height: AppSpacing.md),
                  ExpansionTile(
                    tilePadding: EdgeInsets.zero,
                    title: Text(
                      'Données techniques',
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                    subtitle: const Text('Réservé au diagnostic'),
                    children: [
                      if (detail.oldValue != null)
                        _Section(
                          title: 'Avant (brut)',
                          child: _JsonView(data: detail.oldValue!),
                        ),
                      if (detail.newValue != null) ...[
                        const SizedBox(height: AppSpacing.sm),
                        _Section(
                          title: 'Après (brut)',
                          child: _JsonView(data: detail.newValue!),
                        ),
                      ],
                    ],
                  ),
                ],
                const SizedBox(height: AppSpacing.lg),
                OutlinedButton.icon(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => AuditEntityHistoryPage(
                        session: widget.session,
                        entityTable: detail.entityTable,
                        entityId: detail.entityId,
                      ),
                    ),
                  ),
                  icon: const Icon(Icons.timeline_outlined),
                  label: Text(
                    'Historique ${_presenter.entityLabel(detail.entityTable)} '
                    '#${detail.entityId}',
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _HeaderCard extends StatelessWidget {
  const _HeaderCard({required this.detail, required this.presenter});

  final AuditLogDetail detail;
  final AuditValuePresenter presenter;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              detail.actionLabel,
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(detail.moduleLabel, style: theme.textTheme.titleMedium),
            const Divider(height: AppSpacing.lg),
            _MetaRow(
              icon: Icons.schedule,
              label: formatAuditDateTime(detail.createdAt),
            ),
            _MetaRow(
              icon: Icons.person_outline,
              label: detail.userName ?? 'Utilisateur #${detail.userId}',
            ),
            _MetaRow(
              icon: Icons.link,
              label:
                  '${presenter.entityLabel(detail.entityTable)} #${detail.entityId}',
            ),
          ],
        ),
      ),
    );
  }
}

class _MetaRow extends StatelessWidget {
  const _MetaRow({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.xs),
      child: Row(
        children: [
          Icon(icon, size: 18),
          const SizedBox(width: AppSpacing.sm),
          Expanded(child: Text(label)),
        ],
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
            ),
            const SizedBox(height: AppSpacing.sm),
            child,
          ],
        ),
      ),
    );
  }
}

class _KeyValueList extends StatelessWidget {
  const _KeyValueList({required this.rows});

  final List<({String label, String value})> rows;

  @override
  Widget build(BuildContext context) {
    if (rows.isEmpty) {
      return Text(
        'Aucune donnée à afficher.',
        style: Theme.of(context).textTheme.bodyMedium,
      );
    }
    return Column(
      children: [
        for (var i = 0; i < rows.length; i++) ...[
          if (i > 0) const Divider(height: AppSpacing.md),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 2,
                child: Text(
                  rows[i].label,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                flex: 3,
                child: Text(
                  rows[i].value,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }
}

class _DiffList extends StatelessWidget {
  const _DiffList({required this.diffs});

  final List<AuditFieldDiff> diffs;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      children: [
        for (var i = 0; i < diffs.length; i++) ...[
          if (i > 0) const Divider(height: AppSpacing.lg),
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              diffs[i].label,
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          if (diffs[i].before != null)
            _ChangeRow(
              label: 'Avant',
              value: diffs[i].before!,
              color: AppColors.surface,
              borderColor: AppColors.onSurfaceMuted.withValues(alpha: 0.25),
            ),
          if (diffs[i].after != null) ...[
            const SizedBox(height: 4),
            _ChangeRow(
              label: 'Après',
              value: diffs[i].after!,
              color: AppColors.lockGradientTop,
              borderColor: AppColors.seed.withValues(alpha: 0.25),
            ),
          ],
        ],
      ],
    );
  }
}

class _ChangeRow extends StatelessWidget {
  const _ChangeRow({
    required this.label,
    required this.value,
    required this.color,
    this.borderColor,
  });

  final String label;
  final String value;
  final Color color;
  final Color? borderColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: borderColor ?? AppColors.onSurfaceMuted.withValues(alpha: 0.2),
        ),
      ),
      child: RichText(
        text: TextSpan(
          style: Theme.of(context).textTheme.bodyMedium,
          children: [
            TextSpan(
              text: '$label : ',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            TextSpan(text: value),
          ],
        ),
      ),
    );
  }
}

class _JsonView extends StatelessWidget {
  const _JsonView({required this.data});

  final Map<String, dynamic> data;

  @override
  Widget build(BuildContext context) {
    final pretty = const JsonEncoder.withIndent('  ').convert(data);
    return SelectableText(
      pretty,
      style: Theme.of(context).textTheme.bodySmall?.copyWith(
            fontFamily: 'monospace',
          ),
    );
  }
}
