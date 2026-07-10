import 'package:flutter/material.dart';

import 'package:flutter_bloc/flutter_bloc.dart';

import 'dart:async';

import '../core/auth/app_lock_controller.dart';
import '../core/auth/cloud_session_coordinator.dart';
import '../core/auth/cloud_session_controller.dart';
import '../core/auth/cloud_session_repair_service.dart';
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

  late final AppSessionBloc _authBloc;
  late final CloudSessionController _cloudSession;
  StreamSubscription<AuthState>? _authSub;
  final _navigatorKey = GlobalKey<NavigatorState>();



  @override

  void initState() {

    super.initState();

    WidgetsBinding.instance.addObserver(this);

    _authBloc = sl<AppSessionBloc>();

    _cloudSession = sl<CloudSessionController>()..start();
    _authSub = _authBloc.stream.listen((state) {
      if (state is AuthAuthenticated) {
        unawaited(_cloudSession.refresh());
      }
    });

    final sessionPolicy = sl<OnlineSessionPolicy>();
    final cloudCoordinator = sl<CloudSessionCoordinator>();
    final cloudRepair = sl<CloudSessionRepairService>();
    final apiClient = sl<ApiClient>();

    cloudCoordinator.bind(
      navigatorKey: _navigatorKey,
      onReconnectRequested: () {
        _authBloc.add(const AuthCloudReconnectRequested());
      },
    );

    sessionPolicy.onCloudSessionExpired = () {
      cloudCoordinator.handleInvalidRefreshToken(
        offerWhatsAppReconnect: true,
      );
    };

    apiClient.onRefreshTokenInvalid = () async {
      final outcome = await cloudRepair.onRefreshTokenRejected();
      if (outcome == CloudRepairOutcome.alreadyValid ||
          outcome == CloudRepairOutcome.refreshed ||
          outcome == CloudRepairOutcome.pinLogin) {
        cloudCoordinator.markCloudSessionValid();
        cloudRepair.clearAwaitingState();
      } else if (outcome == CloudRepairOutcome.failed) {
        await cloudCoordinator.handleInvalidRefreshToken(
          offerWhatsAppReconnect: true,
          skipGrace: true,
        );
      }
    };

    apiClient.onRefreshTokenRestored = () async {
      cloudCoordinator.markCloudSessionValid();
      cloudRepair.clearAwaitingState();
      unawaited(_cloudSession.refresh());
    };

    _authBloc.add(const AuthBootstrapRequested());

    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(initDeferredServices());
    });

  }



  @override

  void dispose() {

    WidgetsBinding.instance.removeObserver(this);

    _authSub?.cancel();

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
      unawaited(_cloudSession.refresh());
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
