import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../../../app/theme/app_tokens.dart';
import '../../data/utils/stock_transfer_qr_payload.dart';
import '../services/stock_transfer_qr_sharer.dart';

class StockTransferQrDialog extends StatefulWidget {
  const StockTransferQrDialog({
    super.key,
    required this.payload,
    required this.title,
  });

  final StockTransferQrPayload payload;
  final String title;

  static Future<void> show(
    BuildContext context, {
    required StockTransferQrPayload payload,
    required String title,
  }) {
    return showDialog<void>(
      context: context,
      builder: (_) => StockTransferQrDialog(payload: payload, title: title),
    );
  }

  @override
  State<StockTransferQrDialog> createState() => _StockTransferQrDialogState();
}

class _StockTransferQrDialogState extends State<StockTransferQrDialog> {
  bool _sharing = false;

  Future<void> _share() async {
    if (_sharing) return;
    setState(() => _sharing = true);
    try {
      await StockTransferQrSharer.share(widget.payload);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Partage impossible : $e')),
      );
    } finally {
      if (mounted) setState(() => _sharing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final encoded = widget.payload.encode();
    return AlertDialog(
      title: Text(widget.title),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '${widget.payload.reference} · ${widget.payload.shipmentLabel}',
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: AppSpacing.sm),
            Container(
              padding: const EdgeInsets.all(AppSpacing.sm),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(AppRadius.md),
              ),
              child: QrImageView(
                data: encoded,
                version: QrVersions.auto,
                size: 220,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'Partagez ce QR avec le chauffeur (WhatsApp, SMS…). '
              'Le vendeur destination le scanne à la livraison pour '
              'préremplir la réception.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _sharing ? null : () => Navigator.pop(context),
          child: const Text('Fermer'),
        ),
        FilledButton.icon(
          onPressed: _sharing ? null : _share,
          icon: _sharing
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.share_outlined),
          label: Text(_sharing ? 'Partage…' : 'Partager'),
        ),
      ],
    );
  }
}
