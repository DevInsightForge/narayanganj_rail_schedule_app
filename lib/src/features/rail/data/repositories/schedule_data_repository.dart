import 'dart:convert';
import 'dart:developer' as developer;

import 'package:shared_preferences/shared_preferences.dart';

import '../../domain/entities/rail_schedule.dart';
import '../models/rail_schedule_document_parser.dart';
import 'schedule_remote_source.dart';

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
    ScheduleRemoteSource? remoteSource,
  }) : _parser = parser,
       _remoteSource = remoteSource;

  static const storageKey = 'nrs:schedule-data';

  final RailScheduleDocumentParser _parser;
  final ScheduleRemoteSource? _remoteSource;

  Future<ScheduleLoadResult?> readStoredSchedule() async {
    try {
      final preferences = await SharedPreferences.getInstance();
      final value = preferences.getString(storageKey);
      if (value == null || value.isEmpty) {
        return null;
      }

      final jsonValue = jsonDecode(value);
      if (jsonValue is! Map<String, dynamic>) {
        return null;
      }

      final document = _extractDocument(jsonValue);
      final validationFailure = _validateScheduleDocument(document);
      if (validationFailure != null) {
        return null;
      }

      final loadedAt = _extractStoredAt(jsonValue) ?? DateTime.now();
      final schedule = _parser.parse(document);
      return ScheduleLoadResult(
        schedule: schedule,
        source: ScheduleDataSource.cached,
        loadedAt: loadedAt,
      );
    } catch (_) {
      return null;
    }
  }

  Future<ScheduleLoadResult?> fetchRemoteSchedule() async {
    final source = _remoteSource;
    if (source == null) {
      return null;
    }

    _log('remote_load_start');

    RemoteSchedulePayload? remotePayload;
    try {
      remotePayload = await source.fetchSchedule();
    } catch (error, stackTrace) {
      _log(
        'remote_load_failed',
        data: const {'reason': 'source_exception'},
        error: error,
        stackTrace: stackTrace,
      );
      return null;
    }

    if (remotePayload == null) {
      _log('remote_load_empty');
      return null;
    }

    final validationFailure = _validateScheduleDocument(remotePayload.document);
    if (validationFailure != null) {
      _log('remote_load_invalid', data: {'reason': validationFailure});
      return null;
    }

    final remoteVersion = _extractVersion(remotePayload.document);
    final storedVersion = await _readStoredVersion();
    if (remoteVersion.isNotEmpty &&
        storedVersion.isNotEmpty &&
        remoteVersion == storedVersion) {
      _log(
        'remote_load_skipped_same_version',
        data: {'version': remoteVersion},
      );
      return null;
    }

    try {
      final schedule = _parser.parse(remotePayload.document);
      final loadedAt = DateTime.now();
      await _persistDocument(
        document: remotePayload.document,
        sourceLabel: remotePayload.sourceLabel,
        loadedAt: loadedAt,
      );
      _log(
        'remote_load_success',
        data: {
          'version': schedule.version,
          'source': remotePayload.sourceLabel,
        },
      );
      return ScheduleLoadResult(
        schedule: schedule,
        source: ScheduleDataSource.remote,
        loadedAt: loadedAt,
      );
    } catch (error, stackTrace) {
      _log(
        'remote_parse_failed',
        data: {'source': remotePayload.sourceLabel},
        error: error,
        stackTrace: stackTrace,
      );
      return null;
    }
  }

  Future<void> _persistDocument({
    required Map<String, dynamic> document,
    required String sourceLabel,
    required DateTime loadedAt,
  }) async {
    final preferences = await SharedPreferences.getInstance();
    final wrapped = {
      'fetchedAt': loadedAt.toUtc().toIso8601String(),
      'cachedAt': loadedAt.toUtc().toIso8601String(),
      'sourceUrl': sourceLabel,
      'schemaVersion': _extractVersion(document),
      'checksum': '${document['checksum'] ?? ''}',
      'document': document,
    };
    await preferences.setString(storageKey, jsonEncode(wrapped));
  }

  Future<String> _readStoredVersion() async {
    try {
      final preferences = await SharedPreferences.getInstance();
      final value = preferences.getString(storageKey);
      if (value == null || value.isEmpty) {
        return '';
      }
      final jsonValue = jsonDecode(value);
      if (jsonValue is! Map<String, dynamic>) {
        return '';
      }
      final schemaVersion = '${jsonValue['schemaVersion'] ?? ''}'.trim();
      if (schemaVersion.isNotEmpty) {
        return schemaVersion;
      }
      final document = _extractDocument(jsonValue);
      return _extractVersion(document);
    } catch (_) {
      return '';
    }
  }

  Map<String, dynamic> _extractDocument(Map<String, dynamic> storedValue) {
    final wrapped = storedValue['document'];
    if (wrapped is Map<String, dynamic>) {
      return wrapped;
    }
    return storedValue;
  }

  DateTime? _extractStoredAt(Map<String, dynamic> storedValue) {
    final fetched = '${storedValue['fetchedAt'] ?? ''}'.trim();
    if (fetched.isNotEmpty) {
      return DateTime.tryParse(fetched)?.toLocal();
    }
    final cached = '${storedValue['cachedAt'] ?? ''}'.trim();
    if (cached.isNotEmpty) {
      return DateTime.tryParse(cached)?.toLocal();
    }
    return null;
  }

  String _extractVersion(Map<String, dynamic> document) {
    return '${document['version'] ?? ''}'.trim();
  }

  String? _validateScheduleDocument(Map<String, dynamic> document) {
    final stations = document['stations'];
    if (stations is! List || stations.isEmpty) {
      return 'stations_missing_or_empty';
    }
    final directions = document['directions'];
    if (directions is! List || directions.isEmpty) {
      return 'directions_missing_or_empty';
    }
    final trips = document['trips'];
    final tripsByDirection = document['tripsByDirection'];
    final hasTrips = trips is List && trips.isNotEmpty;
    final hasTripsByDirection =
        tripsByDirection is Map && tripsByDirection.isNotEmpty;
    if (!hasTrips && !hasTripsByDirection) {
      return 'trips_missing_or_empty';
    }
    return null;
  }

  void _log(
    String event, {
    Map<String, Object?> data = const {},
    Object? error,
    StackTrace? stackTrace,
  }) {
    final payload = {'event': event, ...data};
    developer.log(
      jsonEncode(payload),
      name: 'ScheduleDataRepository',
      error: error,
      stackTrace: stackTrace,
    );
  }
}
