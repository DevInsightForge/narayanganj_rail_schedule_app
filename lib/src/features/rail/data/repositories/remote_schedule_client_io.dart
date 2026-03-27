import 'dart:convert';

import 'package:http/http.dart' as http;

import 'remote_schedule_client.dart';

class RemoteScheduleClientImpl implements RemoteScheduleClient {
  RemoteScheduleClientImpl({http.Client? client})
    : _client = client ?? http.Client();

  final http.Client _client;

  @override
  Future<RemoteJsonResponse> getJson(String url) async {
    final response = await _client
        .get(
          Uri.parse(url),
          headers: const {
            'Accept': 'application/json',
            'Cache-Control': 'no-cache, no-store, max-age=0',
            'Pragma': 'no-cache',
          },
        )
        .timeout(const Duration(seconds: 10));

    Map<String, dynamic>? document;
    if (response.statusCode >= 200 && response.statusCode < 300) {
      final decoded = jsonDecode(response.body);
      if (decoded is Map<String, dynamic>) {
        document = decoded;
      }
    }

    return RemoteJsonResponse(statusCode: response.statusCode, json: document);
  }
}
