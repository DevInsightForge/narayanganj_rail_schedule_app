import 'package:flutter_dotenv/flutter_dotenv.dart';

import 'platform_env_stub.dart' if (dart.library.io) 'platform_env_io.dart';

String? readRuntimeEnv(String key) {
  try {
    final dotenvValue = dotenv.env[key]?.trim();
    if (dotenvValue != null && dotenvValue.isNotEmpty) {
      return dotenvValue;
    }
  } catch (_) {}

  final platformValue = readPlatformEnv(key)?.trim();
  if (platformValue != null && platformValue.isNotEmpty) {
    return platformValue;
  }

  return null;
}
