import 'package:drift/drift.dart';

import '../../../core/storage/app_database.dart';
import '../../../domain/entities/chat_message.dart';

part 'chat_dao.g.dart';

/// VEDA chat history.
@DriftAccessor(tables: [ChatMessages])
class ChatDao extends DatabaseAccessor<AppDatabase> with _$ChatDaoMixin {
  ChatDao(super.db);

  ChatMessage _fromRow(ChatMessageRow row) => ChatMessage(
        id: row.id,
        role: ChatRole.values.byName(row.role),
        text: row.content,
        createdAt: row.createdAt,
        contextRef: row.contextRef,
        syncedAt: row.syncedAt,
      );

  Future<List<ChatMessage>> all() async {
    final rows = await (select(chatMessages)
          ..orderBy([(t) => OrderingTerm.asc(t.createdAt)]))
        .get();
    return rows.map(_fromRow).toList();
  }

  Future<void> upsert(ChatMessage message) =>
      into(chatMessages).insertOnConflictUpdate(ChatMessagesCompanion.insert(
        id: message.id,
        role: message.role.name,
        content: message.text,
        createdAt: message.createdAt,
        contextRef: Value(message.contextRef),
        syncedAt: Value(message.syncedAt),
      ));

  Future<void> clear() => delete(chatMessages).go();

  /// Merge lookup for the sync engine.
  Future<ChatMessage?> byId(String id) async {
    final row = await (select(chatMessages)
          ..where((t) => t.id.equals(id)))
        .getSingleOrNull();
    return row == null ? null : _fromRow(row);
  }

  // --- sync -------------------------------------------------------------

  Future<List<ChatMessage>> dirty() async {
    final rows = await (select(chatMessages)
          ..where((t) => t.syncedAt.isNull())
          ..orderBy([(t) => OrderingTerm.asc(t.createdAt)]))
        .get();
    return rows.map(_fromRow).toList();
  }

  Future<void> markSynced(String id, DateTime at) =>
      (update(chatMessages)..where((t) => t.id.equals(id)))
          .write(ChatMessagesCompanion(syncedAt: Value(at)));
}
