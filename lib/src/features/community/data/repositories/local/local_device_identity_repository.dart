import 'dart:math';

import 'package:shared_preferences/shared_preferences.dart';

import '../../../domain/entities/auth_readiness.dart';
import '../../../domain/entities/device_identity.dart';
import '../../../domain/repositories/device_identity_repository.dart';

class LocalDeviceIdentityRepository implements DeviceIdentityRepository {
  LocalDeviceIdentityRepository({SharedPreferences? preferences})
    : _preferences = preferences;

  static const _storageKey = 'nrs:community:device-identity-id';
  static const _createdAtKey = 'nrs:community:device-identity-created';
  final SharedPreferences? _preferences;

  @override
  Future<AuthReadiness> readAuthReadiness({String? attemptId}) async {
    final identity = await readOrCreateIdentity(attemptId: attemptId);
    return AuthReadiness.ready(identity.deviceId);
  }

  @override
  Future<DeviceIdentity> readOrCreateIdentity({String? attemptId}) async {
    final prefs = _preferences ?? await SharedPreferences.getInstance();
    var deviceId = prefs.getString(_storageKey);
    final createdAtRaw = prefs.getString(_createdAtKey);

    final now = DateTime.now();
    DateTime createdAt;

    if (deviceId == null || deviceId.isEmpty) {
      final random = Random();
      final randomHex = List.generate(
        16,
        (_) => random.nextInt(16).toRadixString(16),
      ).join();
      deviceId = 'anon_${now.millisecondsSinceEpoch}_$randomHex';
      createdAt = now;

      await prefs.setString(_storageKey, deviceId);
      await prefs.setString(_createdAtKey, createdAt.toIso8601String());
    } else {
      createdAt = DateTime.tryParse(createdAtRaw ?? '') ?? now;
    }

    return DeviceIdentity(
      deviceId: deviceId,
      createdAt: createdAt,
      lastSeenAt: now,
    );
  }
}
