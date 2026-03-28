import 'dart:convert';

import 'package:narayanganj_rail_schedule/src/features/rail/data/default_schedule_json.dart';
import 'package:narayanganj_rail_schedule/src/features/rail/data/models/rail_schedule_document_parser.dart';
import 'package:narayanganj_rail_schedule/src/features/rail/domain/entities/rail_schedule.dart';

RailSchedule loadBundledScheduleFixture() {
  final decoded = jsonDecode(defaultScheduleJson);
  if (decoded is! Map<String, dynamic>) {
    throw const FormatException('Invalid schedule fixture.');
  }
  return RailScheduleDocumentParser().parse(decoded);
}
