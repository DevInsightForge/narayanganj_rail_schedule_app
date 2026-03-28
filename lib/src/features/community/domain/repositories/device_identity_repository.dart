import '../entities/device_identity.dart';

abstract class DeviceIdentityRepository {
  Future<DeviceIdentity> readOrCreateIdentity();

  Future<void> touchIdentity(DateTime now);
}
