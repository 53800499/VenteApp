import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../../../app/theme/app_tokens.dart';
import '../../../../core/errors/exception_mapper.dart';
import '../../../../core/errors/failures.dart';
import '../../domain/entities/stock_transfer.dart';
import '../../domain/repositories/stock_transfer_repository.dart';

class StockTransferQrScanPage extends StatefulWidget {
  const StockTransferQrScanPage({
    super.key,
    required this.repository,
    required this.shopId,
  });

  final StockTransferRepository repository;
  final int shopId;

  @override
  State<StockTransferQrScanPage> createState() =>
      _StockTransferQrScanPageState();
}

class _StockTransferQrScanPageState extends State<StockTransferQrScanPage> {
  final MobileScannerController _controller = MobileScannerController();
  bool _processing = false;
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _onDetect(BarcodeCapture capture) async {
    if (_processing) return;
    final raw = capture.barcodes.firstOrNull?.rawValue;
    if (raw == null || raw.isEmpty) return;

    setState(() {
      _processing = true;
      _error = null;
    });

    try {
      final intent = await widget.repository.resolveQrReceiveIntent(
        rawPayload: raw,
        destinationShopId: widget.shopId,
      );
      if (!mounted) return;
      Navigator.pop(context, intent);
    } on Failure catch (e) {
      if (!mounted) return;
      setState(() {
        _processing = false;
        _error = friendlyErrorMessage(e);
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _processing = false;
        _error = 'QR illisible.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Scanner QR expédition')),
      body: Column(
        children: [
          Expanded(
            child: Stack(
              fit: StackFit.expand,
              children: [
                MobileScanner(
                  controller: _controller,
                  onDetect: _onDetect,
                ),
                if (_processing)
                  const ColoredBox(
                    color: Colors.black45,
                    child: Center(child: CircularProgressIndicator()),
                  ),
              ],
            ),
          ),
          if (_error != null)
            Container(
              width: double.infinity,
              color: Colors.red.shade50,
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Text(
                _error!,
                style: TextStyle(color: Colors.red.shade900),
              ),
            ),
          Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Text(
              'Placez le QR code de l\'expédition dans le cadre.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
        ],
      ),
    );
  }
}

typedef StockTransferQrScanResult = StockTransferQrReceiveIntent;
