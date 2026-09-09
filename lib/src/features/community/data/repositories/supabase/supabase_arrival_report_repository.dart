import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../domain/entities/arrival_report.dart';
import '../../../domain/entities/arrival_report_submission.dart';
import '../../../domain/entities/community_session_aggregate.dart';
import '../../../domain/repositories/arrival_report_repository.dart';
import '../../../domain/services/service_day_key.dart';
import '../../mappers/http_community_mapper.dart';

class SupabaseArrivalReportRepository implements ArrivalReportRepository {
  const SupabaseArrivalReportRepository({
    required SupabaseClient client,
    HttpCommunityMapper mapper = const HttpCommunityMapper(),
  }) : _client = client,
       _mapper = mapper;

  final SupabaseClient _client;
  final HttpCommunityMapper _mapper;

  @override
  Future<CommunitySessionAggregate> submitArrivalReport(
    ArrivalReportSubmission submission,
  ) async {
    final dateKey = serviceDateKey(submission.session.serviceDate);
    final payload = {
      'p_session_id': submission.session.sessionId,
      'p_route_id': submission.session.routeId,
      'p_direction_id': submission.session.directionId,
      'p_train_no': submission.session.trainNo,
      'p_service_date': dateKey,
      'p_station_id': submission.report.stationId,
      'p_scheduled_at': submission.stationStop.scheduledAt
          .toUtc()
          .toIso8601String(),
      'p_observed_at': submission.report.observedArrivalAt
          .toUtc()
          .toIso8601String(),
      'p_device_id': submission.report.deviceId,
    };

    try {
      final response = await _client.rpc(
        'submit_arrival_report',
        params: payload,
      );

      if (response is Map<String, dynamic>) {
        return _mapper.toCommunitySessionAggregate(
          json: response,
          directionId: submission.session.directionId,
          trainNo: submission.session.trainNo,
        );
      }

      throw const ArrivalReportRepositoryException(
        ArrivalReportRepositoryErrorCode.unknown,
      );
    } on PostgrestException catch (error) {
      _handlePostgrestError(error);
      throw const ArrivalReportRepositoryException(
        ArrivalReportRepositoryErrorCode.unknown,
      );
    } catch (error) {
      if (error is ArrivalReportRepositoryException) {
        rethrow;
      }
      throw const ArrivalReportRepositoryException(
        ArrivalReportRepositoryErrorCode.unknown,
      );
    }
  }

  void _handlePostgrestError(PostgrestException error) {
    final code = error.code?.toUpperCase() ?? '';
    final msg = error.message.toUpperCase();

    if (code == 'P0430' ||
        code == 'STATION_CAPACITY_REACHED' ||
        msg.contains('STATION_CAPACITY_REACHED')) {
      throw const ArrivalReportRepositoryException(
        ArrivalReportRepositoryErrorCode.stationCapacityReached,
      );
    }

    if (code == '42501' ||
        msg.contains('PERMISSION_DENIED') ||
        msg.contains('UNAUTHORIZED')) {
      throw const ArrivalReportRepositoryException(
        ArrivalReportRepositoryErrorCode.permissionDenied,
      );
    }

    throw const ArrivalReportRepositoryException(
      ArrivalReportRepositoryErrorCode.unknown,
    );
  }

  @override
  Future<int> fetchStationSubmissionCount({
    required String sessionId,
    required DateTime serviceDate,
    required String stationId,
  }) async {
    final dateKey = serviceDateKey(serviceDate);
    try {
      final data = await _client
          .from('session_snapshots')
          .select('station_buckets')
          .eq('session_id', sessionId)
          .eq('service_date', dateKey)
          .maybeSingle();

      if (data != null) {
        final stations =
            (data['station_buckets'] ?? data['stations'])
                as Map<String, dynamic>?;
        if (stations != null && stations.containsKey(stationId)) {
          final bucket = stations[stationId] as Map<String, dynamic>?;
          return ((bucket?['reportCount'] ?? bucket?['report_count']) as num?)
                  ?.toInt() ??
              0;
        }
      }
      return 0;
    } catch (_) {
      return 0;
    }
  }

  @override
  Future<List<ArrivalReport>> fetchStopReports({
    required String sessionId,
    required DateTime serviceDate,
    required String stationId,
  }) async {
    return const [];
  }
}
