import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:narayanganj_rail_schedule/src/features/community/data/mappers/http_community_mapper.dart';
import 'package:narayanganj_rail_schedule/src/features/community/data/repositories/supabase/supabase_arrival_report_repository.dart';
import 'package:narayanganj_rail_schedule/src/features/community/data/repositories/supabase/supabase_community_overlay_repository.dart';
import 'package:narayanganj_rail_schedule/src/features/community/domain/entities/arrival_report.dart';
import 'package:narayanganj_rail_schedule/src/features/community/domain/entities/arrival_report_submission.dart';
import 'package:narayanganj_rail_schedule/src/features/community/domain/entities/delay_status.dart';
import 'package:narayanganj_rail_schedule/src/features/community/domain/entities/train_session.dart';
import 'package:narayanganj_rail_schedule/src/features/community/domain/repositories/arrival_report_repository.dart';

void main() {
  group('HttpCommunityMapper', () {
    const mapper = HttpCommunityMapper();

    test('maps raw JSON to SessionStatusSnapshot', () {
      final json = {
        'sessionId': 'session-123',
        'status': 'delayed',
        'delayMinutes': 10,
        'confidence': {'score': 0.85, 'sampleSize': 3, 'freshnessSeconds': 45},
        'updatedAt': '2026-08-26T10:00:00.000Z',
        'stations': {
          'dhaka': {'delayMinutes': 0, 'reportCount': 1},
          'chashara': {'delayMinutes': 10, 'reportCount': 2},
        },
      };

      final snapshot = mapper.toSessionStatusSnapshot(json);
      expect(snapshot, isNotNull);
      expect(snapshot!.sessionId, equals('session-123'));
      expect(snapshot.delayMinutes, equals(10));
      expect(snapshot.delayStatus, equals(DelayStatus.late));
      expect(snapshot.confidence.score, equals(0.85));
      expect(snapshot.confidence.sampleSize, equals(3));
      expect(snapshot.freshnessSeconds, equals(45));
    });

    test('maps snake_case Supabase PostgREST row to SessionStatusSnapshot', () {
      final json = {
        'session_id': 'session-456',
        'status': 'onTime',
        'delay_minutes': 0,
        'confidence': 0.95,
        'sample_size': 4,
        'freshness_seconds': 15,
        'updated_at': '2026-08-26T10:00:00.000Z',
        'station_buckets': {
          'dhaka': {'delay_minutes': 0, 'report_count': 2},
        },
      };

      final snapshot = mapper.toSessionStatusSnapshot(json);
      expect(snapshot, isNotNull);
      expect(snapshot!.sessionId, equals('session-456'));
      expect(snapshot.delayMinutes, equals(0));
      expect(snapshot.delayStatus, equals(DelayStatus.onTime));
      expect(snapshot.confidence.score, equals(0.95));
      expect(snapshot.freshnessSeconds, equals(15));
    });

    test('maps raw JSON to CommunitySessionAggregate', () {
      final json = {
        'sessionId': 'session-123',
        'routeId': 'narayanganj_line',
        'serviceDate': '2026-08-26',
        'status': 'delayed',
        'delayMinutes': 12,
        'confidence': 0.75,
        'freshnessSeconds': 30,
        'updatedAt': '2026-08-26T10:00:00.000Z',
        'stations': {
          'chashara': {
            'delayMinutes': 12,
            'reportCount': 2,
            'updatedAt': '2026-08-26T10:00:00.000Z',
          },
        },
      };

      final aggregate = mapper.toCommunitySessionAggregate(
        json: json,
        directionId: 'dhaka_to_narayanganj',
        trainNo: 2,
      );

      expect(aggregate.sessionId, equals('session-123'));
      expect(aggregate.delayMinutes, equals(12));
      expect(aggregate.delayStatus, equals(DelayStatus.late));
      expect(aggregate.stationBuckets.length, equals(1));
      expect(aggregate.stationBuckets.first.stationId, equals('chashara'));
      expect(aggregate.stationBuckets.first.delayMinutes, equals(12));
      expect(aggregate.stationBuckets.first.submissionCount, equals(2));
    });
  });

  group('SupabaseCommunityOverlayRepository', () {
    test('fetches session overlay from PostgREST session_snapshots', () async {
      final mockClient = MockClient((request) async {
        expect(request.url.path, contains('/rest/v1/session_snapshots'));
        expect(request.url.queryParameters['session_id'], equals('eq.s-1'));
        return http.Response(
          jsonEncode([
            {
              'session_id': 's-1',
              'status': 'onTime',
              'delay_minutes': 0,
              'confidence': 0.9,
              'freshness_seconds': 10,
              'updated_at': '2026-08-26T12:00:00.000Z',
              'station_buckets': {},
            },
          ]),
          200,
          headers: {'content-type': 'application/json'},
          request: request,
        );
      });

      final supabaseClient = SupabaseClient(
        'https://api.test.local',
        'anon-key',
        httpClient: mockClient,
      );

      final repo = SupabaseCommunityOverlayRepository(client: supabaseClient);
      final result = await repo.fetchSessionOverlay(
        sessionId: 's-1',
        serviceDate: DateTime(2026, 8, 26),
      );

      expect(result.sessionStatusSnapshot, isNotNull);
      expect(result.sessionStatusSnapshot!.sessionId, equals('s-1'));
      expect(result.sessionStatusSnapshot!.delayMinutes, equals(0));
    });
  });

  group('SupabaseArrivalReportRepository', () {
    test(
      'submits report via PostgREST RPC and maps aggregate response',
      () async {
        final mockClient = MockClient((request) async {
          expect(
            request.url.path,
            contains('/rest/v1/rpc/submit_arrival_report'),
          );
          return http.Response(
            jsonEncode({
              'sessionId': 's-1',
              'routeId': 'narayanganj_line',
              'serviceDate': '2026-08-26',
              'status': 'delayed',
              'delayMinutes': 5,
              'confidence': 0.8,
              'freshnessSeconds': 0,
              'updatedAt': '2026-08-26T12:00:00.000Z',
              'stations': {
                'chashara': {
                  'status': 'delayed',
                  'delayMinutes': 5,
                  'reportCount': 1,
                  'updatedAt': '2026-08-26T12:00:00.000Z',
                },
              },
            }),
            200,
            headers: {'content-type': 'application/json'},
            request: request,
          );
        });

        final supabaseClient = SupabaseClient(
          'https://api.test.local',
          'anon-key',
          httpClient: mockClient,
        );

        final session = TrainSession(
          sessionId: 's-1',
          templateId: 't-1',
          routeId: 'narayanganj_line',
          directionId: 'dhaka_to_narayanganj',
          trainNo: 2,
          serviceDate: DateTime(2026, 8, 26),
          stops: [
            SessionStop(
              stationId: 'chashara',
              stationName: 'Chashara',
              sequence: 5,
              scheduledAt: DateTime(2026, 8, 26, 12, 0),
            ),
          ],
        );
        final report = ArrivalReport(
          reportId: 'rep-1',
          sessionId: 's-1',
          stationId: 'chashara',
          deviceId: 'dev_12345678',
          observedArrivalAt: DateTime(2026, 8, 26, 12, 5),
          submittedAt: DateTime(2026, 8, 26, 12, 5),
        );

        final repo = SupabaseArrivalReportRepository(client: supabaseClient);
        final aggregate = await repo.submitArrivalReport(
          ArrivalReportSubmission(
            report: report,
            session: session,
            stationStop: session.stops.first,
          ),
        );

        expect(aggregate.sessionId, equals('s-1'));
        expect(aggregate.delayMinutes, equals(5));
        expect(aggregate.stationBuckets.first.stationId, equals('chashara'));
      },
    );

    test('maps P0430 capacity reached error to domain exception', () async {
      final mockClient = MockClient((request) async {
        return http.Response(
          jsonEncode({
            'code': 'P0430',
            'details': null,
            'hint': null,
            'message': 'STATION_CAPACITY_REACHED: Maximum reports reached',
          }),
          400,
          headers: {'content-type': 'application/json'},
          request: request,
        );
      });

      final supabaseClient = SupabaseClient(
        'https://api.test.local',
        'anon-key',
        httpClient: mockClient,
      );

      final session = TrainSession(
        sessionId: 's-1',
        templateId: 't-1',
        routeId: 'narayanganj_line',
        directionId: 'dhaka_to_narayanganj',
        trainNo: 2,
        serviceDate: DateTime(2026, 8, 26),
        stops: [
          SessionStop(
            stationId: 'chashara',
            stationName: 'Chashara',
            sequence: 5,
            scheduledAt: DateTime(2026, 8, 26, 12, 0),
          ),
        ],
      );
      final report = ArrivalReport(
        reportId: 'rep-1',
        sessionId: 's-1',
        stationId: 'chashara',
        deviceId: 'dev_12345678',
        observedArrivalAt: DateTime(2026, 8, 26, 12, 5),
        submittedAt: DateTime(2026, 8, 26, 12, 5),
      );

      final repo = SupabaseArrivalReportRepository(client: supabaseClient);

      expect(
        () => repo.submitArrivalReport(
          ArrivalReportSubmission(
            report: report,
            session: session,
            stationStop: session.stops.first,
          ),
        ),
        throwsA(
          isA<ArrivalReportRepositoryException>().having(
            (e) => e.code,
            'code',
            ArrivalReportRepositoryErrorCode.stationCapacityReached,
          ),
        ),
      );
    });
  });
}
