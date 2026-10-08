import 'package:flutter_test/flutter_test.dart';
import 'package:venteapp/core/licensing/domain/module_access_guard.dart';
import 'package:venteapp/features/subscription/domain/entities/subscription_details.dart';
import 'package:venteapp/features/subscription/domain/services/subscription_controller.dart';

void main() {
  group('SALES_ORDERS in Free Plan Tests', () {
    test('ArikeModule.salesOrders is granted on Free plan', () {
      final freeDetails = SubscriptionDetails(
        planCode: 'FREE',
        planName: 'ARIKE Gratuit',
        status: 'ACTIVE',
        startedAt: DateTime(2026, 1, 1),
        expiresAt: DateTime(2036, 1, 1),
        graceUntil: DateTime(2036, 1, 8),
        autoRenew: false,
        grantedModules: const [
          'Vente & Encaissement',
          'Gestion de Stock simple',
        ],
        maxUsers: 1,
        maxShops: 1,
        currentUsersCount: 1,
        currentShopsCount: 1,
        paymentHistory: const [],
      );

      final controller = SubscriptionController(initialDetails: freeDetails);

      expect(controller.details.isFreePlan, isTrue);
      expect(controller.isModuleGranted(ArikeModule.salesOrders), isTrue);
      expect(controller.isModuleNameGranted('SALES_ORDERS'), isTrue);
      expect(controller.isModuleNameGranted('sales_orders'), isTrue);
      expect(controller.getRequiredPlanForModule(ArikeModule.salesOrders), 'Gratuit');
    });

    test('ArikeModule.salesOrders is granted on STARTER plan', () {
      final starterDetails = SubscriptionDetails(
        planCode: 'STARTER',
        planName: 'ARIKE Starter',
        status: 'ACTIVE',
        startedAt: DateTime(2026, 1, 1),
        expiresAt: DateTime(2036, 1, 1),
        graceUntil: DateTime(2036, 1, 8),
        autoRenew: false,
        grantedModules: const [],
        maxUsers: 1,
        maxShops: 1,
        currentUsersCount: 1,
        currentShopsCount: 1,
        paymentHistory: const [],
      );

      final controller = SubscriptionController(initialDetails: starterDetails);

      expect(controller.details.isFreePlan, isTrue);
      expect(controller.isModuleGranted(ArikeModule.salesOrders), isTrue);
      expect(controller.isModuleNameGranted('SALES_ORDERS'), isTrue);
    });

    test('ArikeModule.salesOrders is granted on paid plans if module in grantedModules or ALL_MODULES', () {
      final paidDetails = SubscriptionDetails(
        planCode: 'ESSENTIEL',
        planName: 'ARIKE Essentiel',
        status: 'ACTIVE',
        startedAt: DateTime(2026, 1, 1),
        expiresAt: DateTime(2027, 1, 1),
        graceUntil: DateTime(2027, 1, 8),
        autoRenew: false,
        grantedModules: const [
          'Approvisionnements & Commandes clients',
        ],
        maxUsers: 3,
        maxShops: 1,
        currentUsersCount: 1,
        currentShopsCount: 1,
        paymentHistory: const [],
      );

      final controller = SubscriptionController(initialDetails: paidDetails);

      expect(controller.details.isFreePlan, isFalse);
      expect(controller.isModuleGranted(ArikeModule.salesOrders), isTrue);
      expect(controller.isModuleNameGranted('SALES_ORDERS'), isTrue);
    });
  });
}
