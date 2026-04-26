import 'package:narayanganj_rail_schedule/src/features/community/domain/entities/arrival_report.dart';
import 'package:narayanganj_rail_schedule/src/features/community/domain/entities/arrival_report_submission.dart';
import 'package:narayanganj_rail_schedule/src/features/community/domain/entities/community_session_aggregate.dart';
import 'package:narayanganj_rail_schedule/src/features/community/domain/entities/device_identity.dart';
import 'package:narayanganj_rail_schedule/src/features/community/domain/entities/firebase_auth_readiness.dart';
import 'package:narayanganj_rail_schedule/src/features/community/domain/entities/train_session.dart';
import 'package:narayanganj_rail_schedule/src/features/community/domain/repositories/arrival_report_ledger_repository.dart';
import 'package:narayanganj_rail_schedule/src/features/community/domain/repositories/arrival_report_repository.dart';
import 'package:narayanganj_rail_schedule/src/features/community/domain/repositories/community_overlay_repository.dart';
import 'package:narayanganj_rail_schedule/src/features/community/domain/repositories/device_identity_repository.dart';
import 'package:narayanganj_rail_schedule/src/features/community/domain/repositories/session_repository.dart';
import 'package:narayanganj_rail_schedule/src/features/community/domain/services/community_session_aggregate_reducer.dart';
import 'package:narayanganj_rail_schedule/src/features/community/domain/services/service_day_key.dart';
import 'package:narayanganj_rail_schedule/src/features/community/domain/entities/community_overlay_result.dart';
import 'dart:math';

class FakeArrivalReportLedgerRepository
    implements ArrivalReportLedgerRepository {
  static const _entryTtl = Duration(hours: 18);
  final Map<String, DateTime> _entries = <String, DateTime>{};

  @override
  Future<bool> hasSubmitted({
    required String sessionId,
    required DateTime serviceDate,
    required String stationId,
    required String deviceId,
    DateTime? now,
  }) async {
    if (now != null) {
      _pruneExpiredEntries(now);
    }
    return _entries.containsKey(
      _key(sessionId, serviceDate, stationId, deviceId),
    );
  }

  @override
  Future<void> markSubmitted({
    required String sessionId,
    required DateTime serviceDate,
    required String stationId,
    required String deviceId,
    required DateTime submittedAt,
  }) async {
    _pruneExpiredEntries(submittedAt);
    _entries[_key(sessionId, serviceDate, stationId, deviceId)] = submittedAt;
  }

  void _pruneExpiredEntries(DateTime now) {
    final cutoff = now.subtract(_entryTtl);
    _entries.removeWhere((_, submittedAt) => submittedAt.isBefore(cutoff));
  }

  String _key(
    String sessionId,
    DateTime serviceDate,
    String stationId,
    String deviceId,
  ) {
    return '$sessionId::${serviceDayKey(serviceDate)}::$stationId::$deviceId';
  }
}

class FakeArrivalReportRepository implements ArrivalReportRepository {
  FakeArrivalReportRepository({List<ArrivalReport> seed = const []})
    : _reports = List<ArrivalReport>.from(seed);

  final List<ArrivalReport> _reports;
  final Map<String, CommunitySessionAggregate> _aggregates =
      <String, CommunitySessionAggregate>{};
  final CommunitySessionAggregateReducer _reducer =
      const CommunitySessionAggregateReducer();

  @override
  Future<List<ArrivalReport>> fetchStopReports({
    required String sessionId,
    required DateTime serviceDate,
    required String stationId,
  }) async {
    final aggregate = _aggregates[_key(sessionId, serviceDate)];
    if (aggregate == null) {
      return _reports
          .where(
            (report) =>
                report.sessionId == sessionId && report.stationId == stationId,
          )
          .toList(growable: false);
    }
    final bucket = aggregate.bucketForStation(stationId);
    if (bucket == null) {
      return const <ArrivalReport>[];
    }
    return [
      ArrivalReport(
        reportId: bucket.latestReportId,
        sessionId: aggregate.sessionId,
        stationId: bucket.stationId,
        deviceId: bucket.latestDeviceId,
        observedArrivalAt: bucket.lastObservedAt,
        submittedAt: bucket.lastSubmittedAt,
      ),
    ];
  }

  @override
  Future<int> fetchStationSubmissionCount({
    required String sessionId,
    required DateTime serviceDate,
    required String stationId,
  }) async {
    return _aggregates[_key(sessionId, serviceDate)]
            ?.bucketForStation(stationId)
            ?.submissionCount ??
        0;
  }

  @override
  Future<CommunitySessionAggregate> submitArrivalReport(
    ArrivalReportSubmission submission,
  ) async {
    _reports.add(submission.report);
    try {
      final key = _key(
        submission.session.sessionId,
        submission.session.serviceDate,
      );
      _aggregates[key] = _reducer.reduce(
        current: _aggregates[key],
        submission: submission,
        now: submission.report.submittedAt,
      );
    } on StateError catch (error) {
      _reports.removeLast();
      if (error.message == 'station_submission_capacity_reached') {
        throw const ArrivalReportRepositoryException(
          ArrivalReportRepositoryErrorCode.stationCapacityReached,
        );
      }
      rethrow;
    }
    return _aggregates[_key(
      submission.session.sessionId,
      submission.session.serviceDate,
    )]!;
  }

  CommunitySessionAggregate? aggregateForSession(
    String sessionId, [
    DateTime? serviceDate,
  ]) {
    if (serviceDate != null) {
      return _aggregates[_key(sessionId, serviceDate)];
    }
    for (final aggregate in _aggregates.values) {
      if (aggregate.sessionId == sessionId) {
        return aggregate;
      }
    }
    return null;
  }

  String _key(String sessionId, DateTime serviceDate) {
    return '$sessionId::${serviceDayKey(serviceDate)}';
  }
}

class FakeCommunityOverlayRepository implements CommunityOverlayRepository {
  FakeCommunityOverlayRepository({
    Map<String, CommunityOverlayResult> seed = const {},
  }) : _overlays = Map<String, CommunityOverlayResult>.from(seed);

  final Map<String, CommunityOverlayResult> _overlays;
  final Map<String, int> fetchCounts = <String, int>{};
  bool failFetch = false;

  @override
  Future<CommunityOverlayResult> fetchSessionOverlay({
    required String sessionId,
    required DateTime serviceDate,
    bool forceRefresh = false,
  }) async {
    if (failFetch) {
      throw StateError('overlay_fetch_failed');
    }
    final key = _key(sessionId, serviceDate);
    fetchCounts.update(key, (count) => count + 1, ifAbsent: () => 1);
    fetchCounts.update(sessionId, (count) => count + 1, ifAbsent: () => 1);
    return _overlays[key] ??
        _overlays.values.firstWhere(
          (overlay) => overlay.sessionStatusSnapshot?.sessionId == sessionId,
          orElse: () => CommunityOverlayResult(
            fetchedAt: DateTime(1970),
            fromCache: false,
          ),
        );
  }

  String _key(String sessionId, DateTime serviceDate) {
    return '$sessionId::${serviceDayKey(serviceDate)}';
  }
}

class FakeDeviceIdentityRepository implements DeviceIdentityRepository {
  DeviceIdentity? _identity;

  @override
  Future<FirebaseAuthReadiness> readAuthReadiness({String? attemptId}) async {
    final identity = await readOrCreateIdentity(attemptId: attemptId);
    return FirebaseAuthReadiness.ready(identity.deviceId);
  }

  @override
  Future<DeviceIdentity> readOrCreateIdentity({String? attemptId}) async {
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

class FakeSessionRepository implements SessionRepository {
  FakeSessionRepository({List<TrainSession> seed = const []})
    : _sessions = List<TrainSession>.from(seed);

  final List<TrainSession> _sessions;

  @override
  Future<List<TrainSession>> fetchSessions({
    required String routeId,
    required DateTime serviceDate,
  }) async {
    final targetDay = DateTime(
      serviceDate.year,
      serviceDate.month,
      serviceDate.day,
    );
    return _sessions
        .where((session) {
          final day = DateTime(
            session.serviceDate.year,
            session.serviceDate.month,
            session.serviceDate.day,
          );
          return session.routeId == routeId && day == targetDay;
        })
        .toList(growable: false);
  }

  @override
  Future<TrainSession?> fetchNextEligibleSession({
    required String routeId,
    required String fromStationId,
    required String toStationId,
    required DateTime now,
  }) async {
    final candidates = _sessions.where((session) {
      if (session.routeId != routeId) {
        return false;
      }
      final fromIndex = session.stops.indexWhere(
        (stop) => stop.stationId == fromStationId,
      );
      final toIndex = session.stops.indexWhere(
        (stop) => stop.stationId == toStationId,
      );
      if (fromIndex < 0 || toIndex < 0 || fromIndex >= toIndex) {
        return false;
      }
      return session.departureAt.isAfter(now) || session.arrivalAt.isAfter(now);
    }).toList()..sort((a, b) => a.departureAt.compareTo(b.departureAt));

    return candidates.isEmpty ? null : candidates.first;
  }
}
