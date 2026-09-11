class ApiConstants {
  static const String productionUrl = 'https://backend-tau-puce-j0499ijf6d.vercel.app';

  static String get baseUrl {
    const fromEnv = String.fromEnvironment('API_BASE_URL');
    if (fromEnv.isNotEmpty) return fromEnv;

    // Use live Vercel production server so mobile works globally on Wi-Fi and mobile data!
    return productionUrl;
  }

  static String get verificationBaseUrl {
    const fromEnv = String.fromEnvironment('VERIFY_BASE_URL');
    if (fromEnv.isNotEmpty) return fromEnv;
    return '$baseUrl/verify';
  }

  // Endpoints
  static const String invoices = '/api/invoices';
  static const String deliveryNotes = '/api/delivery-notes';
  static const String analytics = '/api/analytics';
  static const String copilotChat = '/api/copilot/chat';
  static const String copilotConfig = '/api/copilot/config';
  static const String copilotTest = '/api/copilot/test';
  static const String copilotUndo = '/api/copilot/undo';
  static const String appVersion = '/api/version';
  static const String githubReleasesLatest =
      'https://api.github.com/repos/Clinton-Gilly/Selisco-Invoice-APP/releases/latest';

  static String invoiceDetail(String id) => '/api/invoices/$id';
  static String convertInvoice(String id) => '/api/invoices/$id/convert';
  static String deliveryNoteDetail(String id) => '/api/delivery-notes/$id';
}
