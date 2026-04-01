import 'package:firebase_remote_config/firebase_remote_config.dart';

import '../core/errors/error_reporting.dart';
import '../core/firebase/firebase_bootstrap.dart';
import '../features/rail/data/models/rail_schedule_document_parser.dart';
import '../features/rail/data/repositories/bundled_schedule_source.dart';
import '../features/rail/data/repositories/firebase_remote_schedule_source.dart';
import '../features/rail/data/repositories/schedule_data_repository.dart';
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
    final scheduleDataRepository = ScheduleDataRepository(
      parser: _parser,
      remoteSource: FirebaseRemoteScheduleSource(
        remoteConfig: firebaseRuntime.initialized
            ? FirebaseRemoteConfig.instance
            : null,
      ),
    );
    final errorReporter = buildErrorReporter(firebaseRuntime: firebaseRuntime);
    await errorReporter.initialize();

    return AppComposition(
      firebaseRuntime: firebaseRuntime,
      bundledSchedule: bundledSchedule,
      scheduleDataRepository: scheduleDataRepository,
      errorReporter: errorReporter,
    );
  }
}
