import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;

class EdgeHmacClient {
  EdgeHmacClient({
    required String baseUrl,
    required this.appSecret,
    http.Client? client,
    this.userAgent = 'NarayanganjCommuterApp/2.0',
    this.timeout = const Duration(seconds: 10),
  }) : baseUrl = baseUrl.endsWith('/')
            ? baseUrl.substring(0, baseUrl.length - 1)
            : baseUrl,
       _client = client ?? http.Client();

  final String baseUrl;
  final String appSecret;
  final String userAgent;
  final Duration timeout;
  final http.Client _client;

  Map<String, String> buildHeaders({
    required String method,
    required String pathWithQuery,
    String body = '',
    int? customTimestamp,
  }) {
    final timestamp = (customTimestamp ??
            (DateTime.now().toUtc().millisecondsSinceEpoch ~/ 1000))
        .toString();
    final canonical =
        '${method.toUpperCase()}\n$pathWithQuery\n$timestamp\n$body';
    final hmac = Hmac(sha256, utf8.encode(appSecret));
    final signature = hmac.convert(utf8.encode(canonical)).toString();

    return {
      'Content-Type': 'application/json',
      'User-Agent': userAgent,
      'x-app-timestamp': timestamp,
      'x-app-signature': signature,
    };
  }

  Future<http.Response> get(String pathWithQuery) async {
    final uri = Uri.parse('$baseUrl$pathWithQuery');
    final headers = buildHeaders(method: 'GET', pathWithQuery: pathWithQuery);
    return _client.get(uri, headers: headers).timeout(timeout);
  }

  Future<http.Response> post(
    String pathWithQuery,
    Map<String, dynamic> jsonBody,
  ) async {
    final uri = Uri.parse('$baseUrl$pathWithQuery');
    final bodyStr = jsonEncode(jsonBody);
    final headers = buildHeaders(
      method: 'POST',
      pathWithQuery: pathWithQuery,
      body: bodyStr,
    );
    return _client
        .post(uri, headers: headers, body: bodyStr)
        .timeout(timeout);
  }

  static String toCanonicalTripId({
    required String directionId,
    required int trainNo,
  }) {
    final prefix =
        directionId == 'dhaka_to_narayanganj' ? 'dhk-ngj' : 'ngj-dhk';
    return '$prefix-$trainNo';
  }

  void close() {
    _client.close();
  }
}
