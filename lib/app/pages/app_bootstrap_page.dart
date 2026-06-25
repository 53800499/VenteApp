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
  static const _minSplashDuration = Duration(milliseconds: 1800);

  bool _splashFinished = false;
  bool _onboardingCompleted = true;
  bool _showOnboarding = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _runBootstrap());
  }

  Future<void> _runBootstrap() async {
    final authBloc = context.read<AuthBloc>();
    final onboardingStorage = sl<OnboardingStorage>();

    final onboardingDone = await Future.wait([
      Future.delayed(_minSplashDuration),
      onboardingStorage.isCompleted(),
      _waitForAuthReady(authBloc),
    ]).then((results) => results[1] as bool);

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

  Future<void> _waitForAuthReady(AuthBloc authBloc) async {
    if (authBloc.state is! AuthInitial && authBloc.state is! AuthLoading) {
      return;
    }
    await authBloc.stream.firstWhere(
      (state) => state is! AuthInitial && state is! AuthLoading,
    );
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
