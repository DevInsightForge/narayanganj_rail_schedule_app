import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

import 'firebase_options_factory.dart';
import 'firebase_runtime.dart';

class FirebaseBootstrap {
  FirebaseBootstrap({
    FirebaseOptionsFactory? optionsFactory,
    Future<FirebaseApp> Function({String? name, FirebaseOptions? options})?
    initializer,
    Future<void> Function({required bool web, String? webRecaptchaKey})?
    appCheckActivator,
  }) : _optionsFactory = optionsFactory ?? const FirebaseOptionsFactory(),
       _initializer = initializer ?? Firebase.initializeApp,
       _appCheckActivator = appCheckActivator ?? _defaultAppCheckActivator;

  final FirebaseOptionsFactory _optionsFactory;
  final Future<FirebaseApp> Function({String? name, FirebaseOptions? options})
  _initializer;
  final Future<void> Function({required bool web, String? webRecaptchaKey})
  _appCheckActivator;

  Future<FirebaseRuntime> initialize() async {
    final options = _optionsFactory.create();
    if (options == null) {
      return FirebaseRuntime.disabled;
    }

    try {
      await _initializer(options: options);
      final appCheckEnabled = _optionsFactory.isAppCheckEnabled;
      if (appCheckEnabled) {
        await _appCheckActivator(
          web: kIsWeb,
          webRecaptchaKey: _optionsFactory.webRecaptchaKey,
        );
      }
      return FirebaseRuntime(
        enabled: true,
        initialized: true,
        appCheckEnabled: appCheckEnabled,
        status: 'initialized',
      );
    } catch (_) {
      return const FirebaseRuntime(
        enabled: true,
        initialized: false,
        appCheckEnabled: false,
        status: 'failed',
      );
    }
  }

  static Future<void> _defaultAppCheckActivator({
    required bool web,
    String? webRecaptchaKey,
  }) async {
    if (web) {
      if (webRecaptchaKey == null || webRecaptchaKey.isEmpty) {
        return;
      }
      await FirebaseAppCheck.instance.activate(
        webProvider: ReCaptchaV3Provider(webRecaptchaKey),
      );
      return;
    }
    await FirebaseAppCheck.instance.activate(
      androidProvider: AndroidProvider.debug,
      appleProvider: AppleProvider.debug,
    );
  }
}
