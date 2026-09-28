import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:narayanganj_rail_schedule/src/app.dart';
import 'package:narayanganj_rail_schedule/src/bootstrap/app_composition.dart';
import 'package:narayanganj_rail_schedule/src/features/rail/domain/entities/rail_selection.dart';
import 'package:narayanganj_rail_schedule/src/features/rail/domain/repositories/selection_repository.dart';
import 'package:narayanganj_rail_schedule/src/features/rail/presentation/widgets/rail_primitives.dart';

import 'support/bundled_schedule_fixture.dart';
import 'support/community_fakes.dart';

void main() {
  testWidgets('clamps system TextScaler between 0.85 and 1.35', (tester) async {
    final composition = AppComposition(
      bundledSchedule: loadBundledScheduleFixture(),
      communityRepository: FakeCommunityRepository(),
      selectionRepository: _InMemorySelectionRepository(
        const RailSelection(
          direction: 'dhaka_to_narayanganj',
          boardingStationId: 'dhaka',
          destinationStationId: 'narayanganj',
        ),
      ),
    );

    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(
          textScaler: TextScaler.linear(2.0),
          size: Size(390, 844),
        ),
        child: NarayanganjRailScheduleApp(composition: composition),
      ),
    );
    await tester.pumpAndSettle();

    final context = tester.element(find.byType(RailPill).first);
    final observedScaler = MediaQuery.textScalerOf(context);

    expect(observedScaler.scale(10), closeTo(13.5, 0.001));
  });

  testWidgets(
    'renders board on compact 320dp width with 1.35x text scale without overflow',
    (tester) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final composition = AppComposition(
        bundledSchedule: loadBundledScheduleFixture(),
        communityRepository: FakeCommunityRepository(),
        selectionRepository: _InMemorySelectionRepository(
          const RailSelection(
            direction: 'dhaka_to_narayanganj',
            boardingStationId: 'dhaka',
            destinationStationId: 'narayanganj',
          ),
        ),
      );

      await tester.pumpWidget(
        MediaQuery(
          data: const MediaQueryData(
            textScaler: TextScaler.linear(1.35),
            size: Size(320, 640),
          ),
          child: NarayanganjRailScheduleApp(composition: composition),
        ),
      );

      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.byType(RailPill), findsWidgets);
      expect(find.text('From Dhaka'), findsWidgets);
    },
  );
}

class _InMemorySelectionRepository implements SelectionRepository {
  _InMemorySelectionRepository(this._selection);

  RailSelection? _selection;

  @override
  Future<RailSelection?> read() async => _selection;

  @override
  Future<void> write(RailSelection selection) async {
    _selection = selection;
  }
}
