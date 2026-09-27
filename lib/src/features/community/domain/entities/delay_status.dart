enum DelayStatus {
  early,
  onTime,
  minorDelay,
  majorDelay,
  severeDelay;

  static DelayStatus fromString(String value) {
    return switch (value.toLowerCase()) {
      'early' => DelayStatus.early,
      'on_time' || 'ontime' => DelayStatus.onTime,
      'minor_delay' => DelayStatus.minorDelay,
      'major_delay' => DelayStatus.majorDelay,
      'severe_delay' => DelayStatus.severeDelay,
      'late' || 'delayed' => DelayStatus.minorDelay,
      _ => DelayStatus.onTime,
    };
  }

  String toApiString() {
    return switch (this) {
      DelayStatus.early => 'early',
      DelayStatus.onTime => 'on_time',
      DelayStatus.minorDelay => 'minor_delay',
      DelayStatus.majorDelay => 'major_delay',
      DelayStatus.severeDelay => 'severe_delay',
    };
  }
}
