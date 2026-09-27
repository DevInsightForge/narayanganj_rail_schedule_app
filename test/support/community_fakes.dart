import 'package:narayanganj_rail_schedule/src/features/community/domain/entities/community_overlay.dart';
import 'package:narayanganj_rail_schedule/src/features/community/domain/repositories/community_repository.dart';

class FakeCommunityRepository implements CommunityRepository {
  FakeCommunityRepository({
    Map<String, CommunityOverlay?> seed = const {},
    this.nextReportResult = const ArrivalReportResult.accepted(),
  }) : _overlays = Map<String, CommunityOverlay?>.from(seed);

  final Map<String, CommunityOverlay?> _overlays;
  final Map<String, int> fetchCounts = <String, int>{};
  final List<Map<String, dynamic>> submissions = [];
  ArrivalReportResult nextReportResult;
  bool failFetch = false;
  bool failSubmission = false;

  void setOverlay(String tripId, CommunityOverlay? overlay) {
    _overlays[tripId] = overlay;
  }

  @override
  Future<CommunityOverlay?> fetchOverlay({
    required String tripId,
    String? serviceDate,
  }) async {
    if (failFetch) {
      throw StateError('overlay_fetch_failed');
    }
    fetchCounts.update(tripId, (count) => count + 1, ifAbsent: () => 1);
    return _overlays[tripId];
  }

  @override
  Future<ArrivalReportResult> submitArrivalReport({
    required String tripId,
    required String stationId,
    int? delayMinutes,
    String? serviceDate,
  }) async {
    if (failSubmission) {
      throw StateError('report_submission_failed');
    }
    submissions.add({
      'tripId': tripId,
      'stationId': stationId,
      'delayMinutes': delayMinutes,
      'serviceDate': serviceDate,
    });
    return nextReportResult;
  }
}
