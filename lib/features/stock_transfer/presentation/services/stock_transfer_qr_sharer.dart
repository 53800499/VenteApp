import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../../../core/backup/backup_file_sharer.dart';
import '../../data/utils/stock_transfer_qr_payload.dart';

class StockTransferQrSharer {
  StockTransferQrSharer._();

  static Future<void> share(StockTransferQrPayload payload) async {
    final encoded = payload.encode();
    final pngBytes = await _renderQrPng(encoded);
    final safeRef = payload.reference.replaceAll(RegExp(r'[^\w\-]+'), '_');
    final safeLabel = payload.shipmentLabel.replaceAll(RegExp(r'[^\w\-]+'), '_');

    await BackupFileSharer.shareBytes(
      bytes: pngBytes,
      filename: 'qr_${safeRef}_$safeLabel.png',
      mimeType: 'image/png',
      subject: 'QR expédition — ${payload.reference}',
      text: _shareMessage(payload),
    );
  }

  static String _shareMessage(StockTransferQrPayload payload) {
    final date = DateTime.fromMillisecondsSinceEpoch(payload.shippedAt)
        .toLocal()
        .toString()
        .substring(0, 16);
    final lines = <String>[
      'Expédition ARIKE',
      '${payload.reference} · ${payload.shipmentLabel}',
      'Expédié le $date',
      '',
      if (payload.items.isNotEmpty) ...[
        'Articles :',
        ...payload.items.map(
          (i) =>
              '• ${i.productName ?? i.productServerId} : ${i.quantity}',
        ),
        '',
      ],
      'À la livraison, le vendeur destination scanne ce QR dans '
      'Transferts → Scanner QR.',
    ];
    return lines.join('\n');
  }

  static Future<List<int>> _renderQrPng(String data) async {
    final painter = QrPainter(
      data: data,
      version: QrVersions.auto,
      gapless: true,
      eyeStyle: const QrEyeStyle(color: Colors.black),
      dataModuleStyle: const QrDataModuleStyle(color: Colors.black),
    );
    final imageData = await painter.toImageData(512, format: ImageByteFormat.png);
    if (imageData == null) {
      throw StateError('Impossible de générer l\'image QR.');
    }
    return imageData.buffer.asUint8List();
  }
}
