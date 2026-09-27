import '../core/api/api_config.dart';
import '../core/api/edge_hmac_client.dart';
import '../features/community/data/repositories/edge_community_repository.dart';
import '../features/community/data/repositories/noop_community_repository.dart';
import '../features/community/domain/repositories/community_repository.dart';
import '../features/rail/data/repositories/bundled_schedule_source.dart';
import '../features/rail/data/repositories/shared_preferences_selection_repository.dart';
import '../features/rail/domain/entities/rail_schedule.dart';
import '../features/rail/domain/repositories/selection_repository.dart';
import '../features/rail/domain/services/rail_board_service.dart';
import '../features/rail/presentation/bloc/rail_board_cubit.dart';

class AppComposition {
  AppComposition({
    required this.bundledSchedule,
    ApiConfig? apiConfig,
    EdgeHmacClient? edgeClient,
    SelectionRepository? selectionRepository,
    CommunityRepository? communityRepository,
  }) : apiConfig = apiConfig ?? ApiConfig.fromEnv(),
       selectionRepository =
           selectionRepository ?? SharedPreferencesSelectionRepository(),
       communityRepository =
           communityRepository ??
           _buildCommunityRepository(
             apiConfig ?? ApiConfig.fromEnv(),
             edgeClient,
           );

  final RailSchedule bundledSchedule;
  final ApiConfig apiConfig;
  final SelectionRepository selectionRepository;
  final CommunityRepository communityRepository;

  static Future<AppComposition> initialize({ApiConfig? apiConfig}) async {
    final resolvedConfig = apiConfig ?? ApiConfig.fromEnv();
    final schedule = const BundledScheduleSource().loadSchedule();
    return AppComposition(bundledSchedule: schedule, apiConfig: resolvedConfig);
  }

  RailBoardCubit createRailBoardCubit() {
    return RailBoardCubit(
      boardService: RailBoardService(schedule: bundledSchedule),
      selectionRepository: selectionRepository,
      communityRepository: communityRepository,
      communityFeaturesEnabled: apiConfig.enabled,
    );
  }

  static CommunityRepository _buildCommunityRepository(
    ApiConfig config,
    EdgeHmacClient? client,
  ) {
    if (!config.isValid) {
      return const NoOpCommunityRepository();
    }
    final edgeClient =
        client ??
        EdgeHmacClient(
          baseUrl: config.baseUrl,
          appSecret: config.apiSecret!,
          timeout: config.timeout,
        );
    return EdgeCommunityRepository(client: edgeClient);
  }
}
