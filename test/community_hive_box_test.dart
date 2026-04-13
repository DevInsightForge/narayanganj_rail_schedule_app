import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:narayanganj_rail_schedule/src/features/community/data/local/hive/community_hive_box.dart';
import 'package:narayanganj_rail_schedule/src/features/community/data/models/hive/arrival_report_ledger_entry_hive.dart';
import 'package:narayanganj_rail_schedule/src/features/community/data/models/hive/community_overlay_cache_hive.dart';
import 'package:narayanganj_rail_schedule/src/features/community/data/models/hive/firebase_identity_state_hive.dart';

void main() {
  late Directory tempDir;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('community-hive-test');
    SharedPreferences.setMockInitialValues({
      'nrs:community:overlay:s1::20260328': jsonEncode({
        'fetchedAt': '2026-03-28T04:25:00.000Z',
        'sessionStatusSnapshot': {
          'sessionId': 's1',
          'state': 'active',
          'delayMinutes': 4,
          'delayStatus': 'late',
          'confidence': {
            'score': 0.85,
            'sampleSize': 3,
            'freshnessSeconds': 30,
            'agreementScore': 0.8,
          },
          'freshnessSeconds': 30,
          'lastObservedAt': '2026-03-28T04:24:00.000Z',
        },
        'predictedStopTimes': [
          {
            'sessionId': 's1',
            'stationId': 'narayanganj',
            'predictedAt': '2026-03-28T05:18:00.000Z',
            'referenceStationId': 'dhaka',
            'origin': 'community',
            'confidence': {
              'score': 0.8,
              'sampleSize': 3,
              'freshnessSeconds': 30,
              'agreementScore': 0.8,
            },
          },
        ],
      }),
      'nrs:community:arrival-report-ledger': jsonEncode({
        's1::20260328::dhaka::device-1': '2026-03-28T04:30:00.000Z',
      }),
      'nrs:community:firebase-identity-state': jsonEncode({
        'uid': 'device-1',
        'handshakeCompleted': true,
      }),
    });
  });

  tearDown(() async {
    await Hive.close();
    CommunityHiveBox.resetForTests();
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  test(
    'migrates legacy shared preferences community state into hive boxes',
    () async {
      await CommunityHiveBox.initialize(hivePath: tempDir.path);
      await CommunityHiveBox.migrateLegacySharedPreferences();

      final overlayBox = Hive.box<CommunityOverlayCacheHive>(
        CommunityHiveBox.overlayCacheBoxName,
      );
      final ledgerBox = Hive.box<ArrivalReportLedgerEntryHive>(
        CommunityHiveBox.arrivalReportLedgerBoxName,
      );
      final identityBox = Hive.box<FirebaseIdentityStateHive>(
        CommunityHiveBox.firebaseIdentityStateBoxName,
      );

      final overlay = overlayBox.get('s1::20260328');
      expect(overlay, isNotNull);
      expect(overlay?.sessionId, equals('s1'));
      expect(overlay?.serviceDateKey, equals('20260328'));
      expect(overlay?.lastSyncedAt, isNotNull);
      expect(overlay?.sessionStatusSnapshotJson, contains('"delayMinutes":4'));

      final ledger = ledgerBox.get('s1::20260328::dhaka::device-1');
      expect(ledger, isNotNull);
      expect(ledger?.sessionId, equals('s1'));
      expect(ledger?.deviceFingerprint, equals('device-1'));
      expect(ledger?.syncedAt, isNotNull);

      final identity = identityBox.get('device-1');
      expect(identity, isNotNull);
      expect(identity?.uid, equals('device-1'));
      expect(identity?.handshakeCompleted, isTrue);
    },
  );

  test('recovers by resetting a corrupted hive box', () async {
    final corruptedBox = File('${tempDir.path}/nrs.community.overlay_cache.hive');
    await corruptedBox.writeAsBytes(<int>[0, 1, 2, 3, 4, 5], flush: true);

    await CommunityHiveBox.initialize(hivePath: tempDir.path);
    final overlayBox = Hive.box<CommunityOverlayCacheHive>(
      CommunityHiveBox.overlayCacheBoxName,
    );

    expect(overlayBox.values, isEmpty);
  });
}
