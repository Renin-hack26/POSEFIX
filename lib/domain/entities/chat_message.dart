/// VEDA chat message (PLANNING §5.6 / §7).
library;

enum ChatRole { user, assistant }

class ChatMessage {
  const ChatMessage({
    required this.id,
    required this.role,
    required this.text,
    required this.createdAt,
    this.contextRef,
    this.syncedAt,
  });

  final String id;
  final ChatRole role;
  final String text;
  final DateTime createdAt;

  /// Optional pointer to what was discussed (session/report id).
  final String? contextRef;

  /// Server sync watermark (chat history follows the account).
  final DateTime? syncedAt;

  ChatMessage copyWith({DateTime? syncedAt}) => ChatMessage(
        id: id,
        role: role,
        text: text,
        createdAt: createdAt,
        contextRef: contextRef,
        syncedAt: syncedAt ?? this.syncedAt,
      );
}
