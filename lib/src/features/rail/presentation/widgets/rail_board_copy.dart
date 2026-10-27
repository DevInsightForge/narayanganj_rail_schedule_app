class RailBoardCopy {
  static String formatTimeAmPm(String time24) {
    final parts = time24.split(':');
    final hour24 = int.tryParse(parts.isNotEmpty ? parts[0] : '0') ?? 0;
    final minute = int.tryParse(parts.length > 1 ? parts[1] : '0') ?? 0;
    final period = hour24 >= 12 ? 'PM' : 'AM';
    final hour12 = hour24 % 12 == 0 ? 12 : hour24 % 12;
    return '$hour12:${minute.toString().padLeft(2, '0')} $period';
  }

  static String getDurationLabel(int totalMinutes) {
    final safeMinutes = totalMinutes < 0 ? 0 : totalMinutes;
    final hours = safeMinutes ~/ 60;
    final minutes = safeMinutes % 60;

    if (hours == 0) {
      return '$minutes min';
    }

    if (minutes == 0) {
      return hours == 1 ? '1 hour' : '$hours hours';
    }

    if (hours == 1) {
      return '1 hour $minutes min';
    }

    return '$hours hours $minutes min';
  }

  static String getWaitLabel(int waitMinutes) {
    if (waitMinutes <= 0) {
      return 'Now';
    }

    return 'In ${getDurationLabel(waitMinutes)}';
  }

  static String getDecision(int waitMinutes) {
    if (waitMinutes <= 5) {
      return 'Run now';
    }
    if (waitMinutes <= 15) {
      return 'Leave now';
    }
    if (waitMinutes <= 30) {
      return 'You can catch this';
    }
    return 'No need to rush';
  }

  static String getOverdueDecision() {
    return 'Running late / Check platform';
  }

  static String getOverdueDepartureDetail({
    required int overdueMinutes,
    int? delayMinutes,
    String? scheduledDepartureTime,
  }) {
    if (delayMinutes != null &&
        delayMinutes > 0 &&
        scheduledDepartureTime != null) {
      final parts = scheduledDepartureTime.split(':');
      final hour = int.tryParse(parts.isNotEmpty ? parts[0] : '0') ?? 0;
      final minute = int.tryParse(parts.length > 1 ? parts[1] : '0') ?? 0;
      final totalEstMinutes = hour * 60 + minute + delayMinutes;
      final estHour = (totalEstMinutes ~/ 60) % 24;
      final estMin = totalEstMinutes % 60;
      final estTimeStr =
          '${estHour.toString().padLeft(2, '0')}:${estMin.toString().padLeft(2, '0')}';
      final formattedEst = formatTimeAmPm(estTimeStr);
      final remaining = delayMinutes - overdueMinutes;
      if (remaining > 0) {
        return 'Est. $formattedEst (in $remaining min)';
      }
      return 'Est. $formattedEst (arriving)';
    }
    return 'Scheduled $overdueMinutes min ago • Awaiting arrival';
  }

  static String getServicePeriodLabel(String period) {
    return period.split('_').join(' ').toUpperCase();
  }
}
