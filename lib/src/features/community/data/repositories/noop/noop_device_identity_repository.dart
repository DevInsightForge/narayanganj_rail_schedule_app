import '../../../domain/entities/device_identity.dart';
import '../../../domain/entities/firebase_auth_readiness.dart';
import '../../../domain/repositories/device_identity_repository.dart';

class NoOpDeviceIdentityRepository implements DeviceIdentityRepository {
  const NoOpDeviceIdentityRepository();

  @override
  Future<FirebaseAuthReadiness> readAuthReadiness({String? attemptId}) async {
    return const FirebaseAuthReadiness.unknown();
  }

  @override
  Future<DeviceIdentity> readOrCreateIdentity({String? attemptId}) async {
    final now = DateTime.fromMillisecondsSinceEpoch(0);
    return DeviceIdentity(deviceId: 'noop', createdAt: now, lastSeenAt: now);
  }
}
