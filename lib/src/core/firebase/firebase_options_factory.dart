import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

import '../config/runtime_env.dart';

class FirebaseOptionsFactory {
  const FirebaseOptionsFactory({String? Function(String key)? envReader})
    : _envReader = envReader ?? readRuntimeEnv;

  final String? Function(String key) _envReader;

  bool get isEnabled => _readBool('FIREBASE_ENABLED');

  bool get isAppCheckEnabled => _readBool('FIREBASE_APPCHECK_ENABLED');

  FirebaseOptions? create() {
    if (!isEnabled) {
      return null;
    }

    final apiKey = _envReader('FIREBASE_API_KEY');
    final appId = _envReader('FIREBASE_APP_ID');
    final messagingSenderId = _envReader('FIREBASE_MESSAGING_SENDER_ID');
    final projectId = _envReader('FIREBASE_PROJECT_ID');
    final authDomain = _envReader('FIREBASE_AUTH_DOMAIN');
    final storageBucket = _envReader('FIREBASE_STORAGE_BUCKET');
    final iosBundleId = _envReader('FIREBASE_IOS_BUNDLE_ID');
    final measurementId = _envReader('FIREBASE_MEASUREMENT_ID');

    if (apiKey == null ||
        appId == null ||
        messagingSenderId == null ||
        projectId == null) {
      return null;
    }

    return FirebaseOptions(
      apiKey: apiKey,
      appId: appId,
      messagingSenderId: messagingSenderId,
      projectId: projectId,
      authDomain: kIsWeb ? authDomain : null,
      storageBucket: storageBucket,
      iosBundleId: iosBundleId,
      measurementId: measurementId,
    );
  }

  String? get webRecaptchaKey => _envReader('FIREBASE_APPCHECK_WEB_KEY');

  bool _readBool(String key) {
    final raw = _envReader(key)?.toLowerCase().trim();
    return raw == 'true' || raw == '1' || raw == 'yes';
  }
}
