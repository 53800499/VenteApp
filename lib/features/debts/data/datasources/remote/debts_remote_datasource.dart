import 'package:dio/dio.dart';

import '../../../../../core/errors/exception_mapper.dart';
import '../../../../../core/errors/failures.dart';
import '../../../../../core/network/api_client.dart';
import '../../models/debt_api_models.dart';

class DebtsRemoteDatasource {
  DebtsRemoteDatasource(this._client);

  final ApiClient _client;

  Future<List<DebtApiDto>> listDebts({
    int? customerId,
    String? status,
    bool criticalOnly = false,
  }) async {
    final data = await _getData(
      '/debts',
      query: {
        if (customerId != null) 'customerId': '$customerId',
        if (status != null) 'status': status,
        if (criticalOnly) 'criticalOnly': 'true',
      },
    );

    final items = data['items'] ?? data;
    if (items is List) {
      return items
          .whereType<Map<String, dynamic>>()
          .map(DebtApiDto.fromJson)
          .toList();
    }
    return [];
  }

  Future<DebtApiDto> getDebt(int id) async {
    final data = await _getData('/debts/$id');
    return DebtApiDto.fromJson(data);
  }

  Future<DebtPaymentResultApiDto> recordPayment(
    int debtId, {
    required int amount,
    required String method,
    String? reference,
    int? amountTendered,
    String? note,
  }) async {
    final body = <String, dynamic>{
      'amount': amount,
      'method': method,
      if (reference != null && reference.isNotEmpty) 'reference': reference,
      if (amountTendered != null) 'amountTendered': amountTendered,
      if (note != null && note.isNotEmpty) 'note': note,
    };

    final data = await _postData('/debts/$debtId/payments', body);
    return DebtPaymentResultApiDto.fromJson(data);
  }

  Future<ForgiveDebtApiDto> forgiveDebt(
    int debtId, {
    required String reason,
  }) async {
    final data = await _patchData(
      '/debts/$debtId/forgive',
      {'reason': reason},
    );
    return ForgiveDebtApiDto.fromJson(data);
  }

  Future<Map<String, dynamic>> _getData(
    String path, {
    Map<String, String>? query,
  }) async {
    try {
      final response = await _client.get<Map<String, dynamic>>(
        path,
        queryParameters: query,
      );
      return _unwrap(response.data);
    } on DioException catch (error) {
      throw mapDioException(error);
    }
  }

  Future<Map<String, dynamic>> _postData(
    String path,
    Map<String, dynamic> body,
  ) async {
    try {
      final response =
          await _client.post<Map<String, dynamic>>(path, data: body);
      return _unwrap(response.data);
    } on DioException catch (error) {
      throw mapDioException(error);
    }
  }

  Future<Map<String, dynamic>> _patchData(
    String path,
    Map<String, dynamic> body,
  ) async {
    try {
      final response =
          await _client.patch<Map<String, dynamic>>(path, data: body);
      return _unwrap(response.data);
    } on DioException catch (error) {
      throw mapDioException(error);
    }
  }

  Map<String, dynamic> _unwrap(Map<String, dynamic>? payload) {
    if (payload == null) {
      throw const NetworkFailure('Réponse serveur vide.');
    }
    if (payload['success'] == true && payload['data'] is Map<String, dynamic>) {
      return payload['data'] as Map<String, dynamic>;
    }
    if (payload['success'] == true && payload['data'] is List) {
      return {'items': payload['data']};
    }
    if (payload['data'] is Map<String, dynamic>) {
      return payload['data'] as Map<String, dynamic>;
    }
    if (payload['data'] is List) {
      return {'items': payload['data']};
    }
    return payload;
  }
}
