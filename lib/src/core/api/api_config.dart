import '../config/runtime_env.dart';

class ApiConfig {
  const ApiConfig({
    required this.baseUrl,
    required this.enabled,
    this.apiKey,
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
    final rawApiKey =
        (reader('COMMUNITY_API_KEY') ?? reader('SUPABASE_ANON_KEY'))?.trim();
    final apiKey = (rawApiKey != null && rawApiKey.isNotEmpty)
        ? rawApiKey
        : null;

    return ApiConfig(baseUrl: baseUrl, enabled: enabled, apiKey: apiKey);
  }

  final String baseUrl;
  final bool enabled;
  final String? apiKey;
  final Duration timeout;
}
