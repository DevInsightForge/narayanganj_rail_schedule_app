import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:narayanganj_rail_schedule/src/features/community/data/repositories/noop_community_repository.dart';
import 'package:narayanganj_rail_schedule/src/features/rail/application/models/rail_widget_payload.dart';
import 'package:narayanganj_rail_schedule/src/features/rail/application/services/widget_sync_service.dart';
import 'package:narayanganj_rail_schedule/src/features/rail/data/repositories/bundled_schedule_source.dart';
import 'package:narayanganj_rail_schedule/src/features/rail/domain/entities/rail_selection.dart';
import 'package:narayanganj_rail_schedule/src/features/rail/domain/repositories/selection_repository.dart';
import 'package:narayanganj_rail_schedule/src/features/rail/domain/services/rail_board_service.dart';
import 'package:narayanganj_rail_schedule/src/features/rail/presentation/bloc/rail_board_cubit.dart';

class _FakeHomeWidgetGateway implements HomeWidgetPlatformGateway {
  final Map<String, String> savedPayloads = <String, String>{};
  final List<String> updatedProviders = <String>[];
  int saveCount = 0;

  @override
  Future<bool?> savePayloadJson(String key, String json) async {
    saveCount += 1;
    savedPayloads[key] = json;
    return true;
  }

  @override
  Future<bool?> updateProvider(String qualifiedAndroidName) async {
    updatedProviders.add(qualifiedAndroidName);
    return true;
  }

  @override
  Future<Uri?> initiallyLaunchedFromHomeWidget() async => null;

  @override
  Stream<Uri?> get widgetClicked => const Stream<Uri?>.empty();
}

class _InMemorySelectionRepository implements SelectionRepository {
  RailSelection? stored;

  @override
  Future<RailSelection?> read() async => stored;

  @override
  Future<void> write(RailSelection selection) async {
    stored = selection;
  }
}

void main() {
  test(
    'coalesces unchanged states and updates both widget providers when route changes',
    () async {
      final gateway = _FakeHomeWidgetGateway();
      final syncService = AndroidWidgetSyncService(
        gateway: gateway,
        nowProvider: () => DateTime(2026, 10, 27, 7, 10),
        isSupportedPlatform: true,
      );
      final schedule = const BundledScheduleSource().loadSchedule();
      final cubit = RailBoardCubit(
        boardService: RailBoardService(schedule: schedule),
        selectionRepository: _InMemorySelectionRepository(),
        communityRepository: const NoOpCommunityRepository(),
        widgetSyncService: syncService,
        communityFeaturesEnabled: false,
        enableTicker: false,
        nowProvider: () => DateTime(2026, 10, 27, 7, 10),
      );

      await cubit.stream
          .firstWhere((state) => state.status == RailBoardStatus.ready)
          .timeout(const Duration(seconds: 5));
      await Future<void>.delayed(Duration.zero);

      expect(gateway.saveCount, 1);
      expect(
        gateway.updatedProviders,
        equals([
          AndroidWidgetSyncService.compactProviderClass,
          AndroidWidgetSyncService.expandedProviderClass,
        ]),
      );

      cubit.toggleTimelineExpansion();
      await Future<void>.delayed(Duration.zero);
      expect(gateway.saveCount, 1);

      await cubit.swapDirectionAndStations();
      await Future<void>.delayed(Duration.zero);
      expect(gateway.saveCount, 2);

      final latestPayload = RailWidgetPayload.tryParseJson(
        gateway.savedPayloads[RailWidgetPayload.storageKey],
      );
      expect(latestPayload, isNotNull);
      expect(latestPayload!.direction, cubit.state.selection.direction);
      expect(
        latestPayload.boardingStationId,
        cubit.state.selection.boardingStationId,
      );
      expect(
        latestPayload.destinationStationId,
        cubit.state.selection.destinationStationId,
      );

      await cubit.syncWidgets(force: true);
      expect(gateway.saveCount, 3);

      await cubit.close();
      syncService.dispose();
    },
  );
}
