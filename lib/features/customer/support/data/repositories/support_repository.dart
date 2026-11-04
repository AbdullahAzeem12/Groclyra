import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:groclyra/features/customer/support/domain/entities/support_entities.dart';

class SupportRepository {
  final FirebaseFirestore? _explicitFirestore;
  final List<SupportMessageEntity> _messageMemory = [];
  final List<SupportTicketEntity> _ticketMemory = [];

  SupportRepository({FirebaseFirestore? firestore})
      : _explicitFirestore = firestore {
    _seedWelcomeIfEmpty();
  }

  FirebaseFirestore? get _firestore {
    if (_explicitFirestore != null) return _explicitFirestore;
    try {
      return FirebaseFirestore.instance;
    } catch (_) {
      return null;
    }
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

  Stream<List<SupportMessageEntity>> streamThreadMessages(String threadId) {
    if (threadId.isEmpty || _firestore == null) {
      return Stream.value(List.unmodifiable(_messageMemory));
    }

    try {
      return _firestore!
          .collection('supportThreads')
          .doc(threadId)
          .collection('messages')
          .orderBy('createdAt', descending: false)
          .snapshots()
          .map<List<SupportMessageEntity>>((snap) {
        if (snap.docs.isEmpty) {
          return List.unmodifiable(_messageMemory);
        }
        final list = snap.docs
            .map((doc) => SupportMessageEntity.fromMap(doc.data(), doc.id))
            .toList();
        _messageMemory.clear();
        _messageMemory.addAll(list);
        return list;
      });
    } catch (_) {
      return Stream.value(List.unmodifiable(_messageMemory));
    }
  }

  Future<void> saveMessage(SupportMessageEntity msg) async {
    _messageMemory.add(msg);
    if (msg.threadId.isNotEmpty && _firestore != null) {
      try {
        await _firestore!
            .collection('supportThreads')
            .doc(msg.threadId)
            .collection('messages')
            .doc(msg.id)
            .set(msg.toMap(), SetOptions(merge: true));
      } catch (e) {
        debugPrint('SupportRepository.saveMessage error: $e');
      }
    }
  }

  Future<void> saveTicket(SupportTicketEntity ticket) async {
    _ticketMemory.insert(0, ticket);
    if (_firestore != null) {
      try {
        await _firestore!
            .collection('supportTickets')
            .doc(ticket.id)
            .set(ticket.toMap(), SetOptions(merge: true));
      } catch (e) {
        debugPrint('SupportRepository.saveTicket error: $e');
      }
    }
  }
}

final supportRepositoryProvider = Provider<SupportRepository>((ref) {
  return SupportRepository();
});
