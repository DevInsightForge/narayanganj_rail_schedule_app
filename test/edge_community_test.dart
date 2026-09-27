import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:narayanganj_rail_schedule/src/core/api/edge_hmac_client.dart';
import 'package:narayanganj_rail_schedule/src/features/community/data/repositories/edge_community_repository.dart';
import 'package:narayanganj_rail_schedule/src/features/community/domain/entities/community_overlay.dart';
import 'package:narayanganj_rail_schedule/src/features/community/domain/repositories/community_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('EdgeHmacClient', () {
    const testSecret = 'test-mock-secret';
    const baseUrl = 'https://api.test.local';

    test('canonical trip id converts correctly', () {
      expect(
        EdgeHmacClient.toCanonicalTripId(
          directionId: 'dhaka_to_narayanganj',
          trainNo: 2,
        ),
        equals('dhk-ngj-2'),
      );
      expect(
        EdgeHmacClient.toCanonicalTripId(
          directionId: 'narayanganj_to_dhaka',
          trainNo: 1,
        ),
        equals('ngj-dhk-1'),
      );
    });

    test('builds valid HMAC headers with User-Agent and signature', () {
      final client = EdgeHmacClient(baseUrl: baseUrl, appSecret: testSecret);
      final headers = client.buildHeaders(
        method: 'GET',
        pathWithQuery: '/overlay?tripId=dhk-ngj-2',
        customTimestamp: 1774600000,
      );

      expect(headers['User-Agent'], equals('NarayanganjCommuterApp/2.0'));
      expect(headers['Content-Type'], equals('application/json'));
      expect(headers['x-app-timestamp'], equals('1774600000'));
      expect(headers['x-app-signature'], isNotEmpty);
      expect(headers['x-app-signature']!.length, equals(64));
    });
  });

  group('EdgeCommunityRepository', () {
    const testSecret = 'test-secret';
    const baseUrl = 'https://test.local';

    test('fetches overlay successfully', () async {
      final mockHttp = MockClient((request) async {
        expect(request.url.path, equals('/overlay'));
        expect(request.url.queryParameters['tripId'], equals('dhk-ngj-2'));
        return http.Response(
          jsonEncode({
            'tripId': 'dhk-ngj-2',
            'serviceDate': '2026-03-27',
            'delayMinutes': 7,
            'delayStatus': 'minor_delay',
            'freshness': 'live',
            'confidence': {'score': 0.7, 'sampleCount': 2},
            'lastReportedStation': 'fatullah',
            'lastReportedAt': 1774602000,
          }),
          200,
        );
      });

      final hmacClient = EdgeHmacClient(
        baseUrl: baseUrl,
        appSecret: testSecret,
        client: mockHttp,
      );
      final repo = EdgeCommunityRepository(
        client: hmacClient,
        nowProvider: () =>
            DateTime.fromMillisecondsSinceEpoch(1774602060 * 1000),
      );

      final overlay = await repo.fetchOverlay(tripId: 'dhk-ngj-2');
      expect(overlay, isNotNull);
      expect(overlay!.delayMinutes, equals(7));
      expect(overlay.freshnessSeconds, equals(60));
      expect(overlay.freshnessState, equals(CommunityOverlayFreshness.fresh));
    });

    test('handles failure gracefully without throwing', () async {
      final mockHttp = MockClient((request) async {
        return http.Response('Server error', 500);
      });

      final hmacClient = EdgeHmacClient(
        baseUrl: baseUrl,
        appSecret: testSecret,
        client: mockHttp,
      );
      final repo = EdgeCommunityRepository(client: hmacClient);

      final overlay = await repo.fetchOverlay(tripId: 'dhk-ngj-2');
      expect(overlay, isNull);
    });

    test('submits report and receives accepted (202)', () async {
      final mockHttp = MockClient((request) async {
        expect(request.url.path, equals('/reports'));
        final body = jsonDecode(request.body) as Map<String, dynamic>;
        expect(body['tripId'], equals('dhk-ngj-2'));
        expect(body['stationId'], equals('chashara'));
        expect(body['deviceId'], isNotEmpty);
        return http.Response(jsonEncode({'status': 'accepted'}), 202);
      });

      final hmacClient = EdgeHmacClient(
        baseUrl: baseUrl,
        appSecret: testSecret,
        client: mockHttp,
      );
      final repo = EdgeCommunityRepository(client: hmacClient);

      final result = await repo.submitArrivalReport(
        tripId: 'dhk-ngj-2',
        stationId: 'chashara',
      );
      expect(result.status, equals(ArrivalReportResultStatus.accepted));
    });

    test('submits report and receives cooldown (429)', () async {
      final mockHttp = MockClient((request) async {
        return http.Response(
          jsonEncode({'status': 'cooldown', 'retryAfterSeconds': 95}),
          429,
        );
      });

      final hmacClient = EdgeHmacClient(
        baseUrl: baseUrl,
        appSecret: testSecret,
        client: mockHttp,
      );
      final repo = EdgeCommunityRepository(client: hmacClient);

      final result = await repo.submitArrivalReport(
        tripId: 'dhk-ngj-2',
        stationId: 'chashara',
      );
      expect(result.status, equals(ArrivalReportResultStatus.cooldown));
      expect(result.retryAfterSeconds, equals(95));
    });
  });
}
