import '../../../domain/entities/session_chat_thread.dart';
import '../../../domain/repositories/session_chat_repository.dart';

class FakeSessionChatRepository implements SessionChatRepository {
  FakeSessionChatRepository({Map<String, SessionChatThread> seed = const {}})
    : _threads = Map<String, SessionChatThread>.from(seed);

  final Map<String, SessionChatThread> _threads;

  @override
  Future<SessionChatThread> fetchSessionChat({
    required String sessionId,
  }) async {
    final existing = _threads[sessionId];
    if (existing != null) {
      return existing;
    }
    final now = DateTime.now();
    final thread = SessionChatThread(
      threadId: 'thread:$sessionId',
      sessionId: sessionId,
      eligibleFrom: now,
      eligibleUntil: now.add(const Duration(hours: 2)),
      messages: const [],
    );
    _threads[sessionId] = thread;
    return thread;
  }

  @override
  Future<void> postMessage({
    required String sessionId,
    required SessionChatMessage message,
  }) async {
    final thread = await fetchSessionChat(sessionId: sessionId);
    _threads[sessionId] = SessionChatThread(
      threadId: thread.threadId,
      sessionId: thread.sessionId,
      eligibleFrom: thread.eligibleFrom,
      eligibleUntil: thread.eligibleUntil,
      messages: [...thread.messages, message],
    );
  }
}
