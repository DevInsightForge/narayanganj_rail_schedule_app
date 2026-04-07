import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../community/domain/entities/arrival_report.dart';
import '../../../community/domain/entities/arrival_report_submission.dart';
import '../../../community/domain/entities/data_origin.dart';
import '../../../community/domain/entities/community_overlay_result.dart';
import '../../../community/domain/entities/predicted_stop_time.dart';
import '../../../community/domain/entities/session_status_snapshot.dart';
import '../../../community/domain/entities/train_session.dart';
import '../../../community/domain/repositories/arrival_report_ledger_repository.dart';
import '../../../community/domain/repositories/arrival_report_repository.dart';
import '../../../community/domain/repositories/community_overlay_repository.dart';
import '../../../community/domain/repositories/device_identity_repository.dart';
import '../../../community/domain/repositories/session_repository.dart';
import '../../../community/domain/services/session_lifecycle_service.dart';
import '../../../community/domain/services/service_day_key.dart';
import '../../../../core/errors/error_report_context.dart';
import '../../../../core/errors/error_reporter.dart';
import '../models/rail_community_insight_result.dart';
import '../models/rail_reporting.dart';
import '../../domain/entities/rail_selection.dart';
import '../../domain/entities/rail_snapshot.dart';

part 'rail_board_use_case_availability.dart';
part 'rail_board_use_case_community.dart';
part 'rail_board_use_case_session_lookup.dart';
part 'rail_board_use_case_submission.dart';

class RailBoardUseCase {
  RailBoardUseCase({
    required SessionRepository sessionRepository,
    required ArrivalReportRepository arrivalReportRepository,
    required ArrivalReportLedgerRepository arrivalReportLedgerRepository,
    required CommunityOverlayRepository communityOverlayRepository,
    required DeviceIdentityRepository deviceIdentityRepository,
    required this.routeId,
    ErrorReporter? errorReporter,
    SessionLifecycleService? sessionLifecycleService,
    this.reportDedupeBucketMinutes = 2,
    this.reportDedupeRetentionMinutes = 10,
    this.staleInsightThresholdSeconds = 10 * 60,
  }) : _sessionRepository = sessionRepository,
       _arrivalReportRepository = arrivalReportRepository,
       _arrivalReportLedgerRepository = arrivalReportLedgerRepository,
       _communityOverlayRepository = communityOverlayRepository,
       _deviceIdentityRepository = deviceIdentityRepository,
       _errorReporter = errorReporter ?? const NoopErrorReporter(),
       _sessionLifecycleService =
           sessionLifecycleService ?? const SessionLifecycleService();

  final SessionRepository _sessionRepository;
  final ArrivalReportRepository _arrivalReportRepository;
  final ArrivalReportLedgerRepository _arrivalReportLedgerRepository;
  final CommunityOverlayRepository _communityOverlayRepository;
  final DeviceIdentityRepository _deviceIdentityRepository;
  final ErrorReporter _errorReporter;
  final SessionLifecycleService _sessionLifecycleService;
  final String routeId;
  final int reportDedupeBucketMinutes;
  final int reportDedupeRetentionMinutes;
  final int staleInsightThresholdSeconds;
  final Map<String, DateTime> _recentReportKeys = {};
  final Set<String> _inFlightSubmissionKeys = <String>{};
  final Set<String> _submittedSessionKeys = <String>{};
}
