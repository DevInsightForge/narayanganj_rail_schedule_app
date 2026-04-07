String serviceDayKey(DateTime date) {
  final year = date.year.toString().padLeft(4, '0');
  final month = date.month.toString().padLeft(2, '0');
  final day = date.day.toString().padLeft(2, '0');
  return '$year$month$day';
}

String serviceDateKey(DateTime date) {
  final year = date.year.toString().padLeft(4, '0');
  final month = date.month.toString().padLeft(2, '0');
  final day = date.day.toString().padLeft(2, '0');
  return '$year-$month-$day';
}

bool isSameServiceDay(DateTime? first, DateTime second) {
  if (first == null) {
    return false;
  }
  return first.year == second.year &&
      first.month == second.month &&
      first.day == second.day;
}
