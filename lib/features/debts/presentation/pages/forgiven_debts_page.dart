import 'package:flutter/material.dart';

import '../../../../app/di/injection_container.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_tokens.dart';
import '../../../../core/errors/failures.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../../shared/components/empty_list_placeholder.dart';
import '../../../../shared/enums/permission.dart';
import '../../../../shared/guards/permission_guard.dart';
import '../../../auth/domain/entities/auth_entities.dart';
import '../../domain/entities/debt_entities.dart';
import '../../domain/usecases/debt_usecases.dart';
import 'debt_detail_page.dart';

class ForgivenDebtsPage extends StatelessWidget {
  const ForgivenDebtsPage({super.key, required this.session});

  final AuthSession session;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Dettes pardonnées'),
      ),
      body: ForgivenDebtsList(session: session),
    );
  }
}

class ForgivenDebtsList extends StatefulWidget {
  const ForgivenDebtsList({
    super.key,
    required this.session,
    this.customerId,
    this.customerName,
  });

  final AuthSession session;
  final int? customerId;
  final String? customerName;

  @override
  State<ForgivenDebtsList> createState() => _ForgivenDebtsListState();
}

class _ForgivenDebtsListState extends State<ForgivenDebtsList> {
  List<ForgivenDebtEntry> _entries = const [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final entries = await sl<ListForgivenDebts>()(
        session: widget.session,
        customerId: widget.customerId,
      );
      if (!mounted) return;
      setState(() {
        _entries = entries;
        _loading = false;
      });
    } on Failure catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.message;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'Impossible de charger les dettes pardonnées.';
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(_error!),
            const SizedBox(height: AppSpacing.md),
            FilledButton(onPressed: _load, child: const Text('Réessayer')),
          ],
        ),
      );
    }
    if (_entries.isEmpty) {
      return EmptyListPlaceholder.refreshable(
        icon: Icons.volunteer_activism_outlined,
        title: 'Aucune dette pardonnée',
        onRefresh: _load,
      );
    }

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.builder(
        padding: const EdgeInsets.all(AppSpacing.md),
        itemCount: _entries.length,
        itemBuilder: (context, index) {
          final entry = _entries[index];
          return _ForgivenDebtCard(
            entry: entry,
            showCustomerName: widget.customerId == null,
            onTap: () => _openDetail(entry),
          );
        },
      ),
    );
  }

  Future<void> _openDetail(ForgivenDebtEntry entry) async {
    if (!PermissionGuard.can(
      widget.session.user.permissions,
      Permission.debtsRead,
    )) {
      return;
    }

    final customerName =
        entry.customerName ?? widget.customerName ?? 'Client';

    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => DebtDetailPage(
          session: widget.session,
          debtId: entry.debt.id,
          customerName: customerName,
        ),
      ),
    );
  }
}

class _ForgivenDebtCard extends StatelessWidget {
  const _ForgivenDebtCard({
    required this.entry,
    required this.showCustomerName,
    required this.onTap,
  });

  final ForgivenDebtEntry entry;
  final bool showCustomerName;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final debt = entry.debt;
    final info = entry.forgiveness;
    final title = debt.receiptNumber != null
        ? 'Vente ${debt.receiptNumber}'
        : 'Dette #${debt.id}';

    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.md),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      title,
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                  ),
                  Text(
                    formatFcfa(info.forgivenAmount),
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          color: AppColors.seed,
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                ],
              ),
              if (showCustomerName && entry.customerName != null) ...[
                const SizedBox(height: AppSpacing.xs),
                Text(
                  entry.customerName!,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ],
              const SizedBox(height: AppSpacing.sm),
              Text(
                _formatDateTime(info.forgivenAt),
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                info.reason,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              if (info.forgivenByName != null) ...[
                const SizedBox(height: AppSpacing.xs),
                Text(
                  'Par ${info.forgivenByName}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  String _formatDateTime(int ms) {
    final dt = DateTime.fromMillisecondsSinceEpoch(ms);
    return '${dt.day.toString().padLeft(2, '0')}/'
        '${dt.month.toString().padLeft(2, '0')}/'
        '${dt.year} '
        '${dt.hour.toString().padLeft(2, '0')}:'
        '${dt.minute.toString().padLeft(2, '0')}';
  }
}
