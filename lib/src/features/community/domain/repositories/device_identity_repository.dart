import '../entities/anonymous_profile.dart';
import '../entities/device_identity.dart';

abstract class DeviceIdentityRepository {
  Future<DeviceIdentity> readOrCreateIdentity();

  Future<void> touchIdentity(DateTime now);

  Future<AnonymousProfile> readProfile(String deviceId);

  Future<void> saveProfile(AnonymousProfile profile);
}
