import 'package:flutter/material.dart';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../core/auth/app_lock_controller.dart';
import '../core/auth/cloud_session_coordinator.dart';
import '../core/network/api_client.dart';
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
  final _navigatorKey = GlobalKey<NavigatorState>();



  @override

  void initState() {

    super.initState();

    WidgetsBinding.instance.addObserver(this);

    _authBloc = sl<AuthBloc>();

    final sessionPolicy = sl<OnlineSessionPolicy>();
    final cloudCoordinator = sl<CloudSessionCoordinator>();
    final apiClient = sl<ApiClient>();

    cloudCoordinator.bind(
      navigatorKey: _navigatorKey,
      onReconnectRequested: () {
        _authBloc.add(const AuthCloudReconnectRequested());
      },
    );

    sessionPolicy.onCloudSessionExpired = () {
      cloudCoordinator.handleInvalidRefreshToken();
    };

    apiClient.onRefreshTokenInvalid = () {
      return cloudCoordinator.handleInvalidRefreshToken();
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

    if (state == AppLifecycleState.paused) {
      sl<AppLockController>().markBackgrounded();
      return;
    }

    if (state == AppLifecycleState.resumed) {
      final lock = sl<AppLockController>();
      if (lock.isLockSuppressed) return;

      final authState = _authBloc.state;
      if (authState is AuthAuthenticated) {
        final autoLockMinutes = authState.session.autoLockMinutes;
        if (lock.requiresPinOnResume(autoLockMinutes)) {
          _authBloc.add(const AuthAppLockedRequested());
        }
      }
    }

  }



  @override

  Widget build(BuildContext context) {

    return BlocProvider.value(

      value: _authBloc,

      child: MaterialApp(

        navigatorKey: _navigatorKey,

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
