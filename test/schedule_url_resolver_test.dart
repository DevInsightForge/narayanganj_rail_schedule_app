import 'package:flutter_test/flutter_test.dart';
import 'package:narayanganj_rail_schedule/src/features/rail/data/repositories/schedule_url_resolver.dart';

void main() {
  group('resolveScheduleUriFromManifest', () {
    final manifestUri = Uri.parse('https://example.com/schedule/manifest.json');

    test('resolves relative latest_path against manifest directory', () {
      final resolved = resolveScheduleUriFromManifest(
        manifestUri: manifestUri,
        latestPath: 'schedule-data-v1.json',
      );

      expect(
        resolved?.toString(),
        equals('https://example.com/schedule/schedule-data-v1.json'),
      );
    });

    test('resolves absolute latest_path against manifest origin', () {
      final resolved = resolveScheduleUriFromManifest(
        manifestUri: manifestUri,
        latestPath: '/schedule/schedule-data-v1.json',
      );

      expect(
        resolved?.toString(),
        equals('https://example.com/schedule/schedule-data-v1.json'),
      );
    });

    test('returns full URL latest_path as-is', () {
      const latestPath = 'https://cdn.example.com/schedule-data-v1.json';
      final resolved = resolveScheduleUriFromManifest(
        manifestUri: manifestUri,
        latestPath: latestPath,
      );

      expect(resolved?.toString(), equals(latestPath));
    });
  });
}
