import '../entities/session_chat_thread.dart';

abstract class SessionChatRepository {
  Future<SessionChatThread> fetchSessionChat({required String sessionId});

  Future<void> postMessage({
    required String sessionId,
    required SessionChatMessage message,
  });
}
