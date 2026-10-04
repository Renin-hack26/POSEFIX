import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart';

import '../../../core/storage/app_database.dart';
import '../../../domain/entities/chat_message.dart';

part 'chat_dao.g.dart';

/// VEDA chat history.
@DriftAccessor(tables: [ChatMessages])
class ChatDao extends DatabaseAccessor<AppDatabase> with _$ChatDaoMixin {
  ChatDao(super.db);

  /// One corrupt row skips loudly instead of blanking chat history.
  ChatMessage? _fromRowOrNull(ChatMessageRow row) {
    try {
      return _fromRow(row);
    } catch (e) {
      debugPrint('chat: skipping unreadable row ${row.id} ($e)');
      return null;
    }
  }

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
    return rows.map(_fromRowOrNull).whereType<ChatMessage>().toList();
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
    return row == null ? null : _fromRowOrNull(row);
  }

  // --- sync -------------------------------------------------------------

  Future<List<ChatMessage>> dirty() async {
    final rows = await (select(chatMessages)
          ..where((t) => t.syncedAt.isNull())
          ..orderBy([(t) => OrderingTerm.asc(t.createdAt)]))
        .get();
    return rows.map(_fromRowOrNull).whereType<ChatMessage>().toList();
  }

  Future<void> markSynced(String id, DateTime at) =>
      (update(chatMessages)
            ..where((t) => t.id.equals(id) & t.syncedAt.isNull()))
          .write(ChatMessagesCompanion(syncedAt: Value(at)));
}
