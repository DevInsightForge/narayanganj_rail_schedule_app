import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../../domain/entities/rail_schedule.dart';
import '../models/rail_schedule_document_parser.dart';

class ScheduleDataRepository {
  ScheduleDataRepository({
    required RailScheduleDocumentParser parser,
    http.Client? client,
  }) : _parser = parser,
       _client = client ?? http.Client();

  static const defaultRemoteUrl =
      'https://gist.githubusercontent.com/IMZihad21/cd4d181220aa57d85f6ce4db2cd7ce99/raw/nrs_data.json';
  static const storageKey = 'nrs:schedule-data';

  final RailScheduleDocumentParser _parser;
  final http.Client _client;

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
      final response = await _client.get(
        Uri.parse(resolvedUrl),
        headers: const {
          'accept': 'application/json',
          'cache-control': 'no-cache',
        },
      );

      if (response.statusCode < 200 || response.statusCode >= 300) {
        return null;
      }

      final jsonValue = jsonDecode(response.body);

      if (jsonValue is! Map<String, dynamic>) {
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
