import '../../../../core/utils/currency_formatter.dart';
import '../../domain/entities/sale_entities.dart';

/// Formate un reçu de vente en texte (partage / impression).
class ReceiptFormatterService {
  const ReceiptFormatterService();

  String formatText({
    required String shopName,
    required Sale sale,
    String? shopPhone,
  }) {
    final buffer = StringBuffer();
    final dt = DateTime.fromMillisecondsSinceEpoch(sale.createdAt);
    final date =
        '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year} '
        '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';

    buffer.writeln(shopName.toUpperCase());
    if (shopPhone != null && shopPhone.isNotEmpty) {
      buffer.writeln(shopPhone);
    }
    buffer.writeln('─' * 32);
    buffer.writeln(sale.receiptNumber ?? 'Vente #${sale.id}');
    buffer.writeln(date);
    buffer.writeln('─' * 32);

    for (final item in sale.items) {
      buffer.writeln('${item.productName} x${item.quantity}');
      buffer.writeln('  ${formatFcfa(item.lineTotal)}');
    }

    buffer.writeln('─' * 32);
    buffer.writeln('Sous-total : ${formatFcfa(sale.subtotal)}');
    if (sale.discountAmount > 0) {
      buffer.writeln('Remise     : -${formatFcfa(sale.discountAmount)}');
    }
    buffer.writeln('TOTAL      : ${formatFcfa(sale.totalAmount)}');
    buffer.writeln('Paiement   : ${sale.paymentMethod.label}');
    if (sale.amountCash > 0) {
      buffer.writeln('Espèces    : ${formatFcfa(sale.amountCash)}');
    }
    if (sale.amountMomo > 0) {
      buffer.writeln('MoMo       : ${formatFcfa(sale.amountMomo)}');
    }
    if (sale.amountCredit > 0) {
      buffer.writeln('Crédit     : ${formatFcfa(sale.amountCredit)}');
    }
    if (sale.customerName != null) {
      buffer.writeln('Client     : ${sale.customerName}');
    }
    buffer.writeln('─' * 32);
    buffer.writeln('Merci pour votre achat !');
    return buffer.toString();
  }
}
