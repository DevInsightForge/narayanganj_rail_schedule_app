import '../config/runtime_env.dart';
import '../firebase/firebase_runtime.dart';
import 'error_reporter.dart';
import 'firebase_error_reporter_stub.dart'
    if (dart.library.io) 'firebase_error_reporter.dart';

ErrorReporter buildErrorReporter({
  required FirebaseRuntime firebaseRuntime,
  String? Function(String key)? envReader,
}) {
  if (!firebaseRuntime.initialized) {
    return const NoopErrorReporter();
  }

  final enabled =
      firebaseRuntime.errorReportingEnabled ||
      readRuntimeBoolEnv(
        'FIREBASE_ERROR_REPORTING_ENABLED',
        defaultValue: false,
        envReader: envReader,
      );
  if (!enabled) {
    return const NoopErrorReporter();
  }

  return createFirebaseErrorReporter(collectionEnabled: true);
}
