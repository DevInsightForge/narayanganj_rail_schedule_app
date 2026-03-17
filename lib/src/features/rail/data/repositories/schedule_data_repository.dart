import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../domain/entities/rail_schedule.dart';
import '../models/rail_schedule_document_parser.dart';
import 'remote_schedule_client.dart';
import 'remote_schedule_client_io.dart'
    if (dart.library.js_interop) 'remote_schedule_client_web.dart';

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

  Future<RailSchedule?> readStoredSchedule() async {
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

      return _parser.parse(jsonValue);
    } catch (_) {
      return null;
    }
  }

  Future<RailSchedule?> fetchRemoteSchedule({String? url}) async {
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
      await _persistDocument(jsonValue);
      return schedule;
    } catch (_) {
      return null;
    }
  }

  Future<void> _persistDocument(Map<String, dynamic> document) async {
    try {
      final preferences = await SharedPreferences.getInstance();
      await preferences.setString(storageKey, jsonEncode(document));
    } catch (_) {}
  }
}
