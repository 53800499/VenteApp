import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../shared/components/ui_primitives.dart';

/// Écran de démarrage animé affiché au lancement.
class SplashPage extends StatefulWidget {
  const SplashPage({super.key});

  @override
  State<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends State<SplashPage>
    with TickerProviderStateMixin {
  late final AnimationController _entranceController;
  late final AnimationController _ambientController;
  late final Animation<double> _fade;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _entranceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    );
    _ambientController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat(reverse: true);
    _fade = CurvedAnimation(
      parent: _entranceController,
      curve: Curves.easeOut,
    );
    _scale = Tween<double>(begin: 0.75, end: 1).animate(
      CurvedAnimation(parent: _entranceController, curve: Curves.easeOutBack),
    );
    _entranceController.forward();
  }

  @override
  void dispose() {
    _entranceController.dispose();
    _ambientController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              AppColors.heroGradientStart,
              AppColors.heroGradientEnd,
              Color(0xFF0A3D2E),
            ],
          ),
        ),
        child: Stack(
          children: [
            ...List.generate(3, (i) {
              return AnimatedBuilder(
                animation: _ambientController,
                builder: (context, child) {
                  final offset = _ambientController.value * 30;
                  return Positioned(
                    top: 80.0 + i * 120 + math.sin(offset + i) * 12,
                    left: i.isEven ? -20.0 + offset : null,
                    right: i.isOdd ? -20.0 - offset : null,
                    child: Container(
                      width: 100 + i * 40,
                      height: 100 + i * 40,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white.withValues(alpha: 0.04 + i * 0.02),
                      ),
                    ),
                  );
                },
              );
            }),
            SafeArea(
              child: FadeTransition(
                opacity: _fade,
                child: Center(
                  child: ScaleTransition(
                    scale: _scale,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const AppLogo.onDark(size: 108),
                        const SizedBox(height: 28),
                        Text(
                          'VenteApp',
                          style:
                              Theme.of(context).textTheme.headlineMedium?.copyWith(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: 1,
                                  ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Gestion commerciale pour le Bénin',
                          style:
                              Theme.of(context).textTheme.bodyMedium?.copyWith(
                                    color: Colors.white.withValues(alpha: 0.88),
                                  ),
                        ),
                        const SizedBox(height: 48),
                        SizedBox(
                          width: 32,
                          height: 32,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            color: Colors.white.withValues(alpha: 0.95),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
