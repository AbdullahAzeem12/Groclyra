import 'package:cloud_firestore/cloud_firestore.dart';

enum SupportSenderType {
  user('Customer'),
  aiAgent('Groclyra AI Assistant'),
  humanAgent('Support Executive');

  final String displayName;
  const SupportSenderType(this.displayName);
}

enum SupportTicketStatus {
  open('Open & In Review', 0xFF3B82F6),
  waitingForAgent('Waiting for Human Agent', 0xFFF59E0B),
  investigating('Investigating with Logistics', 0xFFF59E0B),
  approved('Approved & Processing', 0xFF10B981),
  resolved('Resolved', 0xFF10B981),
  closed('Closed', 0xFF6B7280);

  final String label;
  final int colorValue;
  const SupportTicketStatus(this.label, this.colorValue);
}

enum SupportTicketPriority {
  low('Low'),
  medium('Medium'),
  high('High - Priority Escalation'),
  urgent('Urgent - Damaged Crockery / Perishable');

  final String label;
  const SupportTicketPriority(this.label);
}

class SupportMessageEntity {
  final String id;
  final String threadId;
  final SupportSenderType senderType;
  final String text;
  final DateTime createdAt;
  final String? toolType; // e.g. 'order_status', 'cancellation', 'return_request', 'ticket_created'
  final Map<String, dynamic>? toolData;
  final bool isPending;

  const SupportMessageEntity({
    required this.id,
    required this.threadId,
    required this.senderType,
    required this.text,
    required this.createdAt,
    this.toolType,
    this.toolData,
    this.isPending = false,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'threadId': threadId,
        'senderType': senderType.name,
        'text': text,
        'createdAt': createdAt.toIso8601String(),
        'toolType': toolType,
        'toolData': toolData,
      };

  factory SupportMessageEntity.fromMap(Map<String, dynamic> map, String docId) {
    DateTime parseDate(dynamic val) {
      if (val is Timestamp) return val.toDate();
      if (val is String) return DateTime.tryParse(val) ?? DateTime.now();
      return DateTime.now();
    }

    SupportSenderType sender = SupportSenderType.aiAgent;
    if (map['senderType'] == 'user') {
      sender = SupportSenderType.user;
    } else if (map['senderType'] == 'humanAgent') {
      sender = SupportSenderType.humanAgent;
    }

    return SupportMessageEntity(
      id: docId,
      threadId: map['threadId'] as String? ?? 'general_thread',
      senderType: sender,
      text: map['text'] as String? ?? '',
      createdAt: parseDate(map['createdAt']),
      toolType: map['toolType'] as String?,
      toolData: map['toolData'] is Map ? Map<String, dynamic>.from(map['toolData'] as Map) : null,
      isPending: false,
    );
  }
}

class SupportTicketEntity {
  final String id;
  final String customerId;
  final String customerName;
  final String customerPhone;
  final String category; // 'Crockery Damage', 'Order Cancellation', 'Delivery Delay', 'Missing Item', 'Refund Inquiry'
  final SupportTicketPriority priority;
  final SupportTicketStatus status;
  final String summary;
  final String details;
  final String? relatedOrderId;
  final DateTime createdAt;
  final DateTime updatedAt;

  const SupportTicketEntity({
    required this.id,
    required this.customerId,
    required this.customerName,
    required this.customerPhone,
    required this.category,
    this.priority = SupportTicketPriority.medium,
    this.status = SupportTicketStatus.open,
    required this.summary,
    required this.details,
    this.relatedOrderId,
    required this.createdAt,
    required this.updatedAt,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'customerId': customerId,
        'customerName': customerName,
        'customerPhone': customerPhone,
        'category': category,
        'priority': priority.name,
        'status': status.name,
        'summary': summary,
        'details': details,
        'relatedOrderId': relatedOrderId,
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
      };

  factory SupportTicketEntity.fromMap(Map<String, dynamic> map, String docId) {
    DateTime parseDate(dynamic val) {
      if (val is Timestamp) return val.toDate();
      if (val is String) return DateTime.tryParse(val) ?? DateTime.now();
      return DateTime.now();
    }

    return SupportTicketEntity(
      id: docId,
      customerId: map['customerId'] as String? ?? '',
      customerName: map['customerName'] as String? ?? 'Valued Customer',
      customerPhone: map['customerPhone'] as String? ?? '',
      category: map['category'] as String? ?? 'General Inquiry',
      priority: SupportTicketPriority.values.firstWhere(
        (p) => p.name == map['priority'],
        orElse: () => SupportTicketPriority.medium,
      ),
      status: SupportTicketStatus.values.firstWhere(
        (s) => s.name == map['status'],
        orElse: () => SupportTicketStatus.open,
      ),
      summary: map['summary'] as String? ?? '',
      details: map['details'] as String? ?? '',
      relatedOrderId: map['relatedOrderId'] as String?,
      createdAt: parseDate(map['createdAt']),
      updatedAt: parseDate(map['updatedAt']),
    );
  }
}
