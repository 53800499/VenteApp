import 'package:flutter/material.dart';


/// Conteneur réactif unifié pour normaliser les marges et la largeur d'affichage
/// sur toutes les pages et sous-pages du système (mobile et desktop/Windows).
///
/// - Sur mobile : pleine largeur naturelle.
/// - Sur grand écran / Windows : pleine largeur justifiée et fluide par défaut,
///   ou 560px centré ergonomique pour les formulaires de saisie (.form).
/// - Harmonise l'espacement et élimine les goulots d'étranglement artificiels.
class AppPageContainer extends StatelessWidget {
  const AppPageContainer({
    super.key,
    required this.child,
    this.maxWidth = double.infinity,
    this.padding,
    this.alignment = Alignment.topCenter,
  });

  /// Variante optimisée pour les formulaires de saisie (largeur max 560px).
  const AppPageContainer.form({
    super.key,
    required this.child,
    this.maxWidth = 560.0,
    this.padding,
    this.alignment = Alignment.topCenter,
  });

  final Widget child;
  final double maxWidth;
  final EdgeInsetsGeometry? padding;
  final Alignment alignment;

  @override
  Widget build(BuildContext context) {
    Widget content = child;
    if (padding != null) {
      content = Padding(padding: padding!, child: content);
    }
    if (maxWidth.isInfinite) {
      return SizedBox(
        width: double.infinity,
        child: content,
      );
    }
    return Align(
      alignment: alignment,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: content,
      ),
    );
  }
}
