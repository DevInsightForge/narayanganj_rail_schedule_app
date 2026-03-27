class RemoteJsonResponse {
  const RemoteJsonResponse({required this.statusCode, required this.json});

  final int statusCode;
  final Map<String, dynamic>? json;
}

abstract class RemoteScheduleClient {
  Future<RemoteJsonResponse> getJson(String url);
}
