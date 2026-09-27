import '../config/runtime_env.dart';

class ApiConfig {
  const ApiConfig({
    required this.baseUrl,
    required this.enabled,
    this.apiSecret,
    this.timeout = const Duration(seconds: 10),
  });

  factory ApiConfig.fromEnv({String? Function(String key)? envReader}) {
    final reader = envReader ?? readRuntimeEnv;
    final enabledRaw = reader('COMMUNITY_API_ENABLED')?.trim().toLowerCase();
    final enabled = enabledRaw != 'false';
    final rawBaseUrl = reader('COMMUNITY_API_BASE_URL')?.trim();
    final baseUrl = (rawBaseUrl != null && rawBaseUrl.isNotEmpty)
        ? rawBaseUrl
        : '';
    final rawSecret = reader('COMMUNITY_API_SECRET')?.trim();
    final apiSecret = (rawSecret != null && rawSecret.isNotEmpty)
        ? rawSecret
        : null;

    return ApiConfig(baseUrl: baseUrl, enabled: enabled, apiSecret: apiSecret);
  }

  final String baseUrl;
  final bool enabled;
  final String? apiSecret;
  final Duration timeout;

  bool get isValid =>
      enabled &&
      baseUrl.isNotEmpty &&
      apiSecret != null &&
      apiSecret!.isNotEmpty;
}
