import 'package:flutter_test/flutter_test.dart';
import 'package:narayanganj_rail_schedule/src/core/firebase/firebase_options_factory.dart';

void main() {
  test('creates firebase options when required env values are present', () {
    final env = <String, String>{
      'FIREBASE_ENABLED': 'true',
      'FIREBASE_API_KEY': 'key',
      'FIREBASE_PROJECT_ID': 'project',
    };
    final factory = FirebaseOptionsFactory(envReader: (key) => env[key]);

    final options = factory.create();

    expect(options, isNotNull);
    expect(factory.isEnabled, isTrue);
    expect(options?.projectId, equals('project'));
    expect(options?.storageBucket, equals('project.firebasestorage.app'));
  });

  test('returns null options when firebase is disabled', () {
    final factory = FirebaseOptionsFactory(
      envReader: (key) => key == 'FIREBASE_ENABLED' ? 'false' : null,
    );

    expect(factory.create(), isNull);
    expect(factory.isEnabled, isFalse);
  });

  test('returns null options when required env values are missing', () {
    final factory = const FirebaseOptionsFactory(envReader: _emptyEnv);

    final options = factory.create();

    expect(factory.isEnabled, isTrue);
    expect(options, isNull);
  });

  test('treats blank env values as missing', () {
    final env = <String, String>{
      'FIREBASE_ENABLED': 'true',
      'FIREBASE_API_KEY': '   ',
      'FIREBASE_PROJECT_ID': 'project',
    };
    final factory = FirebaseOptionsFactory(envReader: (key) => env[key]);

    expect(factory.create(), isNull);
  });

  test('reads error reporting flag independently', () {
    final env = <String, String>{
      'FIREBASE_ENABLED': 'true',
      'FIREBASE_CRASHLYTICS_ENABLED': 'true',
    };
    final factory = FirebaseOptionsFactory(envReader: (key) => env[key]);

    expect(factory.isErrorReportingEnabled, isTrue);
  });
}

String? _emptyEnv(String key) => null;
