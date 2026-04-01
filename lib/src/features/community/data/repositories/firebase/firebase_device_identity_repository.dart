import 'package:firebase_auth/firebase_auth.dart';

import '../../../../../core/errors/error_report_context.dart';
import '../../../../../core/errors/error_reporter.dart';
import '../../../domain/entities/device_identity.dart';
import '../../../domain/entities/firebase_auth_readiness.dart';
import '../../../domain/entities/firebase_identity_state.dart';
import '../../../domain/repositories/device_identity_repository.dart';
import '../../../domain/repositories/firebase_identity_state_repository.dart';

class FirebaseResolvedIdentity {
  const FirebaseResolvedIdentity({
    required this.uid,
    required this.createdAt,
    required this.lastSeenAt,
  });

  final String uid;
  final DateTime createdAt;
  final DateTime lastSeenAt;
}

class FirebaseDeviceIdentityRepository implements DeviceIdentityRepository {
  FirebaseDeviceIdentityRepository({
    FirebaseAuth? auth,
    required FirebaseIdentityStateRepository identityStateRepository,
    Future<FirebaseResolvedIdentity> Function()? identityResolver,
    ErrorReporter? errorReporter,
  }) : assert(auth != null || identityResolver != null),
       _auth = auth,
       _identityStateRepository = identityStateRepository,
       _identityResolver = identityResolver,
       _errorReporter = errorReporter ?? const NoopErrorReporter();

  final FirebaseAuth? _auth;
  final FirebaseIdentityStateRepository _identityStateRepository;
  final Future<FirebaseResolvedIdentity> Function()? _identityResolver;
  final ErrorReporter _errorReporter;
  Future<FirebaseAuthReadiness>? _pendingAuthReadiness;
  FirebaseAuthReadiness _cachedAuthReadiness =
      const FirebaseAuthReadiness.unknown();

  @override
  Future<FirebaseAuthReadiness> readAuthReadiness({String? attemptId}) {
    final cached = _cachedAuthReadiness;
    if (cached.status == FirebaseAuthReadinessStatus.ready ||
        cached.status == FirebaseAuthReadinessStatus.failed) {
      return Future.value(cached);
    }

    final pending = _pendingAuthReadiness;
    if (pending != null) {
      return pending;
    }

    final future = _resolveAuthReadiness(attemptId: attemptId);
    _pendingAuthReadiness = future;
    return future;
  }

  @override
  Future<DeviceIdentity> readOrCreateIdentity({String? attemptId}) async {
    final resolved = await (_identityResolver?.call() ?? _resolveIdentity());
    final existingState = await _identityStateRepository.read();
    final nextState = existingState == null || existingState.uid != resolved.uid
        ? FirebaseIdentityState(uid: resolved.uid, handshakeCompleted: true)
        : existingState.copyWith(uid: resolved.uid, handshakeCompleted: true);
    await _identityStateRepository.write(nextState);
    _cachedAuthReadiness = FirebaseAuthReadiness.ready(resolved.uid);
    return DeviceIdentity(
      deviceId: resolved.uid,
      createdAt: resolved.createdAt,
      lastSeenAt: resolved.lastSeenAt,
    );
  }

  Future<FirebaseResolvedIdentity> _resolveIdentity() async {
    final auth = _auth;
    if (auth == null) {
      throw StateError('Missing FirebaseAuth instance.');
    }
    var user = auth.currentUser;
    if (user == null) {
      final credential = await auth.signInAnonymously();
      user = credential.user;
    }
    if (user == null) {
      throw StateError('Unable to resolve anonymous Firebase identity.');
    }
    final metadata = user.metadata;
    return FirebaseResolvedIdentity(
      uid: user.uid,
      createdAt: metadata.creationTime ?? DateTime.now(),
      lastSeenAt: metadata.lastSignInTime ?? DateTime.now(),
    );
  }

  Future<FirebaseAuthReadiness> _resolveAuthReadiness({
    String? attemptId,
  }) async {
    _cachedAuthReadiness = const FirebaseAuthReadiness.resolving();
    try {
      final existingState = await _identityStateRepository.read();
      if (existingState != null &&
          existingState.handshakeCompleted &&
          existingState.uid.isNotEmpty) {
        final ready = FirebaseAuthReadiness.ready(existingState.uid);
        _cachedAuthReadiness = ready;
        return ready;
      }

      final resolved = await (_identityResolver?.call() ?? _resolveIdentity());
      final nextState =
          existingState == null || existingState.uid != resolved.uid
          ? FirebaseIdentityState(uid: resolved.uid, handshakeCompleted: true)
          : existingState.copyWith(uid: resolved.uid, handshakeCompleted: true);
      await _identityStateRepository.write(nextState);
      final ready = FirebaseAuthReadiness.ready(resolved.uid);
      _cachedAuthReadiness = ready;
      return ready;
    } catch (error, stackTrace) {
      final failed = const FirebaseAuthReadiness.failed();
      _cachedAuthReadiness = failed;
      await _errorReporter.reportNonFatal(
        error,
        stackTrace,
        reason: 'auth_resolve_failed',
        context: _context(attemptId: attemptId),
      );
      return failed;
    } finally {
      _pendingAuthReadiness = null;
    }
  }

  ErrorReportContext _context({String? attemptId, String? uid}) {
    return ErrorReportContext(
      feature: 'community_auth',
      event: 'read_auth_readiness',
      attemptId: attemptId,
      uid: uid,
    );
  }
}
