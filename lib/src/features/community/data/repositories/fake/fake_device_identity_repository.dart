import 'dart:math';

import '../../../domain/entities/device_identity.dart';
import '../../../domain/repositories/device_identity_repository.dart';

class FakeDeviceIdentityRepository implements DeviceIdentityRepository {
  DeviceIdentity? _identity;

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
