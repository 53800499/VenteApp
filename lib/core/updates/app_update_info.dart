class AppUpdateInfo {
  const AppUpdateInfo({
    required this.platform,
    required this.latestVersion,
    required this.latestBuild,
    required this.minimumSupportedBuild,
    required this.downloadUrl,
    this.checksumSha256,
    this.fileSizeBytes,
    required this.forceUpdate,
    this.releaseNotes,
    required this.publishedAt,
  });

  final String platform;
  final String latestVersion;
  final int latestBuild;
  final int minimumSupportedBuild;
  final String downloadUrl;
  final String? checksumSha256;
  final int? fileSizeBytes;
  final bool forceUpdate;
  final String? releaseNotes;
  final String publishedAt;

  factory AppUpdateInfo.fromJson(Map<String, dynamic> json) {
    return AppUpdateInfo(
      platform: json['platform'] as String? ?? 'ANDROID',
      latestVersion: json['latestVersion'] as String? ?? '1.0.0',
      latestBuild: json['latestBuild'] as int? ?? 1,
      minimumSupportedBuild: json['minimumSupportedBuild'] as int? ?? 1,
      downloadUrl: json['downloadUrl'] as String? ?? '',
      checksumSha256: json['checksumSha256'] as String?,
      fileSizeBytes: json['fileSizeBytes'] as int?,
      forceUpdate: json['forceUpdate'] as bool? ?? false,
      releaseNotes: json['releaseNotes'] as String?,
      publishedAt: json['publishedAt'] as String? ?? '',
    );
  }
}

