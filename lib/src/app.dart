import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter/services.dart';

import 'core/theme/app_theme.dart';
import 'features/community/data/repositories/fake/fake_arrival_report_repository.dart';
import 'features/community/data/repositories/fake/fake_device_identity_repository.dart';
import 'features/community/data/repositories/fake/fake_prediction_repository.dart';
import 'features/community/data/repositories/fake/fake_rate_limit_policy_repository.dart';
import 'features/community/data/repositories/fake/fake_session_chat_repository.dart';
import 'features/community/data/repositories/fake/fake_session_repository.dart';
import 'features/community/domain/repositories/arrival_report_repository.dart';
import 'features/community/domain/repositories/device_identity_repository.dart';
import 'features/community/domain/repositories/prediction_repository.dart';
import 'features/community/domain/repositories/rate_limit_policy_repository.dart';
import 'features/community/domain/repositories/session_chat_repository.dart';
import 'features/community/domain/repositories/session_repository.dart';
import 'features/rail/data/datasources/static_schedule_data_source.dart';
import 'features/rail/data/models/rail_schedule_document_parser.dart';
import 'features/rail/data/repositories/schedule_data_repository.dart';
import 'features/rail/data/repositories/shared_preferences_selection_repository.dart';
import 'features/rail/domain/services/rail_board_service.dart';
import 'features/rail/presentation/bloc/rail_board_bloc.dart';
import 'features/rail/presentation/pages/rail_board_page.dart';

class NarayanganjRailScheduleApp extends StatelessWidget {
  const NarayanganjRailScheduleApp({super.key});

  @override
  Widget build(BuildContext context) {
    final parser = RailScheduleDocumentParser();
    final boardService = RailBoardService(
      schedule: StaticScheduleDataSource.schedule,
    );
    final scheduleDataRepository = ScheduleDataRepository(parser: parser);
    final sessionRepository = FakeSessionRepository();
    final arrivalReportRepository = FakeArrivalReportRepository();
    final predictionRepository = FakePredictionRepository();
    final sessionChatRepository = FakeSessionChatRepository();
    final deviceIdentityRepository = FakeDeviceIdentityRepository();
    final rateLimitPolicyRepository = FakeRateLimitPolicyRepository();

    return MultiRepositoryProvider(
      providers: [
        RepositoryProvider<SessionRepository>.value(value: sessionRepository),
        RepositoryProvider<ArrivalReportRepository>.value(
          value: arrivalReportRepository,
        ),
        RepositoryProvider<PredictionRepository>.value(
          value: predictionRepository,
        ),
        RepositoryProvider<SessionChatRepository>.value(
          value: sessionChatRepository,
        ),
        RepositoryProvider<DeviceIdentityRepository>.value(
          value: deviceIdentityRepository,
        ),
        RepositoryProvider<RateLimitPolicyRepository>.value(
          value: rateLimitPolicyRepository,
        ),
      ],
      child: BlocProvider(
        create: (_) => RailBoardBloc(
          boardService: boardService,
          scheduleDataRepository: scheduleDataRepository,
          selectionRepository: SharedPreferencesSelectionRepository(),
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
