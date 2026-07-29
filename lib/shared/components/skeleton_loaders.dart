import 'package:flutter/material.dart';

import '../../app/theme/app_tokens.dart';

/// Animation Shimmer légère sans dépendance externe pour charger les squelettes UI.
class ShimmerBox extends StatefulWidget {
  const ShimmerBox({
    super.key,
    required this.width,
    required this.height,
    this.borderRadius = 8,
  });

  final double width;
  final double height;
  final double borderRadius;

  @override
  State<ShimmerBox> createState() => _ShimmerBoxState();
}

class _ShimmerBoxState extends State<ShimmerBox>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);

    _animation = Tween<double>(begin: 0.35, end: 0.75).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final baseColor = Theme.of(context).colorScheme.surfaceContainerHighest;

    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Container(
          width: widget.width,
          height: widget.height,
          decoration: BoxDecoration(
            color: baseColor.withValues(alpha: _animation.value),
            borderRadius: BorderRadius.circular(widget.borderRadius),
          ),
        );
      },
    );
  }
}

/// Squelette de chargement pour le Tableau de bord.
class DashboardSkeleton extends StatelessWidget {
  const DashboardSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const ShimmerBox(width: 180, height: 24),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: const [
              Expanded(child: ShimmerBox(width: double.infinity, height: 90)),
              SizedBox(width: AppSpacing.sm),
              Expanded(child: ShimmerBox(width: double.infinity, height: 90)),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: const [
              Expanded(child: ShimmerBox(width: double.infinity, height: 90)),
              SizedBox(width: AppSpacing.sm),
              Expanded(child: ShimmerBox(width: double.infinity, height: 90)),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          const ShimmerBox(width: 140, height: 20),
          const SizedBox(height: AppSpacing.sm),
          for (int i = 0; i < 4; i++) ...[
            const Padding(
              padding: EdgeInsets.only(bottom: AppSpacing.sm),
              child: ShimmerBox(width: double.infinity, height: 60),
            ),
          ],
        ],
      ),
    );
  }
}

/// Squelette de chargement pour la Liste des ventes.
class SaleListSkeleton extends StatelessWidget {
  const SaleListSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.all(AppSpacing.md),
      itemCount: 6,
      itemBuilder: (context, index) {
        return const Padding(
          padding: EdgeInsets.only(bottom: AppSpacing.md),
          child: ShimmerBox(width: double.infinity, height: 72, borderRadius: 12),
        );
      },
    );
  }
}
