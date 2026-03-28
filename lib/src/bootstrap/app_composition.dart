import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../core/firebase/firebase_runtime.dart';
import '../features/community/data/mappers/rail_schedule_template_mapper.dart';
import '../features/community/data/repositories/fake/fake_arrival_report_repository.dart';
import '../features/community/data/repositories/fake/fake_device_identity_repository.dart';
import '../features/community/data/repositories/fake/fake_prediction_repository.dart';
import '../features/community/data/repositories/fake/fake_rate_limit_policy_repository.dart';
import '../features/community/data/repositories/firebase/firebase_arrival_report_repository.dart';
import '../features/community/data/repositories/firebase/firebase_device_identity_repository.dart';
import '../features/community/data/repositories/firebase/firebase_prediction_repository.dart';
import '../features/community/data/repositories/local/generated_session_repository.dart';
import '../features/community/data/repositories/resilient/resilient_arrival_report_repository.dart';
import '../features/community/data/repositories/resilient/resilient_device_identity_repository.dart';
import '../features/community/data/repositories/resilient/resilient_prediction_repository.dart';
import '../features/community/domain/entities/rate_limit_policy.dart';
import '../features/community/domain/repositories/arrival_report_repository.dart';
import '../features/community/domain/repositories/device_identity_repository.dart';
import '../features/community/domain/repositories/prediction_repository.dart';
import '../features/community/domain/repositories/rate_limit_policy_repository.dart';
import '../features/community/domain/repositories/session_repository.dart';
import '../features/rail/data/repositories/schedule_data_repository.dart';
import '../features/rail/data/repositories/shared_preferences_selection_repository.dart';
import '../features/rail/domain/entities/rail_schedule.dart';
import '../features/rail/domain/repositories/selection_repository.dart';
import '../features/rail/domain/services/rail_board_service.dart';
import '../features/rail/presentation/bloc/rail_board_bloc.dart';

class AppComposition {
  AppComposition({
    required this.firebaseRuntime,
    required this.bundledSchedule,
    required this.scheduleDataRepository,
  }) : selectionRepository = SharedPreferencesSelectionRepository(),
       sessionRepository = GeneratedSessionRepository(
         templates: const RailScheduleTemplateMapper().map(
           routeId: 'narayanganj_line',
           schedule: bundledSchedule,
         ),
       ),
       arrivalReportRepository = _buildArrivalReportRepository(firebaseRuntime),
       predictionRepository = _buildPredictionRepository(firebaseRuntime),
       deviceIdentityRepository = _buildDeviceIdentityRepository(
         firebaseRuntime,
       ),
       rateLimitPolicyRepository = FakeRateLimitPolicyRepository(
         seed: const {
           'arrival_report': RateLimitPolicy(
             key: 'arrival_report',
             maxEvents: 3,
             windowSeconds: 120,
             coolDownSeconds: 30,
           ),
         },
       );

  final FirebaseRuntime firebaseRuntime;
  final RailSchedule bundledSchedule;
  final ScheduleDataRepository scheduleDataRepository;
  final SelectionRepository selectionRepository;
  final SessionRepository sessionRepository;
  final ArrivalReportRepository arrivalReportRepository;
  final PredictionRepository predictionRepository;
  final DeviceIdentityRepository deviceIdentityRepository;
  final RateLimitPolicyRepository rateLimitPolicyRepository;

  RailBoardBloc createRailBoardBloc() {
    return RailBoardBloc(
      boardService: RailBoardService(schedule: bundledSchedule),
      scheduleDataRepository: scheduleDataRepository,
      selectionRepository: selectionRepository,
      sessionRepository: sessionRepository,
      arrivalReportRepository: arrivalReportRepository,
      predictionRepository: predictionRepository,
      deviceIdentityRepository: deviceIdentityRepository,
      rateLimitPolicyRepository: rateLimitPolicyRepository,
      communityFeaturesEnabled: firebaseRuntime.enabled,
    );
  }

  static ArrivalReportRepository _buildArrivalReportRepository(
    FirebaseRuntime firebaseRuntime,
  ) {
    final fallback = FakeArrivalReportRepository();
    if (!firebaseRuntime.initialized) {
      return fallback;
    }
    return ResilientArrivalReportRepository(
      primary: FirebaseArrivalReportRepository(
        firestore: FirebaseFirestore.instance,
        routeId: 'narayanganj_line',
      ),
      fallback: fallback,
    );
  }

  static PredictionRepository _buildPredictionRepository(
    FirebaseRuntime firebaseRuntime,
  ) {
    final fallback = FakePredictionRepository();
    if (!firebaseRuntime.initialized) {
      return fallback;
    }
    return ResilientPredictionRepository(
      primary: FirebasePredictionRepository(
        firestore: FirebaseFirestore.instance,
      ),
      fallback: fallback,
    );
  }

  static DeviceIdentityRepository _buildDeviceIdentityRepository(
    FirebaseRuntime firebaseRuntime,
  ) {
    final fallback = FakeDeviceIdentityRepository();
    if (!firebaseRuntime.initialized) {
      return fallback;
    }
    return ResilientDeviceIdentityRepository(
      primary: FirebaseDeviceIdentityRepository(
        auth: FirebaseAuth.instance,
        firestore: FirebaseFirestore.instance,
      ),
      fallback: fallback,
    );
  }
}
