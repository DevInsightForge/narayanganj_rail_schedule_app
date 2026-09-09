import 'package:flutter_test/flutter_test.dart';
import 'package:narayanganj_rail_schedule/src/features/community/data/repositories/local/local_device_identity_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('LocalDeviceIdentityRepository', () {
    test(
      'generates and persists a new device identity when none exists',
      () async {
        SharedPreferences.setMockInitialValues({});
        final repository = LocalDeviceIdentityRepository();

        final identity = await repository.readOrCreateIdentity();
        expect(identity.deviceId, startsWith('anon_'));
        expect(identity.deviceId.length, greaterThan(10));

        final readiness = await repository.readAuthReadiness();
        expect(readiness.isReady, isTrue);
        expect(readiness.deviceId, equals(identity.deviceId));
      },
    );

    test('reuses existing device identity when already persisted', () async {
      SharedPreferences.setMockInitialValues({
        'nrs:community:device-identity-id': 'custom_device_12345',
        'nrs:community:device-identity-created': '2026-08-26T10:00:00.000Z',
      });
      final repository = LocalDeviceIdentityRepository();

      final identity = await repository.readOrCreateIdentity();
      expect(identity.deviceId, equals('custom_device_12345'));

      final readiness = await repository.readAuthReadiness();
      expect(readiness.isReady, isTrue);
      expect(readiness.deviceId, equals('custom_device_12345'));
    });
  });
}
