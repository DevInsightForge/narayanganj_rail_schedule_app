import 'package:flutter_test/flutter_test.dart';
import 'package:narayanganj_rail_schedule/src/bootstrap/app_bootstrap.dart';
import 'package:narayanganj_rail_schedule/src/core/api/api_config.dart';
import 'package:narayanganj_rail_schedule/src/features/community/data/repositories/local/local_device_identity_repository.dart';
import 'package:narayanganj_rail_schedule/src/features/community/data/repositories/noop/noop_arrival_report_repository.dart';
import 'package:narayanganj_rail_schedule/src/features/community/data/repositories/noop/noop_community_overlay_repository.dart';
import 'package:narayanganj_rail_schedule/src/features/community/data/repositories/supabase/supabase_arrival_report_repository.dart';
import 'package:narayanganj_rail_schedule/src/features/community/data/repositories/supabase/supabase_community_overlay_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });
  test(
    'builds composition with bundled schedule when api is disabled',
    () async {
      final composition = await AppBootstrap(
        apiConfig: const ApiConfig(
          baseUrl: 'https://api.test.local',
          enabled: false,
        ),
      ).initialize();

      expect(composition.apiConfig.enabled, isFalse);
      expect(
        composition.arrivalReportRepository,
        isA<NoOpArrivalReportRepository>(),
      );
      expect(
        composition.communityOverlayRepository,
        isA<NoOpCommunityOverlayRepository>(),
      );
      expect(
        composition.deviceIdentityRepository,
        isA<LocalDeviceIdentityRepository>(),
      );
      expect(composition.bundledSchedule.stations, isNotEmpty);
      expect(composition.bundledSchedule.trips, isNotEmpty);
    },
  );

  test(
    'builds composition with Supabase repositories when api is enabled',
    () async {
      final composition = await AppBootstrap(
        apiConfig: const ApiConfig(
          baseUrl: 'https://api.test.local',
          apiKey: 'test-key',
          enabled: true,
        ),
      ).initialize();

      expect(composition.apiConfig.enabled, isTrue);
      expect(
        composition.arrivalReportRepository,
        isA<SupabaseArrivalReportRepository>(),
      );
      expect(
        composition.communityOverlayRepository,
        isA<SupabaseCommunityOverlayRepository>(),
      );
      expect(
        composition.deviceIdentityRepository,
        isA<LocalDeviceIdentityRepository>(),
      );

      final cubit = composition.createRailBoardCubit();
      expect(cubit.communityFeaturesEnabled, isTrue);
      await cubit.close();
    },
  );
}
