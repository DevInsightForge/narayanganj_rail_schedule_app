import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/api/api_config.dart';
import '../core/errors/error_reporter.dart';
import '../features/community/data/mappers/rail_schedule_template_mapper.dart';
import '../features/community/data/repositories/cached/cached_community_overlay_repository.dart';
import '../features/community/data/repositories/local/generated_session_repository.dart';
import '../features/community/data/repositories/local/local_device_identity_repository.dart';
import '../features/community/data/repositories/local/shared_preferences_arrival_report_ledger_repository.dart';
import '../features/community/data/repositories/local/shared_preferences_community_overlay_cache_repository.dart';
import '../features/community/data/repositories/noop/noop_arrival_report_repository.dart';
import '../features/community/data/repositories/noop/noop_community_overlay_repository.dart';
import '../features/community/data/repositories/supabase/supabase_arrival_report_repository.dart';
import '../features/community/data/repositories/supabase/supabase_community_overlay_repository.dart';
import '../features/community/domain/repositories/arrival_report_ledger_repository.dart';
import '../features/community/domain/repositories/arrival_report_repository.dart';
import '../features/community/domain/repositories/community_overlay_repository.dart';
import '../features/community/domain/repositories/device_identity_repository.dart';
import '../features/community/domain/repositories/session_repository.dart';
import '../features/rail/data/repositories/shared_preferences_selection_repository.dart';
import '../features/rail/domain/entities/rail_schedule.dart';
import '../features/rail/domain/repositories/selection_repository.dart';
import '../features/rail/domain/services/rail_board_service.dart';
import '../features/rail/presentation/bloc/rail_board_cubit.dart';

class AppComposition {
  AppComposition({
    required this.bundledSchedule,
    required this.errorReporter,
    ApiConfig? apiConfig,
    SupabaseClient? supabaseClient,
    this.communityDebugBypassEnabled = kDebugMode,
  }) : apiConfig = apiConfig ?? ApiConfig.fromEnv(),
       selectionRepository = SharedPreferencesSelectionRepository(),
       sessionRepository = GeneratedSessionRepository(
         templates: const RailScheduleTemplateMapper().map(
           routeId: 'narayanganj_line',
           schedule: bundledSchedule,
         ),
       ),
       arrivalReportRepository = _buildArrivalReportRepository(
         apiConfig ?? ApiConfig.fromEnv(),
         supabaseClient,
       ),
       arrivalReportLedgerRepository =
           SharedPreferencesArrivalReportLedgerRepository(),
       communityOverlayRepository = _buildCommunityOverlayRepository(
         apiConfig ?? ApiConfig.fromEnv(),
         supabaseClient,
         communityDebugBypassEnabled,
       ),
       deviceIdentityRepository = LocalDeviceIdentityRepository();

  final RailSchedule bundledSchedule;
  final ErrorReporter errorReporter;
  final ApiConfig apiConfig;
  final bool communityDebugBypassEnabled;
  final SelectionRepository selectionRepository;
  final SessionRepository sessionRepository;
  final ArrivalReportRepository arrivalReportRepository;
  final ArrivalReportLedgerRepository arrivalReportLedgerRepository;
  final CommunityOverlayRepository communityOverlayRepository;
  final DeviceIdentityRepository deviceIdentityRepository;

  RailBoardCubit createRailBoardCubit() {
    return RailBoardCubit(
      boardService: RailBoardService(schedule: bundledSchedule),
      selectionRepository: selectionRepository,
      sessionRepository: sessionRepository,
      arrivalReportRepository: arrivalReportRepository,
      arrivalReportLedgerRepository: arrivalReportLedgerRepository,
      communityOverlayRepository: communityOverlayRepository,
      deviceIdentityRepository: deviceIdentityRepository,
      errorReporter: errorReporter,
      communityFeaturesEnabled: apiConfig.enabled,
      communityDebugBypassEnabled: communityDebugBypassEnabled,
    );
  }

  static SupabaseClient _resolveSupabaseClient(
    ApiConfig config,
    SupabaseClient? client,
  ) {
    if (client != null) {
      return client;
    }
    try {
      return Supabase.instance.client;
    } catch (_) {
      return SupabaseClient(config.baseUrl, config.apiKey ?? '');
    }
  }

  static ArrivalReportRepository _buildArrivalReportRepository(
    ApiConfig config,
    SupabaseClient? client,
  ) {
    final apiKey = config.apiKey;
    if (!config.enabled || config.baseUrl.isEmpty || apiKey == null || apiKey.isEmpty) {
      return const NoOpArrivalReportRepository();
    }
    final supabaseClient = _resolveSupabaseClient(config, client);
    return SupabaseArrivalReportRepository(client: supabaseClient);
  }

  static CommunityOverlayRepository _buildCommunityOverlayRepository(
    ApiConfig config,
    SupabaseClient? client,
    bool communityDebugBypassEnabled,
  ) {
    final apiKey = config.apiKey;
    if (!config.enabled || config.baseUrl.isEmpty || apiKey == null || apiKey.isEmpty) {
      return const NoOpCommunityOverlayRepository();
    }
    final supabaseClient = _resolveSupabaseClient(config, client);
    final primary = SupabaseCommunityOverlayRepository(client: supabaseClient);

    if (communityDebugBypassEnabled) {
      return primary;
    }
    return CachedCommunityOverlayRepository(
      primary: primary,
      cache: SharedPreferencesCommunityOverlayCacheRepository(),
    );
  }
}
