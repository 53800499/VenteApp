import 'package:flutter/material.dart';

import '../../../../app/theme/app_tokens.dart';
import '../../../../core/responsive/responsive_builder.dart';
import '../../../../shared/components/ui_primitives.dart';
import '../../data/onboarding_slides.dart';
import '../widgets/onboarding_animated_slide.dart';

/// Présentation immersive des modules VenteApp (première installation).
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
                        Text(
                          '${_currentPage + 1}/${onboardingSlides.length}',
                          style: Theme.of(context).textTheme.labelLarge?.copyWith(
                                color: accent,
                                fontWeight: FontWeight.w700,
                              ),
                        ),
                        const Spacer(),
                        TextButton(
                          onPressed: widget.onComplete,
                          child: const Text('Passer'),
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
                        ),
                        child: Text(
                          _isLastPage ? 'Commencer' : 'Découvrir la suite',
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
