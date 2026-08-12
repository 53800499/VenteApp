import '../../../../core/network/api_client.dart';
import '../../domain/entities/subscription_details.dart';

class SubscriptionRemoteService {
  final ApiClient _apiClient;

  SubscriptionRemoteService(this._apiClient);

  Future<SubscriptionDetails?> fetchMySubscription() async {
    try {
      final response = await _apiClient.get('/subscriptions/me');
      if (response.statusCode == 200 && response.data != null) {
        final rawData = response.data;
        final map = rawData is Map<String, dynamic> && rawData.containsKey('data')
            ? rawData['data'] as Map<String, dynamic>
            : rawData as Map<String, dynamic>;
        return _mapSubscriptionDetails(map);
      }
    } catch (_) {
      // Fallback
    }
    return null;
  }

  Future<List<Map<String, dynamic>>> fetchPackages() async {
    try {
      final response = await _apiClient.get('/subscriptions/packages');
      if (response.statusCode == 200 && response.data != null) {
        final rawData = response.data;
        final list = rawData is Map<String, dynamic> && rawData.containsKey('data')
            ? rawData['data'] as List
            : rawData as List;
        return list.cast<Map<String, dynamic>>();
      }
    } catch (_) {}
    return [];
  }

  Future<List<Map<String, dynamic>>> fetchPaidOptions() async {
    try {
      final response = await _apiClient.get('/subscriptions/options');
      if (response.statusCode == 200 && response.data != null) {
        final rawData = response.data;
        final list = rawData is Map<String, dynamic> && rawData.containsKey('data')
            ? rawData['data'] as List
            : rawData as List;
        return list.cast<Map<String, dynamic>>();
      }
    } catch (_) {}
    return [];
  }

  Future<Map<String, dynamic>> fetchOnboardingPolicy() async {
    try {
      final response = await _apiClient.get('/subscriptions/onboarding-policy');
      if (response.statusCode == 200 && response.data != null) {
        final rawData = response.data;
        final map = rawData is Map<String, dynamic> && rawData.containsKey('data')
            ? rawData['data'] as Map<String, dynamic>
            : rawData as Map<String, dynamic>;
        return map;
      }
    } catch (_) {}
    return {
      'planSelectionRequired': true,
      'trialEnabled': true,
      'trialDurationDays': 14,
      'gracePeriodDays': 7,
      'defaultPlanCode': 'ESSENTIEL',
      'allowPlanChangeDuringTrial': true,
    };
  }

  Future<SubscriptionDetails?> subscribe({
    required String planCode,
    int durationDays = 30,
    String? provider,
    String? paymentReference,
    double? amount,
  }) async {
    try {
      final response = await _apiClient.post(
        '/subscriptions/subscribe',
        data: {
          'planCode': planCode,
          'durationDays': durationDays,
          'provider': provider,
          'paymentReference': paymentReference,
          'amount': amount,
        },
      );
      if (response.statusCode == 200 || response.statusCode == 201) {
        final rawData = response.data;
        final map = rawData is Map<String, dynamic> && rawData.containsKey('data')
            ? rawData['data'] as Map<String, dynamic>
            : rawData as Map<String, dynamic>;
        return _mapSubscriptionDetails(map);
      }
    } catch (_) {}
    return null;
  }

  SubscriptionDetails _mapSubscriptionDetails(Map<String, dynamic> json) {
    return SubscriptionDetails(
      planCode: json['planCode'] ?? 'ESSENTIEL',
      planName: json['planName'] ?? 'ARIKE Essentiel',
      status: json['status'] ?? 'ACTIVE',
      startedAt: json['startedAt'] != null ? DateTime.parse(json['startedAt']) : DateTime.now(),
      expiresAt: json['expiresAt'] != null ? DateTime.parse(json['expiresAt']) : DateTime.now().add(const Duration(days: 30)),
      graceUntil: json['graceUntil'] != null ? DateTime.parse(json['graceUntil']) : DateTime.now().add(const Duration(days: 37)),
      autoRenew: json['autoRenew'] == true,
      grantedModules: (json['grantedModules'] as List?)?.cast<String>() ?? const [],
      maxUsers: json['maxUsers'] ?? 3,
      maxShops: json['maxShops'] ?? 1,
      currentUsersCount: json['currentUsersCount'] ?? 1,
      currentShopsCount: json['currentShopsCount'] ?? 1,
      paymentHistory: (json['paymentHistory'] as List?)
              ?.map((p) => PaymentTransactionRecord(
                    id: p['id'] ?? '',
                    date: p['date'] != null ? DateTime.parse(p['date']) : DateTime.now(),
                    planName: p['planName'] ?? '',
                    amount: (p['amount'] as num?)?.toDouble() ?? 0.0,
                    currency: p['currency'] ?? 'FCFA',
                    provider: p['provider'] ?? 'Mobile Money',
                    status: p['status'] ?? 'PAYÉ',
                  ))
              .toList() ??
          const [],
    );
  }
}
