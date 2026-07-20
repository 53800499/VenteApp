import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../app/di/injection_container.dart';
import '../../../../core/sync/sync_policy.dart';
import '../../../../core/sync/sync_service.dart';
import '../../../auth/domain/entities/auth_entities.dart';
import '../../domain/repositories/stock_transfer_repository.dart';
import '../bloc/stock_transfer_bloc.dart';
import '../pages/stock_transfer_detail_page.dart';
import '../pages/stock_transfer_page.dart';

Future<T?> openStockTransferPage<T>(
  BuildContext context,
  AuthSession session,
) {
  ensureStockTransferDependencies();

  return Navigator.of(context).push<T>(
    MaterialPageRoute(
      builder: (_) => const StockTransferPage(),
    ),
  );
}

Future<T?> openStockTransferDetailPage<T>(
  BuildContext context,
  AuthSession session, {
  required int transferId,
  Map<int, int>? initialReceiveQuantities,
  int? initialShipmentId,
}) {
  ensureStockTransferDependencies();

  return Navigator.of(context).push<T>(
    MaterialPageRoute(
      builder: (_) => BlocProvider(
        create: (_) => StockTransferBloc(
          repository: sl<StockTransferRepository>(),
          session: session,
          syncPolicy: sl<SyncPolicy>(),
          syncService: sl<SyncService>(),
        )..add(StockTransferDetailLoadRequested(transferId)),
        child: StockTransferDetailPage(
          transferId: transferId,
          initialReceiveQuantities: initialReceiveQuantities,
          initialShipmentId: initialShipmentId,
        ),
      ),
    ),
  );
}
