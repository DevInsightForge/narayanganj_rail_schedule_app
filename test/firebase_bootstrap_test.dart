import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:narayanganj_rail_schedule/src/core/firebase/firebase_bootstrap.dart';
import 'package:narayanganj_rail_schedule/src/core/firebase/firebase_options_factory.dart';

void main() {
  test('returns failed runtime when initializer throws', () async {
    final env = <String, String>{
      'FIREBASE_ENABLED': 'true',
      'FIREBASE_API_KEY': 'key',
      'FIREBASE_PROJECT_ID': 'project',
      'FIREBASE_APPCHECK_ENABLED': 'true',
    };
    var appCheckActivated = false;
    final bootstrap = FirebaseBootstrap(
      optionsFactory: FirebaseOptionsFactory(envReader: (key) => env[key]),
      initializer: ({name, options}) =>
          Future<FirebaseApp>.error(StateError('init mocked')),
      appCheckActivator: ({required web, webRecaptchaKey}) async {
        appCheckActivated = true;
      },
    );

    final runtime = await bootstrap.initialize();

    expect(runtime.enabled, isTrue);
    expect(runtime.initialized, isFalse);
    expect(appCheckActivated, isFalse);
  });

  test(
    'returns disabled runtime when firebase is explicitly disabled',
    () async {
      final bootstrap = FirebaseBootstrap(
        optionsFactory: const FirebaseOptionsFactory(envReader: _disabledEnv),
        initializer: ({name, options}) =>
            Future<FirebaseApp>.error(StateError('should not initialize')),
      );

      final runtime = await bootstrap.initialize();
      expect(runtime.enabled, isFalse);
      expect(runtime.initialized, isFalse);
    },
  );
}

String? _disabledEnv(String key) => key == 'FIREBASE_ENABLED' ? 'false' : null;
