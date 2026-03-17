import 'dart:convert';

import 'package:http/http.dart' as http;

import 'remote_schedule_client.dart';

class RemoteScheduleClientImpl implements RemoteScheduleClient {
  RemoteScheduleClientImpl({http.Client? client})
    : _client = client ?? http.Client();

  final http.Client _client;

  @override
  Future<Map<String, dynamic>?> getJson(String url) async {
    final response = await _client
        .get(Uri.parse(url))
        .timeout(const Duration(seconds: 10));

    if (response.statusCode < 200 || response.statusCode >= 300) {
      return null;
    }

    final jsonValue = jsonDecode(response.body);

    if (jsonValue is! Map<String, dynamic>) {
      return null;
    }

    return jsonValue;
  }
}
