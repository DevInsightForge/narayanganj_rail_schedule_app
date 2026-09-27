import 'package:flutter_test/flutter_test.dart';
import 'package:narayanganj_rail_schedule/src/bootstrap/app_composition.dart';
import 'package:narayanganj_rail_schedule/src/core/api/api_config.dart';
import 'package:narayanganj_rail_schedule/src/features/community/data/repositories/edge_community_repository.dart';
import 'package:narayanganj_rail_schedule/src/features/community/data/repositories/noop_community_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test(
    'builds composition with bundled schedule when api is disabled',
    () async {
      final composition = await AppComposition.initialize(
        apiConfig: const ApiConfig(
          baseUrl: 'https://api.test.local',
          enabled: false,
        ),
      );

      expect(composition.apiConfig.enabled, isFalse);
      expect(composition.communityRepository, isA<NoOpCommunityRepository>());
      expect(composition.bundledSchedule.stations, isNotEmpty);
      expect(composition.bundledSchedule.trips, isNotEmpty);
    },
  );

  test(
    'builds composition with Edge repositories when api is enabled',
    () async {
      final composition = await AppComposition.initialize(
        apiConfig: const ApiConfig(
          baseUrl: 'https://api.test.local',
          apiSecret: 'test-secret',
          enabled: true,
        ),
      );

      expect(composition.apiConfig.enabled, isTrue);
      expect(composition.communityRepository, isA<EdgeCommunityRepository>());

      final cubit = composition.createRailBoardCubit();
      expect(cubit.communityFeaturesEnabled, isTrue);
      await cubit.close();
    },
  );
}
