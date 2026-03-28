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
  Future<DeviceIdentity> readOrCreateIdentity() async {
    try {
      return await _primary.readOrCreateIdentity();
    } catch (_) {
      return _fallback.readOrCreateIdentity();
    }
  }

  @override
  Future<void> touchIdentity(DateTime now) async {
    await _fallback.touchIdentity(now);
    try {
      await _primary.touchIdentity(now);
    } catch (_) {}
  }
}
