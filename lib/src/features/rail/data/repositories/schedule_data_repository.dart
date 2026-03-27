import 'dart:convert';
import 'dart:developer' as developer;

import 'package:shared_preferences/shared_preferences.dart';

import '../../../../core/config/runtime_env.dart';
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

  static const defaultWebsiteBaseUrl =
      'https://narayanganj-rail-schedule.pages.dev/';
  static const scheduleEndpointPath = 'api/schedule/data.json';
  static const storageKey = 'nrs:schedule-data';
  static const _maxAttempts = 2;

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
        _log(
          'cache_read_failed',
          data: const {'reason': 'stored_payload_not_map'},
        );
        return null;
      }

      final document = _extractDocument(jsonValue);
      final validationFailure = _validateScheduleDocument(document);
      if (validationFailure != null) {
        _log('cache_validation_failed', data: {'reason': validationFailure});
        return null;
      }

      final loadedAt = _extractStoredAt(jsonValue) ?? DateTime.now();
      final schedule = _parser.parse(document);

      _log(
        'cache_read_success',
        data: {
          'loadedAt': loadedAt.toUtc().toIso8601String(),
          'version': schedule.version,
          'sourceUrl': (jsonValue['sourceUrl'] ?? '').toString(),
        },
      );

      return ScheduleLoadResult(
        schedule: schedule,
        source: ScheduleDataSource.cached,
        loadedAt: loadedAt,
      );
    } on FormatException catch (error, stackTrace) {
      _log(
        'cache_parse_failed',
        data: {'reason': error.message},
        error: error,
        stackTrace: stackTrace,
      );
      return null;
    } catch (error, stackTrace) {
      _log(
        'cache_read_failed',
        data: const {'reason': 'exception'},
        error: error,
        stackTrace: stackTrace,
      );
      return null;
    }
  }

  Future<ScheduleLoadResult?> fetchRemoteSchedule() async {
    final scheduleUrl = _resolvedScheduleUrl;
    _log('remote_load_start', data: {'scheduleUrl': scheduleUrl});

    final remoteResult = await _fetchScheduleDocument(
      url: scheduleUrl,
      branch: 'direct',
    );
    if (remoteResult != null) {
      return _parseAndPersistRemote(remoteResult);
    }

    _log(
      'remote_load_failed_all_paths',
      data: const {'fallbackBranch': 'direct_only_bundled_or_cached'},
    );
    return null;
  }

  String get _resolvedScheduleUrl {
    final websiteBaseUrl = readRuntimeEnv('WEBSITE_BASE_URL');
    final baseUri = Uri.tryParse(websiteBaseUrl ?? defaultWebsiteBaseUrl);
    if (baseUri == null) {
      return Uri.parse(
        defaultWebsiteBaseUrl,
      ).resolve(scheduleEndpointPath).toString();
    }
    return baseUri.resolve(scheduleEndpointPath).toString();
  }

  Future<_RemoteScheduleDocument?> _fetchScheduleDocument({
    required String url,
    required String branch,
  }) async {
    if (url.trim().isEmpty) {
      _log(
        'schedule_fetch_skipped',
        data: {'branch': branch, 'reason': 'empty_url'},
      );
      return null;
    }

    final document = await _fetchJsonWithRetry(url: url, branch: branch);
    if (document == null) {
      _log('schedule_fetch_failed', data: {'branch': branch, 'url': url});
      return null;
    }

    final validationFailure = _validateScheduleDocument(document);
    if (validationFailure != null) {
      _log(
        'schedule_validation_failed',
        data: {'branch': branch, 'url': url, 'reason': validationFailure},
      );
      return null;
    }

    _log('schedule_fetch_success', data: {'branch': branch, 'url': url});

    return _RemoteScheduleDocument(sourceUrl: url, document: document);
  }

  Future<Map<String, dynamic>?> _fetchJsonWithRetry({
    required String url,
    required String branch,
  }) async {
    for (var attempt = 1; attempt <= _maxAttempts; attempt++) {
      try {
        _log(
          'http_fetch_start',
          data: {'branch': branch, 'url': url, 'attempt': attempt},
        );

        final response = await _remoteClient.getJson(url);

        if (response.statusCode < 200 || response.statusCode >= 300) {
          _log(
            'http_fetch_non_200',
            data: {
              'branch': branch,
              'url': url,
              'attempt': attempt,
              'statusCode': response.statusCode,
            },
          );
          continue;
        }

        if (response.json == null) {
          _log(
            'http_fetch_invalid_json',
            data: {'branch': branch, 'url': url, 'attempt': attempt},
          );
          continue;
        }

        return response.json;
      } catch (error, stackTrace) {
        _log(
          'http_fetch_exception',
          data: {'branch': branch, 'url': url, 'attempt': attempt},
          error: error,
          stackTrace: stackTrace,
        );
      }
    }

    return null;
  }

  Future<ScheduleLoadResult?> _parseAndPersistRemote(
    _RemoteScheduleDocument remote,
  ) async {
    try {
      final schedule = _parser.parse(remote.document);
      final loadedAt = DateTime.now();

      await _persistDocument(
        document: remote.document,
        sourceUrl: remote.sourceUrl,
        loadedAt: loadedAt,
      );

      return ScheduleLoadResult(
        schedule: schedule,
        source: ScheduleDataSource.remote,
        loadedAt: loadedAt,
      );
    } on FormatException catch (error, stackTrace) {
      _log(
        'schedule_parse_failed',
        data: {'sourceUrl': remote.sourceUrl, 'reason': error.message},
        error: error,
        stackTrace: stackTrace,
      );
      return null;
    } catch (error, stackTrace) {
      _log(
        'schedule_parse_failed',
        data: {'sourceUrl': remote.sourceUrl, 'reason': 'exception'},
        error: error,
        stackTrace: stackTrace,
      );
      return null;
    }
  }

  Future<void> _persistDocument({
    required Map<String, dynamic> document,
    required String sourceUrl,
    required DateTime loadedAt,
  }) async {
    try {
      final preferences = await SharedPreferences.getInstance();
      final wrapped = {
        'fetchedAt': loadedAt.toUtc().toIso8601String(),
        'cachedAt': loadedAt.toUtc().toIso8601String(),
        'sourceUrl': sourceUrl,
        'schemaVersion': '${document['version'] ?? ''}',
        'checksum': '${document['checksum'] ?? ''}',
        'document': document,
      };
      await preferences.setString(storageKey, jsonEncode(wrapped));
    } catch (error, stackTrace) {
      _log(
        'cache_write_failed',
        data: const {'reason': 'exception'},
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

class _RemoteScheduleDocument {
  const _RemoteScheduleDocument({
    required this.sourceUrl,
    required this.document,
  });

  final String sourceUrl;
  final Map<String, dynamic> document;
}
