import 'admin_policy.dart';

/// DTO de synchronisation de configuration retourné par l'endpoint `GET /sync/configuration` de NestJS.
class ConfigurationSyncDto {
  const ConfigurationSyncDto({
    required this.serverTime,
    required this.configurationVersion,
    this.tenantId,
    this.shopId,
    this.license,
    this.organizationSettings,
    this.shopSettings,
    this.adminPolicies = const [],
    this.featureFlags = const [],
  });

  final DateTime serverTime;
  final int configurationVersion;
  final String? tenantId;
  final String? shopId;
  final Map<String, dynamic>? license;
  final Map<String, dynamic>? organizationSettings;
  final Map<String, dynamic>? shopSettings;
  final List<AdminPolicy> adminPolicies;
  final List<Map<String, dynamic>> featureFlags;

  Map<String, dynamic> toJson() => {
        'serverTime': serverTime.toIso8601String(),
        'configurationVersion': configurationVersion,
        'tenantId': tenantId,
        'shopId': shopId,
        'license': license,
        'organizationSettings': organizationSettings,
        'shopSettings': shopSettings,
        'adminPolicies': adminPolicies.map((p) => p.toJson()).toList(),
        'featureFlags': featureFlags,
      };

  factory ConfigurationSyncDto.fromJson(Map<String, dynamic> json) {
    return ConfigurationSyncDto(
      serverTime: json['serverTime'] != null
          ? DateTime.parse(json['serverTime'] as String)
          : DateTime.now(),
      configurationVersion: json['configurationVersion'] as int? ?? 1,
      tenantId: json['tenantId'] as String?,
      shopId: json['shopId'] as String?,
      license: json['license'] as Map<String, dynamic>?,
      organizationSettings: json['organizationSettings'] as Map<String, dynamic>?,
      shopSettings: json['shopSettings'] as Map<String, dynamic>?,
      adminPolicies: (json['adminPolicies'] as List<dynamic>?)
              ?.map((e) => AdminPolicy.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const [],
      featureFlags: (json['featureFlags'] as List<dynamic>?)
              ?.map((e) => e as Map<String, dynamic>)
              .toList() ??
          const [],
    );
  }
}
