import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../core/storage/onboarding_storage.dart';
import '../../features/auth/presentation/bloc/auth_bloc.dart';
import '../../features/onboarding/presentation/pages/onboarding_page.dart';
import '../../features/onboarding/presentation/pages/splash_page.dart';
import '../di/injection_container.dart';
import 'auth_gate.dart';

/// Orchestre le démarrage : splash → onboarding (1ère fois) → authentification.
class AppBootstrapPage extends StatefulWidget {
  const AppBootstrapPage({super.key});

  @override
  State<AppBootstrapPage> createState() => _AppBootstrapPageState();
}

class _AppBootstrapPageState extends State<AppBootstrapPage> {
  /// Flash de marque minimal — n'ajoute du délai que si l'auth est déjà prête.
  static const _maxBrandingSplash = Duration(milliseconds: 400);

  /// Plafond de sécurité pour ne pas rester bloqué sur le splash vert.
  static const _maxAuthWait = Duration(seconds: 8);

  bool _splashFinished = false;
  bool _onboardingCompleted = true;
  bool _showOnboarding = false;

  Timer? _authCapTimer;
  StreamSubscription<AuthState>? _authSubscription;
  Timer? _brandingTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _runBootstrap());
  }

  @override
  void dispose() {
    _authCapTimer?.cancel();
    _authSubscription?.cancel();
    _brandingTimer?.cancel();
    super.dispose();
  }

  Future<void> _runBootstrap() async {
    final authBloc = context.read<AuthBloc>();
    final onboardingStorage = sl<OnboardingStorage>();
    final brandingStarted = DateTime.now();

    final results = await Future.wait([
      onboardingStorage.isCompleted(),
      _waitForAuthReadyWithCap(authBloc, _maxAuthWait),
    ]);
    final onboardingDone = results[0] as bool;

    final brandingElapsed = DateTime.now().difference(brandingStarted);
    final brandingRemaining = _maxBrandingSplash - brandingElapsed;
    if (brandingRemaining > Duration.zero) {
      await _delay(brandingRemaining);
    }

    if (!mounted) return;

    final authState = authBloc.state;
    final shouldShowOnboarding =
        !onboardingDone && authState is AuthNeedsSetup;

    setState(() {
      _onboardingCompleted = onboardingDone;
      _showOnboarding = shouldShowOnboarding;
      _splashFinished = true;
    });
  }

  Future<void> _delay(Duration duration) {
    final completer = Completer<void>();
    _brandingTimer?.cancel();
    _brandingTimer = Timer(duration, () {
      if (!completer.isCompleted) completer.complete();
    });
    return completer.future;
  }

  Future<void> _waitForAuthReadyWithCap(
    AuthBloc authBloc,
    Duration cap,
  ) async {
    if (authBloc.state is! AuthInitial && authBloc.state is! AuthLoading) {
      return;
    }

    final completer = Completer<void>();

    void finish() {
      if (completer.isCompleted) return;
      _authCapTimer?.cancel();
      _authSubscription?.cancel();
      completer.complete();
    }

    _authCapTimer = Timer(cap, finish);
    _authSubscription = authBloc.stream.listen((state) {
      if (state is! AuthInitial && state is! AuthLoading) {
        finish();
      }
    });

    if (authBloc.state is! AuthInitial && authBloc.state is! AuthLoading) {
      finish();
    }

    await completer.future;
  }

  Future<void> _completeOnboarding() async {
    await sl<OnboardingStorage>().markCompleted();
    if (!mounted) return;
    setState(() {
      _onboardingCompleted = true;
      _showOnboarding = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!_splashFinished) {
      return const SplashPage();
    }

    if (_showOnboarding && !_onboardingCompleted) {
      return OnboardingPage(onComplete: _completeOnboarding);
    }

    return const AuthGate();
  }
}
