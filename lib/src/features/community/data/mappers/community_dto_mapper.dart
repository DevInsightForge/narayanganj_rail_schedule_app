import '../../domain/entities/arrival_report.dart';
import '../dtos/community_dtos.dart';

class CommunityDtoMapper {
  const CommunityDtoMapper();

  ArrivalReport fromArrivalReportDto(ArrivalReportDto dto) {
    return ArrivalReport(
      reportId: dto.reportId,
      sessionId: dto.sessionId,
      stationId: dto.stationId,
      deviceId: dto.deviceId,
      observedArrivalAt: DateTime.parse(dto.observedArrivalAtIso),
      submittedAt: DateTime.parse(dto.submittedAtIso),
      displayName: dto.displayName,
    );
  }

  ArrivalReportDto toArrivalReportDto(ArrivalReport report) {
    return ArrivalReportDto(
      reportId: report.reportId,
      sessionId: report.sessionId,
      stationId: report.stationId,
      deviceId: report.deviceId,
      observedArrivalAtIso: report.observedArrivalAt.toUtc().toIso8601String(),
      submittedAtIso: report.submittedAt.toUtc().toIso8601String(),
      displayName: report.displayName,
    );
  }
}
