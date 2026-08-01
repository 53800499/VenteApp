import '../../../../core/network/api_client.dart';

class FedaPayInitializeResult {
  const FedaPayInitializeResult({
    required this.success,
    this.transactionId,
    this.token,
    this.checkoutUrl,
    required this.message,
  });

  final bool success;
  final int? transactionId;
  final String? token;
  final String? checkoutUrl;
  final String message;

  factory FedaPayInitializeResult.fromJson(Map<String, dynamic> json) {
    final data = json['data'] as Map<String, dynamic>? ?? json;
    return FedaPayInitializeResult(
      success: data['success'] as bool? ?? true,
      transactionId: data['transactionId'] as int?,
      token: data['token'] as String?,
      checkoutUrl: data['checkoutUrl'] as String?,
      message: data['message'] as String? ?? 'Paiement initialisé',
    );
  }
}

class FedaPayRemoteService {
  const FedaPayRemoteService({required ApiClient client}) : _client = client;

  final ApiClient _client;

  /// Initialiser un paiement FedaPay via le backend NestJS
  Future<FedaPayInitializeResult> initializePayment({
    required double amount,
    required String description,
    String? phoneNumber,
    String? mode, // 'mtn', 'moov', 'celtiis', 'card'
    String? planCode,
    int? durationDays,
    String? addonCode,
  }) async {
    try {
      final res = await _client.post(
        '/payments/fedapay/initialize',
        data: {
          'amount': amount,
          'description': description,
          'phoneNumber': phoneNumber,
          'mode': mode,
          'planCode': planCode,
          'durationDays': durationDays,
          'addonCode': addonCode,
        },
      );
      return FedaPayInitializeResult.fromJson(res.data as Map<String, dynamic>);
    } catch (e) {
      return FedaPayInitializeResult(
        success: false,
        message: 'Impossible de joindre le serveur de paiement FedaPay : $e',
      );
    }
  }

  /// Vérifier l'état en direct de la transaction FedaPay
  Future<String> checkTransactionStatus(int transactionId) async {
    try {
      final res = await _client.get('/payments/fedapay/status/$transactionId');
      final data = res.data as Map<String, dynamic>;
      final inner = data['data'] as Map<String, dynamic>? ?? data;
      return inner['status'] as String? ?? 'pending';
    } catch (_) {
      return 'pending';
    }
  }
}
