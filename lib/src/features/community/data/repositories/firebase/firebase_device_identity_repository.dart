import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../../domain/entities/anonymous_profile.dart';
import '../../../domain/entities/device_identity.dart';
import '../../../domain/repositories/device_identity_repository.dart';

class FirebaseDeviceIdentityRepository implements DeviceIdentityRepository {
  FirebaseDeviceIdentityRepository({
    required FirebaseAuth auth,
    required FirebaseFirestore firestore,
  }) : _auth = auth,
       _firestore = firestore;

  final FirebaseAuth _auth;
  final FirebaseFirestore _firestore;

  @override
  Future<AnonymousProfile> readProfile(String deviceId) async {
    final doc = await _firestore
        .collection('user_profiles')
        .doc(deviceId)
        .get();
    final data = doc.data();
    return AnonymousProfile(
      deviceId: deviceId,
      displayName: data == null ? null : data['displayName'] as String?,
    );
  }

  @override
  Future<DeviceIdentity> readOrCreateIdentity() async {
    var user = _auth.currentUser;
    if (user == null) {
      final credential = await _auth.signInAnonymously();
      user = credential.user;
    }
    if (user == null) {
      throw StateError('Unable to resolve anonymous Firebase identity.');
    }
    final metadata = user.metadata;
    final createdAt = metadata.creationTime ?? DateTime.now();
    final lastSeenAt = metadata.lastSignInTime ?? DateTime.now();
    return DeviceIdentity(
      deviceId: user.uid,
      createdAt: createdAt,
      lastSeenAt: lastSeenAt,
    );
  }

  @override
  Future<void> saveProfile(AnonymousProfile profile) async {
    await _firestore.collection('user_profiles').doc(profile.deviceId).set({
      'uid': profile.deviceId,
      'displayName': profile.displayName,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  @override
  Future<void> touchIdentity(DateTime now) async {
    final identity = await readOrCreateIdentity();
    await _firestore.collection('user_profiles').doc(identity.deviceId).set({
      'uid': identity.deviceId,
      'lastSeenAt': Timestamp.fromDate(now),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }
}
