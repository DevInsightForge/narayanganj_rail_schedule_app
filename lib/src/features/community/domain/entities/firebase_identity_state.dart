import 'package:equatable/equatable.dart';

class FirebaseIdentityState extends Equatable {
  const FirebaseIdentityState({
    required this.uid,
    required this.handshakeCompleted,
  });

  final String uid;
  final bool handshakeCompleted;

  FirebaseIdentityState copyWith({String? uid, bool? handshakeCompleted}) {
    return FirebaseIdentityState(
      uid: uid ?? this.uid,
      handshakeCompleted: handshakeCompleted ?? this.handshakeCompleted,
    );
  }

  @override
  List<Object?> get props => [uid, handshakeCompleted];
}
