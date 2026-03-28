import 'dart:math';

import '../../../domain/entities/anonymous_profile.dart';
import '../../../domain/entities/device_identity.dart';
import '../../../domain/repositories/device_identity_repository.dart';

class FakeDeviceIdentityRepository implements DeviceIdentityRepository {
  DeviceIdentity? _identity;
  AnonymousProfile? _profile;

  @override
  Future<AnonymousProfile> readProfile(String deviceId) async {
    final existing = _profile;
    if (existing != null && existing.deviceId == deviceId) {
      return existing;
    }
    final profile = AnonymousProfile(deviceId: deviceId);
    _profile = profile;
    return profile;
  }

  @override
  Future<DeviceIdentity> readOrCreateIdentity() async {
    final existing = _identity;
    if (existing != null) {
      return existing;
    }
    final now = DateTime.now();
    final created = DeviceIdentity(
      deviceId: _generateDeviceId(),
      createdAt: now,
      lastSeenAt: now,
    );
    _identity = created;
    return created;
  }

  @override
  Future<void> saveProfile(AnonymousProfile profile) async {
    _profile = profile;
  }

  @override
  Future<void> touchIdentity(DateTime now) async {
    final identity = await readOrCreateIdentity();
    _identity = identity.copyWith(lastSeenAt: now);
  }

  String _generateDeviceId() {
    final random = Random.secure();
    final timestamp = DateTime.now().microsecondsSinceEpoch.toRadixString(16);
    final entropy = List.generate(
      6,
      (_) => random.nextInt(256).toRadixString(16).padLeft(2, '0'),
    ).join();
    return 'dev-$timestamp-$entropy';
  }
}
