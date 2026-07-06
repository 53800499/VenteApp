import 'package:flutter_test/flutter_test.dart';
import 'package:venteapp/core/database/app_database.dart';
import 'package:venteapp/core/shop/shop_hierarchy.dart';

void main() {
  group('ShopHierarchy', () {
    final shops = [
      Shop(
        id: 1,
        name: 'Principale',
        address: null,
        phone: null,
        ownerUserId: 10,
        isActive: true,
        isDefault: true,
        parentShopId: null,
        createdAt: 1000,
        serverId: '1',
        syncedAt: null,
      ),
      Shop(
        id: 2,
        name: 'Annexe',
        address: null,
        phone: null,
        ownerUserId: 10,
        isActive: true,
        isDefault: false,
        parentShopId: 1,
        createdAt: 2000,
        serverId: '2',
        syncedAt: null,
      ),
      Shop(
        id: 3,
        name: 'Autre réseau',
        address: null,
        phone: null,
        ownerUserId: 10,
        isActive: true,
        isDefault: false,
        parentShopId: null,
        createdAt: 3000,
        serverId: '3',
        syncedAt: null,
      ),
    ];

    test('retourne uniquement le réseau de la boutique active', () {
      expect(ShopHierarchy.groupShopIds(shops, 2), [1, 2]);
    });

    test('isole les réseaux indépendants', () {
      expect(ShopHierarchy.groupShopIds(shops, 3), [3]);
    });
  });
}
