import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Fournit un [BlocBase] créé une seule fois (survit aux rebuilds du parent).
class PersistentBlocProvider<T extends BlocBase<Object?>>
    extends StatefulWidget {
  const PersistentBlocProvider({
    super.key,
    required this.create,
    required this.child,
  });

  final T Function() create;
  final Widget child;

  @override
  State<PersistentBlocProvider<T>> createState() =>
      _PersistentBlocProviderState<T>();
}

class _PersistentBlocProviderState<T extends BlocBase<Object?>>
    extends State<PersistentBlocProvider<T>> {
  late final T _bloc;

  @override
  void initState() {
    super.initState();
    _bloc = widget.create();
  }

  @override
  void dispose() {
    _bloc.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider<T>.value(value: _bloc, child: widget.child);
  }
}
