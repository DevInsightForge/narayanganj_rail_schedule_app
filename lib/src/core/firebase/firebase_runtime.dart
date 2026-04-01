class FirebaseRuntime {
  const FirebaseRuntime({
    required this.enabled,
    required this.initialized,
    required this.appCheckEnabled,
    required this.errorReportingEnabled,
    required this.status,
  });

  final bool enabled;
  final bool initialized;
  final bool appCheckEnabled;
  final bool errorReportingEnabled;
  final String status;

  static const disabled = FirebaseRuntime(
    enabled: false,
    initialized: false,
    appCheckEnabled: false,
    errorReportingEnabled: false,
    status: 'disabled',
  );
}
