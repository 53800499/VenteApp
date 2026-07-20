import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'bloc/fx_exchange_bloc.dart';

/// Ouvre un sous-écran FX en conservant le [FxExchangeBloc] parent.
void openFxSubPage(BuildContext context, Widget page) {
  final bloc = context.read<FxExchangeBloc>();
  Navigator.of(context).push(
    MaterialPageRoute(
      builder: (_) => BlocProvider.value(
        value: bloc,
        child: page,
      ),
    ),
  );
}
