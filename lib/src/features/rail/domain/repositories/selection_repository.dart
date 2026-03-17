import '../entities/rail_selection.dart';

abstract class SelectionRepository {
  Future<RailSelection?> read();
  Future<void> write(RailSelection selection);
}
