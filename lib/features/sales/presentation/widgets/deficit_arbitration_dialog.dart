import 'package:flutter/material.dart';

import '../../../../app/theme/app_tokens.dart';

/// Modal d'arbitrage intelligent lorsque la quantité demandée dépasse le stock disponible.
class DeficitArbitrationDialog extends StatefulWidget {
  const DeficitArbitrationDialog({
    super.key,
    required this.productName,
    required this.availableStock,
    required this.requestedQuantity,
    required this.onAuthorizeDeficit,
    this.onProcure,
    required this.onAdjustQuantity,
  });

  final String productName;
  final int availableStock;
  final int requestedQuantity;
  final void Function(int quantity, String reason) onAuthorizeDeficit;
  final VoidCallback? onProcure;
  final void Function(int adjustedQuantity) onAdjustQuantity;

  static Future<void> show({
    required BuildContext context,
    required String productName,
    required int availableStock,
    required int requestedQuantity,
    required void Function(int quantity, String reason) onAuthorizeDeficit,
    VoidCallback? onProcure,
    required void Function(int adjustedQuantity) onAdjustQuantity,
  }) {
    return showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (_) => DeficitArbitrationDialog(
        productName: productName,
        availableStock: availableStock,
        requestedQuantity: requestedQuantity,
        onAuthorizeDeficit: onAuthorizeDeficit,
        onProcure: onProcure,
        onAdjustQuantity: onAdjustQuantity,
      ),
    );
  }

  @override
  State<DeficitArbitrationDialog> createState() => _DeficitArbitrationDialogState();
}

class _DeficitArbitrationDialogState extends State<DeficitArbitrationDialog> {
  static const _predefinedReasons = [
    'Marchandise reçue non encore enregistrée',
    'Stock physique supérieur au logiciel',
    'Achat fournisseur en cours',
    'Erreur de saisie inventaire antérieure',
    'Autre motif commercial justifié',
  ];

  late String _selectedReason;
  final _customReasonCtrl = TextEditingController();

  int get _deficit => widget.requestedQuantity - (widget.availableStock > 0 ? widget.availableStock : 0);
  bool get _isZeroStock => widget.availableStock <= 0;

  @override
  void initState() {
    super.initState();
    _selectedReason = _predefinedReasons.first;
  }

  @override
  void dispose() {
    _customReasonCtrl.dispose();
    super.dispose();
  }

  void _submitAuthorization() {
    final reason = _selectedReason == 'Autre motif commercial justifié' && _customReasonCtrl.text.trim().isNotEmpty
        ? _customReasonCtrl.text.trim()
        : _selectedReason;
    Navigator.of(context).pop();
    widget.onAuthorizeDeficit(widget.requestedQuantity, reason);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    const amberColor = Color(0xFFD97706);
    const amberBg = Color(0xFFFFFBEB);
    const emeraldColor = Color(0xFF0B6E4F);

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header
              Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF78350F) : amberBg,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.warning_amber_rounded,
                      color: amberColor,
                      size: 26,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Stock insuffisant',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          'Pour « ${widget.productName} »',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),

              Text(
                'La quantité demandée dépasse le stock actuellement enregistré.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: isDark ? Colors.white70 : const Color(0xFF475569),
                ),
              ),
              const SizedBox(height: AppSpacing.md),

              // KPI Cards: Dispo / Demandé / Déficit
              Container(
                padding: const EdgeInsets.all(AppSpacing.md),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                  ),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        children: [
                          Text(
                            'Stock dispo',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${widget.availableStock}',
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: widget.availableStock <= 0 ? Colors.redAccent : null,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(width: 1, height: 36, color: isDark ? Colors.white24 : Colors.black12),
                    Expanded(
                      child: Column(
                        children: [
                          Text(
                            'Demandé',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${widget.requestedQuantity}',
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(width: 1, height: 36, color: isDark ? Colors.white24 : Colors.black12),
                    Expanded(
                      child: Column(
                        children: [
                          Text(
                            'Déficit',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: amberColor,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '-$_deficit',
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: amberColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.md),

              // Justification motif
              Text(
                _isZeroStock
                    ? 'Motif du déficit (Obligatoire — stock à zéro) :'
                    : 'Motif du déficit constaté :',
                style: theme.textTheme.bodySmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 6),
              DropdownButtonFormField<String>(
                value: _selectedReason,
                isExpanded: true,
                decoration: InputDecoration(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                ),
                items: _predefinedReasons.map((r) {
                  return DropdownMenuItem(
                    value: r,
                    child: Text(r, style: const TextStyle(fontSize: 13)),
                  );
                }).toList(),
                onChanged: (val) {
                  if (val != null) setState(() => _selectedReason = val);
                },
              ),
              if (_selectedReason == 'Autre motif commercial justifié') ...[
                const SizedBox(height: 8),
                TextField(
                  controller: _customReasonCtrl,
                  decoration: InputDecoration(
                    hintText: 'Précisez le motif...',
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ],
              const SizedBox(height: AppSpacing.lg),

              // Actions
              Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  FilledButton.icon(
                    onPressed: _submitAuthorization,
                    style: FilledButton.styleFrom(
                      backgroundColor: emeraldColor,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    icon: const Icon(Icons.check_circle_outline_rounded, size: 18),
                    label: Text('Autoriser la vente avec déficit (-$_deficit)'),
                  ),
                  if (widget.onProcure != null) ...[
                    const SizedBox(height: 8),
                    OutlinedButton.icon(
                      onPressed: () {
                        Navigator.of(context).pop();
                        widget.onProcure!();
                      },
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      icon: const Icon(Icons.local_shipping_outlined, size: 18),
                      label: const Text('Enregistrer un approvisionnement'),
                    ),
                  ],
                  const SizedBox(height: 8),
                  TextButton(
                    onPressed: () {
                      Navigator.of(context).pop();
                      widget.onAdjustQuantity(widget.availableStock > 0 ? widget.availableStock : 1);
                    },
                    child: Text(
                      widget.availableStock > 0
                          ? 'Modifier la quantité (${widget.availableStock} unités)'
                          : 'Annuler',
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

