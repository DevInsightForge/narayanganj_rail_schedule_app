import 'dart:convert';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_remote_config/firebase_remote_config.dart';

import 'schedule_remote_source.dart';

class FirebaseRemoteScheduleSource implements ScheduleRemoteSource {
  FirebaseRemoteScheduleSource({
    FirebaseRemoteConfig? remoteConfig,
    Duration? fetchTimeout,
    Duration? minimumFetchInterval,
  }) : _remoteConfig = remoteConfig,
       _fetchTimeout = fetchTimeout ?? const Duration(seconds: 10),
       _minimumFetchInterval =
           minimumFetchInterval ?? const Duration(minutes: 10);

  static const _parameterKey = 'schedule_data_json';

  final FirebaseRemoteConfig? _remoteConfig;
  final Duration _fetchTimeout;
  final Duration _minimumFetchInterval;

  @override
  Future<RemoteSchedulePayload?> fetchSchedule() async {
    if (Firebase.apps.isEmpty || _remoteConfig == null) {
      return null;
    }

    try {
      await _remoteConfig.setConfigSettings(
        RemoteConfigSettings(
          fetchTimeout: _fetchTimeout,
          minimumFetchInterval: _minimumFetchInterval,
        ),
      );
      await _remoteConfig.setDefaults(<String, dynamic>{_parameterKey: ''});
      await _remoteConfig.fetchAndActivate();
      final raw = _remoteConfig.getString(_parameterKey).trim();
      if (raw.isEmpty) {
        return null;
      }
      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) {
        return null;
      }
      return RemoteSchedulePayload(
        sourceLabel: 'firebase_remote_config:$_parameterKey',
        document: decoded,
      );
    } catch (_) {
      return null;
    }
  }
}
