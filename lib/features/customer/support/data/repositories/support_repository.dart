import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:groclyra/core/database/app_database.dart';
import 'package:groclyra/features/customer/support/domain/entities/support_entities.dart';

/// Groclyra SQL-backed SupportRepository (SQLite).
class SupportRepository {
  final AppDatabase _database;
  final List<SupportMessageEntity> _messageMemory = [];
  final List<SupportTicketEntity> _ticketMemory = [];

  SupportRepository({
    dynamic firestore, // Kept dynamic for legacy test compatibility
    AppDatabase? database,
  })  : _database = database ?? AppDatabase.instance {
    _seedWelcomeIfEmpty();
  }

  void _seedWelcomeIfEmpty() {
    if (_messageMemory.isEmpty) {
      _messageMemory.add(
        SupportMessageEntity(
          id: 'msg_welcome_ai',
          threadId: 'thread_main',
          senderType: SupportSenderType.aiAgent,
          text:
              'Assalam-o-Alaikum! 👋 I am your Groclyra 24/7 Intelligent Support Assistant, connected live to your account, orders, and nationwide Pakistan delivery network.\n\n'
              'I can immediately track your active shipment, process crockery breakage claims under our 48-hr guarantee, cancel orders, or connect you with a human representative. How may I assist you today?',
          createdAt: DateTime.now().subtract(const Duration(minutes: 5)),
        ),
      );
    }
  }

  Stream<List<SupportMessageEntity>> streamThreadMessages(String threadId) async* {
    yield await getThreadMessages(threadId);

    yield* _database.watchTable('support_messages').asyncMap((_) async {
      return await getThreadMessages(threadId);
    });
  }

  Future<List<SupportMessageEntity>> getThreadMessages(String threadId) async {
    if (threadId.isEmpty) {
      return List.unmodifiable(_messageMemory);
    }

    try {
      final rows = await _database.query(
        'support_messages',
        where: 'threadId = ?',
        whereArgs: [threadId],
        orderBy: 'createdAt ASC',
      );

      if (rows.isEmpty) {
        return List.unmodifiable(_messageMemory);
      }

      final list = rows.map((r) {
        final full = r['fullDataJson'] as String?;
        if (full != null && full.isNotEmpty) {
          try {
            return SupportMessageEntity.fromMap(jsonDecode(full) as Map<String, dynamic>, r['id'] as String);
          } catch (_) {}
        }
        return SupportMessageEntity.fromMap(r, r['id'] as String);
      }).toList();

      _messageMemory.clear();
      _messageMemory.addAll(list);
      return List.unmodifiable(list);
    } catch (e) {
      debugPrint('SupportRepository.getThreadMessages error: $e');
      return List.unmodifiable(_messageMemory);
    }
  }

  Future<void> saveMessage(SupportMessageEntity msg) async {
    _messageMemory.add(msg);
    try {
      final row = <String, dynamic>{
        'id': msg.id,
        'threadId': msg.threadId,
        'senderType': msg.senderType.name,
        'text': msg.text,
        'toolType': msg.toolType,
        'createdAt': msg.createdAt.toIso8601String(),
        'fullDataJson': jsonEncode(msg.toMap()),
      };
      await _database.insertOrReplace('support_messages', row);
      _database.notifyTable('support_messages');
    } catch (e) {
      debugPrint('SupportRepository.saveMessage error: $e');
    }
  }

  Future<void> saveTicket(SupportTicketEntity ticket) async {
    _ticketMemory.insert(0, ticket);
    try {
      await _database.insertOrReplace('system_telemetry', {
        'id': ticket.id,
        'metricName': 'support_ticket',
        'metricValue': 1.0,
        'tagsJson': jsonEncode(ticket.toMap()),
        'recordedAt': DateTime.now().toIso8601String(),
      });
      _database.notifyTable('system_telemetry');
    } catch (e) {
      debugPrint('SupportRepository.saveTicket error: $e');
    }
  }
}

final supportRepositoryProvider = Provider<SupportRepository>((ref) {
  return SupportRepository();
});
