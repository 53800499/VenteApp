import 'package:flutter/material.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../core/utils/currency_formatter.dart';

/// Bouton de sélection produit avec texte tronqué (évite les overflows).
class CalculatorProductPickerButton extends StatelessWidget {
  const CalculatorProductPickerButton({
    super.key,
    required this.productName,
    required this.unitPrice,
    required this.onPressed,
    this.onClear,
  });

  final String? productName;
  final int? unitPrice;
  final VoidCallback onPressed;
  final VoidCallback? onClear;

  @override
  Widget build(BuildContext context) {
    final hasProduct = productName != null && productName!.isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        OutlinedButton(
          onPressed: onPressed,
          style: OutlinedButton.styleFrom(
            minimumSize: const Size.fromHeight(48),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
          child: Row(
            children: [
              const Icon(Icons.search),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  hasProduct
                      ? '$productName (${formatFcfa(unitPrice ?? 0)})'
                      : 'Rechercher un produit…',
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
              ),
            ],
          ),
        ),
        if (hasProduct && onClear != null) ...[
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Produit lié sélectionné',
                style: TextStyle(fontSize: 12, color: AppColors.onSurfaceMuted),
              ),
              TextButton(
                onPressed: onClear,
                child: const Text(
                  'Détacher',
                  style: TextStyle(color: AppColors.danger),
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }
}
