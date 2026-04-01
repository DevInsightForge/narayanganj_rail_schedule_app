import 'package:firebase_crashlytics/firebase_crashlytics.dart';

import 'error_report_context.dart';
import 'error_reporter.dart';

class FirebaseErrorReporter implements ErrorReporter {
  FirebaseErrorReporter({
    required FirebaseCrashlytics crashlytics,
    required this.collectionEnabled,
  }) : _crashlytics = crashlytics;

  final FirebaseCrashlytics _crashlytics;
  final bool collectionEnabled;
  bool _initialized = false;

  @override
  bool get isEnabled => collectionEnabled;

  @override
  Future<void> initialize() async {
    if (_initialized) {
      return;
    }
    _initialized = true;
    await _crashlytics.setCrashlyticsCollectionEnabled(collectionEnabled);
  }

  @override
  Future<void> reportFatal(
    Object error,
    StackTrace stackTrace, {
    String? reason,
    ErrorReportContext context = const ErrorReportContext(),
  }) async {
    if (!collectionEnabled) {
      return;
    }
    await initialize();
    await _applyContext(context);
    await _crashlytics.recordError(
      error,
      stackTrace,
      reason: reason,
      fatal: true,
    );
  }

  @override
  Future<void> reportNonFatal(
    Object error,
    StackTrace stackTrace, {
    String? reason,
    ErrorReportContext context = const ErrorReportContext(),
  }) async {
    if (!collectionEnabled) {
      return;
    }
    await initialize();
    await _applyContext(context);
    await _crashlytics.recordError(
      error,
      stackTrace,
      reason: reason,
      fatal: false,
    );
  }

  Future<void> _applyContext(ErrorReportContext context) async {
    for (final entry in context.toMap().entries) {
      await _crashlytics.setCustomKey(entry.key, entry.value ?? '');
    }
  }
}

ErrorReporter createFirebaseErrorReporter({required bool collectionEnabled}) {
  return FirebaseErrorReporter(
    crashlytics: FirebaseCrashlytics.instance,
    collectionEnabled: collectionEnabled,
  );
}
