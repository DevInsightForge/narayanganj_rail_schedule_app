import '../entities/firebase_identity_state.dart';

abstract class FirebaseIdentityStateRepository {
  Future<FirebaseIdentityState?> read();

  Future<void> write(FirebaseIdentityState state);
}
