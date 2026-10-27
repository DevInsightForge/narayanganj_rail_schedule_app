import 'package:equatable/equatable.dart';

class ReportConfidence extends Equatable {
  const ReportConfidence({required this.score, this.sampleCount = 0});

  final double score;
  final int sampleCount;

  @override
  List<Object> get props => [score, sampleCount];
}
