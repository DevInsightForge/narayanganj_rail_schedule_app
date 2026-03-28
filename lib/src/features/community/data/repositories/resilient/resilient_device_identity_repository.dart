import '../../../domain/entities/anonymous_profile.dart';
import '../../../domain/entities/device_identity.dart';
import '../../../domain/repositories/device_identity_repository.dart';

class ResilientDeviceIdentityRepository implements DeviceIdentityRepository {
  ResilientDeviceIdentityRepository({
    required DeviceIdentityRepository primary,
    required DeviceIdentityRepository fallback,
  }) : _primary = primary,
       _fallback = fallback;

  final DeviceIdentityRepository _primary;
  final DeviceIdentityRepository _fallback;

  @override
  Future<AnonymousProfile> readProfile(String deviceId) async {
    try {
      return await _primary.readProfile(deviceId);
    } catch (_) {
      return _fallback.readProfile(deviceId);
    }
  }

  @override
  Future<DeviceIdentity> readOrCreateIdentity() async {
    try {
      return await _primary.readOrCreateIdentity();
    } catch (_) {
      return _fallback.readOrCreateIdentity();
    }
  }

  @override
  Future<void> saveProfile(AnonymousProfile profile) async {
    await _fallback.saveProfile(profile);
    try {
      await _primary.saveProfile(profile);
    } catch (_) {}
  }

  @override
  Future<void> touchIdentity(DateTime now) async {
    await _fallback.touchIdentity(now);
    try {
      await _primary.touchIdentity(now);
    } catch (_) {}
  }
}
