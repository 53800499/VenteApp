import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../app/theme/app_tokens.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../bloc/fx_exchange_bloc.dart';

class FxCloseSessionPage extends StatefulWidget {
  const FxCloseSessionPage({super.key});

  @override
  State<FxCloseSessionPage> createState() => _FxCloseSessionPageState();
}

class _FxCloseSessionPageState extends State<FxCloseSessionPage> {
  final _noteCtrl = TextEditingController();
  Map<String, TextEditingController> _controllers = {};
  bool _controllersReady = false;

  void _initControllers(FxExchangeState state) {
    if (_controllersReady) return;
    _controllers = {
      for (final entry in state.liveBalances.entries)
        entry.key: TextEditingController(text: entry.value.toString()),
    };
    _controllersReady = true;
  }

  @override
  void dispose() {
    _noteCtrl.dispose();
    for (final c in _controllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bloc = context.watch<FxExchangeBloc>();
    final state = bloc.state;
    final session = state.openSession;
    if (session == null) {
      return const Scaffold(
        body: Center(child: Text('Aucune session ouverte.')),
      );
    }

    if (session.isPendingClose) {
      return Scaffold(
        appBar: AppBar(title: const Text('Validation clôture FX')),
        body: const Center(
          child: Padding(
            padding: EdgeInsets.all(AppSpacing.lg),
            child: Text(
              'Le comptage est déjà soumis. Validez ou reprenez depuis l’écran principal.',
              textAlign: TextAlign.center,
            ),
          ),
        ),
      );
    }

    _initControllers(state);

    return Scaffold(
      appBar: AppBar(title: const Text('Comptage session FX')),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.md),
        children: [
          const Text(
            'Étape 1/2 — Comptez chaque caisse et saisissez le montant physique. '
            'La session passera en attente de validation (plus d’opérations).',
          ),
          const SizedBox(height: AppSpacing.md),
          ...state.liveBalances.entries.map((entry) {
            final expected = entry.value;
            return Card(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.sm),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      entry.key,
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                    Text(
                      'Attendu : ${formatAmount(expected, entry.key)}',
                    ),
                    TextField(
                      controller: _controllers[entry.key],
                      keyboardType: TextInputType.number,
                      decoration:
                          const InputDecoration(labelText: 'Montant compté'),
                    ),
                  ],
                ),
              ),
            );
          }),
          TextField(
            controller: _noteCtrl,
            decoration: const InputDecoration(labelText: 'Note de clôture'),
          ),
          const SizedBox(height: AppSpacing.lg),
          FilledButton(
            onPressed: state.isSubmitting
                ? null
                : () {
                    final counted = <String, int>{};
                    for (final entry in _controllers.entries) {
                      counted[entry.key] =
                          int.tryParse(entry.value.text.replaceAll(' ', '')) ??
                              0;
                    }
                    bloc.add(
                      FxCloseSessionRequested(
                        countedBalances: counted,
                        closingNote: _noteCtrl.text.trim().isEmpty
                            ? null
                            : _noteCtrl.text.trim(),
                      ),
                    );
                    Navigator.pop(context);
                  },
            child: const Text('Soumettre le comptage'),
          ),
        ],
      ),
    );
  }
}
