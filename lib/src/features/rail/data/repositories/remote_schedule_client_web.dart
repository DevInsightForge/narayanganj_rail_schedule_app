import 'dart:convert';
import 'dart:js_interop';

import 'package:web/web.dart' as web;

import 'remote_schedule_client.dart';

class RemoteScheduleClientImpl implements RemoteScheduleClient {
  @override
  Future<RemoteJsonResponse> getJson(String url) async {
    final response = await web.window
        .fetch(
          url.toJS,
          web.RequestInit(
            method: 'GET',
            mode: 'cors',
            credentials: 'omit',
            cache: 'no-store',
          ),
        )
        .toDart
        .timeout(const Duration(seconds: 10));

    Map<String, dynamic>? document;
    if (response.ok) {
      final text = (await response.text().toDart.timeout(
        const Duration(seconds: 10),
      )).toDart;
      final jsonValue = jsonDecode(text);
      if (jsonValue is Map<String, dynamic>) {
        document = jsonValue;
      }
    }

    return RemoteJsonResponse(
      statusCode: response.status.toInt(),
      json: document,
    );
  }
}
