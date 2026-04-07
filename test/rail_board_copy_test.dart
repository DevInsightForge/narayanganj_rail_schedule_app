import 'package:flutter_test/flutter_test.dart';
import 'package:narayanganj_rail_schedule/src/features/rail/presentation/widgets/rail_board_copy.dart';

void main() {
  group('RailBoardCopy', () {
    test('formats time labels', () {
      expect(RailBoardCopy.formatTimeAmPm('00:05'), equals('12:05 AM'));
      expect(RailBoardCopy.formatTimeAmPm('12:30'), equals('12:30 PM'));
    });

    test('formats duration labels', () {
      expect(RailBoardCopy.getDurationLabel(0), equals('0 min'));
      expect(RailBoardCopy.getDurationLabel(75), equals('1 hour 15 min'));
    });

    test('maps decision and service labels', () {
      expect(RailBoardCopy.getDecision(3), equals('Run now'));
      expect(
        RailBoardCopy.getServicePeriodLabel('peak_hour'),
        equals('PEAK HOUR'),
      );
    });
  });
}
