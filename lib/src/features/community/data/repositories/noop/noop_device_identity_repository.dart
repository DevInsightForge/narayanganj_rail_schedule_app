import '../../../domain/entities/auth_readiness.dart';
import '../../../domain/entities/device_identity.dart';
import '../../../domain/repositories/device_identity_repository.dart';

class NoOpDeviceIdentityRepository implements DeviceIdentityRepository {
  const NoOpDeviceIdentityRepository();

  @override
  Future<AuthReadiness> readAuthReadiness({String? attemptId}) async {
    return const AuthReadiness.unknown();
  }

  @override
  Future<DeviceIdentity> readOrCreateIdentity({String? attemptId}) async {
    final now = DateTime.now();
    return DeviceIdentity(
      deviceId: 'noop_device',
      createdAt: now,
      lastSeenAt: now,
    );
  }
}
