import 'package:dio/dio.dart';

import '../../../../../core/errors/exception_mapper.dart';
import '../../../../../core/errors/failures.dart';
import '../../../../../core/network/api_client.dart';
import '../../../domain/entities/customer_entities.dart';
import '../../models/customer_api_models.dart';

class CustomersRemoteDatasource {
  CustomersRemoteDatasource(this._client);

  final ApiClient _client;

  Future<List<CustomerApiDto>> listCustomers({
    String search = '',
    bool includeArchived = false,
    bool? hasDebt,
    CustomerSort sort = CustomerSort.name,
  }) async {
    final sortParam = switch (sort) {
      CustomerSort.name => 'name',
      CustomerSort.debt => 'debt',
      CustomerSort.lastActivity => 'lastActivity',
    };

    final data = await _getData(
      '/customers',
      query: {
        if (search.trim().isNotEmpty) 'search': search.trim(),
        if (includeArchived) 'includeArchived': 'true',
        if (hasDebt == true) 'hasDebt': 'true',
        'sort': sortParam,
      },
    );

    final items = data['items'] ?? data['customers'] ?? data;
    if (items is List) {
      return items
          .whereType<Map<String, dynamic>>()
          .map(CustomerApiDto.fromJson)
          .toList();
    }
    return [];
  }

  Future<CustomerDetailApiDto> getCustomer(int id) async {
    final data = await _getData('/customers/$id');
    return CustomerDetailApiDto.fromJson(data);
  }

  Future<List<CustomerSaleApiDto>> listCustomerSales(int customerId) async {
    final data = await _getData('/customers/$customerId/sales');
    final items = data['items'] ?? data['sales'];
    if (items is List) {
      return items
          .whereType<Map<String, dynamic>>()
          .map(CustomerSaleApiDto.fromJson)
          .toList();
    }
    return [];
  }

  Future<DebtorsApiDto> listDebtors() async {
    final data = await _getData('/customers/debtors');
    return DebtorsApiDto.fromJson(data);
  }

  Future<DebtReminderApiDto> getDebtReminder(int customerId) async {
    final data = await _getData('/customers/$customerId/debt-reminder');
    return DebtReminderApiDto.fromJson(data);
  }

  Future<CustomerApiDto> createCustomer({
    required String name,
    String? phone,
    String? address,
    String? note,
    bool isShared = false,
  }) async {
    final data = await _postData(
      '/customers',
      {
        'name': name,
        if (phone != null && phone.isNotEmpty) 'phone': phone,
        if (address != null && address.isNotEmpty) 'address': address,
        if (note != null && note.isNotEmpty) 'note': note,
        if (isShared) 'isShared': isShared,
      },
    );
    return CustomerApiDto.fromJson(data);
  }

  Future<CustomerApiDto> updateCustomer(
    int id, {
    String? name,
    String? phone,
    String? address,
    String? note,
    bool? isShared,
  }) async {
    final body = <String, dynamic>{};
    if (name != null) body['name'] = name;
    if (phone != null) body['phone'] = phone;
    if (address != null) body['address'] = address;
    if (note != null) body['note'] = note;
    if (isShared != null) body['isShared'] = isShared;

    final data = await _patchData('/customers/$id', body);
    return CustomerApiDto.fromJson(data);
  }

  Future<void> archiveCustomer(int id) async {
    await _patchData('/customers/$id/archive', {});
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
