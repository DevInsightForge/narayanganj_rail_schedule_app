import '../entities/firebase_auth_readiness.dart';
import '../entities/device_identity.dart';

abstract class DeviceIdentityRepository {
  Future<FirebaseAuthReadiness> readAuthReadiness({String? attemptId});

  Future<DeviceIdentity> readOrCreateIdentity({String? attemptId});
}
