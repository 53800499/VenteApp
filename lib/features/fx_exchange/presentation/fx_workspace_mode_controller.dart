import 'package:flutter/foundation.dart';

/// Contrôle l'affichage de l'onglet Change en racine (mode cambiste).
class FxWorkspaceModeController extends ChangeNotifier {
  bool _primary = false;
  bool _moduleEnabled = false;

  bool get primary => _primary;
  bool get moduleEnabled => _moduleEnabled;

  /// True si la barre principale doit montrer Change en 1er onglet.
  bool get useFxPrimaryShell => _primary && _moduleEnabled;

  void apply({required bool primary, required bool moduleEnabled}) {
    if (_primary == primary && _moduleEnabled == moduleEnabled) return;
    _primary = primary;
    _moduleEnabled = moduleEnabled;
    notifyListeners();
  }
}
