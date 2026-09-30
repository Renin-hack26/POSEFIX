import '../../domain/entities/chat_message.dart';

/// VEDA chat — local history (synced to the account) + GROQ transport.
///
/// Transport contract: returns the assistant reply text. Offline behavior
/// (local retrieval / graceful message) is handled by `AskVeda`.
abstract class VedaRepository {
  /// Full chat history, oldest first.
  Future<List<ChatMessage>> history();

  /// Append a message (marks dirty for sync).
  Future<void> saveMessage(ChatMessage message);

  /// Drop all locally stored chat (Settings → Privacy).
  Future<void> clearHistory();

  /// One GROQ chat completion over [turns]; throws on network failure.
  Future<String> complete({
    required List<ChatMessage> turns,
    required String systemPrompt,
  });
}
