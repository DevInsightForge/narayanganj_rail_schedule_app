import 'package:flutter_test/flutter_test.dart';
import 'package:narayanganj_rail_schedule/src/bootstrap/app_bootstrap.dart';
import 'package:narayanganj_rail_schedule/src/core/firebase/firebase_bootstrap.dart';
import 'package:narayanganj_rail_schedule/src/core/firebase/firebase_runtime.dart';

void main() {
  test(
    'builds composition with bundled schedule when firebase is disabled',
    () async {
      final composition = await AppBootstrap(
        firebaseBootstrap: _FakeFirebaseBootstrap(FirebaseRuntime.disabled),
      ).initialize();

      expect(composition.firebaseRuntime.enabled, isFalse);
      expect(composition.bundledSchedule.stations, isNotEmpty);
      expect(composition.bundledSchedule.trips, isNotEmpty);
    },
  );

  test(
    'creates a board bloc with community feature gating from runtime',
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

      final bloc = composition.createRailBoardBloc();

      expect(bloc.communityFeaturesEnabled, isFalse);
      await bloc.close();
    },
  );
}

class _FakeFirebaseBootstrap extends FirebaseBootstrap {
  _FakeFirebaseBootstrap(this.runtime);

  final FirebaseRuntime runtime;

  @override
  Future<FirebaseRuntime> initialize() async => runtime;
}
