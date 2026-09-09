import 'package:equatable/equatable.dart';

enum AuthReadinessStatus { unknown, resolving, ready, failed }

class AuthReadiness extends Equatable {
  const AuthReadiness._(this.status, {this.deviceId});

  const AuthReadiness.unknown() : this._(AuthReadinessStatus.unknown);

  const AuthReadiness.resolving() : this._(AuthReadinessStatus.resolving);

  const AuthReadiness.ready(String deviceId)
    : this._(AuthReadinessStatus.ready, deviceId: deviceId);

  const AuthReadiness.failed() : this._(AuthReadinessStatus.failed);

  final AuthReadinessStatus status;
  final String? deviceId;

  bool get isReady => status == AuthReadinessStatus.ready;

  @override
  List<Object?> get props => [status, deviceId];
}
