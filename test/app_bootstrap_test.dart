import 'package:flutter_test/flutter_test.dart';
import 'package:narayanganj_rail_schedule/src/bootstrap/app_bootstrap.dart';
import 'package:narayanganj_rail_schedule/src/core/firebase/firebase_bootstrap.dart';
import 'package:narayanganj_rail_schedule/src/core/firebase/firebase_runtime.dart';
import 'package:narayanganj_rail_schedule/src/features/community/data/repositories/noop/noop_arrival_report_repository.dart';
import 'package:narayanganj_rail_schedule/src/features/community/data/repositories/noop/noop_community_overlay_repository.dart';
import 'package:narayanganj_rail_schedule/src/features/community/data/repositories/noop/noop_device_identity_repository.dart';

void main() {
  test(
    'builds composition with bundled schedule when firebase is disabled',
    () async {
      final composition = await AppBootstrap(
        firebaseBootstrap: _FakeFirebaseBootstrap(FirebaseRuntime.disabled),
      ).initialize();

      expect(composition.firebaseRuntime.enabled, isFalse);
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
        isA<NoOpDeviceIdentityRepository>(),
      );
      expect(composition.bundledSchedule.stations, isNotEmpty);
      expect(composition.bundledSchedule.trips, isNotEmpty);
    },
  );

  test(
    'creates a board cubit with community feature gating from runtime',
    () async {
      final composition = await AppBootstrap(
        firebaseBootstrap: _FakeFirebaseBootstrap(
          const FirebaseRuntime(
            enabled: true,
            initialized: false,
            appCheckEnabled: false,
            errorReportingEnabled: false,
            status: 'failed',
          ),
        ),
      ).initialize();

      final cubit = composition.createRailBoardCubit();

      expect(cubit.communityFeaturesEnabled, isFalse);
      await cubit.close();
    },
  );
}

class _FakeFirebaseBootstrap extends FirebaseBootstrap {
  _FakeFirebaseBootstrap(this.runtime);

  final FirebaseRuntime runtime;

  @override
  Future<FirebaseRuntime> initialize() async => runtime;
}
