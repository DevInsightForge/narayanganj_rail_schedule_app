import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/api/api_config.dart';
import '../core/errors/error_report_context.dart';
import '../core/errors/error_reporter.dart';
import '../core/errors/error_reporting.dart';
import '../features/community/data/local/hive/community_hive_box.dart';
import '../features/rail/data/repositories/bundled_schedule_source.dart';
import 'app_composition.dart';

class AppBootstrap {
  AppBootstrap({ApiConfig? apiConfig}) : _apiConfig = apiConfig;

  final ApiConfig? _apiConfig;

  Future<AppComposition> initialize() async {
    final apiConfig = _apiConfig ?? ApiConfig.fromEnv();
    final apiKey = apiConfig.apiKey;
    if (apiConfig.enabled &&
        apiConfig.baseUrl.isNotEmpty &&
        apiKey != null &&
        apiKey.isNotEmpty) {
      try {
        await Supabase.initialize(
          url: apiConfig.baseUrl,
          publishableKey: apiKey,
        );
      } catch (_) {}
    }

    final bundledSchedule = const BundledScheduleSource().loadSchedule();
    final errorReporter = buildErrorReporter();
    await errorReporter.initialize();
    try {
      await CommunityHiveBox.initialize();
      await CommunityHiveBox.migrateLegacySharedPreferences();
    } catch (error, stackTrace) {
      await errorReporter.reportNonFatal(
        error,
        stackTrace,
        reason: 'community_hive_bootstrap_failed',
        context: const ErrorReportContext(
          feature: 'community_hive',
          event: 'bootstrap',
        ),
      );
    }
    _configureFatalErrorHandlers(errorReporter);

    return AppComposition(
      bundledSchedule: bundledSchedule,
      errorReporter: errorReporter,
      apiConfig: apiConfig,
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
          context: const ErrorReportContext(
            feature: 'app',
            event: 'flutter_error',
          ),
        ),
      );
      FlutterError.presentError(details);
    };
    PlatformDispatcher.instance.onError = (error, stack) {
      unawaited(
        errorReporter.reportFatal(
          error,
          stack,
          context: const ErrorReportContext(
            feature: 'app',
            event: 'platform_error',
          ),
        ),
      );
      return true;
    };
  }
}
