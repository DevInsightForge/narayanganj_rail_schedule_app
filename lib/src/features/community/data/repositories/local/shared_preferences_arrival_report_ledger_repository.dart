import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../../domain/repositories/arrival_report_ledger_repository.dart';

class SharedPreferencesArrivalReportLedgerRepository
    implements ArrivalReportLedgerRepository {
  SharedPreferencesArrivalReportLedgerRepository({
    DateTime Function()? nowProvider,
  }) : _nowProvider = nowProvider ?? DateTime.now;

  static const _storageKey = 'nrs:community:arrival-report-ledger';
  static const _entryTtl = Duration(hours: 18);
  final DateTime Function() _nowProvider;

  @override
  Future<bool> hasSubmitted({
    required String sessionId,
    required String stationId,
    required String deviceId,
    DateTime? now,
  }) async {
    final entries = await _readEntries(now: now);
    return entries.containsKey(_key(sessionId, stationId, deviceId));
  }

  @override
  Future<void> markSubmitted({
    required String sessionId,
    required String stationId,
    required String deviceId,
    required DateTime submittedAt,
  }) async {
    final entries = await _readEntries(now: submittedAt);
    entries[_key(sessionId, stationId, deviceId)] = submittedAt
        .toUtc()
        .toIso8601String();
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(_storageKey, jsonEncode(entries));
  }

  Future<Map<String, dynamic>> _readEntries({DateTime? now}) async {
    final preferences = await SharedPreferences.getInstance();
    final raw = preferences.getString(_storageKey);
    if (raw == null || raw.isEmpty) {
      return <String, dynamic>{};
    }
    final decoded = jsonDecode(raw);
    if (decoded is! Map<String, dynamic>) {
      return <String, dynamic>{};
    }
    final entries = Map<String, dynamic>.from(decoded);
    final pruned = _pruneExpiredEntries(
      entries: entries,
      now: now ?? _nowProvider(),
    );
    if (pruned.length != entries.length) {
      await preferences.setString(_storageKey, jsonEncode(pruned));
    }
    return pruned;
  }

  Map<String, dynamic> _pruneExpiredEntries({
    required Map<String, dynamic> entries,
    required DateTime now,
  }) {
    final cutoff = now.toUtc().subtract(_entryTtl);
    final result = <String, dynamic>{};
    entries.forEach((key, value) {
      final submittedAt = DateTime.tryParse('$value')?.toUtc();
      if (submittedAt == null) {
        return;
      }
      if (!submittedAt.isBefore(cutoff)) {
        result[key] = value;
      }
    });
    return result;
  }

  String _key(String sessionId, String stationId, String deviceId) {
    return '$sessionId::$stationId::$deviceId';
  }
}
