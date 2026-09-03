/// Local storage repository using SQLite.
///
/// Stores conversations and messages locally. The interface is designed
/// to be easily swappable with a remote backend — just implement the
/// same methods with HTTP calls.

import 'dart:async';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import '../models/chat_message.dart';

abstract class ChatRepository {
  Future<void> init();
  Future<List<Conversation>> getConversations();
  Future<Conversation> createConversation({String? title, String? systemPrompt});
  Future<void> updateConversation(Conversation conversation);
  Future<void> deleteConversation(String id);
  Future<List<ChatMessage>> getMessages(String conversationId);
  Future<ChatMessage> addMessage(ChatMessage message);
  Future<void> updateMessage(ChatMessage message);
  Future<void> deleteMessage(String id);
  Future<void> clearAll();
}

class LocalChatRepository implements ChatRepository {
  Database? _db;

  @override
  Future<void> init() async {
    final docsDir = await getApplicationDocumentsDirectory();
    final dbPath = p.join(docsDir.path, 'sarvam_chat.db');

    _db = await openDatabase(
      dbPath,
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE conversations (
            id TEXT PRIMARY KEY,
            title TEXT NOT NULL,
            createdAt TEXT NOT NULL,
            updatedAt TEXT NOT NULL,
            systemPrompt TEXT,
            messageCount INTEGER DEFAULT 0
          )
        ''');

        await db.execute('''
          CREATE TABLE messages (
            id TEXT PRIMARY KEY,
            conversationId TEXT NOT NULL,
            role TEXT NOT NULL,
            content TEXT NOT NULL,
            attachments TEXT NOT NULL DEFAULT '[]',
            createdAt TEXT NOT NULL,
            isError INTEGER DEFAULT 0,
            FOREIGN KEY (conversationId) REFERENCES conversations (id) ON DELETE CASCADE
          )
        ''');

        await db.execute(
          'CREATE INDEX idx_messages_conversation ON messages(conversationId)',
        );
      },
    );
  }

  Database get _database {
    if (_db == null) {
      throw StateError('Repository not initialized. Call init() first.');
    }
    return _db!;
  }

  @override
  Future<List<Conversation>> getConversations() async {
    final maps = await _database.query(
      'conversations',
      orderBy: 'updatedAt DESC',
    );
    return maps.map((m) => Conversation.fromMap(m)).toList();
  }

  @override
  Future<Conversation> createConversation({
    String? title,
    String? systemPrompt,
  }) async {
    final now = DateTime.now();
    final conversation = Conversation(
      id: now.microsecondsSinceEpoch.toString(),
      title: title ?? 'New Chat',
      createdAt: now,
      updatedAt: now,
      systemPrompt: systemPrompt,
    );

    await _database.insert('conversations', conversation.toMap());
    return conversation;
  }

  @override
  Future<void> updateConversation(Conversation conversation) async {
    await _database.update(
      'conversations',
      conversation.toMap(),
      where: 'id = ?',
      whereArgs: [conversation.id],
    );
  }

  @override
  Future<void> deleteConversation(String id) async {
    await _database.delete('messages', where: 'conversationId = ?', whereArgs: [id]);
    await _database.delete('conversations', where: 'id = ?', whereArgs: [id]);
  }

  @override
  Future<List<ChatMessage>> getMessages(String conversationId) async {
    final maps = await _database.query(
      'messages',
      where: 'conversationId = ?',
      whereArgs: [conversationId],
      orderBy: 'createdAt ASC',
    );
    return maps.map((m) => ChatMessage.fromMap(m)).toList();
  }

  @override
  Future<ChatMessage> addMessage(ChatMessage message) async {
    await _database.insert('messages', message.toMap());

    // Update conversation's updatedAt and messageCount.
    final convMaps = await _database.query(
      'conversations',
      where: 'id = ?',
      whereArgs: [message.conversationId],
    );
    if (convMaps.isNotEmpty) {
      final conv = Conversation.fromMap(convMaps.first);
      await _database.update(
        'conversations',
        {
          'updatedAt': DateTime.now().toIso8601String(),
          'messageCount': conv.messageCount + 1,
        },
        where: 'id = ?',
        whereArgs: [message.conversationId],
      );
    }

    return message;
  }

  @override
  Future<void> updateMessage(ChatMessage message) async {
    await _database.update(
      'messages',
      message.toMap(),
      where: 'id = ?',
      whereArgs: [message.id],
    );
  }

  @override
  Future<void> deleteMessage(String id) async {
    await _database.delete('messages', where: 'id = ?', whereArgs: [id]);
  }

  @override
  Future<void> clearAll() async {
    await _database.delete('messages');
    await _database.delete('conversations');
  }
}
