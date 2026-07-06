import 'package:flutter/material.dart';

import '../../../../app/di/injection_container.dart';
import '../../../../app/theme/app_tokens.dart';
import '../../../../core/errors/exception_mapper.dart';
import '../../../../shared/components/empty_list_placeholder.dart';
import '../../../auth/domain/entities/auth_entities.dart';
import '../../domain/entities/audit_entities.dart';
import '../../domain/usecases/audit_usecases.dart';
import '../services/audit_pdf_exporter.dart';
import 'audit_detail_page.dart';

class AuditEntityHistoryPage extends StatefulWidget {
  const AuditEntityHistoryPage({
    super.key,
    required this.session,
    required this.entityTable,
    required this.entityId,
  });

  final AuthSession session;
  final String entityTable;
  final int entityId;

  @override
  State<AuditEntityHistoryPage> createState() => _AuditEntityHistoryPageState();
}

class _AuditEntityHistoryPageState extends State<AuditEntityHistoryPage> {
  late Future<AuditEntityHistory> _future;

  @override
  void initState() {
    super.initState();
    ensureAuditDependencies();
    _reload();
  }

  void _reload() {
    _future = sl<GetEntityAuditHistory>()(
      shopId: widget.session.shop.id,
      entityTable: widget.entityTable,
      entityId: widget.entityId,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.entityTable} #${widget.entityId}'),
      ),
      body: FutureBuilder<AuditEntityHistory>(
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
                      onPressed: () => setState(_reload),
                      child: const Text('Réessayer'),
                    ),
                  ],
                ),
              ),
            );
          }

          final history = snapshot.data!;
          if (history.timeline.isEmpty) {
            return EmptyListPlaceholder.refreshable(
              icon: Icons.history,
              title: 'Aucun historique pour cette entité',
              onRefresh: () async => setState(_reload),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.all(AppSpacing.md),
            itemCount: history.timeline.length,
            separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.sm),
            itemBuilder: (context, index) {
              final entry = history.timeline[index];
              return Card(
                child: ListTile(
                  leading: CircleAvatar(
                    child: Text('${index + 1}'),
                  ),
                  title: Text(entry.actionLabel),
                  subtitle: Text(
                    '${formatAuditDateTime(entry.createdAt)} · '
                    '${entry.userName ?? 'Utilisateur #${entry.userId}'}',
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => AuditDetailPage(
                        session: widget.session,
                        logId: entry.id,
                      ),
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
