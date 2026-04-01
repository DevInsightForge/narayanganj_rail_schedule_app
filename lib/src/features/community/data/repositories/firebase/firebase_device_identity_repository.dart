import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../../../../core/errors/error_report_context.dart';
import '../../../../../core/errors/error_reporter.dart';
import '../../../../../core/logging/debug_logger.dart';
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
    FirebaseFirestore? firestore,
    required FirebaseIdentityStateRepository identityStateRepository,
    Future<FirebaseResolvedIdentity> Function()? identityResolver,
    Future<void> Function(String uid, DateTime now)? profileWriter,
    ErrorReporter? errorReporter,
    DebugLogger? logger,
  }) : assert(auth != null || identityResolver != null),
       assert(firestore != null || profileWriter != null),
       _auth = auth,
       _firestore = firestore,
       _identityStateRepository = identityStateRepository,
       _identityResolver = identityResolver,
       _profileWriter = profileWriter,
       _errorReporter = errorReporter ?? const NoopErrorReporter(),
       _logger =
           logger ?? const DebugLogger('FirebaseDeviceIdentityRepository');

  final FirebaseAuth? _auth;
  final FirebaseFirestore? _firestore;
  final FirebaseIdentityStateRepository _identityStateRepository;
  final Future<FirebaseResolvedIdentity> Function()? _identityResolver;
  final Future<void> Function(String uid, DateTime now)? _profileWriter;
  final ErrorReporter _errorReporter;
  final DebugLogger _logger;
  Future<FirebaseAuthReadiness>? _pendingAuthReadiness;
  FirebaseAuthReadiness _cachedAuthReadiness =
      const FirebaseAuthReadiness.unknown();

  @override
  Future<FirebaseAuthReadiness> readAuthReadiness({String? attemptId}) {
    final cached = _cachedAuthReadiness;
    if (cached.status == FirebaseAuthReadinessStatus.ready ||
        cached.status == FirebaseAuthReadinessStatus.failed) {
      _logger.log(
        'auth_resolve_cached',
        context: _context(attemptId: attemptId, uid: cached.uid).toMap(),
      );
      return Future.value(cached);
    }

    final pending = _pendingAuthReadiness;
    if (pending != null) {
      _logger.log(
        'auth_resolve_pending',
        context: _context(attemptId: attemptId).toMap(),
      );
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

  @override
  Future<void> touchIdentity(DateTime now, {String? attemptId}) async {
    final identity = await readOrCreateIdentity(attemptId: attemptId);
    final state = await _identityStateRepository.read();
    if (state != null &&
        state.uid == identity.deviceId &&
        state.profileWrittenAt != null) {
      return;
    }
    await (_profileWriter?.call(identity.deviceId, now) ??
        _writeProfile(identity.deviceId, now));
    await _identityStateRepository.write(
      FirebaseIdentityState(
        uid: identity.deviceId,
        handshakeCompleted: true,
        profileWrittenAt: now,
      ),
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

  Future<void> _writeProfile(String uid, DateTime now) async {
    final firestore = _firestore;
    if (firestore == null) {
      throw StateError('Missing FirebaseFirestore instance.');
    }
    await firestore.collection('user_profiles').doc(uid).set({
      'uid': uid,
      'lastSeenAt': Timestamp.fromDate(now),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<FirebaseAuthReadiness> _resolveAuthReadiness({
    String? attemptId,
  }) async {
    _cachedAuthReadiness = const FirebaseAuthReadiness.resolving();
    _logger.log(
      'auth_resolve_start',
      context: _context(attemptId: attemptId).toMap(),
    );
    try {
      final existingState = await _identityStateRepository.read();
      if (existingState != null &&
          existingState.handshakeCompleted &&
          existingState.uid.isNotEmpty) {
        final ready = FirebaseAuthReadiness.ready(existingState.uid);
        _cachedAuthReadiness = ready;
        _logger.log(
          'auth_resolve_success',
          context: _context(
            attemptId: attemptId,
            uid: existingState.uid,
          ).toMap(),
        );
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
      _logger.log(
        'auth_resolve_success',
        context: _context(attemptId: attemptId, uid: resolved.uid).toMap(),
      );
      return ready;
    } catch (error, stackTrace) {
      final failed = const FirebaseAuthReadiness.failed();
      _cachedAuthReadiness = failed;
      _logger.log(
        'auth_resolve_fail',
        context: _context(attemptId: attemptId).toMap(),
      );
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
