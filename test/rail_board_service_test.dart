import 'package:flutter_test/flutter_test.dart';
import 'package:narayanganj_rail_schedule/src/features/rail/domain/entities/rail_selection.dart';
import 'package:narayanganj_rail_schedule/src/features/rail/domain/services/rail_board_service.dart';

import 'support/bundled_schedule_fixture.dart';

void main() {
  group('RailBoardService', () {
    final service = RailBoardService(schedule: loadBundledScheduleFixture());

    test('returns stations ordered by direction', () {
      final forward = service.getStationsForDirection('dhaka_to_narayanganj');
      final reverse = service.getStationsForDirection('narayanganj_to_dhaka');

      expect(forward.first.id, equals('dhaka'));
      expect(forward.last.id, equals('narayanganj'));
      expect(reverse.first.id, equals('narayanganj'));
      expect(reverse.last.id, equals('dhaka'));
    });

    test('prevents invalid downstream destination', () {
      final selection = RailSelection(
        direction: 'dhaka_to_narayanganj',
        boardingStationId: 'chashara',
        destinationStationId: 'narayanganj',
      );

      final result = service.changeDestinationStation(selection, 'dhaka');
      expect(result.destinationStationId, equals('narayanganj'));
    });

    test('selects next train from now', () {
      final selection = service.createSelection(
        direction: 'dhaka_to_narayanganj',
        boardingStationId: 'dhaka',
        destinationStationId: 'narayanganj',
      );

      final snapshot = service.getSnapshot(
        selection: selection,
        now: DateTime(2026, 3, 27, 6, 50),
      );

      expect(snapshot.nextService, isNotNull);
      expect(snapshot.nextService!.departureTime, equals('06:55'));
    });

    test('handles cross-midnight wait correctly', () {
      final selection = service.createSelection(
        direction: 'dhaka_to_narayanganj',
        boardingStationId: 'dhaka',
        destinationStationId: 'narayanganj',
      );

      final snapshot = service.getSnapshot(
        selection: selection,
        now: DateTime(2026, 3, 27, 23, 58),
      );

      expect(snapshot.nextService, isNotNull);
      expect(snapshot.nextService!.waitMinutes, greaterThan(0));
    });

    test('retains train within grace window when departure has passed', () {
      final selection = service.createSelection(
        direction: 'dhaka_to_narayanganj',
        boardingStationId: 'dhaka',
        destinationStationId: 'narayanganj',
      );

      final snapshot = service.getSnapshot(
        selection: selection,
        now: DateTime(2026, 3, 27, 7, 10),
      );

      expect(snapshot.nextService, isNotNull);
      expect(snapshot.nextService!.departureTime, equals('06:55'));
      expect(snapshot.nextService!.isOverdue, isTrue);
      expect(snapshot.nextService!.overdueMinutes, equals(15));
      expect(snapshot.nextService!.waitMinutes, equals(0));
      expect(snapshot.nextDepartureService, isNotNull);
      expect(snapshot.nextDepartureService!.departureTime, equals('09:15'));
      expect(snapshot.nextDepartureService!.isOverdue, isFalse);
    });

    test(
      'retires train after grace window expires and promotes next train',
      () {
        final selection = service.createSelection(
          direction: 'dhaka_to_narayanganj',
          boardingStationId: 'dhaka',
          destinationStationId: 'narayanganj',
        );

        final snapshot = service.getSnapshot(
          selection: selection,
          now: DateTime(2026, 3, 27, 7, 30),
        );

        expect(snapshot.nextService, isNotNull);
        expect(snapshot.nextService!.departureTime, equals('09:15'));
        expect(snapshot.nextService!.isOverdue, isFalse);
      },
    );

    test('extends grace window dynamically when delay is known', () {
      final selection = service.createSelection(
        direction: 'dhaka_to_narayanganj',
        boardingStationId: 'dhaka',
        destinationStationId: 'narayanganj',
      );

      final snapshot = service.getSnapshot(
        selection: selection,
        now: DateTime(2026, 3, 27, 7, 30),
        knownDelayMinutes: 45,
      );

      expect(snapshot.nextService, isNotNull);
      expect(snapshot.nextService!.departureTime, equals('06:55'));
      expect(snapshot.nextService!.isOverdue, isTrue);
      expect(snapshot.nextService!.overdueMinutes, equals(35));
      expect(snapshot.nextService!.waitMinutes, equals(10));
    });

    test(
      'retains train within grace window regardless of destination distance',
      () {
        final selection = service.createSelection(
          direction: 'dhaka_to_narayanganj',
          boardingStationId: 'dhaka',
          destinationStationId: 'gendaria',
        );

        final snapshot = service.getSnapshot(
          selection: selection,
          now: DateTime(2026, 3, 27, 7, 10),
        );

        expect(snapshot.nextService, isNotNull);
        expect(snapshot.nextService!.departureTime, equals('06:55'));
        expect(snapshot.nextService!.isOverdue, isTrue);
        expect(snapshot.nextService!.overdueMinutes, equals(15));
      },
    );
  });
}
