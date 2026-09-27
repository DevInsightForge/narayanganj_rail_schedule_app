enum Freshness {
  live,
  stale,
  scheduled;

  static Freshness fromString(String value) {
    return switch (value.toLowerCase()) {
      'live' => Freshness.live,
      'stale' => Freshness.stale,
      _ => Freshness.scheduled,
    };
  }
}
