import 'dart:convert';

import '../../domain/entities/rail_schedule.dart';
import '../default_schedule_json.dart';
import '../models/rail_schedule_document_parser.dart';

class BundledScheduleSource {
  const BundledScheduleSource({
    required RailScheduleDocumentParser parser,
    this.documentJson = defaultScheduleJson,
  }) : _parser = parser;

  final RailScheduleDocumentParser _parser;
  final String documentJson;

  RailSchedule loadSchedule() {
    final decoded = jsonDecode(documentJson);
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('Invalid bundled schedule document.');
    }
    return _parser.parse(decoded);
  }
}
