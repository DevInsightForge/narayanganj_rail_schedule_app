import 'package:narayanganj_rail_schedule/src/features/rail/data/repositories/bundled_schedule_source.dart';
import 'package:narayanganj_rail_schedule/src/features/rail/domain/entities/rail_schedule.dart';

RailSchedule loadBundledScheduleFixture() {
  return const BundledScheduleSource().loadSchedule();
}
