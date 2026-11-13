import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Contrôleur de facteur d'échelle des polices et textes (Text Scaling).
///
/// Permet d'adapter dynamiquement la taille de police sur Windows Desktop
/// et tous les écrans, sans redémarrer l'application, et persiste la préférence
/// dans [SharedPreferences].
class UiScaleController extends ChangeNotifier {
  UiScaleController(this._prefs) {
    _load();
  }

  final SharedPreferences _prefs;

  static const String keyTextScaleFactor = 'ui_text_scale_factor';

  /// Valeurs standards recommandées
  static const double minScale = 0.85;
  static const double maxScale = 1.50;
  static const double defaultScale = 1.0;

  static const List<double> standardPresets = [
    0.90,
    1.00,
    1.15,
    1.25,
    1.35,
    1.50,
  ];

  double _scaleFactor = defaultScale;

  double get scaleFactor => _scaleFactor;

  int get percentage => (_scaleFactor * 100).round();

  bool get isDefault => (_scaleFactor - defaultScale).abs() < 0.01;

  void _load() {
    final saved = _prefs.getDouble(keyTextScaleFactor);
    if (saved != null) {
      _scaleFactor = saved.clamp(minScale, maxScale);
    } else {
      _scaleFactor = defaultScale;
    }
  }

  /// Modifie la taille d'échelle du texte et notifie tous les auditeurs
  Future<void> setScaleFactor(double value) async {
    final clamped = value.clamp(minScale, maxScale);
    // Arrondi à 2 décimales pour éviter le bruit de virgule flottante
    final rounded = (clamped * 100).round() / 100.0;
    if ((_scaleFactor - rounded).abs() < 0.005) return;

    _scaleFactor = rounded;
    notifyListeners();
    await _prefs.setDouble(keyTextScaleFactor, _scaleFactor);
  }

  /// Augmente la taille du texte d'un palier (+5%)
  Future<void> zoomIn() async {
    await setScaleFactor(_scaleFactor + 0.05);
  }

  /// Réduit la taille du texte d'un palier (-5%)
  Future<void> zoomOut() async {
    await setScaleFactor(_scaleFactor - 0.05);
  }

  /// Rétablit l'échelle par défaut (100%)
  Future<void> reset() async {
    await setScaleFactor(defaultScale);
  }
}
