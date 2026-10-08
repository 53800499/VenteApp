import 'package:flutter/material.dart';

import '../../../../app/theme/app_tokens.dart';
import '../../../../core/responsive/responsive_builder.dart';
import '../../../../shared/components/ui_primitives.dart';
import '../../data/onboarding_slides.dart';
import '../widgets/onboarding_animated_slide.dart';
import '../widgets/onboarding_desktop_view.dart';

/// Présentation immersive des modules ARIKE (première installation).
class OnboardingPage extends StatefulWidget {
  const OnboardingPage({
    super.key,
    required this.onComplete,
  });

  final VoidCallback onComplete;

  @override
  State<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends State<OnboardingPage> {
  final _pageController = PageController();
  int _currentPage = 0;

  bool get _isLastPage => _currentPage == onboardingSlides.length - 1;

  void _next() {
    if (_isLastPage) {
      widget.onComplete();
      return;
    }
    _pageController.nextPage(
      duration: const Duration(milliseconds: 450),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // Mode Grand Écran / Windows Desktop : Vue studio 2 colonnes ultra-moderne
        if (constraints.maxWidth >= 850) {
          return OnboardingDesktopView(
            onComplete: widget.onComplete,
            slides: onboardingSlides,
          );
        }

        // Mode Mobile / Écran compact : Présentation tactile fluide
        return _buildMobileView(context);
      },
    );
  }

  Widget _buildMobileView(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final slide = onboardingSlides[_currentPage];
    final accent = slide.gradientColors?.first ?? scheme.primary;

    return GradientBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: Stack(
          children: [
            OnboardingBackgroundOrbs(pageIndex: _currentPage),
            SafeArea(
              child: ResponsivePage(
                child: Column(
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: accent.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(AppRadius.pill),
                            border: Border.all(
                              color: accent.withValues(alpha: 0.3),
                            ),
                          ),
                          child: Text(
                            '${_currentPage + 1} / ${onboardingSlides.length}',
                            style: Theme.of(context).textTheme.labelMedium?.copyWith(
                                  color: accent,
                                  fontWeight: FontWeight.w800,
                                ),
                          ),
                        ),
                        const Spacer(),
                        TextButton.icon(
                          onPressed: widget.onComplete,
                          icon: const Icon(Icons.skip_next_rounded, size: 16),
                          label: const Text('Passer'),
                        ),
                      ],
                    ),
                    Expanded(
                      child: PageView.builder(
                        controller: _pageController,
                        itemCount: onboardingSlides.length,
                        onPageChanged: (index) =>
                            setState(() => _currentPage = index),
                        itemBuilder: (context, index) {
                          return OnboardingAnimatedSlide(
                            slide: onboardingSlides[index],
                            isActive: index == _currentPage,
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(onboardingSlides.length, (index) {
                        final active = index == _currentPage;
                        return AnimatedContainer(
                          duration: const Duration(milliseconds: 300),
                          curve: Curves.easeOut,
                          margin: const EdgeInsets.symmetric(horizontal: 3),
                          width: active ? 28 : 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: active
                                ? accent
                                : accent.withValues(alpha: 0.25),
                            borderRadius: BorderRadius.circular(4),
                          ),
                        );
                      }),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: _next,
                        style: FilledButton.styleFrom(
                          backgroundColor: accent,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(AppRadius.md),
                          ),
                        ),
                        child: Text(
                          _isLastPage ? 'Commencer maintenant' : 'Découvrir la suite',
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                      ),
                    ),
                    if (_isLastPage) ...[
                      const SizedBox(height: AppSpacing.sm),
                      Text(
                        'Retrouvez l\'aide détaillée dans Plus → Aide & guides',
                        style: Theme.of(context).textTheme.bodySmall,
                        textAlign: TextAlign.center,
                      ),
                    ],
                    const SizedBox(height: AppSpacing.sm),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
