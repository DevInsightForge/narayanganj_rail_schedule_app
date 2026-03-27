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

    test('loads schedule through manifest success path', () async {
      final manifestUrl = ScheduleDataRepository.defaultManifestUrl;
      final resolvedScheduleUrl = Uri.parse(
        manifestUrl,
      ).resolve('schedule-data-v1.json').toString();
      final remoteDocument = _validScheduleDocument(version: 'manifest-remote');

      final client = _FakeRemoteClient(
        responses: {
          manifestUrl: [
            const RemoteJsonResponse(
              statusCode: 200,
              json: {'latest_path': 'schedule-data-v1.json'},
            ),
          ],
          resolvedScheduleUrl: [
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
      expect(result?.schedule.version, equals('manifest-remote'));
      expect(client.requestedUrls.first, equals(manifestUrl));
      expect(client.requestedUrls.last, equals(resolvedScheduleUrl));

      final preferences = await SharedPreferences.getInstance();
      final rawCache = preferences.getString(ScheduleDataRepository.storageKey);
      expect(rawCache, isNotNull);
      final wrapped = jsonDecode(rawCache!) as Map<String, dynamic>;
      expect(wrapped['sourceUrl'], equals(resolvedScheduleUrl));
      expect(wrapped['schemaVersion'], equals('manifest-remote'));
    });

    test('returns null when manifest request fails', () async {
      final manifestUrl = ScheduleDataRepository.defaultManifestUrl;

      final client = _FakeRemoteClient(
        responses: {
          manifestUrl: const [
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
      expect(client.requestedUrls.contains(manifestUrl), isTrue);
    });

    test('returns null when manifest latest_path is missing', () async {
      final manifestUrl = ScheduleDataRepository.defaultManifestUrl;

      final client = _FakeRemoteClient(
        responses: {
          manifestUrl: const [
            RemoteJsonResponse(statusCode: 200, json: {'unexpected': true}),
          ],
        },
      );

      final repository = ScheduleDataRepository(
        parser: RailScheduleDocumentParser(),
        remoteClient: client,
      );

      final result = await repository.fetchRemoteSchedule();

      expect(result, isNull);
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

        final manifestUrl = ScheduleDataRepository.defaultManifestUrl;
        final resolvedScheduleUrl = Uri.parse(
          manifestUrl,
        ).resolve('schedule-data-v1.json').toString();
        final client = _FakeRemoteClient(
          responses: {
            manifestUrl: const [
              RemoteJsonResponse(
                statusCode: 200,
                json: {'latest_path': 'schedule-data-v1.json'},
              ),
            ],
            resolvedScheduleUrl: const [
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
