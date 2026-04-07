import 'package:flutter_test/flutter_test.dart';
import 'package:narayanganj_rail_schedule/src/features/community/data/repositories/local/shared_preferences_arrival_report_ledger_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('prunes ledger entries older than eighteen hours', () async {
    final serviceDate = DateTime.utc(2026, 3, 28);
    SharedPreferences.setMockInitialValues(<String, Object>{
      'nrs:community:arrival-report-ledger':
          '{"old::20260327::station::device":"2026-03-27T05:59:00.000Z"}',
    });
    final repository = SharedPreferencesArrivalReportLedgerRepository(
      nowProvider: () => DateTime.utc(2026, 3, 28, 0),
    );

    final hasSubmitted = await repository.hasSubmitted(
      sessionId: 'old',
      serviceDate: serviceDate,
      stationId: 'station',
      deviceId: 'device',
      now: DateTime.utc(2026, 3, 28, 0),
    );

    expect(hasSubmitted, isFalse);
    final preferences = await SharedPreferences.getInstance();
    expect(
      preferences.getString('nrs:community:arrival-report-ledger'),
      equals('{}'),
    );
  });

  test('keeps ledger entries within eighteen hours', () async {
    final serviceDate = DateTime.utc(2026, 3, 28);
    SharedPreferences.setMockInitialValues(<String, Object>{
      'nrs:community:arrival-report-ledger':
          '{"recent::20260328::station::device":"2026-03-27T06:30:00.000Z"}',
    });
    final repository = SharedPreferencesArrivalReportLedgerRepository(
      nowProvider: () => DateTime.utc(2026, 3, 28, 0),
    );

    final hasSubmitted = await repository.hasSubmitted(
      sessionId: 'recent',
      serviceDate: serviceDate,
      stationId: 'station',
      deviceId: 'device',
      now: DateTime.utc(2026, 3, 28, 0),
    );

    expect(hasSubmitted, isTrue);
  });
}
