import 'package:flutter/material.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../core/responsive/responsive_builder.dart';
import '../../../../shared/components/ui_primitives.dart';

class OnboardingSlide {
  const OnboardingSlide({
    required this.icon,
    required this.title,
    required this.description,
    this.iconColor,
  });

  final IconData icon;
  final String title;
  final String description;
  final Color? iconColor;
}

const _slides = [
  OnboardingSlide(
    icon: Icons.waving_hand_rounded,
    title: 'Bienvenue sur VenteApp',
    description:
        'Votre assistant de gestion commerciale, conçu pour les boutiques au Bénin.',
    iconColor: AppColors.secondary,
  ),
  OnboardingSlide(
    icon: Icons.point_of_sale_rounded,
    title: 'Ventes & inventaire',
    description:
        'Enregistrez vos ventes, suivez votre stock et consultez vos indicateurs en un coup d\'œil.',
  ),
  OnboardingSlide(
    icon: Icons.cloud_off_rounded,
    title: 'Travaillez hors ligne',
    description:
        'Continuez à vendre sans internet. Vos données se synchronisent dès que la connexion revient.',
  ),
  OnboardingSlide(
    icon: Icons.lock_rounded,
    title: 'Sécurisé & simple',
    description:
        'Connectez-vous avec votre code PIN. Le patron peut gérer plusieurs boutiques.',
  ),
];

/// Présentation informative affichée une seule fois avant l'installation.
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

  bool get _isLastPage => _currentPage == _slides.length - 1;

  void _next() {
    if (_isLastPage) {
      widget.onComplete();
      return;
    }
    _pageController.nextPage(
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeInOut,
    );
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GradientBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: SafeArea(
          child: ResponsivePage(
            child: Column(
              children: [
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: widget.onComplete,
                    child: const Text('Passer'),
                  ),
                ),
                Expanded(
                  child: PageView.builder(
                    controller: _pageController,
                    itemCount: _slides.length,
                    onPageChanged: (index) => setState(() => _currentPage = index),
                    itemBuilder: (context, index) {
                      final slide = _slides[index];
                      return _OnboardingSlideView(slide: slide);
                    },
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(_slides.length, (index) {
                    final active = index == _currentPage;
                    return AnimatedContainer(
                      duration: const Duration(milliseconds: 250),
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      width: active ? 24 : 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: active
                            ? Theme.of(context).colorScheme.primary
                            : Theme.of(context)
                                .colorScheme
                                .primary
                                .withValues(alpha: 0.25),
                        borderRadius: BorderRadius.circular(4),
                      ),
                    );
                  }),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: _next,
                    child: Text(_isLastPage ? 'Continuer' : 'Suivant'),
                  ),
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _OnboardingSlideView extends StatelessWidget {
  const _OnboardingSlideView({required this.slide});

  final OnboardingSlide slide;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        PageHeader(
          icon: slide.icon,
          iconColor: slide.iconColor,
          title: slide.title,
          subtitle: slide.description,
        ),
      ],
    );
  }
}
