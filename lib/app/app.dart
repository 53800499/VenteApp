import 'package:flutter/material.dart';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../core/network/online_session_policy.dart';
import 'pages/app_bootstrap_page.dart';
import 'router/app_router.dart';
import 'theme/app_theme.dart';
import '../features/auth/presentation/bloc/auth_bloc.dart';
import 'di/injection_container.dart';


class VenteApp extends StatefulWidget {

  const VenteApp({super.key});



  @override

  State<VenteApp> createState() => _VenteAppState();

}



class _VenteAppState extends State<VenteApp> with WidgetsBindingObserver {

  late final AuthBloc _authBloc;



  @override

  void initState() {

    super.initState();

    WidgetsBinding.instance.addObserver(this);

    _authBloc = sl<AuthBloc>();
    final sessionPolicy = sl<OnlineSessionPolicy>();
    sessionPolicy.onSessionInvalidated = () {
      sessionPolicy.reset();
      // Verrouillage PIN — pas de déconnexion complète (offline-first).
      _authBloc.add(const AuthAppLockedRequested());
    };
    _authBloc.add(const AuthBootstrapRequested());

  }



  @override

  void dispose() {

    WidgetsBinding.instance.removeObserver(this);

    _authBloc.close();

    super.dispose();

  }



  @override

  void didChangeAppLifecycleState(AppLifecycleState state) {

    // Verrouiller uniquement quand l'app passe en arrière-plan (pas sur
    // `inactive`, déclenché par les dialogues système / barre de statut).
    if (state == AppLifecycleState.paused) {
      final authState = _authBloc.state;
      if (authState is AuthAuthenticated) {
        _authBloc.add(const AuthAppLockedRequested());
      }
    }

  }



  @override

  Widget build(BuildContext context) {

    return BlocProvider.value(

      value: _authBloc,

      child: MaterialApp(

        title: 'VenteApp Bénin',

        debugShowCheckedModeBanner: false,

        theme: AppTheme.light,

        home: const AppBootstrapPage(),

        routes: AppRouter.routes(),

        onGenerateRoute: AppRouter.onGenerateRoute,

      ),

    );

  }

}

