import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../../../core/errors/error_report_context.dart';
import '../../../../../core/logging/debug_logger.dart';
import '../../../domain/entities/community_overlay_result.dart';
import '../../../domain/entities/community_session_aggregate.dart';
import '../../../domain/entities/session_status_snapshot.dart';
import '../../../domain/repositories/community_overlay_repository.dart';
import '../../../domain/services/service_day_key.dart';
import '../../mappers/firestore_community_mapper.dart';
import '../../models/firestore_models.dart';

class FirebaseCommunityOverlayRepository implements CommunityOverlayRepository {
  FirebaseCommunityOverlayRepository({
    required FirebaseFirestore firestore,
    Future<Map<String, dynamic>?> Function(String sessionId)? loader,
    DateTime Function()? nowProvider,
    DebugLogger? logger,
  }) : _firestore = firestore,
       _loader = loader,
       _nowProvider = nowProvider ?? DateTime.now,
       _logger =
           logger ?? const DebugLogger('FirebaseCommunityOverlayRepository');

  final FirebaseFirestore _firestore;
  final Future<Map<String, dynamic>?> Function(String sessionId)? _loader;
  final DateTime Function() _nowProvider;
  final DebugLogger _logger;
  final FirestoreCommunityMapper _mapper = const FirestoreCommunityMapper();

  @override
  Future<CommunityOverlayResult> fetchSessionOverlay({
    required String sessionId,
    required DateTime serviceDate,
    bool forceRefresh = false,
  }) async {
    final data = await (_loader?.call(sessionId) ?? _load(sessionId));
    final fetchedAt = _nowProvider();
    if (data == null || data.isEmpty) {
      return CommunityOverlayResult(fetchedAt: fetchedAt, fromCache: false);
    }
    final aggregate = _readAggregate(data);
    if (aggregate == null ||
        !isSameServiceDay(aggregate.serviceDate, serviceDate)) {
      return CommunityOverlayResult(fetchedAt: fetchedAt, fromCache: false);
    }
    return CommunityOverlayResult(
      sessionStatusSnapshot: _readSnapshot(sessionId, aggregate),
      fetchedAt: fetchedAt,
      fromCache: false,
    );
  }

  Future<Map<String, dynamic>?> _load(String sessionId) async {
    try {
      final document = await _firestore
          .collection('session_status_snapshots')
          .doc(sessionId)
          .get();
      return document.data();
    } catch (error) {
      _logger.log(
        'overlay_load_fail',
        context: ErrorReportContext(
          feature: 'community_overlay',
          event: 'overlay_load',
          sessionId: sessionId,
        ).toMap(),
      );
      rethrow;
    }
  }

  SessionStatusSnapshot? _readSnapshot(
    String sessionId,
    CommunitySessionAggregate aggregate,
  ) {
    return SessionStatusSnapshot(
      sessionId: aggregate.sessionId.isEmpty ? sessionId : aggregate.sessionId,
      state: SessionLifecycleState.active,
      delayMinutes: aggregate.delayMinutes,
      delayStatus: aggregate.delayStatus,
      confidence: aggregate.confidence,
      freshnessSeconds: aggregate.freshnessSeconds,
      lastObservedAt: aggregate.lastObservedAt,
    );
  }

  CommunitySessionAggregate? _readAggregate(Map<String, dynamic> map) {
    try {
      return _mapper.toCommunitySessionAggregate(
        FirestoreSessionAggregateModel.fromMap(map),
      );
    } catch (_) {
      return null;
    }
  }
}
