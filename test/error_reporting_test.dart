import 'package:flutter_test/flutter_test.dart';
import 'package:narayanganj_rail_schedule/src/core/errors/error_reporting.dart';
import 'package:narayanganj_rail_schedule/src/core/firebase/firebase_runtime.dart';

void main() {
  test('returns noop reporter when firebase is not initialized', () {
    final reporter = buildErrorReporter(
      firebaseRuntime: FirebaseRuntime.disabled,
    );

    expect(reporter.isEnabled, isFalse);
  });

  test('returns noop reporter when error reporting flag is disabled', () {
    final reporter = buildErrorReporter(
      firebaseRuntime: const FirebaseRuntime(
        enabled: true,
        initialized: true,
        appCheckEnabled: false,
        errorReportingEnabled: false,
        status: 'initialized',
      ),
      envReader: (key) => null,
    );

    expect(reporter.isEnabled, isFalse);
  });
}
