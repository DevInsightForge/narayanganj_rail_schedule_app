import 'dart:async';

import 'package:flutter/foundation.dart';

import '../core/errors/error_report_context.dart';
import '../core/errors/error_reporter.dart';
import '../core/errors/error_reporting.dart';
import '../core/firebase/firebase_bootstrap.dart';
import '../features/community/data/local/hive/community_hive_box.dart';
import '../features/rail/data/models/rail_schedule_document_parser.dart';
import '../features/rail/data/repositories/bundled_schedule_source.dart';
import 'app_composition.dart';

class AppBootstrap {
  AppBootstrap({
    FirebaseBootstrap? firebaseBootstrap,
    RailScheduleDocumentParser? parser,
  }) : _firebaseBootstrap = firebaseBootstrap ?? FirebaseBootstrap(),
       _parser = parser ?? RailScheduleDocumentParser();

  final FirebaseBootstrap _firebaseBootstrap;
  final RailScheduleDocumentParser _parser;

  Future<AppComposition> initialize() async {
    final firebaseRuntime = await _firebaseBootstrap.initialize();
    final bundledSchedule = BundledScheduleSource(
      parser: _parser,
    ).loadSchedule();
    final errorReporter = buildErrorReporter(firebaseRuntime: firebaseRuntime);
    await errorReporter.initialize();
    try {
      await CommunityHiveBox.initialize();
      await CommunityHiveBox.migrateLegacySharedPreferences();
    } catch (error, stackTrace) {
      await errorReporter.reportNonFatal(
        error,
        stackTrace,
        reason: 'community_hive_bootstrap_failed',
        context: ErrorReportContext(
          feature: 'community_hive',
          event: 'bootstrap',
        ),
      );
    }
    _configureFatalErrorHandlers(errorReporter);

    return AppComposition(
      firebaseRuntime: firebaseRuntime,
      bundledSchedule: bundledSchedule,
      errorReporter: errorReporter,
    );
  }

  void _configureFatalErrorHandlers(ErrorReporter errorReporter) {
    if (!errorReporter.isEnabled) {
      return;
    }

    FlutterError.onError = (details) {
      unawaited(
        errorReporter.reportFatal(
          details.exception,
          details.stack ?? StackTrace.current,
          context: ErrorReportContext(feature: 'app', event: 'flutter_error'),
        ),
      );
      FlutterError.presentError(details);
    };
    PlatformDispatcher.instance.onError = (error, stack) {
      unawaited(
        errorReporter.reportFatal(
          error,
          stack,
          context: ErrorReportContext(feature: 'app', event: 'platform_error'),
        ),
      );
      return true;
    };
  }
}
