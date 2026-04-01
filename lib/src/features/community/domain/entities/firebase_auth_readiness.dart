import 'package:equatable/equatable.dart';

enum FirebaseAuthReadinessStatus { unknown, resolving, ready, failed }

class FirebaseAuthReadiness extends Equatable {
  const FirebaseAuthReadiness._(this.status, {this.uid});

  const FirebaseAuthReadiness.unknown()
    : this._(FirebaseAuthReadinessStatus.unknown);

  const FirebaseAuthReadiness.resolving()
    : this._(FirebaseAuthReadinessStatus.resolving);

  const FirebaseAuthReadiness.ready(String uid)
    : this._(FirebaseAuthReadinessStatus.ready, uid: uid);

  const FirebaseAuthReadiness.failed()
    : this._(FirebaseAuthReadinessStatus.failed);

  final FirebaseAuthReadinessStatus status;
  final String? uid;

  bool get isReady => status == FirebaseAuthReadinessStatus.ready;

  @override
  List<Object?> get props => [status, uid];
}
