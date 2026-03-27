import 'package:flutter_test/flutter_test.dart';
import 'package:narayanganj_rail_schedule/src/features/rail/data/models/rail_schedule_document_parser.dart';

void main() {
  group('RailScheduleDocumentParser', () {
    final parser = RailScheduleDocumentParser();

    test('parses valid minimal schedule document', () {
      final document = {
        'version': '2026.03.27',
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

      final parsed = parser.parse(document);
      expect(parsed.version, equals('2026.03.27'));
      expect(parsed.stations.length, equals(2));
    });

    test('throws when required sections are missing', () {
      expect(() => parser.parse({'version': '1'}), throwsFormatException);
    });

    test('throws when trip stop count is inconsistent', () {
      final document = {
        'version': '1',
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
            'stopTimes': ['06:00'],
          },
        ],
      };

      expect(() => parser.parse(document), throwsFormatException);
    });
  });
}
