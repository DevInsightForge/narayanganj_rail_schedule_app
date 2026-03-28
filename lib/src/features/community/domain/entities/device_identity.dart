import 'package:equatable/equatable.dart';

class DeviceIdentity extends Equatable {
  const DeviceIdentity({
    required this.deviceId,
    required this.createdAt,
    required this.lastSeenAt,
  });

  final String deviceId;
  final DateTime createdAt;
  final DateTime lastSeenAt;

  DeviceIdentity copyWith({DateTime? lastSeenAt}) {
    return DeviceIdentity(
      deviceId: deviceId,
      createdAt: createdAt,
      lastSeenAt: lastSeenAt ?? this.lastSeenAt,
    );
  }

  @override
  List<Object> get props => [deviceId, createdAt, lastSeenAt];
}
