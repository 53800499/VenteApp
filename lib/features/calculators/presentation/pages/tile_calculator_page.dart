import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:drift/drift.dart' as drift;

import '../../../../app/di/injection_container.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../core/database/app_database.dart' as db;
import '../../../../core/utils/currency_formatter.dart';
import '../../../auth/domain/entities/auth_entities.dart';
import '../bloc/calculators_bloc.dart';
import '../../domain/entities/calculator_entities.dart';
import '../../domain/tile_calculator.dart';
import '../../domain/business_calculator.dart';
import '../services/calculator_pdf_exporter.dart';
import '../utils/calculator_form_validators.dart';
import '../widgets/calculator_product_picker_button.dart';

class CalculationIntent {
  const CalculationIntent({
    required this.productId,
    required this.productName,
    required this.quantity,
    required this.unitPrice,
  });

  final int productId;
  final String productName;
  final double quantity;
  final double unitPrice;
}

class TileCalculatorPage extends StatefulWidget {
  const TileCalculatorPage({
    super.key,
    required this.session,
    this.initialHistory,
  });

  final AuthSession session;
  final CalculatorHistoryEntry? initialHistory;

  @override
  State<TileCalculatorPage> createState() => _TileCalculatorPageState();
}

class _TileCalculatorPageState extends State<TileCalculatorPage> {
  final _formKey = GlobalKey<FormState>();
  
  // Inputs controllers
  final _areaController = TextEditingController();
  final _lengthController = TextEditingController(text: '60');
  final _widthController = TextEditingController(text: '60');
  final _piecesController = TextEditingController(text: '1');
  final _wasteController = TextEditingController(text: '10');
  final _labelController = TextEditingController();

  db.Product? _selectedProduct;
  CalculatorResult? _result;

  @override
  void initState() {
    super.initState();
    if (widget.initialHistory != null) {
      final inputs = widget.initialHistory!.input;
      _areaController.text = '${inputs['area'] ?? ''}';
      _lengthController.text = '${inputs['tileLengthCm'] ?? '60'}';
      _widthController.text = '${inputs['tileWidthCm'] ?? '60'}';
      _piecesController.text = '${inputs['piecesPerBox'] ?? '1'}';
      _wasteController.text = '${inputs['wastePercent'] ?? '10'}';
      _labelController.text = widget.initialHistory!.label ?? '';
      _calculate();
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider.value(
      value: sl<CalculatorsBloc>(),
      child: Scaffold(
        appBar: AppBar(
          title: Text(widget.initialHistory != null
              ? 'Détail : Carrelage'
              : 'Calculateur Carrelage'),
          actions: [
            if (_result != null) ...[
              IconButton(
                icon: const Icon(Icons.share),
                tooltip: 'Partager le rapport PDF',
                onPressed: _exportPdf,
              ),
              IconButton(
                icon: const Icon(Icons.save_outlined),
                tooltip: 'Enregistrer dans l\'historique',
                onPressed: _showSaveHistoryDialog,
              ),
            ]
          ],
        ),
        body: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(16.0),
            children: [
              _buildProductSearchCard(),
              const SizedBox(height: 16),
              _buildInputsCard(),
              const SizedBox(height: 16),
              if (_result != null) _buildResultsCard(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProductSearchCard() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Associer un produit du catalogue (Optionnel)',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: AppColors.seed,
              ),
            ),
            const SizedBox(height: 12),
            CalculatorProductPickerButton(
              productName: _selectedProduct?.name,
              unitPrice: _selectedProduct?.priceSell,
              onPressed: _showProductSearchDialog,
              onClear: _selectedProduct == null
                  ? null
                  : () {
                      setState(() => _selectedProduct = null);
                      _calculate();
                    },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInputsCard() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Paramètres de surface & carreaux',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: AppColors.seed,
              ),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _areaController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Surface à couvrir (m²)',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.aspect_ratio),
              ),
              validator: (val) => CalculatorFormValidators.requiredPositiveDouble(
                val,
                label: 'la surface à couvrir',
              ),
              onChanged: (_) => _calculate(),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _lengthController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Longueur (cm)',
                      border: OutlineInputBorder(),
                    ),
                    validator: (val) => CalculatorFormValidators.requiredPositiveDouble(
                      val,
                      label: 'la longueur',
                    ),
                    onChanged: (_) => _calculate(),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: _widthController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Largeur (cm)',
                      border: OutlineInputBorder(),
                    ),
                    validator: (val) => CalculatorFormValidators.requiredPositiveDouble(
                      val,
                      label: 'la largeur',
                    ),
                    onChanged: (_) => _calculate(),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _piecesController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Carreaux par carton',
                      border: OutlineInputBorder(),
                    ),
                    validator: (val) => CalculatorFormValidators.requiredPositiveInt(
                      val,
                      label: 'le nombre de carreaux par carton',
                    ),
                    onChanged: (_) => _calculate(),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: _wasteController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Marge perte (%)',
                      border: OutlineInputBorder(),
                    ),
                    validator: (val) => CalculatorFormValidators.percent(
                      val,
                      label: 'La marge perte',
                    ),
                    onChanged: (_) => _calculate(),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildResultsCard() {
    return Card(
      elevation: 3,
      color: AppColors.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Résultats de l\'estimation',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
                color: AppColors.seed,
              ),
            ),
            const SizedBox(height: 16),
            ..._result!.metrics.map((m) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(m.label, style: const TextStyle(color: AppColors.onSurfaceMuted)),
                      Text(
                        '${m.value} ${m.unit}',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                )),
            const Divider(height: 24),
            if (_selectedProduct != null) ...[
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Coût total estimé',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                  ),
                  Text(
                    formatFcfa(_result!.estimatedPrice.toInt()),
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppColors.seed,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: _injectToSale,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.secondary,
                  foregroundColor: Colors.white,
                  minimumSize: const Size.fromHeight(48),
                ),
                icon: const Icon(Icons.add_shopping_cart),
                label: const Text('Ajouter à la vente'),
              ),
            ]
          ],
        ),
      ),
    );
  }

  void _calculate() {
    if (!_formKey.currentState!.validate()) {
      setState(() => _result = null);
      return;
    }

    final area = double.tryParse(_areaController.text.replaceAll(',', '.'));
    final tileLength = double.tryParse(_lengthController.text.replaceAll(',', '.'));
    final tileWidth = double.tryParse(_widthController.text.replaceAll(',', '.'));
    final pieces = int.tryParse(_piecesController.text);
    final waste = double.tryParse(_wasteController.text.replaceAll(',', '.'));

    if (area == null ||
        tileLength == null ||
        tileWidth == null ||
        pieces == null ||
        waste == null) {
      setState(() => _result = null);
      return;
    }

    final calc = TileCalculator();
    final result = calc.calculate(
      inputs: {
        'area': area,
        'tileLengthCm': tileLength,
        'tileWidthCm': tileWidth,
        'piecesPerBox': pieces,
        'wastePercent': waste,
      },
      unitPrice: _selectedProduct?.priceSell.toDouble(),
    );

    setState(() => _result = result);
  }

  Future<void> _showProductSearchDialog() async {
    final termController = TextEditingController();
    List<db.Product> searchResults = [];

    await showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            Future<void> doSearch() async {
              final term = termController.text.trim();
              final database = sl<db.AppDatabase>();
              final query = database.select(database.products)
                ..where((p) => p.shopId.equals(widget.session.shop.id) & p.isArchived.equals(false));

              if (term.isNotEmpty) {
                query.where((p) =>
                    p.name.lower().like('%${term.toLowerCase()}%') |
                    p.sku.lower().like('%${term.toLowerCase()}%'));
              }

              final list = await (query..limit(15)).get();
              setDialogState(() {
                searchResults = list;
              });
            }

            return AlertDialog(
              title: const Text('Rechercher un produit'),
              content: SizedBox(
                width: double.maxFinite,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: termController,
                      decoration: const InputDecoration(
                        labelText: 'Nom ou code barre',
                        suffixIcon: Icon(Icons.search),
                      ),
                      onChanged: (_) => doSearch(),
                    ),
                    const SizedBox(height: 12),
                    Expanded(
                      child: searchResults.isEmpty
                          ? const Center(
                              child: Text(
                                'Aucun produit trouvé',
                                style: TextStyle(color: AppColors.onSurfaceMuted),
                              ),
                            )
                          : ListView.builder(
                              itemCount: searchResults.length,
                              itemBuilder: (context, index) {
                                final prod = searchResults[index];
                                return ListTile(
                                  title: Text(prod.name),
                                  subtitle: Text(
                                    (prod.sku != null && prod.sku!.isNotEmpty)
                                        ? prod.sku!
                                        : 'Pas de SKU',
                                  ),
                                  trailing: Text(formatFcfa(prod.priceSell)),
                                  onTap: () {
                                    Navigator.of(context).pop(prod);
                                  },
                                );
                              },
                            ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    ).then((prod) {
      if (prod is db.Product) {
        setState(() {
          _selectedProduct = prod;
        });

        // Auto-fill configuration if metadata exists for this product
        final configs = context.read<CalculatorsBloc>().state.configs;
        final matching = configs.where((c) => c.productId == prod.id).toList();

        if (matching.isNotEmpty) {
          final meta = matching.first.metadata;
          _lengthController.text = '${meta['tileLengthCm'] ?? '60'}';
          _widthController.text = '${meta['tileWidthCm'] ?? '60'}';
          _piecesController.text = '${meta['piecesPerBox'] ?? '1'}';
          _wasteController.text = '${meta['wastePercent'] ?? '10'}';
        }

        _calculate();
      }
    });
  }

  void _injectToSale() {
    if (_selectedProduct == null || _result == null) return;

    final intent = CalculationIntent(
      productId: _selectedProduct!.id,
      productName: _selectedProduct!.name,
      quantity: _result!.recommendedQuantity,
      unitPrice: _selectedProduct!.priceSell.toDouble(),
    );

    Navigator.of(context).pop(intent);
  }

  Future<void> _exportPdf() async {
    if (_result == null) return;

    final exporter = CalculatorPdfExporter();
    await exporter.sharePdf(
      shopName: widget.session.shop.name,
      calculatorLabel: 'Carrelage',
      inputs: {
        'area': double.parse(_areaController.text),
        'tileLengthCm': double.parse(_lengthController.text),
        'tileWidthCm': double.parse(_widthController.text),
        'piecesPerBox': int.parse(_piecesController.text),
        'wastePercent': double.parse(_wasteController.text),
      },
      metrics: _result!.metrics.map((m) => {
        'label': m.label,
        'value': m.value,
        'unit': m.unit,
      }).toList(),
      estimatedPrice: _result!.estimatedPrice,
      productName: _selectedProduct?.name,
    );
  }

  Future<void> _showSaveHistoryDialog() async {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Enregistrer l\'estimation'),
          content: TextField(
            controller: _labelController,
            decoration: const InputDecoration(
              labelText: 'Libellé (ex: Salon de M. KOFFI)',
              hintText: 'Laisser vide pour libellé par défaut',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Annuler'),
            ),
            TextButton(
              onPressed: () {
                _saveHistory();
                Navigator.of(context).pop();
              },
              child: const Text('Enregistrer'),
            ),
          ],
        );
      },
    );
  }

  void _saveHistory() {
    if (_result == null) return;

    final entry = CalculatorHistoryEntry(
      id: 0,
      shopId: widget.session.shop.id,
      calculatorType: 'tile',
      input: {
        'area': double.parse(_areaController.text),
        'tileLengthCm': double.parse(_lengthController.text),
        'tileWidthCm': double.parse(_widthController.text),
        'piecesPerBox': int.parse(_piecesController.text),
        'wastePercent': double.parse(_wasteController.text),
      },
      result: {
        'estimatedPrice': _result!.estimatedPrice,
        'recommendedQuantity': _result!.recommendedQuantity,
        'metrics': _result!.metrics.map((m) => {
          'label': m.label,
          'value': m.value,
          'unit': m.unit,
        }).toList(),
      },
      isFavorite: false,
      label: _labelController.text.trim().isNotEmpty
          ? _labelController.text.trim()
          : null,
      createdAt: 0,
      createdBy: widget.session.user.id,
    );

    context.read<CalculatorsBloc>().add(LogCalculationRequested(entry: entry));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Estimation enregistrée avec succès.')),
    );
  }
}
