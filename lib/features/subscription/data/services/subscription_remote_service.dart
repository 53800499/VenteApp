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

  List<Map<String, dynamic>>? _cachedPackages;
  DateTime? _packagesLastFetched;

  List<Map<String, dynamic>>? _cachedOptions;
  DateTime? _optionsLastFetched;

  static const Duration _cacheTtl = Duration(minutes: 15);

  void invalidateCache() {
    _cachedPackages = null;
    _packagesLastFetched = null;
    _cachedOptions = null;
    _optionsLastFetched = null;
  }

  Future<List<Map<String, dynamic>>> fetchPackages({bool forceRefresh = false}) async {
    if (!forceRefresh &&
        _cachedPackages != null &&
        _packagesLastFetched != null &&
        DateTime.now().difference(_packagesLastFetched!) < _cacheTtl) {
      return _cachedPackages!;
    }

    try {
      final response = await _apiClient.get('/subscriptions/packages');
      if (response.statusCode == 200 && response.data != null) {
        final rawData = response.data;
        final list = rawData is Map<String, dynamic> && rawData.containsKey('data')
            ? rawData['data'] as List
            : rawData as List;
        final result = list.cast<Map<String, dynamic>>();
        if (result.isNotEmpty) {
          _cachedPackages = result;
          _packagesLastFetched = DateTime.now();
        }
        return result;
      }
    } catch (_) {}
    return _cachedPackages ?? [];
  }

  Future<List<Map<String, dynamic>>> fetchPaidOptions({bool forceRefresh = false}) async {
    if (!forceRefresh &&
        _cachedOptions != null &&
        _optionsLastFetched != null &&
        DateTime.now().difference(_optionsLastFetched!) < _cacheTtl) {
      return _cachedOptions!;
    }

    try {
      final response = await _apiClient.get('/subscriptions/options');
      if (response.statusCode == 200 && response.data != null) {
        final rawData = response.data;
        final list = rawData is Map<String, dynamic> && rawData.containsKey('data')
            ? rawData['data'] as List
            : rawData as List;
        final result = list.cast<Map<String, dynamic>>();
        if (result.isNotEmpty) {
          _cachedOptions = result;
          _optionsLastFetched = DateTime.now();
        }
        return result;
      }
    } catch (_) {}
    return _cachedOptions ?? [];
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
        invalidateCache();
        final rawData = response.data;
        final map = rawData is Map<String, dynamic> && rawData.containsKey('data')
            ? rawData['data'] as Map<String, dynamic>
            : rawData as Map<String, dynamic>;
        return _mapSubscriptionDetails(map);
      }
    } catch (_) {}
    return null;
  }

  Future<Map<String, dynamic>?> previewSwitch({
    required String targetPlanCode,
    int durationDays = 30,
  }) async {
    try {
      final response = await _apiClient.post(
        '/subscriptions/switch-preview',
        data: {
          'targetPlanCode': targetPlanCode,
          'durationDays': durationDays,
        },
      );
      if (response.statusCode == 200 || response.statusCode == 201) {
        final rawData = response.data;
        return rawData is Map<String, dynamic> && rawData.containsKey('data')
            ? rawData['data'] as Map<String, dynamic>
            : rawData as Map<String, dynamic>;
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
      capabilities: (json['capabilities'] as List?)?.cast<String>() ?? const [],
      maxUsers: json['maxUsers'] ?? 3,
      maxShops: json['maxShops'] ?? 1,
      currentUsersCount: json['currentUsersCount'] ?? 1,
      currentShopsCount: json['currentShopsCount'] ?? 1,
      paymentHistory: (json['paymentHistory'] as List?)
              ?.map((p) => PaymentTransactionRecord(
                    id: p['id'] ?? '',
                    date: p['date'] != null ? DateTime.parse(p['date']) : DateTime.now(),
                    planName: p['planName'] ?? '',
                    planCode: p['planCode'] as String?,
                    amount: (p['amount'] as num?)?.toDouble() ?? 0.0,
                    currency: p['currency'] ?? 'FCFA',
                    provider: p['provider'] ?? 'Mobile Money',
                    reference: p['reference'] as String?,
                    status: p['status'] ?? 'PAYÉ',
                    bonusDays: (p['bonusDays'] as num?)?.toInt() ?? 0,
                    expiresAt: p['expiresAt'] != null ? DateTime.parse(p['expiresAt']) : null,
                  ))
              .toList() ??
          const [],
    );
  }
}

