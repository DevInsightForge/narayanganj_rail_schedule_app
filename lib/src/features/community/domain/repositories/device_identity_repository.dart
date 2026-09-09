import '../entities/auth_readiness.dart';
import '../entities/device_identity.dart';

abstract class DeviceIdentityRepository {
  Future<AuthReadiness> readAuthReadiness({String? attemptId});

  Future<DeviceIdentity> readOrCreateIdentity({String? attemptId});
}
