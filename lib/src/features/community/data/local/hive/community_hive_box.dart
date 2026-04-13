import 'dart:convert';
import 'dart:io';

import 'package:hive_flutter/hive_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../models/hive/arrival_report_ledger_entry_hive.dart';
import '../../models/hive/community_overlay_cache_hive.dart';
import '../../models/hive/firebase_identity_state_hive.dart';
import '../../models/hive/pending_report_hive.dart';

class CommunityHiveBox {
  CommunityHiveBox._();

  static const overlayCacheBoxName = 'nrs.community.overlay_cache';
  static const arrivalReportLedgerBoxName =
      'nrs.community.arrival_report_ledger';
  static const pendingReportBoxName = 'nrs.community.pending_reports';
  static const firebaseIdentityStateBoxName = 'nrs.community.identity_state';
  static const migrationFlagKey = 'nrs:community:hive-migration-v1';
  static const currentSchemaVersion = 1;

  static bool _initialized = false;

  static void resetForTests() {
    _initialized = false;
  }

  static Future<void> initialize({String? hivePath}) async {
    if (!_initialized) {
      if (hivePath == null) {
        await Hive.initFlutter();
      } else {
        Hive.init(hivePath);
      }
      _registerAdapters();
      _initialized = true;
    }

    await openOverlayCacheBox();
    await openArrivalReportLedgerBox();
    await openPendingReportBox();
    await openFirebaseIdentityStateBox();
  }

  static Future<void> migrateLegacySharedPreferences() async {
    final preferences = await SharedPreferences.getInstance();
    if (preferences.getBool(migrationFlagKey) == true) {
      return;
    }

    await _migrateOverlayCache(preferences);
    await _migrateArrivalReportLedger(preferences);
    await _migrateFirebaseIdentityState(preferences);

    await preferences.setBool(migrationFlagKey, true);
  }

  static Future<Box<CommunityOverlayCacheHive>> openOverlayCacheBox() async {
    return _openRecovering<CommunityOverlayCacheHive>(overlayCacheBoxName);
  }

  static Future<Box<ArrivalReportLedgerEntryHive>>
  openArrivalReportLedgerBox() async {
    return _openRecovering<ArrivalReportLedgerEntryHive>(
      arrivalReportLedgerBoxName,
    );
  }

  static Future<Box<PendingReportHive>> openPendingReportBox() async {
    return _openRecovering<PendingReportHive>(pendingReportBoxName);
  }

  static Future<Box<FirebaseIdentityStateHive>>
  openFirebaseIdentityStateBox() async {
    return _openRecovering<FirebaseIdentityStateHive>(
      firebaseIdentityStateBoxName,
    );
  }

  static void _registerAdapters() {
    if (!Hive.isAdapterRegistered(CommunityOverlayCacheHive.typeId)) {
      Hive.registerAdapter(CommunityOverlayCacheHiveAdapter());
    }
    if (!Hive.isAdapterRegistered(ArrivalReportLedgerEntryHive.typeId)) {
      Hive.registerAdapter(ArrivalReportLedgerEntryHiveAdapter());
    }
    if (!Hive.isAdapterRegistered(PendingReportHive.typeId)) {
      Hive.registerAdapter(PendingReportHiveAdapter());
    }
    if (!Hive.isAdapterRegistered(FirebaseIdentityStateHive.typeId)) {
      Hive.registerAdapter(FirebaseIdentityStateHiveAdapter());
    }
  }

  static Future<void> _migrateOverlayCache(
    SharedPreferences preferences,
  ) async {
    final overlayPrefix = 'nrs:community:overlay:';
    final keys = preferences
        .getKeys()
        .where((key) => key.startsWith(overlayPrefix))
        .toList(growable: false);
    if (keys.isEmpty) {
      return;
    }

    final box = await openOverlayCacheBox();
    for (final key in keys) {
      final raw = preferences.getString(key);
      if (raw == null || raw.isEmpty) {
        continue;
      }
      final payload = _decodeMap(raw);
      if (payload == null) {
        continue;
      }
      final parsed = _parseOverlayKey(key);
      if (parsed == null) {
        continue;
      }
      final entry = CommunityOverlayCacheHive.fromLegacyPayload(
        sessionId: parsed.$1,
        serviceDateKey: parsed.$2,
        payload: payload,
        schemaVersion: currentSchemaVersion,
      );
      await box.put(entry.boxKey, entry);
    }
  }

  static Future<void> _migrateArrivalReportLedger(
    SharedPreferences preferences,
  ) async {
    const legacyKey = 'nrs:community:arrival-report-ledger';
    final raw = preferences.getString(legacyKey);
    if (raw == null || raw.isEmpty) {
      return;
    }

    final decoded = _decodeMap(raw);
    if (decoded == null || decoded.isEmpty) {
      return;
    }

    final box = await openArrivalReportLedgerBox();
    for (final entry in decoded.entries) {
      final parsed = _parseLedgerEntryKey(entry.key);
      if (parsed == null) {
        continue;
      }
      final submittedAt = '${entry.value}';
      final hiveEntry = ArrivalReportLedgerEntryHive.fromLegacyEntry(
        sessionId: parsed.$1,
        serviceDateKey: parsed.$2,
        stationId: parsed.$3,
        deviceFingerprint: parsed.$4,
        submittedAt: submittedAt,
        schemaVersion: currentSchemaVersion,
      );
      await box.put(hiveEntry.dedupeKey, hiveEntry);
    }
  }

  static Future<void> _migrateFirebaseIdentityState(
    SharedPreferences preferences,
  ) async {
    const legacyKey = 'nrs:community:firebase-identity-state';
    final raw = preferences.getString(legacyKey);
    if (raw == null || raw.isEmpty) {
      return;
    }

    final decoded = _decodeMap(raw);
    if (decoded == null || decoded.isEmpty) {
      return;
    }

    final uid = '${decoded['uid'] ?? ''}'.trim();
    if (uid.isEmpty) {
      return;
    }

    final box = await openFirebaseIdentityStateBox();
    final hiveValue = FirebaseIdentityStateHive(
      uid: uid,
      handshakeCompleted: decoded['handshakeCompleted'] == true,
      schemaVersion: currentSchemaVersion,
      lastSyncedAt: DateTime.now(),
    );
    await box.put(uid, hiveValue);
  }

  static Map<String, dynamic>? _decodeMap(String raw) {
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map<String, dynamic>) {
        return decoded;
      }
      if (decoded is Map) {
        return Map<String, dynamic>.from(decoded);
      }
    } catch (_) {
      return null;
    }
    return null;
  }

  static (String, String)? _parseOverlayKey(String key) {
    const prefix = 'nrs:community:overlay:';
    if (!key.startsWith(prefix)) {
      return null;
    }
    final remainder = key.substring(prefix.length);
    final parts = remainder.split('::');
    if (parts.length != 2) {
      return null;
    }
    final sessionId = parts[0].trim();
    final serviceDateKey = parts[1].trim();
    if (sessionId.isEmpty || serviceDateKey.isEmpty) {
      return null;
    }
    return (sessionId, serviceDateKey);
  }

  static (String, String, String, String)? _parseLedgerEntryKey(String key) {
    final parts = key.split('::');
    if (parts.length != 4) {
      return null;
    }
    final sessionId = parts[0].trim();
    final serviceDateKey = parts[1].trim();
    final stationId = parts[2].trim();
    final deviceFingerprint = parts[3].trim();
    if (sessionId.isEmpty ||
        serviceDateKey.isEmpty ||
        stationId.isEmpty ||
        deviceFingerprint.isEmpty) {
      return null;
    }
    return (sessionId, serviceDateKey, stationId, deviceFingerprint);
  }

  static Future<Box<T>> _openRecovering<T>(String boxName) async {
    if (Hive.isBoxOpen(boxName)) {
      return Hive.box<T>(boxName);
    }

    try {
      return await Hive.openBox<T>(boxName);
    } catch (error) {
      if (!_shouldResetBox(error)) {
        rethrow;
      }
      await _deleteBoxFiles(boxName);
      return Hive.openBox<T>(boxName);
    }
  }

  static bool _shouldResetBox(Object error) {
    return error is RangeError ||
        error is HiveError ||
        error is FormatException ||
        error is TypeError ||
        error is StateError;
  }

  static Future<void> _deleteBoxFiles(String boxName) async {
    try {
      await Hive.deleteBoxFromDisk(boxName);
    } catch (_) {}

    final boxFile = File('$boxName.hive');
    if (await boxFile.exists()) {
      try {
        await boxFile.delete();
      } catch (_) {}
    }
  }
}
