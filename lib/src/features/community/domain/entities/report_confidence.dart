import 'package:equatable/equatable.dart';

class ReportConfidence extends Equatable {
  const ReportConfidence({
    required this.score,
    int? sampleCount,
    int? sampleSize,
    int? freshnessSeconds,
    double? agreementScore,
  }) : sampleCount = sampleCount ?? sampleSize ?? 0;

  final double score;
  final int sampleCount;

  int get sampleSize => sampleCount;
  int get freshnessSeconds => 0;
  double get agreementScore => 1.0;

  @override
  List<Object> get props => [score, sampleCount];
}
