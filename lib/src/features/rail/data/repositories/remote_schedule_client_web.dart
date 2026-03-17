import 'dart:convert';
import 'dart:js_interop';

import 'package:web/web.dart' as web;

import 'remote_schedule_client.dart';

class RemoteScheduleClientImpl implements RemoteScheduleClient {
  @override
  Future<Map<String, dynamic>?> getJson(String url) async {
    final response = await web.window
        .fetch(
          url.toJS,
          web.RequestInit(method: 'GET', mode: 'cors', credentials: 'omit'),
        )
        .toDart
        .timeout(const Duration(seconds: 10));

    if (!response.ok) {
      return null;
    }

    final text = (await response.text().toDart.timeout(
      const Duration(seconds: 10),
    )).toDart;
    final jsonValue = jsonDecode(text);

    if (jsonValue is! Map<String, dynamic>) {
      return null;
    }

    return jsonValue;
  }
}
