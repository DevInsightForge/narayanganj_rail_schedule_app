import 'dart:convert';

import 'package:hive/hive.dart';

class CommunityOverlayCacheHive {
  const CommunityOverlayCacheHive({
    required this.sessionId,
    required this.serviceDateKey,
    required this.schemaVersion,
    required this.versionStamp,
    required this.lastSyncedAt,
    required this.fetchedAt,
    required this.sessionStatusSnapshotJson,
    required this.predictedStopTimesJson,
  });

  static const typeId = 41;

  final String sessionId;
  final String serviceDateKey;
  final int schemaVersion;
  final String versionStamp;
  final DateTime lastSyncedAt;
  final DateTime fetchedAt;
  final String sessionStatusSnapshotJson;
  final String predictedStopTimesJson;

  String get boxKey => '$sessionId::$serviceDateKey';

  bool get hasPayload {
    return sessionStatusSnapshotJson.isNotEmpty ||
        predictedStopTimesJson.isNotEmpty;
  }

  CommunityOverlayCacheHive copyWith({
    String? sessionId,
    String? serviceDateKey,
    int? schemaVersion,
    String? versionStamp,
    DateTime? lastSyncedAt,
    DateTime? fetchedAt,
    String? sessionStatusSnapshotJson,
    String? predictedStopTimesJson,
  }) {
    return CommunityOverlayCacheHive(
      sessionId: sessionId ?? this.sessionId,
      serviceDateKey: serviceDateKey ?? this.serviceDateKey,
      schemaVersion: schemaVersion ?? this.schemaVersion,
      versionStamp: versionStamp ?? this.versionStamp,
      lastSyncedAt: lastSyncedAt ?? this.lastSyncedAt,
      fetchedAt: fetchedAt ?? this.fetchedAt,
      sessionStatusSnapshotJson:
          sessionStatusSnapshotJson ?? this.sessionStatusSnapshotJson,
      predictedStopTimesJson:
          predictedStopTimesJson ?? this.predictedStopTimesJson,
    );
  }

  Map<String, dynamic> toLegacyPayload() {
    return <String, dynamic>{
      'fetchedAt': fetchedAt.toUtc().toIso8601String(),
      'sessionStatusSnapshot': sessionStatusSnapshotJson.isEmpty
          ? null
          : jsonDecode(sessionStatusSnapshotJson),
      'predictedStopTimes': predictedStopTimesJson.isEmpty
          ? const []
          : jsonDecode(predictedStopTimesJson),
    };
  }

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'sessionId': sessionId,
      'serviceDateKey': serviceDateKey,
      'schemaVersion': schemaVersion,
      'versionStamp': versionStamp,
      'lastSyncedAt': lastSyncedAt.toUtc().toIso8601String(),
      'fetchedAt': fetchedAt.toUtc().toIso8601String(),
      'sessionStatusSnapshotJson': sessionStatusSnapshotJson,
      'predictedStopTimesJson': predictedStopTimesJson,
    };
  }

  factory CommunityOverlayCacheHive.fromLegacyPayload({
    required String sessionId,
    required String serviceDateKey,
    required Map<String, dynamic> payload,
    int schemaVersion = 1,
  }) {
    final fetchedAt =
        DateTime.tryParse('${payload['fetchedAt'] ?? ''}')?.toLocal() ??
        DateTime.now();
    final snapshot = payload['sessionStatusSnapshot'];
    final predictions = payload['predictedStopTimes'];
    return CommunityOverlayCacheHive(
      sessionId: sessionId,
      serviceDateKey: serviceDateKey,
      schemaVersion: schemaVersion,
      versionStamp: _buildVersionStamp(payload),
      lastSyncedAt: fetchedAt,
      fetchedAt: fetchedAt,
      sessionStatusSnapshotJson: snapshot == null ? '' : jsonEncode(snapshot),
      predictedStopTimesJson: predictions == null
          ? '[]'
          : jsonEncode(predictions),
    );
  }

  factory CommunityOverlayCacheHive.fromMap(Map<String, dynamic> map) {
    return CommunityOverlayCacheHive(
      sessionId: '${map['sessionId'] ?? ''}',
      serviceDateKey: '${map['serviceDateKey'] ?? ''}',
      schemaVersion: (map['schemaVersion'] as num?)?.toInt() ?? 1,
      versionStamp: '${map['versionStamp'] ?? ''}',
      lastSyncedAt:
          DateTime.tryParse('${map['lastSyncedAt'] ?? ''}')?.toLocal() ??
          DateTime.fromMillisecondsSinceEpoch(0),
      fetchedAt:
          DateTime.tryParse('${map['fetchedAt'] ?? ''}')?.toLocal() ??
          DateTime.fromMillisecondsSinceEpoch(0),
      sessionStatusSnapshotJson: '${map['sessionStatusSnapshotJson'] ?? ''}',
      predictedStopTimesJson: '${map['predictedStopTimesJson'] ?? '[]'}',
    );
  }

  static String _buildVersionStamp(Map<String, dynamic> payload) {
    final fetchedAt = '${payload['fetchedAt'] ?? ''}'.trim();
    if (fetchedAt.isNotEmpty) {
      return fetchedAt;
    }
    return DateTime.now().toUtc().toIso8601String();
  }
}

class CommunityOverlayCacheHiveAdapter
    extends TypeAdapter<CommunityOverlayCacheHive> {
  @override
  final int typeId = CommunityOverlayCacheHive.typeId;

  @override
  CommunityOverlayCacheHive read(BinaryReader reader) {
    return CommunityOverlayCacheHive(
      sessionId: reader.readString(),
      serviceDateKey: reader.readString(),
      schemaVersion: reader.readInt(),
      versionStamp: reader.readString(),
      lastSyncedAt: DateTime.fromMillisecondsSinceEpoch(
        reader.readInt(),
        isUtc: true,
      ).toLocal(),
      fetchedAt: DateTime.fromMillisecondsSinceEpoch(
        reader.readInt(),
        isUtc: true,
      ).toLocal(),
      sessionStatusSnapshotJson: reader.readString(),
      predictedStopTimesJson: reader.readString(),
    );
  }

  @override
  void write(BinaryWriter writer, CommunityOverlayCacheHive obj) {
    writer
      ..writeString(obj.sessionId)
      ..writeString(obj.serviceDateKey)
      ..writeInt(obj.schemaVersion)
      ..writeString(obj.versionStamp)
      ..writeInt(obj.lastSyncedAt.toUtc().millisecondsSinceEpoch)
      ..writeInt(obj.fetchedAt.toUtc().millisecondsSinceEpoch)
      ..writeString(obj.sessionStatusSnapshotJson)
      ..writeString(obj.predictedStopTimesJson);
  }
}
