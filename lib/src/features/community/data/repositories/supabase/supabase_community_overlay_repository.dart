import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../domain/entities/community_overlay_result.dart';
import '../../../domain/repositories/community_overlay_repository.dart';
import '../../../domain/services/service_day_key.dart';
import '../../mappers/http_community_mapper.dart';

class SupabaseCommunityOverlayRepository implements CommunityOverlayRepository {
  const SupabaseCommunityOverlayRepository({
    required SupabaseClient client,
    HttpCommunityMapper mapper = const HttpCommunityMapper(),
  }) : _client = client,
       _mapper = mapper;

  final SupabaseClient _client;
  final HttpCommunityMapper _mapper;

  @override
  Future<CommunityOverlayResult> fetchSessionOverlay({
    required String sessionId,
    required DateTime serviceDate,
    bool forceRefresh = false,
  }) async {
    final dateKey = serviceDateKey(serviceDate);
    try {
      final data = await _client
          .from('session_snapshots')
          .select()
          .eq('session_id', sessionId)
          .eq('service_date', dateKey)
          .maybeSingle();

      if (data != null) {
        final snapshot = _mapper.toSessionStatusSnapshot(data);
        final predictedStops = _mapper.toPredictedStopTimes(data);

        return CommunityOverlayResult(
          sessionStatusSnapshot: snapshot,
          predictedStopTimes: predictedStops,
          fetchedAt: DateTime.now(),
          fromCache: false,
        );
      }

      return CommunityOverlayResult(
        sessionStatusSnapshot: null,
        fetchedAt: DateTime.now(),
        fromCache: false,
      );
    } catch (error) {
      throw Exception('Failed to fetch community overlay: $error');
    }
  }
}
