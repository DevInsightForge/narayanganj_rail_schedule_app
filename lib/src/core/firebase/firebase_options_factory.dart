import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

import '../config/runtime_env.dart';

class FirebaseOptionsFactory {
  const FirebaseOptionsFactory({String? Function(String key)? envReader})
    : _envReader = envReader ?? readRuntimeEnv;

  final String? Function(String key) _envReader;
  static const _messagingSenderId = '557962758918';
  static const _androidAppId = '1:557962758918:android:efb077ad132b6f8aa16c87';
  static const _iosAppId = '1:557962758918:ios:e75927029f3f6905a16c87';
  static const _webAppId = '1:557962758918:web:6aefc485501427b9a16c87';
  static const _iosBundleId = 'com.devinsightforge.narayanganjcommuter';

  bool get isEnabled => _readBool('FIREBASE_ENABLED', defaultValue: true);

  bool get isAppCheckEnabled =>
      _readBool('FIREBASE_APPCHECK_ENABLED', defaultValue: false);

  bool get isErrorReportingEnabled =>
      _readBool('FIREBASE_CRASHLYTICS_ENABLED', defaultValue: false);

  FirebaseOptions? create() {
    if (!isEnabled) {
      return null;
    }
    return _createEnvOptions();
  }

  String? get webRecaptchaKey => _envReader('FIREBASE_APPCHECK_WEB_KEY');

  FirebaseOptions? _createEnvOptions() {
    final apiKey =
        _readString('FIREBASE_API_KEY') ??
        (kIsWeb
            ? _readString('FIREBASE_WEB_API_KEY')
            : switch (defaultTargetPlatform) {
                TargetPlatform.android => _readString(
                  'FIREBASE_ANDROID_API_KEY',
                ),
                TargetPlatform.iOS => _readString('FIREBASE_IOS_API_KEY'),
                _ => null,
              });
    final projectId = _readString('FIREBASE_PROJECT_ID');
    final measurementId = _readString('FIREBASE_MEASUREMENT_ID');

    if (apiKey == null || projectId == null) {
      return null;
    }

    final authDomain = '$projectId.firebaseapp.com';
    final storageBucket = '$projectId.firebasestorage.app';

    if (kIsWeb) {
      return FirebaseOptions(
        apiKey: apiKey,
        appId: _webAppId,
        messagingSenderId: _messagingSenderId,
        projectId: projectId,
        authDomain: authDomain,
        storageBucket: storageBucket,
        measurementId: measurementId,
      );
    }

    return switch (defaultTargetPlatform) {
      TargetPlatform.android => FirebaseOptions(
        apiKey: apiKey,
        appId: _androidAppId,
        messagingSenderId: _messagingSenderId,
        projectId: projectId,
        storageBucket: storageBucket,
      ),
      TargetPlatform.iOS => FirebaseOptions(
        apiKey: apiKey,
        appId: _iosAppId,
        messagingSenderId: _messagingSenderId,
        projectId: projectId,
        storageBucket: storageBucket,
        iosBundleId: _iosBundleId,
      ),
      _ => null,
    };
  }

  String? _readString(String key) {
    final raw = _envReader(key)?.trim();
    if (raw == null || raw.isEmpty) {
      return null;
    }
    return raw;
  }

  bool _readBool(String key, {required bool defaultValue}) {
    final raw = _envReader(key)?.toLowerCase().trim();
    if (raw == null || raw.isEmpty) {
      return defaultValue;
    }
    return raw == 'true' || raw == '1' || raw == 'yes';
  }
}
