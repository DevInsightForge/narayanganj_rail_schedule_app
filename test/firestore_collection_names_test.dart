import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:narayanganj_rail_schedule/src/features/community/data/repositories/firebase/firestore_collection_names.dart';

void main() {
  test('resolves live aggregate collection outside debug mode', () {
    expect(
      FirestoreCollectionNames.sessionStatusSnapshotsForDebugMode(false),
      equals('session_status_snapshots'),
    );
  });

  test('resolves debug aggregate collection in debug mode', () {
    expect(
      FirestoreCollectionNames.sessionStatusSnapshotsForDebugMode(true),
      equals('session_status_snapshots_debug'),
    );
  });

  test('firestore rules include debug aggregate collection', () {
    final rules = File('firestore.rules').readAsStringSync();

    expect(rules, contains('match /session_status_snapshots/{sessionId}'));
    expect(
      rules,
      contains('match /session_status_snapshots_debug/{sessionId}'),
    );
    expect(rules, contains('request.resource.data.schemaVersion == 2'));
    expect(rules, contains('lastReportedStationId'));
    expect(rules, isNot(contains('reporterUids')));
    expect(rules, isNot(contains('request.auth.uid')));
    expect(rules, isNot(contains('latestDeviceId')));
    expect(rules, isNot(contains('latestReportId')));
  });
}
