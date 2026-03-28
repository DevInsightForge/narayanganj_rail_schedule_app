import 'package:equatable/equatable.dart';

class AnonymousProfile extends Equatable {
  const AnonymousProfile({required this.deviceId, this.displayName});

  final String deviceId;
  final String? displayName;

  AnonymousProfile copyWith({String? displayName}) {
    return AnonymousProfile(
      deviceId: deviceId,
      displayName: displayName ?? this.displayName,
    );
  }

  @override
  List<Object?> get props => [deviceId, displayName];
}
