import 'package:flutter_test/flutter_test.dart';
import 'package:narayanganj_rail_schedule/src/features/community/data/repositories/firebase/firebase_device_identity_repository.dart';
import 'package:narayanganj_rail_schedule/src/features/community/data/repositories/local/shared_preferences_firebase_identity_state_repository.dart';
import 'package:narayanganj_rail_schedule/src/features/community/domain/entities/firebase_identity_state.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('first handshake writes profile once and persists state', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    var profileWriteCount = 0;
    final repository = FirebaseDeviceIdentityRepository(
      identityStateRepository: SharedPreferencesFirebaseIdentityStateRepository(),
      identityResolver: () async => FirebaseResolvedIdentity(
        uid: 'uid-1',
        createdAt: DateTime(2026, 3, 30, 9, 0),
        lastSeenAt: DateTime(2026, 3, 30, 9, 0),
      ),
      profileWriter: (uid, now) async {
        profileWriteCount += 1;
      },
    );

    await repository.readOrCreateIdentity();
    await repository.touchIdentity(DateTime(2026, 3, 30, 9, 1));
    await repository.touchIdentity(DateTime(2026, 3, 30, 9, 2));

    expect(profileWriteCount, equals(1));
  });

  test('subsequent launches reuse persisted handshake without rewriting profile', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final stateRepository = SharedPreferencesFirebaseIdentityStateRepository();
    await stateRepository.write(
      const FirebaseIdentityState(
        uid: 'uid-1',
        handshakeCompleted: true,
      ),
    );

    var profileWriteCount = 0;
    final repository = FirebaseDeviceIdentityRepository(
      identityStateRepository: stateRepository,
      identityResolver: () async => FirebaseResolvedIdentity(
        uid: 'uid-1',
        createdAt: DateTime(2026, 3, 30, 9, 0),
        lastSeenAt: DateTime(2026, 3, 30, 9, 0),
      ),
      profileWriter: (uid, now) async {
        profileWriteCount += 1;
      },
    );

    await repository.touchIdentity(DateTime(2026, 3, 30, 9, 1));
    await repository.touchIdentity(DateTime(2026, 3, 30, 9, 2));

    expect(profileWriteCount, equals(1));
  });
}
