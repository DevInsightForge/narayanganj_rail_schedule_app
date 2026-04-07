import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../core/errors/error_reporter.dart';
import '../core/firebase/firebase_runtime.dart';
import '../features/community/data/mappers/rail_schedule_template_mapper.dart';
import '../features/community/data/repositories/cached/cached_community_overlay_repository.dart';
import '../features/community/data/repositories/firebase/firebase_arrival_report_repository.dart';
import '../features/community/data/repositories/firebase/firebase_community_overlay_repository.dart';
import '../features/community/data/repositories/firebase/firebase_device_identity_repository.dart';
import '../features/community/data/repositories/local/generated_session_repository.dart';
import '../features/community/data/repositories/local/shared_preferences_arrival_report_ledger_repository.dart';
import '../features/community/data/repositories/local/shared_preferences_community_overlay_cache_repository.dart';
import '../features/community/data/repositories/local/shared_preferences_firebase_identity_state_repository.dart';
import '../features/community/data/repositories/noop/noop_arrival_report_repository.dart';
import '../features/community/data/repositories/noop/noop_community_overlay_repository.dart';
import '../features/community/data/repositories/noop/noop_device_identity_repository.dart';
import '../features/community/domain/repositories/arrival_report_ledger_repository.dart';
import '../features/community/domain/repositories/arrival_report_repository.dart';
import '../features/community/domain/repositories/community_overlay_repository.dart';
import '../features/community/domain/repositories/device_identity_repository.dart';
import '../features/community/domain/repositories/session_repository.dart';
import '../features/rail/data/repositories/schedule_data_repository.dart';
import '../features/rail/data/repositories/shared_preferences_selection_repository.dart';
import '../features/rail/domain/entities/rail_schedule.dart';
import '../features/rail/domain/repositories/selection_repository.dart';
import '../features/rail/domain/services/rail_board_service.dart';
import '../features/rail/presentation/bloc/rail_board_cubit.dart';

class AppComposition {
  AppComposition({
    required this.firebaseRuntime,
    required this.bundledSchedule,
    required this.scheduleDataRepository,
    required this.errorReporter,
    this.communityDebugBypassEnabled = kDebugMode,
  }) : selectionRepository = SharedPreferencesSelectionRepository(),
       sessionRepository = GeneratedSessionRepository(
         templates: const RailScheduleTemplateMapper().map(
           routeId: 'narayanganj_line',
           schedule: bundledSchedule,
         ),
       ),
       arrivalReportRepository = _buildArrivalReportRepository(firebaseRuntime),
       arrivalReportLedgerRepository =
           SharedPreferencesArrivalReportLedgerRepository(),
       communityOverlayRepository = _buildCommunityOverlayRepository(
         firebaseRuntime,
         communityDebugBypassEnabled,
       ),
       deviceIdentityRepository = _buildDeviceIdentityRepository(
         firebaseRuntime,
         errorReporter,
       );

  final FirebaseRuntime firebaseRuntime;
  final RailSchedule bundledSchedule;
  final ScheduleDataRepository scheduleDataRepository;
  final ErrorReporter errorReporter;
  final bool communityDebugBypassEnabled;
  final SelectionRepository selectionRepository;
  final SessionRepository sessionRepository;
  final ArrivalReportRepository arrivalReportRepository;
  final ArrivalReportLedgerRepository arrivalReportLedgerRepository;
  final CommunityOverlayRepository communityOverlayRepository;
  final DeviceIdentityRepository deviceIdentityRepository;

  RailBoardCubit createRailBoardCubit() {
    return RailBoardCubit(
      boardService: RailBoardService(schedule: bundledSchedule),
      scheduleDataRepository: scheduleDataRepository,
      selectionRepository: selectionRepository,
      sessionRepository: sessionRepository,
      arrivalReportRepository: arrivalReportRepository,
      arrivalReportLedgerRepository: arrivalReportLedgerRepository,
      communityOverlayRepository: communityOverlayRepository,
      deviceIdentityRepository: deviceIdentityRepository,
      errorReporter: errorReporter,
      communityFeaturesEnabled: firebaseRuntime.initialized,
      communityDebugBypassEnabled: communityDebugBypassEnabled,
    );
  }

  static ArrivalReportRepository _buildArrivalReportRepository(
    FirebaseRuntime firebaseRuntime,
  ) {
    if (!firebaseRuntime.initialized) {
      return const NoOpArrivalReportRepository();
    }
    return FirebaseArrivalReportRepository(
      firestore: FirebaseFirestore.instance,
      routeId: 'narayanganj_line',
    );
  }

  static CommunityOverlayRepository _buildCommunityOverlayRepository(
    FirebaseRuntime firebaseRuntime,
    bool communityDebugBypassEnabled,
  ) {
    if (!firebaseRuntime.initialized) {
      return const NoOpCommunityOverlayRepository();
    }
    if (communityDebugBypassEnabled) {
      return FirebaseCommunityOverlayRepository(
        firestore: FirebaseFirestore.instance,
      );
    }
    return CachedCommunityOverlayRepository(
      primary: FirebaseCommunityOverlayRepository(
        firestore: FirebaseFirestore.instance,
      ),
      cache: SharedPreferencesCommunityOverlayCacheRepository(),
    );
  }

  static DeviceIdentityRepository _buildDeviceIdentityRepository(
    FirebaseRuntime firebaseRuntime,
    ErrorReporter errorReporter,
  ) {
    if (!firebaseRuntime.initialized) {
      return const NoOpDeviceIdentityRepository();
    }
    return FirebaseDeviceIdentityRepository(
      auth: FirebaseAuth.instance,
      identityStateRepository:
          SharedPreferencesFirebaseIdentityStateRepository(),
      errorReporter: errorReporter,
    );
  }
}
