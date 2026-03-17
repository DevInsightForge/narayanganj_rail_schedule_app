import 'package:shared_preferences/shared_preferences.dart';

import '../../domain/entities/rail_selection.dart';
import '../../domain/repositories/selection_repository.dart';

class SharedPreferencesSelectionRepository implements SelectionRepository {
  static const _directionKey = 'nrs:selected-direction';
  static const _boardingKey = 'nrs:boarding-station';
  static const _destinationKey = 'nrs:destination-station';

  @override
  Future<RailSelection?> read() async {
    final preferences = await SharedPreferences.getInstance();
    final direction = preferences.getString(_directionKey);
    final boardingStationId = preferences.getString(_boardingKey);
    final destinationStationId = preferences.getString(_destinationKey);

    if (direction == null ||
        boardingStationId == null ||
        destinationStationId == null) {
      return null;
    }

    return RailSelection(
      direction: direction,
      boardingStationId: boardingStationId,
      destinationStationId: destinationStationId,
    );
  }

  @override
  Future<void> write(RailSelection selection) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(_directionKey, selection.direction);
    await preferences.setString(_boardingKey, selection.boardingStationId);
    await preferences.setString(
      _destinationKey,
      selection.destinationStationId,
    );
  }
}
