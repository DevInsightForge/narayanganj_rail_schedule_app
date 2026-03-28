import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter/services.dart';

import 'core/firebase/firebase_runtime.dart';
import 'core/theme/app_theme.dart';
import 'features/community/data/mappers/rail_schedule_template_mapper.dart';
import 'features/community/data/repositories/fake/fake_arrival_report_repository.dart';
import 'features/community/data/repositories/fake/fake_device_identity_repository.dart';
import 'features/community/data/repositories/fake/fake_prediction_repository.dart';
import 'features/community/data/repositories/fake/fake_rate_limit_policy_repository.dart';
import 'features/community/data/repositories/firebase/firebase_arrival_report_repository.dart';
import 'features/community/data/repositories/firebase/firebase_device_identity_repository.dart';
import 'features/community/data/repositories/firebase/firebase_prediction_repository.dart';
import 'features/community/data/repositories/local/generated_session_repository.dart';
import 'features/community/data/repositories/resilient/resilient_arrival_report_repository.dart';
import 'features/community/data/repositories/resilient/resilient_device_identity_repository.dart';
import 'features/community/data/repositories/resilient/resilient_prediction_repository.dart';
import 'features/community/domain/entities/rate_limit_policy.dart';
import 'features/community/domain/repositories/arrival_report_repository.dart';
import 'features/community/domain/repositories/device_identity_repository.dart';
import 'features/community/domain/repositories/prediction_repository.dart';
import 'features/community/domain/repositories/rate_limit_policy_repository.dart';
import 'features/community/domain/repositories/session_repository.dart';
import 'features/rail/data/datasources/static_schedule_data_source.dart';
import 'features/rail/data/models/rail_schedule_document_parser.dart';
import 'features/rail/data/repositories/schedule_data_repository.dart';
import 'features/rail/data/repositories/shared_preferences_selection_repository.dart';
import 'features/rail/domain/services/rail_board_service.dart';
import 'features/rail/presentation/bloc/rail_board_bloc.dart';
import 'features/rail/presentation/pages/rail_board_page.dart';

class NarayanganjRailScheduleApp extends StatelessWidget {
  const NarayanganjRailScheduleApp({super.key, required this.firebaseRuntime});

  final FirebaseRuntime firebaseRuntime;

  @override
  Widget build(BuildContext context) {
    final parser = RailScheduleDocumentParser();
    final boardService = RailBoardService(
      schedule: StaticScheduleDataSource.schedule,
    );
    final scheduleDataRepository = ScheduleDataRepository(parser: parser);
    final templates = const RailScheduleTemplateMapper().map(
      routeId: 'narayanganj_line',
      schedule: StaticScheduleDataSource.schedule,
    );
    final sessionRepository = GeneratedSessionRepository(templates: templates);
    final fallbackArrivalReportRepository = FakeArrivalReportRepository();
    final fallbackPredictionRepository = FakePredictionRepository();
    final fallbackDeviceIdentityRepository = FakeDeviceIdentityRepository();

    final arrivalReportRepository = firebaseRuntime.initialized
        ? ResilientArrivalReportRepository(
            primary: FirebaseArrivalReportRepository(
              firestore: FirebaseFirestore.instance,
              routeId: 'narayanganj_line',
            ),
            fallback: fallbackArrivalReportRepository,
          )
        : fallbackArrivalReportRepository;
    final predictionRepository = firebaseRuntime.initialized
        ? ResilientPredictionRepository(
            primary: FirebasePredictionRepository(
              firestore: FirebaseFirestore.instance,
            ),
            fallback: fallbackPredictionRepository,
          )
        : fallbackPredictionRepository;
    final deviceIdentityRepository = firebaseRuntime.initialized
        ? ResilientDeviceIdentityRepository(
            primary: FirebaseDeviceIdentityRepository(
              auth: FirebaseAuth.instance,
              firestore: FirebaseFirestore.instance,
            ),
            fallback: fallbackDeviceIdentityRepository,
          )
        : fallbackDeviceIdentityRepository;

    final rateLimitPolicyRepository = FakeRateLimitPolicyRepository(
      seed: const {
        'arrival_report': RateLimitPolicy(
          key: 'arrival_report',
          maxEvents: 3,
          windowSeconds: 120,
          coolDownSeconds: 30,
        ),
      },
    );

    return MultiRepositoryProvider(
      providers: [
        RepositoryProvider<SessionRepository>.value(value: sessionRepository),
        RepositoryProvider<ArrivalReportRepository>.value(
          value: arrivalReportRepository,
        ),
        RepositoryProvider<PredictionRepository>.value(
          value: predictionRepository,
        ),
        RepositoryProvider<DeviceIdentityRepository>.value(
          value: deviceIdentityRepository,
        ),
        RepositoryProvider<RateLimitPolicyRepository>.value(
          value: rateLimitPolicyRepository,
        ),
      ],
      child: BlocProvider(
        create: (context) => RailBoardBloc(
          boardService: boardService,
          scheduleDataRepository: scheduleDataRepository,
          selectionRepository: SharedPreferencesSelectionRepository(),
          sessionRepository: context.read<SessionRepository>(),
          arrivalReportRepository: context.read<ArrivalReportRepository>(),
          predictionRepository: context.read<PredictionRepository>(),
          deviceIdentityRepository: context.read<DeviceIdentityRepository>(),
          rateLimitPolicyRepository: context.read<RateLimitPolicyRepository>(),
        ),
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: AppTheme.light(),
          darkTheme: AppTheme.dark(),
          themeMode: ThemeMode.system,
          builder: (context, child) {
            final isDark = Theme.of(context).brightness == Brightness.dark;
            SystemChrome.setSystemUIOverlayStyle(
              SystemUiOverlayStyle(
                statusBarColor: Colors.transparent,
                statusBarIconBrightness: isDark
                    ? Brightness.light
                    : Brightness.dark,
                statusBarBrightness: isDark
                    ? Brightness.dark
                    : Brightness.light,
                systemStatusBarContrastEnforced: false,
                systemNavigationBarColor: Colors.transparent,
                systemNavigationBarDividerColor: Colors.transparent,
                systemNavigationBarIconBrightness: isDark
                    ? Brightness.light
                    : Brightness.dark,
                systemNavigationBarContrastEnforced: false,
              ),
            );
            return child ?? const SizedBox.shrink();
          },
          home: const RailBoardPage(),
        ),
      ),
    );
  }
}
