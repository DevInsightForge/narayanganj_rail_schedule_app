import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:narayanganj_rail_schedule/src/features/rail/data/models/rail_schedule_document_parser.dart';
import 'package:narayanganj_rail_schedule/src/features/rail/data/repositories/schedule_data_repository.dart';
import 'package:narayanganj_rail_schedule/src/features/rail/data/repositories/schedule_remote_source.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('ScheduleDataRepository loader', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('loads schedule through remote config source', () async {
      final remoteDocument = _validScheduleDocument(version: 'rc-remote');
      final source = _FakeRemoteSource(
        payloads: [
          RemoteSchedulePayload(
            sourceLabel: 'firebase_remote_config:schedule_data_json',
            document: remoteDocument,
          ),
        ],
      );
      final repository = ScheduleDataRepository(
        parser: RailScheduleDocumentParser(),
        remoteSource: source,
      );

      final result = await repository.fetchRemoteSchedule();

      expect(result, isNotNull);
      expect(result?.source, equals(ScheduleDataSource.remote));
      expect(result?.schedule.version, equals('rc-remote'));

      final preferences = await SharedPreferences.getInstance();
      final rawCache = preferences.getString(ScheduleDataRepository.storageKey);
      expect(rawCache, isNotNull);
      final wrapped = jsonDecode(rawCache!) as Map<String, dynamic>;
      expect(
        wrapped['sourceUrl'],
        equals('firebase_remote_config:schedule_data_json'),
      );
      expect(wrapped['schemaVersion'], equals('rc-remote'));
    });

    test('returns null when remote source has no payload', () async {
      final repository = ScheduleDataRepository(
        parser: RailScheduleDocumentParser(),
        remoteSource: _FakeRemoteSource(payloads: const []),
      );

      final result = await repository.fetchRemoteSchedule();

      expect(result, isNull);
    });

    test('skips update when remote version is unchanged', () async {
      final cachedDocument = _validScheduleDocument(version: 'v1');
      final cachedPayload = jsonEncode({
        'fetchedAt': DateTime(2026, 3, 27, 8).toUtc().toIso8601String(),
        'sourceUrl': 'firebase_remote_config:schedule_data_json',
        'schemaVersion': 'v1',
        'checksum': '',
        'document': cachedDocument,
      });
      SharedPreferences.setMockInitialValues({
        ScheduleDataRepository.storageKey: cachedPayload,
      });

      final repository = ScheduleDataRepository(
        parser: RailScheduleDocumentParser(),
        remoteSource: _FakeRemoteSource(
          payloads: [
            RemoteSchedulePayload(
              sourceLabel: 'firebase_remote_config:schedule_data_json',
              document: _validScheduleDocument(version: 'v1'),
            ),
          ],
        ),
      );

      final remoteResult = await repository.fetchRemoteSchedule();
      final cachedResult = await repository.readStoredSchedule();

      expect(remoteResult, isNull);
      expect(cachedResult, isNotNull);
      expect(cachedResult?.schedule.version, equals('v1'));
    });
  });
}

class _FakeRemoteSource implements ScheduleRemoteSource {
  _FakeRemoteSource({required List<RemoteSchedulePayload> payloads})
    : _payloads = List<RemoteSchedulePayload>.from(payloads);

  final List<RemoteSchedulePayload> _payloads;

  @override
  Future<RemoteSchedulePayload?> fetchSchedule() async {
    if (_payloads.isEmpty) {
      return null;
    }
    return _payloads.removeAt(0);
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
