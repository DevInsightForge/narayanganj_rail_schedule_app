class FirebaseRuntime {
  const FirebaseRuntime({
    required this.enabled,
    required this.initialized,
    required this.appCheckEnabled,
    required this.status,
  });

  final bool enabled;
  final bool initialized;
  final bool appCheckEnabled;
  final String status;

  static const disabled = FirebaseRuntime(
    enabled: false,
    initialized: false,
    appCheckEnabled: false,
    status: 'disabled',
  );
}
