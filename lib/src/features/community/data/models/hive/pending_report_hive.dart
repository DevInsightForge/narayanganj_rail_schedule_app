import 'dart:convert';

import 'package:hive/hive.dart';

class PendingReportHive {
  const PendingReportHive({
    required this.pendingReportId,
    required this.sessionId,
    required this.serviceDateKey,
    required this.stationId,
    required this.deviceFingerprint,
    required this.createdAt,
    required this.lastAttemptAt,
    required this.retryCount,
    required this.status,
    required this.schemaVersion,
    required this.versionStamp,
    required this.payloadJson,
  });

  static const typeId = 43;

  final String pendingReportId;
  final String sessionId;
  final String serviceDateKey;
  final String stationId;
  final String deviceFingerprint;
  final DateTime createdAt;
  final DateTime? lastAttemptAt;
  final int retryCount;
  final String status;
  final int schemaVersion;
  final String versionStamp;
  final String payloadJson;

  String get boxKey => pendingReportId;

  bool get isSynced => status == 'synced';

  PendingReportHive copyWith({
    String? pendingReportId,
    String? sessionId,
    String? serviceDateKey,
    String? stationId,
    String? deviceFingerprint,
    DateTime? createdAt,
    DateTime? lastAttemptAt,
    int? retryCount,
    String? status,
    int? schemaVersion,
    String? versionStamp,
    String? payloadJson,
  }) {
    return PendingReportHive(
      pendingReportId: pendingReportId ?? this.pendingReportId,
      sessionId: sessionId ?? this.sessionId,
      serviceDateKey: serviceDateKey ?? this.serviceDateKey,
      stationId: stationId ?? this.stationId,
      deviceFingerprint: deviceFingerprint ?? this.deviceFingerprint,
      createdAt: createdAt ?? this.createdAt,
      lastAttemptAt: lastAttemptAt ?? this.lastAttemptAt,
      retryCount: retryCount ?? this.retryCount,
      status: status ?? this.status,
      schemaVersion: schemaVersion ?? this.schemaVersion,
      versionStamp: versionStamp ?? this.versionStamp,
      payloadJson: payloadJson ?? this.payloadJson,
    );
  }

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'pendingReportId': pendingReportId,
      'sessionId': sessionId,
      'serviceDateKey': serviceDateKey,
      'stationId': stationId,
      'deviceFingerprint': deviceFingerprint,
      'createdAt': createdAt.toUtc().toIso8601String(),
      'lastAttemptAt': lastAttemptAt?.toUtc().toIso8601String(),
      'retryCount': retryCount,
      'status': status,
      'schemaVersion': schemaVersion,
      'versionStamp': versionStamp,
      'payloadJson': payloadJson,
    };
  }

  Map<String, dynamic> toPayloadMap() {
    final decoded = jsonDecode(payloadJson);
    return decoded is Map<String, dynamic> ? decoded : <String, dynamic>{};
  }

  factory PendingReportHive.fromLegacyPayload({
    required String pendingReportId,
    required String sessionId,
    required String serviceDateKey,
    required String stationId,
    required String deviceFingerprint,
    required Map<String, dynamic> payload,
    int schemaVersion = 1,
  }) {
    final createdAt =
        DateTime.tryParse('${payload['createdAt'] ?? ''}')?.toLocal() ??
        DateTime.now();
    final lastAttemptAt = DateTime.tryParse(
      '${payload['lastAttemptAt'] ?? ''}',
    )?.toLocal();
    return PendingReportHive(
      pendingReportId: pendingReportId,
      sessionId: sessionId,
      serviceDateKey: serviceDateKey,
      stationId: stationId,
      deviceFingerprint: deviceFingerprint,
      createdAt: createdAt,
      lastAttemptAt: lastAttemptAt,
      retryCount: (payload['retryCount'] as num?)?.toInt() ?? 0,
      status: '${payload['status'] ?? 'queued'}',
      schemaVersion: schemaVersion,
      versionStamp:
          '${payload['versionStamp'] ?? createdAt.toUtc().toIso8601String()}',
      payloadJson: jsonEncode(payload),
    );
  }

  factory PendingReportHive.fromMap(Map<String, dynamic> map) {
    return PendingReportHive(
      pendingReportId: '${map['pendingReportId'] ?? ''}',
      sessionId: '${map['sessionId'] ?? ''}',
      serviceDateKey: '${map['serviceDateKey'] ?? ''}',
      stationId: '${map['stationId'] ?? ''}',
      deviceFingerprint: '${map['deviceFingerprint'] ?? ''}',
      createdAt:
          DateTime.tryParse('${map['createdAt'] ?? ''}')?.toLocal() ??
          DateTime.fromMillisecondsSinceEpoch(0),
      lastAttemptAt: DateTime.tryParse(
        '${map['lastAttemptAt'] ?? ''}',
      )?.toLocal(),
      retryCount: (map['retryCount'] as num?)?.toInt() ?? 0,
      status: '${map['status'] ?? 'queued'}',
      schemaVersion: (map['schemaVersion'] as num?)?.toInt() ?? 1,
      versionStamp: '${map['versionStamp'] ?? ''}',
      payloadJson: '${map['payloadJson'] ?? '{}'}',
    );
  }
}

class PendingReportHiveAdapter extends TypeAdapter<PendingReportHive> {
  @override
  final int typeId = PendingReportHive.typeId;

  @override
  PendingReportHive read(BinaryReader reader) {
    final hasLastAttemptAt = reader.readBool();
    return PendingReportHive(
      pendingReportId: reader.readString(),
      sessionId: reader.readString(),
      serviceDateKey: reader.readString(),
      stationId: reader.readString(),
      deviceFingerprint: reader.readString(),
      createdAt: DateTime.fromMillisecondsSinceEpoch(
        reader.readInt(),
        isUtc: true,
      ).toLocal(),
      lastAttemptAt: hasLastAttemptAt
          ? DateTime.fromMillisecondsSinceEpoch(
              reader.readInt(),
              isUtc: true,
            ).toLocal()
          : null,
      retryCount: reader.readInt(),
      status: reader.readString(),
      schemaVersion: reader.readInt(),
      versionStamp: reader.readString(),
      payloadJson: reader.readString(),
    );
  }

  @override
  void write(BinaryWriter writer, PendingReportHive obj) {
    writer
      ..writeString(obj.pendingReportId)
      ..writeString(obj.sessionId)
      ..writeString(obj.serviceDateKey)
      ..writeString(obj.stationId)
      ..writeString(obj.deviceFingerprint)
      ..writeInt(obj.createdAt.toUtc().millisecondsSinceEpoch)
      ..writeBool(obj.lastAttemptAt != null)
      ..writeInt(
        (obj.lastAttemptAt ?? obj.createdAt).toUtc().millisecondsSinceEpoch,
      )
      ..writeInt(obj.retryCount)
      ..writeString(obj.status)
      ..writeInt(obj.schemaVersion)
      ..writeString(obj.versionStamp)
      ..writeString(obj.payloadJson);
  }
}
