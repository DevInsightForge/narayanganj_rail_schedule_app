import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../../domain/entities/device_identity.dart';
import '../../../domain/entities/firebase_identity_state.dart';
import '../../../domain/repositories/device_identity_repository.dart';
import '../../../domain/repositories/firebase_identity_state_repository.dart';

class FirebaseResolvedIdentity {
  const FirebaseResolvedIdentity({
    required this.uid,
    required this.createdAt,
    required this.lastSeenAt,
  });

  final String uid;
  final DateTime createdAt;
  final DateTime lastSeenAt;
}

class FirebaseDeviceIdentityRepository implements DeviceIdentityRepository {
  FirebaseDeviceIdentityRepository({
    FirebaseAuth? auth,
    FirebaseFirestore? firestore,
    required FirebaseIdentityStateRepository identityStateRepository,
    Future<FirebaseResolvedIdentity> Function()? identityResolver,
    Future<void> Function(String uid, DateTime now)? profileWriter,
  }) : assert(auth != null || identityResolver != null),
       assert(firestore != null || profileWriter != null),
       _auth = auth,
       _firestore = firestore,
       _identityStateRepository = identityStateRepository,
       _identityResolver = identityResolver,
       _profileWriter = profileWriter;

  final FirebaseAuth? _auth;
  final FirebaseFirestore? _firestore;
  final FirebaseIdentityStateRepository _identityStateRepository;
  final Future<FirebaseResolvedIdentity> Function()? _identityResolver;
  final Future<void> Function(String uid, DateTime now)? _profileWriter;

  @override
  Future<DeviceIdentity> readOrCreateIdentity() async {
    final resolved = await (_identityResolver?.call() ?? _resolveIdentity());
    final existingState = await _identityStateRepository.read();
    final nextState =
        existingState == null || existingState.uid != resolved.uid
        ? FirebaseIdentityState(
            uid: resolved.uid,
            handshakeCompleted: true,
          )
        : existingState.copyWith(
            uid: resolved.uid,
            handshakeCompleted: true,
          );
    await _identityStateRepository.write(nextState);
    return DeviceIdentity(
      deviceId: resolved.uid,
      createdAt: resolved.createdAt,
      lastSeenAt: resolved.lastSeenAt,
    );
  }

  @override
  Future<void> touchIdentity(DateTime now) async {
    final identity = await readOrCreateIdentity();
    final state = await _identityStateRepository.read();
    if (state != null &&
        state.uid == identity.deviceId &&
        state.profileWrittenAt != null) {
      return;
    }
    await (_profileWriter?.call(identity.deviceId, now) ??
        _writeProfile(identity.deviceId, now));
    await _identityStateRepository.write(
      FirebaseIdentityState(
        uid: identity.deviceId,
        handshakeCompleted: true,
        profileWrittenAt: now,
      ),
    );
  }

  Future<FirebaseResolvedIdentity> _resolveIdentity() async {
    final auth = _auth;
    if (auth == null) {
      throw StateError('Missing FirebaseAuth instance.');
    }
    var user = auth.currentUser;
    if (user == null) {
      final credential = await auth.signInAnonymously();
      user = credential.user;
    }
    if (user == null) {
      throw StateError('Unable to resolve anonymous Firebase identity.');
    }
    final metadata = user.metadata;
    return FirebaseResolvedIdentity(
      uid: user.uid,
      createdAt: metadata.creationTime ?? DateTime.now(),
      lastSeenAt: metadata.lastSignInTime ?? DateTime.now(),
    );
  }

  Future<void> _writeProfile(String uid, DateTime now) async {
    final firestore = _firestore;
    if (firestore == null) {
      throw StateError('Missing FirebaseFirestore instance.');
    }
    await firestore.collection('user_profiles').doc(uid).set({
      'uid': uid,
      'lastSeenAt': Timestamp.fromDate(now),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }
}
