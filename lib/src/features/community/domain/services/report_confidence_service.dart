import '../entities/arrival_report.dart';
import '../entities/report_confidence.dart';

class ReportConfidenceService {
  const ReportConfidenceService({
    this.freshnessWindowSeconds = 15 * 60,
    this.agreementToleranceMinutes = 3,
  });

  final int freshnessWindowSeconds;
  final int agreementToleranceMinutes;

  ReportConfidence evaluate({
    required List<ArrivalReport> reports,
    required DateTime now,
  }) {
    if (reports.isEmpty) {
      return const ReportConfidence(
        score: 0,
        sampleSize: 0,
        freshnessSeconds: 0,
        agreementScore: 0,
      );
    }

    final sorted = reports.toList()
      ..sort((a, b) => b.submittedAt.compareTo(a.submittedAt));
    final latest = sorted.first;
    final freshnessSeconds = now.difference(latest.submittedAt).inSeconds;
    final freshnessScore = _clamp01(
      1 - (freshnessSeconds / freshnessWindowSeconds),
    );
    final agreementScore = _agreementScore(reports);
    final sampleScore = _clamp01(reports.length / 5);
    final score = _clamp01(
      (freshnessScore * 0.5) + (agreementScore * 0.35) + (sampleScore * 0.15),
    );

    return ReportConfidence(
      score: score,
      sampleSize: reports.length,
      freshnessSeconds: freshnessSeconds < 0 ? 0 : freshnessSeconds,
      agreementScore: agreementScore,
    );
  }

  double _agreementScore(List<ArrivalReport> reports) {
    if (reports.length <= 1) {
      return 1;
    }
    final observedMinutes =
        reports
            .map(
              (report) =>
                  report.observedArrivalAt.millisecondsSinceEpoch ~/ 60000,
            )
            .toList()
          ..sort();
    final median = observedMinutes[observedMinutes.length ~/ 2];
    final agreeing = observedMinutes.where((value) {
      final delta = value - median;
      return delta.abs() <= agreementToleranceMinutes;
    }).length;
    return _clamp01(agreeing / reports.length);
  }

  double _clamp01(double value) {
    if (value < 0) {
      return 0;
    }
    if (value > 1) {
      return 1;
    }
    return value;
  }
}
