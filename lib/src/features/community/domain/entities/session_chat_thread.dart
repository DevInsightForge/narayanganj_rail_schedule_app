import 'package:equatable/equatable.dart';

import 'moderation_flag.dart';

class SessionChatMessage extends Equatable {
  const SessionChatMessage({
    required this.messageId,
    required this.sessionId,
    required this.deviceId,
    required this.body,
    required this.createdAt,
    this.displayName,
    this.flags = const [],
  });

  final String messageId;
  final String sessionId;
  final String deviceId;
  final String body;
  final DateTime createdAt;
  final String? displayName;
  final List<ModerationFlag> flags;

  @override
  List<Object?> get props => [
    messageId,
    sessionId,
    deviceId,
    body,
    createdAt,
    displayName,
    flags,
  ];
}

class SessionChatThread extends Equatable {
  const SessionChatThread({
    required this.threadId,
    required this.sessionId,
    required this.eligibleFrom,
    required this.eligibleUntil,
    required this.messages,
  });

  final String threadId;
  final String sessionId;
  final DateTime eligibleFrom;
  final DateTime eligibleUntil;
  final List<SessionChatMessage> messages;

  @override
  List<Object> get props => [
    threadId,
    sessionId,
    eligibleFrom,
    eligibleUntil,
    messages,
  ];
}
