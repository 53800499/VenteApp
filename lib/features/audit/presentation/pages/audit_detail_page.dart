import 'dart:convert';

import 'package:flutter/material.dart';

import '../../../../app/di/injection_container.dart';
import '../../../../app/theme/app_tokens.dart';
import '../../../../core/errors/exception_mapper.dart';
import '../../../../core/responsive/responsive_builder.dart';
import '../../../auth/domain/entities/auth_entities.dart';
import '../../domain/entities/audit_entities.dart';
import '../../domain/usecases/audit_usecases.dart';
import '../services/audit_pdf_exporter.dart';
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

  @override
  void initState() {
    super.initState();
    ensureAuditDependencies();
    _future = sl<GetAuditLogDetail>()(
      shopId: widget.session.shop.id,
      id: widget.logId,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Détail audit')),
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
          return ResponsivePage(
            child: ListView(
              padding: const EdgeInsets.all(AppSpacing.md),
              children: [
                _HeaderCard(detail: detail),
                const SizedBox(height: AppSpacing.md),
                if (detail.reason != null && detail.reason!.isNotEmpty)
                  _Section(
                    title: 'Motif',
                    child: Text(detail.reason!),
                  ),
                if (detail.oldValue != null) ...[
                  const SizedBox(height: AppSpacing.md),
                  _Section(
                    title: 'Valeur avant',
                    child: _JsonView(data: detail.oldValue!),
                  ),
                ],
                if (detail.newValue != null) ...[
                  const SizedBox(height: AppSpacing.md),
                  _Section(
                    title: 'Valeur après',
                    child: _JsonView(data: detail.newValue!),
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
                    'Historique ${detail.entityTable} #${detail.entityId}',
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
  const _HeaderCard({required this.detail});

  final AuditLogDetail detail;

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
              label: '${detail.entityTable} #${detail.entityId}',
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
