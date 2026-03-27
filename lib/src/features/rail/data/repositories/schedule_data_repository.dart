import 'dart:convert';
import 'dart:developer' as developer;

import 'package:shared_preferences/shared_preferences.dart';

import '../../domain/entities/rail_schedule.dart';
import '../models/rail_schedule_document_parser.dart';
import 'remote_schedule_client.dart';
import 'remote_schedule_client_io.dart'
    if (dart.library.js_interop) 'remote_schedule_client_web.dart';

enum ScheduleDataSource { bundled, cached, remote }

class ScheduleLoadResult {
  const ScheduleLoadResult({
    required this.schedule,
    required this.source,
    required this.loadedAt,
  });

  final RailSchedule schedule;
  final ScheduleDataSource source;
  final DateTime loadedAt;
}

class ScheduleDataRepository {
  ScheduleDataRepository({
    required RailScheduleDocumentParser parser,
    RemoteScheduleClient? remoteClient,
  }) : _parser = parser,
       _remoteClient = remoteClient ?? RemoteScheduleClientImpl();

  static const defaultRemoteUrl =
      'https://gist.githubusercontent.com/IMZihad21/cd4d181220aa57d85f6ce4db2cd7ce99/raw/nrs_data.json';
  static const storageKey = 'nrs:schedule-data';

  final RailScheduleDocumentParser _parser;
  final RemoteScheduleClient _remoteClient;

  Future<ScheduleLoadResult?> readStoredSchedule() async {
    try {
      final preferences = await SharedPreferences.getInstance();
      final value = preferences.getString(storageKey);

      if (value == null || value.isEmpty) {
        return null;
      }

      final jsonValue = jsonDecode(value);
      if (jsonValue is! Map<String, dynamic>) {
        developer.log('Stored schedule is not a JSON object.', name: '$ScheduleDataRepository');
        return null;
      }

      final loadedAt = _extractStoredAt(jsonValue) ?? DateTime.now();
      final document = _extractDocument(jsonValue);
      final schedule = _parser.parse(document);

      return ScheduleLoadResult(
        schedule: schedule,
        source: ScheduleDataSource.cached,
        loadedAt: loadedAt,
      );
    } catch (error, stackTrace) {
      developer.log(
        'Failed to read cached schedule. Falling back to bundled data.',
        name: '$ScheduleDataRepository',
        error: error,
        stackTrace: stackTrace,
      );
      return null;
    }
  }

  Future<ScheduleLoadResult?> fetchRemoteSchedule({String? url}) async {
    final resolvedUrl =
        url ??
        const String.fromEnvironment(
          'SCHEDULE_DATA_URL',
          defaultValue: defaultRemoteUrl,
        );

    if (resolvedUrl.trim().isEmpty) {
      return null;
    }

    try {
      final jsonValue = await _remoteClient.getJson(resolvedUrl);

      if (jsonValue == null) {
        return null;
      }

      final schedule = _parser.parse(jsonValue);
      final loadedAt = DateTime.now();
      await _persistDocument(document: jsonValue, loadedAt: loadedAt);

      return ScheduleLoadResult(
        schedule: schedule,
        source: ScheduleDataSource.remote,
        loadedAt: loadedAt,
      );
    } on FormatException catch (error, stackTrace) {
      developer.log(
        'Remote schedule format invalid. Keeping existing schedule.',
        name: '$ScheduleDataRepository',
        error: error,
        stackTrace: stackTrace,
      );
      return null;
    } catch (error, stackTrace) {
      developer.log(
        'Remote schedule fetch failed. Keeping existing schedule.',
        name: '$ScheduleDataRepository',
        error: error,
        stackTrace: stackTrace,
      );
      return null;
    }
  }

  Future<void> _persistDocument({
    required Map<String, dynamic> document,
    required DateTime loadedAt,
  }) async {
    try {
      final preferences = await SharedPreferences.getInstance();
      final wrapped = {
        'cachedAt': loadedAt.toUtc().toIso8601String(),
        'document': document,
      };
      await preferences.setString(storageKey, jsonEncode(wrapped));
    } catch (error, stackTrace) {
      developer.log(
        'Failed to persist schedule cache.',
        name: '$ScheduleDataRepository',
        error: error,
        stackTrace: stackTrace,
      );
    }
  }

  Map<String, dynamic> _extractDocument(Map<String, dynamic> storedValue) {
    final wrapped = storedValue['document'];
    if (wrapped is Map<String, dynamic>) {
      return wrapped;
    }

    // Backward-compatible with legacy payload that stored the document directly.
    return storedValue;
  }

  DateTime? _extractStoredAt(Map<String, dynamic> storedValue) {
    final raw = '${storedValue['cachedAt'] ?? ''}'.trim();
    if (raw.isEmpty) {
      return null;
    }

    return DateTime.tryParse(raw)?.toLocal();
  }
}
