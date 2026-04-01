import 'error_report_context.dart';

abstract class ErrorReporter {
  bool get isEnabled;

  Future<void> initialize();

  Future<void> reportNonFatal(
    Object error,
    StackTrace stackTrace, {
    String? reason,
    ErrorReportContext context = const ErrorReportContext(),
  });

  Future<void> reportFatal(
    Object error,
    StackTrace stackTrace, {
    String? reason,
    ErrorReportContext context = const ErrorReportContext(),
  });
}

class NoopErrorReporter implements ErrorReporter {
  const NoopErrorReporter();

  @override
  bool get isEnabled => false;

  @override
  Future<void> initialize() async {}

  @override
  Future<void> reportFatal(
    Object error,
    StackTrace stackTrace, {
    String? reason,
    ErrorReportContext context = const ErrorReportContext(),
  }) async {}

  @override
  Future<void> reportNonFatal(
    Object error,
    StackTrace stackTrace, {
    String? reason,
    ErrorReportContext context = const ErrorReportContext(),
  }) async {}
}
