import 'dart:async';
import 'package:flutter/material.dart';

/// Notification visuelle temporaire (HUD) affichée au centre de l'écran
/// lors de l'utilisation des raccourcis clavier Ctrl + / Ctrl - / Ctrl 0.
class UiScaleOverlay {
  static OverlayEntry? _currentEntry;
  static Timer? _dismissTimer;

  static void show(BuildContext context, int percentage) {
    _dismissTimer?.cancel();
    _currentEntry?.remove();
    _currentEntry = null;

    final overlayState = Overlay.maybeOf(context, rootOverlay: true);
    if (overlayState == null) return;

    final entry = OverlayEntry(
      builder: (context) {
        return Positioned(
          bottom: 48,
          left: 0,
          right: 0,
          child: Center(
            child: Material(
              color: Colors.transparent,
              child: AnimatedOpacity(
                opacity: 1.0,
                duration: const Duration(milliseconds: 200),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0F172A).withValues(alpha: 0.92),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: const Color(0xFF00A86B).withValues(alpha: 0.5),
                      width: 1.2,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.35),
                        blurRadius: 18,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.format_size_rounded,
                        color: Color(0xFF00A86B),
                        size: 20,
                      ),
                      const SizedBox(width: 10),
                      Text(
                        'Taille du texte : $percentage%',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.2,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );

    _currentEntry = entry;
    overlayState.insert(entry);

    _dismissTimer = Timer(const Duration(milliseconds: 1400), () {
      _currentEntry?.remove();
      _currentEntry = null;
    });
  }
}

