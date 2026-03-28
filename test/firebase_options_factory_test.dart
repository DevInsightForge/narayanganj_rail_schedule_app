import 'package:flutter_test/flutter_test.dart';
import 'package:narayanganj_rail_schedule/src/core/firebase/firebase_options_factory.dart';

void main() {
  test('creates firebase options when required env values are present', () {
    final env = <String, String>{
      'FIREBASE_ENABLED': 'true',
      'FIREBASE_API_KEY': 'key',
      'FIREBASE_APP_ID': 'app',
      'FIREBASE_MESSAGING_SENDER_ID': 'sender',
      'FIREBASE_PROJECT_ID': 'project',
    };
    final factory = FirebaseOptionsFactory(envReader: (key) => env[key]);

    final options = factory.create();

    expect(options, isNotNull);
    expect(factory.isEnabled, isTrue);
    expect(options?.projectId, equals('project'));
  });

  test('returns null options when firebase is disabled', () {
    final factory = FirebaseOptionsFactory(
      envReader: (key) => key == 'FIREBASE_ENABLED' ? 'false' : null,
    );

    expect(factory.create(), isNull);
    expect(factory.isEnabled, isFalse);
  });
}
