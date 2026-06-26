import 'package:flutter/material.dart';

import '../../../../app/di/injection_container.dart';
import '../../../../app/theme/app_tokens.dart';
import '../../../../core/errors/failures.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../../shared/enums/permission.dart';
import '../../../../shared/enums/user_role.dart';
import '../../../../shared/guards/permission_guard.dart';
import '../../../auth/domain/entities/auth_entities.dart';
import '../../domain/entities/sale_entities.dart';
import '../../domain/usecases/sale_usecases.dart';
import 'sale_receipt_page.dart';

class SaleDetailPage extends StatefulWidget {
  const SaleDetailPage({
    super.key,
    required this.session,
    required this.saleId,
  });

  final AuthSession session;
  final int saleId;

  @override
  State<SaleDetailPage> createState() => _SaleDetailPageState();
}

class _SaleDetailPageState extends State<SaleDetailPage> {
  Sale? _sale;
  String? _error;
  bool _loading = true;
  bool _cancelling = false;

  bool get _canCancel =>
      widget.session.user.role == UserRole.owner &&
      PermissionGuard.can(
        widget.session.user.permissions,
        Permission.salesCancel,
      );

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
      final sale = await sl<GetSale>()(
        session: widget.session,
        saleId: widget.saleId,
      );
      if (mounted) {
        setState(() {
          _sale = sale;
          _loading = false;
        });
      }
    } on Failure catch (e) {
      if (mounted) {
        setState(() {
          _error = e.message;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _error = 'Impossible de charger la vente.';
          _loading = false;
        });
      }
    }
  }

  Future<void> _cancel() async {
    final reasonController = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Annuler la vente'),
        content: TextField(
          controller: reasonController,
          decoration: const InputDecoration(
            labelText: 'Motif (min. 5 caractères)',
          ),
          maxLines: 3,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Non'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Annuler la vente'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    setState(() => _cancelling = true);
    try {
      await sl<CancelSale>()(
        session: widget.session,
        saleId: widget.saleId,
        reason: reasonController.text,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Vente annulée.')),
        );
        await _load();
      }
    } on Failure catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.message)),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Échec de l\'annulation.')),
        );
      }
    } finally {
      reasonController.dispose();
      if (mounted) setState(() => _cancelling = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Détail vente'),
        actions: [
          if (_sale != null)
            IconButton(
              icon: const Icon(Icons.receipt_long_outlined),
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => SaleReceiptPage(
                    session: widget.session,
                    sale: _sale!,
                  ),
                ),
              ),
            ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text(_error!))
              : _buildContent(context, _sale!),
      bottomNavigationBar: _sale != null &&
              !_sale!.isCancelled &&
              _canCancel
          ? SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.md),
                child: OutlinedButton(
                  onPressed: _cancelling ? null : _cancel,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Theme.of(context).colorScheme.error,
                  ),
                  child: _cancelling
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Annuler la vente'),
                ),
              ),
            )
          : null,
    );
  }

  Widget _buildContent(BuildContext context, Sale sale) {
    final dt = DateTime.fromMillisecondsSinceEpoch(sale.createdAt);
    final date =
        '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year} '
        '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';

    return ListView(
      padding: const EdgeInsets.all(AppSpacing.md),
      children: [
        ListTile(
          title: Text(sale.receiptNumber ?? 'Vente #${sale.id}'),
          subtitle: Text(date),
          trailing: Text(
            formatFcfa(sale.totalAmount),
            style: Theme.of(context).textTheme.titleLarge,
          ),
        ),
        if (sale.isCancelled)
          Card(
            color: Theme.of(context).colorScheme.errorContainer,
            child: ListTile(
              title: const Text('Vente annulée'),
              subtitle: Text(sale.cancelReason ?? ''),
            ),
          ),
        const Divider(),
        ...sale.items.map(
          (item) => ListTile(
            title: Text(item.productName),
            subtitle: Text('${item.quantity} × ${formatFcfa(item.unitPrice)}'),
            trailing: Text(formatFcfa(item.lineTotal)),
          ),
        ),
      ],
    );
  }
}
