import 'error_reporter.dart';

ErrorReporter createFirebaseErrorReporter({required bool collectionEnabled}) {
  return const NoopErrorReporter();
}
