class FirestoreCollectionNames {
  const FirestoreCollectionNames._();

  static const sessionStatusSnapshots = 'session_status_snapshots';
  static const sessionStatusSnapshotsDebug = 'session_status_snapshots_debug';

  static String sessionStatusSnapshotsForDebugMode(bool debugMode) {
    return debugMode ? sessionStatusSnapshotsDebug : sessionStatusSnapshots;
  }
}
