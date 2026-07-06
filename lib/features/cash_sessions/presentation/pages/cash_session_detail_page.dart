import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../app/di/injection_container.dart';
import '../../../../app/theme/app_tokens.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../auth/domain/entities/auth_entities.dart';
import '../../domain/entities/cash_session_entities.dart';
import '../../domain/usecases/cash_session_usecases.dart';
import '../services/cash_session_pdf_exporter.dart';

class CashSessionDetailPage extends StatefulWidget {
  const CashSessionDetailPage({
    super.key,
    required this.session,
    required this.sessionId,
  });

  final AuthSession session;
  final int sessionId;

  @override
  State<CashSessionDetailPage> createState() => _CashSessionDetailPageState();
}

class _CashSessionDetailPageState extends State<CashSessionDetailPage> {
  CashSession? _session;
  List<CashMovement> _movements = const [];
  String? _error;
  bool _loading = true;
  bool _exporting = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    ensureCashSessionDependencies();
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final session = await sl<GetCashSession>()(
        session: widget.session,
        sessionId: widget.sessionId,
      );
      final movements = await sl<ListCashMovements>()(
        session: widget.session,
        sessionId: widget.sessionId,
      );
      if (!mounted) return;
      setState(() {
        _session = session;
        _movements = movements;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Future<void> _exportPdf() async {
    final session = _session;
    if (session == null || _exporting) return;
    setState(() => _exporting = true);
    try {
      await sl<CashSessionPdfExporter>().sharePdf(
        shopName: widget.session.shop.name,
        session: session,
        movements: _movements,
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Export impossible : $e')),
      );
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Rapport de clôture'),
        actions: [
          if (_session != null && !_loading)
            IconButton(
              icon: _exporting
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.picture_as_pdf_outlined),
              tooltip: 'Exporter PDF',
              onPressed: _exporting ? null : _exportPdf,
            ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text(_error!))
              : _buildBody(context, _session!),
    );
  }

  Widget _buildBody(BuildContext context, CashSession s) {
    final dateFmt = DateFormat('dd/MM/yyyy HH:mm');
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.md),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Session du ${dateFmt.format(DateTime.fromMillisecondsSinceEpoch(s.openedAt))}',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                Text('Ouverte par ${s.openedByName}'),
                if (s.closedByName != null && s.closedAt != null)
                  Text(
                    'Clôturée par ${s.closedByName} le '
                    '${dateFmt.format(DateTime.fromMillisecondsSinceEpoch(s.closedAt!))}',
                  ),
                const Divider(),
                _row('Fond initial espèces', s.openingCash),
                _row('Fond initial MoMo', s.openingMomo),
                _row('Ventes espèces', s.salesCash),
                _row('Ventes MoMo', s.salesMomo),
                _row('Dépenses espèces', s.expensesCash),
                _row('Dépenses MoMo', s.expensesMomo),
                _row('Entrées espèces', s.depositsCash),
                _row('Entrées MoMo', s.depositsMomo),
                _row('Retraits espèces', s.withdrawalsCash),
                _row('Retraits MoMo', s.withdrawalsMomo),
                _row('Nombre de ventes', s.saleCount, money: false),
                const Divider(),
                _row('Attendu espèces', s.expectedCash ?? 0, bold: true),
                _row('Attendu MoMo', s.expectedMomo ?? 0, bold: true),
                _row('Compté espèces', s.countedCash ?? 0, bold: true),
                _row('Compté MoMo', s.countedMomo ?? 0, bold: true),
                _row(
                  'Écart espèces',
                  s.differenceCash ?? 0,
                  bold: true,
                  highlight: true,
                ),
                _row(
                  'Écart MoMo',
                  s.differenceMomo ?? 0,
                  bold: true,
                  highlight: true,
                ),
                if (s.closingNote?.isNotEmpty == true) ...[
                  const SizedBox(height: AppSpacing.sm),
                  Text('Note : ${s.closingNote}'),
                ],
              ],
            ),
          ),
        ),
        if (_movements.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.md),
          Text(
            'Mouvements manuels',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          ..._movements.map(
            (m) => ListTile(
              title: Text('${m.movementType.label} · ${m.registerType.label}'),
              subtitle: Text(m.note ?? m.createdByName),
              trailing: Text(formatFcfa(m.amount)),
            ),
          ),
        ],
      ],
    );
  }

  Widget _row(
    String label,
    int value, {
    bool money = true,
    bool bold = false,
    bool highlight = false,
  }) {
    final text = money ? formatFcfa(value) : '$value';
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Expanded(child: Text(label)),
          Text(
            text,
            style: TextStyle(
              fontWeight: bold ? FontWeight.bold : null,
              color: highlight
                  ? (value == 0
                      ? Colors.green
                      : value > 0
                          ? Colors.blue
                          : Colors.red)
                  : null,
            ),
          ),
        ],
      ),
    );
  }
}
