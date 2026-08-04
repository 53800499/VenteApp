/// Préférences strictement locales à l'appareil et à l'utilisateur.
///
/// Ces réglages ne doivent JAMAIS être écrasés ou contrôlés par le Back-Office Admin ARIKE.
class AppPreferences {
  const AppPreferences({
    this.themeMode = 'system',
    this.language = 'fr',
    this.fontSizeScale = 1.0,
    this.compactDashboard = false,
    this.bluetoothPrinterMac,
    this.bluetoothPrinterName,
    this.paperWidthMm = 80,
    this.useBiometrics = false,
    this.autoLockSeconds = 300,
  });

  final String themeMode;
  final String language;
  final double fontSizeScale;
  final bool compactDashboard;
  final String? bluetoothPrinterMac;
  final String? bluetoothPrinterName;
  final int paperWidthMm;
  final bool useBiometrics;
  final int autoLockSeconds;

  AppPreferences copyWith({
    String? themeMode,
    String? language,
    double? fontSizeScale,
    bool? compactDashboard,
    String? bluetoothPrinterMac,
    String? bluetoothPrinterName,
    int? paperWidthMm,
    bool? useBiometrics,
    int? autoLockSeconds,
  }) {
    return AppPreferences(
      themeMode: themeMode ?? this.themeMode,
      language: language ?? this.language,
      fontSizeScale: fontSizeScale ?? this.fontSizeScale,
      compactDashboard: compactDashboard ?? this.compactDashboard,
      bluetoothPrinterMac: bluetoothPrinterMac ?? this.bluetoothPrinterMac,
      bluetoothPrinterName: bluetoothPrinterName ?? this.bluetoothPrinterName,
      paperWidthMm: paperWidthMm ?? this.paperWidthMm,
      useBiometrics: useBiometrics ?? this.useBiometrics,
      autoLockSeconds: autoLockSeconds ?? this.autoLockSeconds,
    );
  }

  Map<String, dynamic> toJson() => {
        'themeMode': themeMode,
        'language': language,
        'fontSizeScale': fontSizeScale,
        'compactDashboard': compactDashboard,
        'bluetoothPrinterMac': bluetoothPrinterMac,
        'bluetoothPrinterName': bluetoothPrinterName,
        'paperWidthMm': paperWidthMm,
        'useBiometrics': useBiometrics,
        'autoLockSeconds': autoLockSeconds,
      };

  factory AppPreferences.fromJson(Map<String, dynamic> json) => AppPreferences(
        themeMode: json['themeMode'] as String? ?? 'system',
        language: json['language'] as String? ?? 'fr',
        fontSizeScale: (json['fontSizeScale'] as num?)?.toDouble() ?? 1.0,
        compactDashboard: json['compactDashboard'] as bool? ?? false,
        bluetoothPrinterMac: json['bluetoothPrinterMac'] as String?,
        bluetoothPrinterName: json['bluetoothPrinterName'] as String?,
        paperWidthMm: json['paperWidthMm'] as int? ?? 80,
        useBiometrics: json['useBiometrics'] as bool? ?? false,
        autoLockSeconds: json['autoLockSeconds'] as int? ?? 300,
      );

  static const AppPreferences defaultPreferences = AppPreferences();
}
