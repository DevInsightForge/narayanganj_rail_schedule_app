import 'package:equatable/equatable.dart';

enum RailDeepLinkKind { none, board, report, invalidReport }

class RailReportDeepLink extends Equatable {
  const RailReportDeepLink._({
    required this.kind,
    this.trainNo,
    this.direction,
    this.boardingStationId,
  });

  const RailReportDeepLink.none() : this._(kind: RailDeepLinkKind.none);

  const RailReportDeepLink.board() : this._(kind: RailDeepLinkKind.board);

  const RailReportDeepLink.invalidReport()
    : this._(kind: RailDeepLinkKind.invalidReport);

  const RailReportDeepLink.report({
    required int trainNo,
    required String direction,
    required String boardingStationId,
  }) : this._(
         kind: RailDeepLinkKind.report,
         trainNo: trainNo,
         direction: direction,
         boardingStationId: boardingStationId,
       );

  static const String scheme = 'com.devinsightforge.narayanganjcommuter';
  static const String reportHost = 'report';
  static const String boardHost = 'board';

  final RailDeepLinkKind kind;
  final int? trainNo;
  final String? direction;
  final String? boardingStationId;

  bool get isReportAttempt =>
      kind == RailDeepLinkKind.report || kind == RailDeepLinkKind.invalidReport;

  static Uri buildReportUri({
    required int trainNo,
    required String direction,
    required String boardingStationId,
  }) {
    return Uri(
      scheme: scheme,
      host: reportHost,
      queryParameters: <String, String>{
        'trainNo': '$trainNo',
        'direction': direction,
        'boardingStation': boardingStationId,
      },
    );
  }

  static Uri buildBoardUri() {
    return Uri(scheme: scheme, host: boardHost);
  }

  static RailReportDeepLink parse(Uri? uri) {
    if (uri == null) {
      return const RailReportDeepLink.none();
    }
    final raw = uri.toString().trim();
    if (raw.isEmpty) {
      return const RailReportDeepLink.none();
    }
    if (uri.scheme.toLowerCase() != scheme) {
      return const RailReportDeepLink.none();
    }
    final host = uri.host.toLowerCase();
    if (host == boardHost || host.isEmpty) {
      return const RailReportDeepLink.board();
    }
    if (host != reportHost) {
      return const RailReportDeepLink.none();
    }

    final trainRaw = uri.queryParameters['trainNo']?.trim() ?? '';
    final direction = uri.queryParameters['direction']?.trim() ?? '';
    final boardingStation =
        uri.queryParameters['boardingStation']?.trim() ?? '';
    final trainNo = int.tryParse(trainRaw);

    if (trainNo == null ||
        trainNo <= 0 ||
        direction.isEmpty ||
        boardingStation.isEmpty ||
        !_isSafeIdentifier(direction) ||
        !_isSafeIdentifier(boardingStation)) {
      return const RailReportDeepLink.invalidReport();
    }

    return RailReportDeepLink.report(
      trainNo: trainNo,
      direction: direction,
      boardingStationId: boardingStation,
    );
  }

  static bool _isSafeIdentifier(String value) {
    if (value.length > 64) {
      return false;
    }
    for (var i = 0; i < value.length; i++) {
      final code = value.codeUnitAt(i);
      final isLower = code >= 97 && code <= 122;
      final isUpper = code >= 65 && code <= 90;
      final isDigit = code >= 48 && code <= 57;
      final isSeparator = code == 95 || code == 45;
      if (!isLower && !isUpper && !isDigit && !isSeparator) {
        return false;
      }
    }
    return true;
  }

  @override
  List<Object?> get props => [kind, trainNo, direction, boardingStationId];
}
