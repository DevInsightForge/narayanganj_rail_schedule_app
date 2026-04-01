import 'package:flutter/foundation.dart';

class DebugLogger {
  const DebugLogger(this.scope);

  final String scope;

  void log(String message, {Map<String, Object?> context = const {}}) {
    if (!kDebugMode) {
      return;
    }
    if (context.isEmpty) {
      debugPrint('[$scope] $message');
      return;
    }
    final serialized = context.entries
        .map((entry) => '${entry.key}=${entry.value}')
        .join(' ');
    debugPrint('[$scope] $message $serialized');
  }
}
