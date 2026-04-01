import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

import 'src/core/errors/error_report_context.dart';
import 'src/app.dart';
import 'src/bootstrap/app_bootstrap.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: '.env', isOptional: true);
  final composition = await AppBootstrap().initialize();
  if (composition.errorReporter.isEnabled) {
    FlutterError.onError = (details) {
      unawaited(
        composition.errorReporter.reportFatal(
          details.exception,
          details.stack ?? StackTrace.current,
          context: ErrorReportContext(feature: 'app', event: 'flutter_error'),
        ),
      );
      FlutterError.presentError(details);
    };
    PlatformDispatcher.instance.onError = (error, stack) {
      unawaited(
        composition.errorReporter.reportFatal(
          error,
          stack,
          context: ErrorReportContext(feature: 'app', event: 'platform_error'),
        ),
      );
      return true;
    };
  }
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  runApp(NarayanganjRailScheduleApp(composition: composition));
}
