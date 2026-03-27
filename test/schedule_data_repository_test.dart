import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:narayanganj_rail_schedule/src/features/rail/data/models/rail_schedule_document_parser.dart';
import 'package:narayanganj_rail_schedule/src/features/rail/data/repositories/remote_schedule_client.dart';
import 'package:narayanganj_rail_schedule/src/features/rail/data/repositories/schedule_data_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('ScheduleDataRepository loader', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('loads schedule through direct website API path', () async {
      final scheduleUrl = Uri.parse(
        ScheduleDataRepository.defaultWebsiteBaseUrl,
      ).resolve(ScheduleDataRepository.scheduleEndpointPath).toString();
      final remoteDocument = _validScheduleDocument(version: 'direct-remote');

      final client = _FakeRemoteClient(
        responses: {
          scheduleUrl: [
            RemoteJsonResponse(statusCode: 200, json: remoteDocument),
          ],
        },
      );

      final repository = ScheduleDataRepository(
        parser: RailScheduleDocumentParser(),
        remoteClient: client,
      );

      final result = await repository.fetchRemoteSchedule();

      expect(result, isNotNull);
      expect(result?.source, equals(ScheduleDataSource.remote));
      expect(result?.schedule.version, equals('direct-remote'));
      expect(client.requestedUrls, equals([scheduleUrl]));

      final preferences = await SharedPreferences.getInstance();
      final rawCache = preferences.getString(ScheduleDataRepository.storageKey);
      expect(rawCache, isNotNull);
      final wrapped = jsonDecode(rawCache!) as Map<String, dynamic>;
      expect(wrapped['sourceUrl'], equals(scheduleUrl));
      expect(wrapped['schemaVersion'], equals('direct-remote'));
    });

    test('returns null when direct schedule request fails', () async {
      final scheduleUrl = Uri.parse(
        ScheduleDataRepository.defaultWebsiteBaseUrl,
      ).resolve(ScheduleDataRepository.scheduleEndpointPath).toString();

      final client = _FakeRemoteClient(
        responses: {
          scheduleUrl: const [
            RemoteJsonResponse(statusCode: 503, json: null),
            RemoteJsonResponse(statusCode: 503, json: null),
          ],
        },
      );

      final repository = ScheduleDataRepository(
        parser: RailScheduleDocumentParser(),
        remoteClient: client,
      );

      final result = await repository.fetchRemoteSchedule();

      expect(result, isNull);
      expect(client.requestedUrls.contains(scheduleUrl), isTrue);
    });

    test(
      'keeps previous cached schedule when remote schema is invalid',
      () async {
        final cachedDocument = _validScheduleDocument(version: 'cached-v1');
        final cachedPayload = jsonEncode({
          'fetchedAt': DateTime(2026, 3, 27, 8).toUtc().toIso8601String(),
          'sourceUrl': 'https://cached.example/schedule-data.json',
          'schemaVersion': 'cached-v1',
          'checksum': '',
          'document': cachedDocument,
        });

        SharedPreferences.setMockInitialValues({
          ScheduleDataRepository.storageKey: cachedPayload,
        });

        final scheduleUrl = Uri.parse(
          ScheduleDataRepository.defaultWebsiteBaseUrl,
        ).resolve(ScheduleDataRepository.scheduleEndpointPath).toString();
        final client = _FakeRemoteClient(
          responses: {
            scheduleUrl: const [
              RemoteJsonResponse(statusCode: 200, json: {'invalid': true}),
            ],
          },
        );

        final repository = ScheduleDataRepository(
          parser: RailScheduleDocumentParser(),
          remoteClient: client,
        );

        final remoteResult = await repository.fetchRemoteSchedule();
        final cachedResult = await repository.readStoredSchedule();

        expect(remoteResult, isNull);
        expect(cachedResult, isNotNull);
        expect(cachedResult?.schedule.version, equals('cached-v1'));
      },
    );
  });
}

class _FakeRemoteClient implements RemoteScheduleClient {
  _FakeRemoteClient({required Map<String, List<RemoteJsonResponse>> responses})
    : _responses = responses.map(
        (key, value) => MapEntry(key, List<RemoteJsonResponse>.from(value)),
      );

  final Map<String, List<RemoteJsonResponse>> _responses;
  final List<String> requestedUrls = [];

  @override
  Future<RemoteJsonResponse> getJson(String url) async {
    requestedUrls.add(url);
    final queue = _responses[url];
    if (queue == null || queue.isEmpty) {
      return const RemoteJsonResponse(statusCode: 404, json: null);
    }
    return queue.removeAt(0);
  }
}

Map<String, dynamic> _validScheduleDocument({required String version}) {
  return {
    'version': version,
    'stations': [
      {'id': 'a', 'code': 'a', 'name': 'A'},
      {'id': 'b', 'code': 'b', 'name': 'B'},
    ],
    'directions': [
      {
        'id': 'a_to_b',
        'directionKey': 'a_to_b',
        'prefix': 'ab',
        'label': 'A to B',
        'isForward': true,
      },
    ],
    'trips': [
      {
        'id': 't1',
        'directionId': 'a_to_b',
        'trainNo': 1,
        'servicePeriod': 'morning',
        'stopTimes': ['06:00', '06:15'],
      },
    ],
  };
}
