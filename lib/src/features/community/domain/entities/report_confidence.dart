import 'package:equatable/equatable.dart';

class ReportConfidence extends Equatable {
  const ReportConfidence({
    required this.score,
    required this.sampleSize,
    required this.freshnessSeconds,
    required this.agreementScore,
  });

  final double score;
  final int sampleSize;
  final int freshnessSeconds;
  final double agreementScore;

  @override
  List<Object> get props => [
    score,
    sampleSize,
    freshnessSeconds,
    agreementScore,
  ];
}
