import 'package:hive/hive.dart';

class ArrivalReportLedgerEntryHive {
  const ArrivalReportLedgerEntryHive({
    required this.sessionId,
    required this.serviceDateKey,
    required this.stationId,
    required this.deviceFingerprint,
    required this.reportId,
    required this.submittedAt,
    required this.syncedAt,
    required this.schemaVersion,
    required this.versionStamp,
  });

  static const typeId = 42;

  final String sessionId;
  final String serviceDateKey;
  final String stationId;
  final String deviceFingerprint;
  final String reportId;
  final DateTime submittedAt;
  final DateTime? syncedAt;
  final int schemaVersion;
  final String versionStamp;

  String get dedupeKey =>
      '$sessionId::$serviceDateKey::$stationId::$deviceFingerprint';

  ArrivalReportLedgerEntryHive copyWith({
    String? sessionId,
    String? serviceDateKey,
    String? stationId,
    String? deviceFingerprint,
    String? reportId,
    DateTime? submittedAt,
    DateTime? syncedAt,
    int? schemaVersion,
    String? versionStamp,
  }) {
    return ArrivalReportLedgerEntryHive(
      sessionId: sessionId ?? this.sessionId,
      serviceDateKey: serviceDateKey ?? this.serviceDateKey,
      stationId: stationId ?? this.stationId,
      deviceFingerprint: deviceFingerprint ?? this.deviceFingerprint,
      reportId: reportId ?? this.reportId,
      submittedAt: submittedAt ?? this.submittedAt,
      syncedAt: syncedAt ?? this.syncedAt,
      schemaVersion: schemaVersion ?? this.schemaVersion,
      versionStamp: versionStamp ?? this.versionStamp,
    );
  }

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'sessionId': sessionId,
      'serviceDateKey': serviceDateKey,
      'stationId': stationId,
      'deviceFingerprint': deviceFingerprint,
      'reportId': reportId,
      'submittedAt': submittedAt.toUtc().toIso8601String(),
      'syncedAt': syncedAt?.toUtc().toIso8601String(),
      'schemaVersion': schemaVersion,
      'versionStamp': versionStamp,
    };
  }

  factory ArrivalReportLedgerEntryHive.fromLegacyEntry({
    required String sessionId,
    required String serviceDateKey,
    required String stationId,
    required String deviceFingerprint,
    required String submittedAt,
    String reportId = '',
    int schemaVersion = 1,
  }) {
    final parsedSubmittedAt =
        DateTime.tryParse(submittedAt)?.toLocal() ??
        DateTime.fromMillisecondsSinceEpoch(0);
    return ArrivalReportLedgerEntryHive(
      sessionId: sessionId,
      serviceDateKey: serviceDateKey,
      stationId: stationId,
      deviceFingerprint: deviceFingerprint,
      reportId: reportId,
      submittedAt: parsedSubmittedAt,
      syncedAt: parsedSubmittedAt,
      schemaVersion: schemaVersion,
      versionStamp: parsedSubmittedAt.toUtc().toIso8601String(),
    );
  }

  factory ArrivalReportLedgerEntryHive.fromMap(Map<String, dynamic> map) {
    return ArrivalReportLedgerEntryHive(
      sessionId: '${map['sessionId'] ?? ''}',
      serviceDateKey: '${map['serviceDateKey'] ?? ''}',
      stationId: '${map['stationId'] ?? ''}',
      deviceFingerprint: '${map['deviceFingerprint'] ?? ''}',
      reportId: '${map['reportId'] ?? ''}',
      submittedAt:
          DateTime.tryParse('${map['submittedAt'] ?? ''}')?.toLocal() ??
          DateTime.fromMillisecondsSinceEpoch(0),
      syncedAt: DateTime.tryParse('${map['syncedAt'] ?? ''}')?.toLocal(),
      schemaVersion: (map['schemaVersion'] as num?)?.toInt() ?? 1,
      versionStamp: '${map['versionStamp'] ?? ''}',
    );
  }
}

class ArrivalReportLedgerEntryHiveAdapter
    extends TypeAdapter<ArrivalReportLedgerEntryHive> {
  @override
  final int typeId = ArrivalReportLedgerEntryHive.typeId;

  @override
  ArrivalReportLedgerEntryHive read(BinaryReader reader) {
    final hasSyncedAt = reader.readBool();
    return ArrivalReportLedgerEntryHive(
      sessionId: reader.readString(),
      serviceDateKey: reader.readString(),
      stationId: reader.readString(),
      deviceFingerprint: reader.readString(),
      reportId: reader.readString(),
      submittedAt: DateTime.fromMillisecondsSinceEpoch(
        reader.readInt(),
        isUtc: true,
      ).toLocal(),
      syncedAt: hasSyncedAt
          ? DateTime.fromMillisecondsSinceEpoch(
              reader.readInt(),
              isUtc: true,
            ).toLocal()
          : null,
      schemaVersion: reader.readInt(),
      versionStamp: reader.readString(),
    );
  }

  @override
  void write(BinaryWriter writer, ArrivalReportLedgerEntryHive obj) {
    writer
      ..writeString(obj.sessionId)
      ..writeString(obj.serviceDateKey)
      ..writeString(obj.stationId)
      ..writeString(obj.deviceFingerprint)
      ..writeString(obj.reportId)
      ..writeInt(obj.submittedAt.toUtc().millisecondsSinceEpoch)
      ..writeBool(obj.syncedAt != null)
      ..writeInt(
        (obj.syncedAt ?? obj.submittedAt).toUtc().millisecondsSinceEpoch,
      )
      ..writeInt(obj.schemaVersion)
      ..writeString(obj.versionStamp);
  }
}
