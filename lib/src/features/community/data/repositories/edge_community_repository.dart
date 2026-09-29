import 'dart:convert';
import 'dart:math';

import 'package:shared_preferences/shared_preferences.dart';

import '../../../../core/api/edge_hmac_client.dart';
import '../../domain/entities/community_overlay.dart';
import '../../domain/entities/freshness.dart';
import '../../domain/repositories/community_repository.dart';

class EdgeCommunityRepository implements CommunityRepository {
  EdgeCommunityRepository({
    required EdgeHmacClient client,
    SharedPreferences? sharedPreferences,
    DateTime Function()? nowProvider,
  }) : _client = client,
       _sharedPreferences = sharedPreferences,
       _nowProvider = nowProvider ?? DateTime.now;

  final EdgeHmacClient _client;
  SharedPreferences? _sharedPreferences;
  final DateTime Function() _nowProvider;
  String? _cachedDeviceId;

  static const _deviceIdKey = 'app_device_id';

  Future<String> _getOrCreateDeviceId() async {
    if (_cachedDeviceId != null) {
      return _cachedDeviceId!;
    }
    _sharedPreferences ??= await SharedPreferences.getInstance();
    var deviceId = _sharedPreferences!.getString(_deviceIdKey);
    if (deviceId == null || deviceId.isEmpty) {
      final random = Random.secure();
      final values = List<int>.generate(16, (_) => random.nextInt(256));
      values[6] = (values[6] & 0x0f) | 0x40;
      values[8] = (values[8] & 0x3f) | 0x80;
      final hex = values.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
      deviceId =
          '${hex.substring(0, 8)}-${hex.substring(8, 12)}-${hex.substring(12, 16)}-${hex.substring(16, 20)}-${hex.substring(20)}';
      await _sharedPreferences!.setString(_deviceIdKey, deviceId);
    }
    _cachedDeviceId = deviceId;
    return deviceId;
  }

  @override
  Future<CommunityOverlay?> fetchOverlay({
    required String tripId,
    required String stationId,
  }) async {
    final now = _nowProvider();
    final path = '/overlay?tripId=$tripId&stationId=$stationId';

    try {
      final response = await _client.get(path);
      if (response.statusCode == 200) {
        final json = jsonDecode(response.body) as Map<String, dynamic>;
        final overlay = CommunityOverlay.fromJson(json);
        if (overlay.freshness == Freshness.scheduled ||
            overlay.confidence.sampleCount == 0 ||
            overlay.lastReportedAt == null) {
          return overlay;
        }
        final nowEpoch = now.millisecondsSinceEpoch ~/ 1000;
        final age = nowEpoch - overlay.lastReportedAt!;
        final freshnessSeconds = age < 0 ? 0 : age;
        return overlay.copyWith(freshnessSeconds: freshnessSeconds);
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  @override
  Future<ArrivalReportResult> submitArrivalReport({
    required String tripId,
    required String stationId,
  }) async {
    try {
      final deviceId = await _getOrCreateDeviceId();
      final payload = <String, dynamic>{
        'tripId': tripId,
        'stationId': stationId,
        'deviceId': deviceId,
      };

      final response = await _client.post('/reports', payload);
      if (response.statusCode == 202) {
        return const ArrivalReportResult.accepted();
      }
      if (response.statusCode == 409) {
        return const ArrivalReportResult.stationCapacityReached();
      }
      if (response.statusCode == 429) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final retryAfter = (data['retryAfterSeconds'] as num?)?.toInt() ?? 120;
        return ArrivalReportResult.cooldown(retryAfterSeconds: retryAfter);
      }
      String? message;
      try {
        final errorData = jsonDecode(response.body) as Map<String, dynamic>;
        message = errorData['error']?.toString();
      } catch (_) {}
      return ArrivalReportResult.error(
        message ?? 'Submission rejected (${response.statusCode})',
      );
    } catch (e) {
      return ArrivalReportResult.error(e.toString());
    }
  }
}
