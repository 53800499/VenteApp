import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_tokens.dart';
import '../../../../core/responsive/breakpoints.dart';

class PinPad extends StatelessWidget {
  const PinPad({
    super.key,
    required this.filledCount,
    required this.maxLength,
    required this.onDigit,
    required this.onBackspace,
    this.enabled = true,
    this.compact = false,
  });

  final int filledCount;
  final int maxLength;
  final ValueChanged<String> onDigit;
  final VoidCallback onBackspace;
  final bool enabled;
  final bool compact;

  void _onKeyTap(VoidCallback action) {
    if (!enabled) return;
    HapticFeedback.lightImpact();
    action();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final veryCompact = constraints.maxHeight < 520;
        final useCompact = compact || veryCompact;
        final colorScheme = Theme.of(context).colorScheme;
        final keys = ['1', '2', '3', '4', '5', '6', '7', '8', '9', '', '0', '⌫'];
        final gridSpacing = useCompact ? 6.0 : 12.0;
        final aspectRatio = useCompact ? 1.5 : 1.15;

        return ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: useCompact ? 300 : Breakpoints.pinPadMaxWidth,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(maxLength, (index) {
                  final filled = index < filledCount;
                  return AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    curve: Curves.easeOut,
                    width: filled ? 14 : 12,
                    height: filled ? 14 : 12,
                    margin: EdgeInsets.symmetric(horizontal: useCompact ? 8 : 10),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: filled ? colorScheme.primary : Colors.transparent,
                      border: Border.all(
                        color: filled
                            ? colorScheme.primary
                            : colorScheme.outline.withValues(alpha: 0.5),
                        width: filled ? 0 : 1.5,
                      ),
                    ),
                  );
                }),
              ),
              SizedBox(height: useCompact ? AppSpacing.sm : AppSpacing.lg),
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: keys.length,
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  mainAxisSpacing: gridSpacing,
                  crossAxisSpacing: gridSpacing,
                  childAspectRatio: aspectRatio,
                ),
                itemBuilder: (context, index) {
                  final key = keys[index];
                  if (key.isEmpty) return const SizedBox.shrink();

                  final isBackspace = key == '⌫';

                  return Material(
                    color: AppColors.surfaceCard,
                    elevation: 0,
                    shadowColor: Colors.black26,
                    shape: const CircleBorder(),
                    child: InkWell(
                      customBorder: const CircleBorder(),
                      onTap: enabled
                          ? () => _onKeyTap(() {
                                if (isBackspace) {
                                  onBackspace();
                                } else {
                                  onDigit(key);
                                }
                              })
                          : null,
                      child: Container(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: colorScheme.outlineVariant.withValues(alpha: 0.6),
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.04),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Center(
                          child: isBackspace
                              ? Icon(
                                  Icons.backspace_outlined,
                                  color: colorScheme.onSurfaceVariant,
                                  size: useCompact ? 20 : 22,
                                )
                              : Text(
                                  key,
                                  style: (useCompact
                                          ? Theme.of(context).textTheme.titleMedium
                                          : Theme.of(context).textTheme.headlineSmall)
                                      ?.copyWith(
                                        fontWeight: FontWeight.w600,
                                      ),
                                ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }
}
