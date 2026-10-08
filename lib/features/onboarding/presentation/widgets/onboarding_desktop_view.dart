import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_tokens.dart';
import '../../data/onboarding_slides.dart';

/// Vue d'accueil et présentation grand écran optimisée pour Windows Desktop.
class OnboardingDesktopView extends StatefulWidget {
  const OnboardingDesktopView({
    super.key,
    required this.onComplete,
    required this.slides,
  });

  final VoidCallback onComplete;
  final List<OnboardingSlideData> slides;

  @override
  State<OnboardingDesktopView> createState() => _OnboardingDesktopViewState();
}

class _OnboardingDesktopViewState extends State<OnboardingDesktopView> {
  int _selectedIndex = 0;
  final ScrollController _listScrollController = ScrollController();

  OnboardingSlideData get _currentSlide => widget.slides[_selectedIndex];
  bool get _isLastSlide => _selectedIndex == widget.slides.length - 1;

  void _next() {
    if (_isLastSlide) {
      widget.onComplete();
    } else {
      _selectSlide(_selectedIndex + 1);
    }
  }

  void _previous() {
    if (_selectedIndex > 0) {
      _selectSlide(_selectedIndex - 1);
    }
  }

  void _selectSlide(int index) {
    if (index < 0 || index >= widget.slides.length) return;
    setState(() => _selectedIndex = index);
    // Assurer la visibilité dans la liste gauche
    if (_listScrollController.hasClients) {
      final targetOffset = (index * 76.0).clamp(
        0.0,
        _listScrollController.position.maxScrollExtent,
      );
      _listScrollController.animateTo(
        targetOffset,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOutCubic,
      );
    }
  }

  KeyEventResult _handleKeyEvent(FocusNode node, KeyEvent event) {
    if (event is KeyDownEvent) {
      if (event.logicalKey == LogicalKeyboardKey.arrowDown ||
          event.logicalKey == LogicalKeyboardKey.arrowRight) {
        _next();
        return KeyEventResult.handled;
      } else if (event.logicalKey == LogicalKeyboardKey.arrowUp ||
          event.logicalKey == LogicalKeyboardKey.arrowLeft) {
        _previous();
        return KeyEventResult.handled;
      } else if (event.logicalKey == LogicalKeyboardKey.enter ||
          event.logicalKey == LogicalKeyboardKey.space) {
        _next();
        return KeyEventResult.handled;
      } else if (event.logicalKey == LogicalKeyboardKey.escape) {
        widget.onComplete();
        return KeyEventResult.handled;
      }
    }
    return KeyEventResult.ignored;
  }

  @override
  void dispose() {
    _listScrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final accent = _currentSlide.gradientColors?.first ?? _currentSlide.accentColor;
    final secondaryAccent = _currentSlide.gradientColors?.last ?? accent.withValues(alpha: 0.8);

    return Focus(
      autofocus: true,
      onKeyEvent: _handleKeyEvent,
      child: Scaffold(
        backgroundColor: const Color(0xFF0F172A), // Slate 900 sombre et moderne
        body: Stack(
          children: [
            // Arrière-plan lumineux dynamique
            _DesktopAmbientOrbs(accentColor: accent),

            // Contenu principal
            SafeArea(
              child: Column(
                children: [
                  // Barre d'en-tête Desktop
                  _buildTopBar(context, accent),

                  // Corps à 2 colonnes
                  Expanded(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Volet Gauche : Navigation & Piliers (Section gauche entière bord à bord)
                        SizedBox(
                          width: 380,
                          child: _buildLeftNavigationPanel(context, accent),
                        ),

                        // Volet Droit : Vitrine immersive & Simulateur POS (Espace restant)
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.all(AppSpacing.lg),
                            child: _buildRightShowcasePanel(
                              context,
                              accent,
                              secondaryAccent,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Barre d'informations bas de page (raccourcis clavier)
                  _buildFooterKeyboardBar(context, accent),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Barre d'en-tête de la fenêtre desktop
  Widget _buildTopBar(BuildContext context, Color accent) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final showEditionBadge = constraints.maxWidth >= 1000;
        final showOfflineBadge = constraints.maxWidth >= 1400;

        return Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg,
            vertical: AppSpacing.sm,
          ),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.25),
            border: Border(
              bottom: BorderSide(
                color: Colors.white.withValues(alpha: 0.08),
              ),
            ),
          ),
          child: Row(
            children: [
              // Logo & Titre
              Container(
                padding: const EdgeInsets.all(AppSpacing.xs + 2),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF0B6E4F), Color(0xFF1565C0)],
                  ),
                  borderRadius: BorderRadius.circular(AppRadius.md),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF0B6E4F).withValues(alpha: 0.35),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.point_of_sale_rounded,
                  color: Colors.white,
                  size: 20,
                ),
              ),
              const SizedBox(width: AppSpacing.sm + 4),
              const Text(
                'ARIKE VenteApp',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                  fontSize: 18,
                  letterSpacing: 0.5,
                ),
              ),
              if (showEditionBadge) ...[
                const SizedBox(width: AppSpacing.md),
                // Badge Édition Windows
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(AppRadius.pill),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.2),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.desktop_windows_rounded,
                        size: 13,
                        color: Colors.white.withValues(alpha: 0.8),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'Édition Windows POS',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.9),
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const Spacer(),

              if (showOfflineBadge) ...[
                // Badge hors-ligne prêt
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.success.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(AppRadius.pill),
                    border: Border.all(
                      color: AppColors.success.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 7,
                        height: 7,
                        decoration: const BoxDecoration(
                          color: AppColors.success,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 6),
                      const Text(
                        '100% Offline-First',
                        style: TextStyle(
                          color: Color(0xFF81C784),
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
              ],

              // Bouton Passer
              TextButton.icon(
                onPressed: widget.onComplete,
                icon: Icon(
                  Icons.skip_next_rounded,
                  size: 18,
                  color: Colors.white.withValues(alpha: 0.7),
                ),
                label: Text(
                  'Passer (Échap)',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.7),
                    fontSize: 13,
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),

              // Bouton Principal Démarrer
              FilledButton.icon(
                onPressed: widget.onComplete,
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF0B6E4F),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppRadius.md),
                  ),
                ),
                icon: const Icon(Icons.arrow_forward_rounded, size: 16),
                label: const Text(
                  'Démarrer (Entrée)',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  /// Volet Gauche : Navigation interactive dans les modules
  Widget _buildLeftNavigationPanel(BuildContext context, Color accent) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B).withValues(alpha: 0.95),
        border: Border(
          right: BorderSide(
            color: Colors.white.withValues(alpha: 0.1),
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Titre de section
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg,
              AppSpacing.md,
              AppSpacing.lg,
              AppSpacing.sm,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: accent.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Icon(Icons.grid_view_rounded, size: 14, color: accent),
                    ),
                    const SizedBox(width: 8),
                    const Text(
                      'LES 8 PILIERS ARIKE',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.2,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                const Text(
                  'Cliquez pour explorer un module',
                  style: TextStyle(
                    color: Colors.white38,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),

          const Divider(color: Colors.white10, height: 1),

          // Liste des 8 slides
          Expanded(
            child: ListView.separated(
              controller: _listScrollController,
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.sm,
                vertical: AppSpacing.xs,
              ),
              itemCount: widget.slides.length,
              separatorBuilder: (_, _) => const SizedBox(height: 4),
              itemBuilder: (context, index) {
                final slide = widget.slides[index];
                final isSelected = index == _selectedIndex;
                final slideAccent = slide.gradientColors?.first ?? slide.accentColor;

                return InkWell(
                  onTap: () => _selectSlide(index),
                  borderRadius: BorderRadius.circular(AppRadius.md),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    curve: Curves.easeOut,
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.md,
                      vertical: AppSpacing.sm + 2,
                    ),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? slideAccent.withValues(alpha: 0.18)
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(AppRadius.md),
                      border: Border.all(
                        color: isSelected
                            ? slideAccent.withValues(alpha: 0.5)
                            : Colors.transparent,
                        width: 1.5,
                      ),
                    ),
                    child: Row(
                      children: [
                        // Numéro de slide
                        Text(
                          '0${index + 1}',
                          style: TextStyle(
                            color: isSelected ? slideAccent : Colors.white30,
                            fontWeight: FontWeight.w800,
                            fontSize: 11,
                          ),
                        ),
                        const SizedBox(width: 10),

                        // Icône du module
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? slideAccent
                                : Colors.white.withValues(alpha: 0.06),
                            borderRadius: BorderRadius.circular(AppRadius.sm),
                          ),
                          child: Icon(
                            slide.icon,
                            size: 16,
                            color: isSelected ? Colors.white : Colors.white70,
                          ),
                        ),
                        const SizedBox(width: 12),

                        // Titre & Tagline
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                slide.title,
                                style: TextStyle(
                                  color: isSelected
                                      ? Colors.white
                                      : Colors.white.withValues(alpha: 0.8),
                                  fontWeight: isSelected
                                      ? FontWeight.w700
                                      : FontWeight.w500,
                                  fontSize: 13,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                slide.headline,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: isSelected
                                      ? slideAccent
                                      : Colors.white38,
                                  fontSize: 11,
                                ),
                              ),
                            ],
                          ),
                        ),

                        // Indicateur de sélection
                        if (isSelected)
                          Container(
                            width: 6,
                            height: 6,
                            decoration: BoxDecoration(
                              color: slideAccent,
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: slideAccent,
                                  blurRadius: 6,
                                  spreadRadius: 1,
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),

          const Divider(color: Colors.white10, height: 1),

          // Pied de volet : Stepper & Contrôles
          Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Étape ${_selectedIndex + 1} sur ${widget.slides.length}',
                      style: TextStyle(
                        color: accent,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      '${((_selectedIndex + 1) / widget.slides.length * 100).toInt()}%',
                      style: const TextStyle(
                        color: Colors.white38,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                // Barre de progression
                ClipRRect(
                  borderRadius: BorderRadius.circular(AppRadius.pill),
                  child: LinearProgressIndicator(
                    value: (_selectedIndex + 1) / widget.slides.length,
                    minHeight: 6,
                    backgroundColor: Colors.white.withValues(alpha: 0.08),
                    valueColor: AlwaysStoppedAnimation<Color>(accent),
                  ),
                ),
                const SizedBox(height: AppSpacing.md),

                // Boutons Précédent / Suivant
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _selectedIndex > 0 ? _previous : null,
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.white70,
                          side: const BorderSide(color: Colors.white24),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(AppRadius.md),
                          ),
                        ),
                        icon: const Icon(Icons.arrow_back_rounded, size: 16),
                        label: const Text('Précédent', style: TextStyle(fontSize: 12)),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      flex: 2,
                      child: FilledButton.icon(
                        onPressed: _next,
                        style: FilledButton.styleFrom(
                          backgroundColor: accent,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(AppRadius.md),
                          ),
                        ),
                        icon: Icon(
                          _isLastSlide ? Icons.check_circle_rounded : Icons.arrow_forward_rounded,
                          size: 16,
                        ),
                        label: Text(
                          _isLastSlide ? 'Terminer & Ouvrir' : 'Suivant',
                          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Volet Droit : Showcase immersif et interactif
  Widget _buildRightShowcasePanel(
    BuildContext context,
    Color accent,
    Color secondaryAccent,
  ) {
    final slide = _currentSlide;

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 350),
      switchInCurve: Curves.easeOutCubic,
      switchOutCurve: Curves.easeInCubic,
      transitionBuilder: (child, animation) {
        return FadeTransition(
          opacity: animation,
          child: SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0.04, 0),
              end: Offset.zero,
            ).animate(animation),
            child: child,
          ),
        );
      },
      child: Container(
        key: ValueKey<int>(_selectedIndex),
        decoration: BoxDecoration(
          color: const Color(0xFF1E293B).withValues(alpha: 0.85),
          borderRadius: BorderRadius.circular(AppRadius.xl),
          border: Border.all(
            color: accent.withValues(alpha: 0.35),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: accent.withValues(alpha: 0.15),
              blurRadius: 36,
              offset: const Offset(0, 12),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(AppRadius.xl),
          child: Stack(
            children: [
              // Halo d'accent local
              Positioned(
                top: -60,
                right: -60,
                child: Container(
                  width: 320,
                  height: 320,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        accent.withValues(alpha: 0.25),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
              ),

              // Contenu défilable de la vitrine
              SingleChildScrollView(
                padding: const EdgeInsets.all(AppSpacing.xl),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Badge supérieur
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 5,
                          ),
                          decoration: BoxDecoration(
                            color: accent.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(AppRadius.pill),
                            border: Border.all(
                              color: accent.withValues(alpha: 0.4),
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(slide.icon, size: 14, color: accent),
                              const SizedBox(width: 8),
                              Text(
                                slide.desktopBadge ?? slide.title.toUpperCase(),
                                style: TextStyle(
                                  color: accent,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 1.1,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const Spacer(),
                        // Raccourci rapide
                        Text(
                          'Module ${_selectedIndex + 1}/8',
                          style: const TextStyle(
                            color: Colors.white38,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: AppSpacing.md),

                    // Titre & Grand Headline
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Icône héro avec halo
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [
                                accent,
                                secondaryAccent,
                              ],
                            ),
                            borderRadius: BorderRadius.circular(AppRadius.lg),
                            boxShadow: [
                              BoxShadow(
                                color: accent.withValues(alpha: 0.4),
                                blurRadius: 20,
                                offset: const Offset(0, 8),
                              ),
                            ],
                          ),
                          child: Icon(slide.icon, size: 36, color: Colors.white),
                        ),
                        const SizedBox(width: AppSpacing.lg),

                        // Textes
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                slide.headline,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 26,
                                  fontWeight: FontWeight.w800,
                                  height: 1.2,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                slide.description,
                                style: const TextStyle(
                                  color: Colors.white70,
                                  fontSize: 14,
                                  height: 1.5,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: AppSpacing.lg),

                    // Atouts majeurs Desktop
                    const Text(
                      'ATOUTS MAJEURS SUR WINDOWS',
                      style: TextStyle(
                        color: Colors.white54,
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.1,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.sm),

                    // Grille des atouts spécifiques
                    Column(
                      children: (slide.desktopBenefits ?? slide.highlights).map((benefit) {
                        return Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppSpacing.md,
                            vertical: AppSpacing.sm + 2,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.04),
                            borderRadius: BorderRadius.circular(AppRadius.md),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.08),
                            ),
                          ),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(4),
                                decoration: BoxDecoration(
                                  color: accent.withValues(alpha: 0.2),
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  Icons.check_rounded,
                                  size: 14,
                                  color: accent,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  benefit,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                    ),

                    const SizedBox(height: AppSpacing.lg),

                    // Simulateur interactif / Mockup dynamique selon le module
                    const Text(
                      'APERÇU VISUEL DU MODULE',
                      style: TextStyle(
                        color: Colors.white54,
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.1,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.sm),

                    _SlideInteractivePreview(
                      slideIndex: _selectedIndex,
                      accentColor: accent,
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

  /// Barre inférieure pour guider sur les touches du clavier Windows
  Widget _buildFooterKeyboardBar(BuildContext context, Color accent) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.xl,
        vertical: AppSpacing.xs + 2,
      ),
      color: Colors.black.withValues(alpha: 0.4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _KeyboardKeyBadge(keyLabel: '← / →', description: 'Naviguer'),
          const SizedBox(width: AppSpacing.md),
          const Text('•', style: TextStyle(color: Colors.white24)),
          const SizedBox(width: AppSpacing.md),
          _KeyboardKeyBadge(keyLabel: 'Entrée', description: 'Continuer'),
          const SizedBox(width: AppSpacing.md),
          const Text('•', style: TextStyle(color: Colors.white24)),
          const SizedBox(width: AppSpacing.md),
          _KeyboardKeyBadge(keyLabel: 'Échap', description: 'Passer'),
        ],
      ),
    );
  }
}

/// Badge stylisé pour touche clavier
class _KeyboardKeyBadge extends StatelessWidget {
  const _KeyboardKeyBadge({
    required this.keyLabel,
    required this.description,
  });

  final String keyLabel;
  final String description;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(4),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.25),
            ),
          ),
          child: Text(
            keyLabel,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 11,
              fontWeight: FontWeight.w700,
              fontFamily: 'monospace',
            ),
          ),
        ),
        const SizedBox(width: 6),
        Text(
          description,
          style: const TextStyle(
            color: Colors.white54,
            fontSize: 11,
          ),
        ),
      ],
    );
  }
}

/// Aperçu visuel / Mockup immersif pour chaque module sélectionné
class _SlideInteractivePreview extends StatelessWidget {
  const _SlideInteractivePreview({
    required this.slideIndex,
    required this.accentColor,
  });

  final int slideIndex;
  final Color accentColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A).withValues(alpha: 0.95),
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(
          color: accentColor.withValues(alpha: 0.25),
        ),
      ),
      child: switch (slideIndex) {
        0 => _buildCockpitPreview(),
        1 => _buildDashboardPreview(),
        2 => _buildPosPreview(),
        3 => _buildStockPreview(),
        4 => _buildDebtsPreview(),
        5 => _buildFinancesPreview(),
        6 => _buildMultiShopPreview(),
        _ => _buildCloudSyncPreview(),
      },
    );
  }

  Widget _buildCockpitPreview() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: AppColors.success.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(4),
              ),
              child: const Row(
                children: [
                  Icon(Icons.check_circle_outline, size: 12, color: AppColors.success),
                  SizedBox(width: 4),
                  Text('SYSTÈME PRÊT', style: TextStyle(color: AppColors.success, fontSize: 10, fontWeight: FontWeight.bold)),
                ],
              ),
            ),
            const Spacer(),
            const Text('Boutique Principale · Cotonou', style: TextStyle(color: Colors.white54, fontSize: 11)),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(child: _miniCard('Base Locale', 'Drift SQLite Chiffrée', Icons.shield_outlined, Colors.teal)),
            const SizedBox(width: 8),
            Expanded(child: _miniCard('Caisse', 'Session Ouverte', Icons.lock_open_rounded, Colors.green)),
            const SizedBox(width: 8),
            Expanded(child: _miniCard('Réseau', 'Mode Autonome', Icons.wifi_off_rounded, Colors.blue)),
          ],
        ),
      ],
    );
  }

  Widget _buildDashboardPreview() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Text('Indicateurs du jour', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(color: Colors.blue.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(4)),
              child: const Text('En direct', style: TextStyle(color: Colors.blue, fontSize: 9, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: _kpiBox('Chiffre d\'Affaires', '185.000 F', '+14% vs hier', Colors.green),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _kpiBox('Ventes Réalisées', '24 tickets', 'Panier moy. 7.700 F', Colors.blue),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _kpiBox('Alertes Rupture', '2 articles', 'À commander', Colors.orange),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildPosPreview() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.point_of_sale, size: 14, color: Colors.green),
            const SizedBox(width: 6),
            const Text('Panier Actuel · Ticket #042', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(color: Colors.green.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(4)),
              child: const Text('42.500 FCFA', style: TextStyle(color: Colors.green, fontSize: 11, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.05), borderRadius: BorderRadius.circular(6)),
          child: const Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('2x Riz Parfumé 25kg + 1x Huile 5L', style: TextStyle(color: Colors.white70, fontSize: 11)),
              Text('Règlement : Espèces / MoMo', style: TextStyle(color: Colors.white38, fontSize: 10)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildStockPreview() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Articles récents & Niveaux d\'alerte', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        _stockRow('Lait Bonnet Rouge 410g', 'Stock : 48', 'Optimal', Colors.teal),
        const SizedBox(height: 4),
        _stockRow('Savon Palmida 200g', 'Stock : 3 (Seuil : 10)', 'Alerte Rupture', Colors.red),
      ],
    );
  }

  Widget _buildDebtsPreview() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.account_circle_outlined, size: 14, color: Colors.purple),
            const SizedBox(width: 6),
            const Text('Mme Adjovi Mensah · Ganhi', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
            const Spacer(),
            const Text('Dette : 15.000 FCFA', style: TextStyle(color: Colors.purpleAccent, fontSize: 11, fontWeight: FontWeight.bold)),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(color: Colors.green.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(4)),
              child: const Row(
                children: [
                  Icon(Icons.chat_bubble_outline, size: 11, color: Colors.green),
                  SizedBox(width: 4),
                  Text('Relance WhatsApp prête', style: TextStyle(color: Colors.green, fontSize: 10)),
                ],
              ),
            ),
            const SizedBox(width: 8),
            const Text('Échéance dans 3 jours', style: TextStyle(color: Colors.white38, fontSize: 10)),
          ],
        ),
      ],
    );
  }

  Widget _buildFinancesPreview() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Point de caisse journalier', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
            Text('Solde théorique : 223.000 F', style: TextStyle(color: Colors.orange, fontSize: 11, fontWeight: FontWeight.bold)),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(child: _finBox('Fond initial', '50.000 F', Colors.blue)),
            const SizedBox(width: 6),
            Expanded(child: _finBox('Ventes encaissées', '+185.000 F', Colors.green)),
            const SizedBox(width: 6),
            Expanded(child: _finBox('Sorties / Frais', '-12.000 F', Colors.red)),
          ],
        ),
      ],
    );
  }

  Widget _buildMultiShopPreview() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Réseau multi-boutiques connecté', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: _shopNode('Boutique Cotonou Ganhi', 'Caisse active · 2 vendeurs', true),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _shopNode('Dépôt Akpakpa', 'Stock relié · Synchronisé', false),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildCloudSyncPreview() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Row(
          children: [
            Icon(Icons.cloud_done_rounded, size: 14, color: Colors.teal),
            SizedBox(width: 6),
            Text('Double Sécurité : Disque Local + Cloud', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
          ],
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(color: Colors.teal.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(6)),
          child: const Row(
            children: [
              Icon(Icons.sync_rounded, size: 14, color: Colors.teal),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Toutes vos opérations sont gravées en local instantanément et synchronisées en tâche de fond dès qu\'Internet est disponible.',
                  style: TextStyle(color: Colors.white70, fontSize: 11),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _miniCard(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.05), borderRadius: BorderRadius.circular(6)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(height: 4),
          Text(label, style: const TextStyle(color: Colors.white38, fontSize: 9)),
          Text(value, style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _kpiBox(String title, String val, String sub, Color color) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.05), borderRadius: BorderRadius.circular(6)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(color: Colors.white38, fontSize: 9)),
          Text(val, style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.bold)),
          Text(sub, style: const TextStyle(color: Colors.white54, fontSize: 8)),
        ],
      ),
    );
  }

  Widget _stockRow(String name, String stock, String status, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.04), borderRadius: BorderRadius.circular(4)),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(name, style: const TextStyle(color: Colors.white70, fontSize: 11)),
          Row(
            children: [
              Text(stock, style: const TextStyle(color: Colors.white38, fontSize: 10)),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                decoration: BoxDecoration(color: color.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(3)),
                child: Text(status, style: TextStyle(color: color, fontSize: 9, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _finBox(String title, String val, Color color) {
    return Container(
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.04), borderRadius: BorderRadius.circular(4)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(color: Colors.white38, fontSize: 9)),
          Text(val, style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _shopNode(String name, String detail, bool active) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: active ? Colors.green.withValues(alpha: 0.1) : Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: active ? Colors.green.withValues(alpha: 0.3) : Colors.white10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.storefront, size: 12, color: active ? Colors.green : Colors.white54),
              const SizedBox(width: 4),
              Expanded(child: Text(name, style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold), overflow: TextOverflow.ellipsis)),
            ],
          ),
          const SizedBox(height: 2),
          Text(detail, style: const TextStyle(color: Colors.white38, fontSize: 9)),
        ],
      ),
    );
  }
}

/// Cercles ambiants décoratifs en arrière-plan
class _DesktopAmbientOrbs extends StatelessWidget {
  const _DesktopAmbientOrbs({required this.accentColor});

  final Color accentColor;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned(
          top: -100,
          left: -100,
          child: Container(
            width: 450,
            height: 450,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  accentColor.withValues(alpha: 0.12),
                  Colors.transparent,
                ],
              ),
            ),
          ),
        ),
        Positioned(
          bottom: -150,
          right: -150,
          child: Container(
            width: 600,
            height: 600,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  const Color(0xFF1565C0).withValues(alpha: 0.08),
                  Colors.transparent,
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
