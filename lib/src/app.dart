import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter/services.dart';

import 'bootstrap/app_composition.dart';
import 'core/theme/app_theme.dart';
import 'features/community/domain/repositories/community_overlay_repository.dart';
import 'features/community/domain/repositories/arrival_report_repository.dart';
import 'features/community/domain/repositories/device_identity_repository.dart';
import 'features/community/domain/repositories/prediction_repository.dart';
import 'features/community/domain/repositories/rate_limit_policy_repository.dart';
import 'features/community/domain/repositories/session_repository.dart';
import 'features/rail/presentation/bloc/rail_board_bloc.dart';
import 'features/rail/presentation/pages/rail_board_page.dart';

class NarayanganjRailScheduleApp extends StatelessWidget {
  const NarayanganjRailScheduleApp({super.key, required this.composition});

  final AppComposition composition;

  @override
  Widget build(BuildContext context) {
    return MultiRepositoryProvider(
      providers: [
        RepositoryProvider<SessionRepository>.value(
          value: composition.sessionRepository,
        ),
        RepositoryProvider<ArrivalReportRepository>.value(
          value: composition.arrivalReportRepository,
        ),
        RepositoryProvider<CommunityOverlayRepository>.value(
          value: composition.communityOverlayRepository,
        ),
        RepositoryProvider<PredictionRepository>.value(
          value: composition.predictionRepository,
        ),
        RepositoryProvider<DeviceIdentityRepository>.value(
          value: composition.deviceIdentityRepository,
        ),
        RepositoryProvider<RateLimitPolicyRepository>.value(
          value: composition.rateLimitPolicyRepository,
        ),
      ],
      child: BlocProvider<RailBoardBloc>(
        create: (_) => composition.createRailBoardBloc(),
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
