import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../../domain/repositories/arrival_report_ledger_repository.dart';

class SharedPreferencesArrivalReportLedgerRepository
    implements ArrivalReportLedgerRepository {
  static const _storageKey = 'nrs:community:arrival-report-ledger';

  @override
  Future<bool> hasSubmitted({
    required String sessionId,
    required String stationId,
    required String deviceId,
  }) async {
    final entries = await _readEntries();
    return entries.containsKey(_key(sessionId, stationId, deviceId));
  }

  @override
  Future<void> markSubmitted({
    required String sessionId,
    required String stationId,
    required String deviceId,
    required DateTime submittedAt,
  }) async {
    final entries = await _readEntries();
    entries[_key(sessionId, stationId, deviceId)] = submittedAt
        .toUtc()
        .toIso8601String();
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(_storageKey, jsonEncode(entries));
  }

  Future<Map<String, dynamic>> _readEntries() async {
    final preferences = await SharedPreferences.getInstance();
    final raw = preferences.getString(_storageKey);
    if (raw == null || raw.isEmpty) {
      return <String, dynamic>{};
    }
    final decoded = jsonDecode(raw);
    if (decoded is! Map<String, dynamic>) {
      return <String, dynamic>{};
    }
    return Map<String, dynamic>.from(decoded);
  }

  String _key(String sessionId, String stationId, String deviceId) {
    return '$sessionId::$stationId::$deviceId';
  }
}
