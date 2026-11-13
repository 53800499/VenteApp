import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// Composant de secours affiché à la place de l'écran rouge de Flutter
/// en cas d'erreur de rendu ou d'assertion non interceptée.
class GlobalErrorFallback extends StatefulWidget {
  const GlobalErrorFallback({
    super.key,
    this.details,
    this.onRetry,
    this.compact = false,
  });

  final FlutterErrorDetails? details;
  final VoidCallback? onRetry;
  final bool compact;

  @override
  State<GlobalErrorFallback> createState() => _GlobalErrorFallbackState();
}

class _GlobalErrorFallbackState extends State<GlobalErrorFallback> {
  bool _showDetails = false;

  @override
  Widget build(BuildContext context) {
    bool isDark = false;
    try {
      isDark = Theme.of(context).brightness == Brightness.dark;
    } catch (_) {
      isDark = false;
    }

    // Palette douce et moderne adaptée à ARIKE (jamais de rouge criard)
    final bgColor = isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC);
    final cardColor = isDark ? const Color(0xFF1E293B) : Colors.white;
    final borderColor = isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0);
    final titleColor = isDark ? const Color(0xFFF1F5F9) : const Color(0xFF0F172A);
    final subtitleColor = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);
    const primaryEmerald = Color(0xFF0B6E4F);

    if (widget.compact) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        margin: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: borderColor),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.info_outline_rounded, color: primaryEmerald, size: 20),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Affichage temporairement indisponible',
                style: TextStyle(color: titleColor, fontSize: 13, fontWeight: FontWeight.w500),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (widget.onRetry != null) ...[
              const SizedBox(width: 8),
              IconButton(
                icon: const Icon(Icons.refresh_rounded, size: 18, color: primaryEmerald),
                onPressed: widget.onRetry,
                tooltip: 'Actualiser',
              ),
            ],
          ],
        ),
      );
    }

    return Material(
      color: bgColor,
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Container(
            constraints: const BoxConstraints(maxWidth: 520),
            padding: const EdgeInsets.all(28),
            decoration: BoxDecoration(
              color: cardColor,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: borderColor),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.05),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: primaryEmerald.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.view_compact_rounded,
                    color: primaryEmerald,
                    size: 28,
                  ),
                ),
                const SizedBox(height: 18),
                Text(
                  'Affichage momentanément indisponible',
                  style: TextStyle(
                    color: titleColor,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  'Une anomalie passagère est survenue lors de l\'affichage de cette section. Vos données sont préservées en toute sécurité.',
                  style: TextStyle(
                    color: subtitleColor,
                    fontSize: 13,
                    height: 1.5,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    FilledButton.icon(
                      onPressed: () {
                        if (widget.onRetry != null) {
                          widget.onRetry!();
                        } else {
                          setState(() {});
                        }
                      },
                      style: FilledButton.styleFrom(
                        backgroundColor: primaryEmerald,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      icon: const Icon(Icons.refresh_rounded, size: 18),
                      label: const Text(
                        'Actualiser la vue',
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
                if (kDebugMode && widget.details != null) ...[
                  const SizedBox(height: 16),
                  TextButton.icon(
                    onPressed: () {
                      setState(() {
                        _showDetails = !_showDetails;
                      });
                    },
                    icon: Icon(
                      _showDetails ? Icons.expand_less_rounded : Icons.expand_more_rounded,
                      size: 16,
                      color: subtitleColor,
                    ),
                    label: Text(
                      _showDetails ? 'Masquer les détails techniques' : 'Détails techniques',
                      style: TextStyle(fontSize: 12, color: subtitleColor),
                    ),
                  ),
                  if (_showDetails) ...[
                    const SizedBox(height: 8),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF020617) : const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        widget.details?.exceptionAsString() ?? 'Erreur non spécifiée',
                        style: TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 11,
                          color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF334155),
                        ),
                        maxLines: 8,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

