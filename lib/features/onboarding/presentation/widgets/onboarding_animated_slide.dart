import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../app/theme/app_tokens.dart';
import '../../../../shared/components/feature_ui.dart';
import '../../data/onboarding_slides.dart';

/// Slide animée avec halo, carte hero et puces de fonctionnalités.
class OnboardingAnimatedSlide extends StatefulWidget {
  const OnboardingAnimatedSlide({
    super.key,
    required this.slide,
    required this.isActive,
  });

  final OnboardingSlideData slide;
  final bool isActive;

  @override
  State<OnboardingAnimatedSlide> createState() =>
      _OnboardingAnimatedSlideState();
}

class _OnboardingAnimatedSlideState extends State<OnboardingAnimatedSlide>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _fade;
  late final Animation<Offset> _slideUp;
  late final Animation<double> _iconScale;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _fade = CurvedAnimation(parent: _controller, curve: Curves.easeOut);
    _slideUp = Tween<Offset>(
      begin: const Offset(0, 0.12),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));
    _iconScale = Tween<double>(begin: 0.7, end: 1).animate(
      CurvedAnimation(parent: _controller, curve: Curves.elasticOut),
    );
    if (widget.isActive) _controller.forward();
  }

  @override
  void didUpdateWidget(OnboardingAnimatedSlide oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isActive && !oldWidget.isActive) {
      _controller.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final slide = widget.slide;
    final theme = Theme.of(context);
    final gradient = slide.gradientColors ??
        [slide.accentColor, slide.accentColor.withValues(alpha: 0.7)];

    return FadeTransition(
      opacity: _fade,
      child: SlideTransition(
        position: _slideUp,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
                    ScaleTransition(
                scale: _iconScale,
                child: FeatureIllustrationIcon(
                  icon: slide.icon,
                  color: slide.accentColor == Colors.white
                      ? gradient.first
                      : slide.accentColor,
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(AppSpacing.lg),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surface.withValues(alpha: 0.92),
                  borderRadius: BorderRadius.circular(AppRadius.xl),
                  border: Border.all(
                    color: gradient.first.withValues(alpha: 0.15),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: gradient.first.withValues(alpha: 0.08),
                      blurRadius: 24,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    Text(
                      slide.title.toUpperCase(),
                      style: theme.textTheme.labelLarge?.copyWith(
                        color: gradient.first,
                        letterSpacing: 1.2,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      slide.headline,
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                        height: 1.15,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      slide.description,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        height: 1.5,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: AppSpacing.md),
                    Wrap(
                      alignment: WrapAlignment.center,
                      spacing: AppSpacing.sm,
                      runSpacing: AppSpacing.sm,
                      children: slide.highlights
                          .map(
                            (h) => Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: AppSpacing.md,
                                vertical: AppSpacing.xs + 2,
                              ),
                              decoration: BoxDecoration(
                                color: gradient.first.withValues(alpha: 0.1),
                                borderRadius:
                                    BorderRadius.circular(AppRadius.pill),
                                border: Border.all(
                                  color:
                                      gradient.first.withValues(alpha: 0.2),
                                ),
                              ),
                              child: Text(
                                h,
                                style: theme.textTheme.labelMedium?.copyWith(
                                  color: gradient.first,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          )
                          .toList(),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Cercles décoratifs animés en arrière-plan.
class OnboardingBackgroundOrbs extends StatefulWidget {
  const OnboardingBackgroundOrbs({super.key, required this.pageIndex});

  final int pageIndex;

  @override
  State<OnboardingBackgroundOrbs> createState() =>
      _OnboardingBackgroundOrbsState();
}

class _OnboardingBackgroundOrbsState extends State<OnboardingBackgroundOrbs>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 8),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final phase = widget.pageIndex * 0.4;

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final t = _controller.value;
        return Stack(
          children: [
            Positioned(
              top: 40 + math.sin(t * math.pi * 2 + phase) * 20,
              right: -30,
              child: _Orb(
                size: 140,
                color: scheme.primary.withValues(alpha: 0.08),
              ),
            ),
            Positioned(
              bottom: 120 + math.cos(t * math.pi * 2 + phase) * 24,
              left: -40,
              child: _Orb(
                size: 180,
                color: scheme.secondary.withValues(alpha: 0.1),
              ),
            ),
            Positioned(
              top: 200,
              left: 60 + math.sin(t * math.pi * 2) * 16,
              child: _Orb(
                size: 60,
                color: scheme.primary.withValues(alpha: 0.06),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _Orb extends StatelessWidget {
  const _Orb({required this.size, required this.color});

  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(shape: BoxShape.circle, color: color),
    );
  }
}
