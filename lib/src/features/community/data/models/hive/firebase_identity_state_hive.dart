import 'package:hive/hive.dart';

class FirebaseIdentityStateHive {
  const FirebaseIdentityStateHive({
    required this.uid,
    required this.handshakeCompleted,
    required this.schemaVersion,
    required this.lastSyncedAt,
  });

  static const typeId = 44;

  final String uid;
  final bool handshakeCompleted;
  final int schemaVersion;
  final DateTime lastSyncedAt;

  FirebaseIdentityStateHive copyWith({
    String? uid,
    bool? handshakeCompleted,
    int? schemaVersion,
    DateTime? lastSyncedAt,
  }) {
    return FirebaseIdentityStateHive(
      uid: uid ?? this.uid,
      handshakeCompleted: handshakeCompleted ?? this.handshakeCompleted,
      schemaVersion: schemaVersion ?? this.schemaVersion,
      lastSyncedAt: lastSyncedAt ?? this.lastSyncedAt,
    );
  }

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'uid': uid,
      'handshakeCompleted': handshakeCompleted,
      'schemaVersion': schemaVersion,
      'lastSyncedAt': lastSyncedAt.toUtc().toIso8601String(),
    };
  }

  factory FirebaseIdentityStateHive.fromLegacyMap(Map<String, dynamic> map) {
    return FirebaseIdentityStateHive(
      uid: '${map['uid'] ?? ''}',
      handshakeCompleted: map['handshakeCompleted'] == true,
      schemaVersion: 1,
      lastSyncedAt: DateTime.now(),
    );
  }

  factory FirebaseIdentityStateHive.fromMap(Map<String, dynamic> map) {
    return FirebaseIdentityStateHive(
      uid: '${map['uid'] ?? ''}',
      handshakeCompleted: map['handshakeCompleted'] == true,
      schemaVersion: (map['schemaVersion'] as num?)?.toInt() ?? 1,
      lastSyncedAt:
          DateTime.tryParse('${map['lastSyncedAt'] ?? ''}')?.toLocal() ??
          DateTime.fromMillisecondsSinceEpoch(0),
    );
  }
}

class FirebaseIdentityStateHiveAdapter
    extends TypeAdapter<FirebaseIdentityStateHive> {
  @override
  final int typeId = FirebaseIdentityStateHive.typeId;

  @override
  FirebaseIdentityStateHive read(BinaryReader reader) {
    return FirebaseIdentityStateHive(
      uid: reader.readString(),
      handshakeCompleted: reader.readBool(),
      schemaVersion: reader.readInt(),
      lastSyncedAt: DateTime.fromMillisecondsSinceEpoch(
        reader.readInt(),
        isUtc: true,
      ).toLocal(),
    );
  }

  @override
  void write(BinaryWriter writer, FirebaseIdentityStateHive obj) {
    writer
      ..writeString(obj.uid)
      ..writeBool(obj.handshakeCompleted)
      ..writeInt(obj.schemaVersion)
      ..writeInt(obj.lastSyncedAt.toUtc().millisecondsSinceEpoch);
  }
}
