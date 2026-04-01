import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../../domain/entities/firebase_identity_state.dart';
import '../../../domain/repositories/firebase_identity_state_repository.dart';

class SharedPreferencesFirebaseIdentityStateRepository
    implements FirebaseIdentityStateRepository {
  static const _storageKey = 'nrs:community:firebase-identity-state';

  @override
  Future<FirebaseIdentityState?> read() async {
    final preferences = await SharedPreferences.getInstance();
    final raw = preferences.getString(_storageKey);
    if (raw == null || raw.isEmpty) {
      return null;
    }
    final decoded = jsonDecode(raw);
    if (decoded is! Map<String, dynamic>) {
      return null;
    }
    final uid = '${decoded['uid'] ?? ''}'.trim();
    if (uid.isEmpty) {
      return null;
    }
    return FirebaseIdentityState(
      uid: uid,
      handshakeCompleted: decoded['handshakeCompleted'] == true,
    );
  }

  @override
  Future<void> write(FirebaseIdentityState state) async {
    final preferences = await SharedPreferences.getInstance();
    final payload = <String, dynamic>{
      'uid': state.uid,
      'handshakeCompleted': state.handshakeCompleted,
    };
    await preferences.setString(_storageKey, jsonEncode(payload));
  }
}
