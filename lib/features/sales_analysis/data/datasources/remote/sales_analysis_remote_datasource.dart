import 'package:dio/dio.dart';

import '../../../../../core/errors/exception_mapper.dart';
import '../../../../../core/errors/failures.dart';
import '../../../../../core/network/api_client.dart';
import '../../../../../core/utils/benin_period_range.dart';
import '../../models/sales_analysis_api_models.dart';

class SalesAnalysisRemoteDatasource {
  SalesAnalysisRemoteDatasource(this._client);

  final ApiClient _client;

  Future<SalesAnalysisApiDto> fetchAnalysis({
    required ReportPeriodPreset period,
    int? from,
    int? to,
    int marginTopLimit = 15,
  }) async {
    final data = await _getData(
      '/sales-analysis',
      query: {
        'period': period.name,
        if (period == ReportPeriodPreset.custom && from != null) 'from': '$from',
        if (period == ReportPeriodPreset.custom && to != null) 'to': '$to',
        'marginTopLimit': '$marginTopLimit',
      },
    );
    return SalesAnalysisApiDto.fromJson(data);
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

  Map<String, dynamic> _unwrap(Map<String, dynamic>? payload) {
    if (payload == null) {
      throw const NetworkFailure('Réponse serveur vide.');
    }
    if (payload['success'] == true && payload['data'] is Map<String, dynamic>) {
      return payload['data'] as Map<String, dynamic>;
    }
    if (payload['data'] is Map<String, dynamic>) {
      return payload['data'] as Map<String, dynamic>;
    }
    return payload;
  }
}
