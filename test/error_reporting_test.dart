import 'package:flutter_test/flutter_test.dart';
import 'package:narayanganj_rail_schedule/src/core/errors/error_reporting.dart';

void main() {
  test('returns noop error reporter', () {
    final reporter = buildErrorReporter();
    expect(reporter.isEnabled, isFalse);
  });
}
