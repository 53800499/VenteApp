import 'package:flutter/material.dart';

import '../../../../app/di/injection_container.dart';
import '../../../../app/theme/app_tokens.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../auth/domain/entities/auth_entities.dart';
import '../../domain/entities/sales_analysis_entities.dart';
import '../../domain/usecases/sales_analysis_usecases.dart';

class CustomerPriceHabitsSection extends StatefulWidget {
  const CustomerPriceHabitsSection({
    super.key,
    required this.session,
    required this.customerId,
  });

  final AuthSession session;
  final int customerId;

  @override
  State<CustomerPriceHabitsSection> createState() =>
      _CustomerPriceHabitsSectionState();
}

class _CustomerPriceHabitsSectionState extends State<CustomerPriceHabitsSection> {
  late Future<List<CustomerProductPriceHabit>> _future;

  @override
  void initState() {
    super.initState();
    ensureSalesAnalysisDependencies();
    _future = sl<GetCustomerPriceHabits>()(
      shopId: widget.session.shop.id,
      customerId: widget.customerId,
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<CustomerProductPriceHabit>>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: AppSpacing.md),
            child: Center(child: CircularProgressIndicator()),
          );
        }
        if (snapshot.hasError) return const SizedBox.shrink();

        final habits = snapshot.data ?? const <CustomerProductPriceHabit>[];
        if (habits.isEmpty) return const SizedBox.shrink();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Prix habituels par produit',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: AppSpacing.sm),
            ...habits.map(
              (habit) => Card(
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        habit.productName,
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      Wrap(
                        spacing: AppSpacing.xs,
                        runSpacing: AppSpacing.xs,
                        children: habit.recentPrices
                            .map(
                              (price) => Chip(
                                label: Text(formatFcfa(price)),
                                visualDensity: VisualDensity.compact,
                              ),
                            )
                            .toList(),
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        'Prix habituel : ${formatFcfa(habit.usualPrice)}',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
