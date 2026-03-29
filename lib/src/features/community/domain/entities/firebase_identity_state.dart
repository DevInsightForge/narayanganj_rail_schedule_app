import 'package:equatable/equatable.dart';

class FirebaseIdentityState extends Equatable {
  const FirebaseIdentityState({
    required this.uid,
    required this.handshakeCompleted,
    this.profileWrittenAt,
  });

  final String uid;
  final bool handshakeCompleted;
  final DateTime? profileWrittenAt;

  FirebaseIdentityState copyWith({
    String? uid,
    bool? handshakeCompleted,
    DateTime? profileWrittenAt,
    bool clearProfileWrittenAt = false,
  }) {
    return FirebaseIdentityState(
      uid: uid ?? this.uid,
      handshakeCompleted: handshakeCompleted ?? this.handshakeCompleted,
      profileWrittenAt: clearProfileWrittenAt
          ? null
          : profileWrittenAt ?? this.profileWrittenAt,
    );
  }

  @override
  List<Object?> get props => [uid, handshakeCompleted, profileWrittenAt];
}
