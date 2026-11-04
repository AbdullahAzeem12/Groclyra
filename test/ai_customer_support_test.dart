import 'package:flutter_test/flutter_test.dart';
import 'package:groclyra/features/customer/support/domain/services/ai_support_agent_engine.dart';
import 'package:groclyra/features/customer/support/domain/services/groclyra_knowledge_base.dart';

void main() {
  group('Groclyra Verified Knowledge Base Policy Tests', () {
    test('Crockery breakage policy mandates 48-hour free doorstep replacement', () {
      final policy = GroclyraKnowledgeBase.crockeryBreakagePolicy;
      expect(policy, contains('48'));
      expect(policy.toLowerCase(), contains('replacement'));
      expect(policy.toLowerCase(), contains('breakage'));
    });

    test('Grocery return policy handles 24-hour perishable window', () {
      final policy = GroclyraKnowledgeBase.groceryReturnPolicy;
      expect(policy, contains('24'));
      expect(policy.toLowerCase(), contains('perishable'));
    });

    test('Cancellation policy prohibits cancellation after packing / dispatch', () {
      final policy = GroclyraKnowledgeBase.cancellationPolicy;
      expect(policy.toLowerCase(), contains('packing'));
      expect(policy.toLowerCase(), contains('cancelled'));
    });

    test('Pakistan delivery coverage policy specifies 30-60m express hubs', () {
      final policy = GroclyraKnowledgeBase.deliveryCoveragePolicy;
      expect(policy, contains('30-45'));
      expect(policy, contains('Karachi'));
      expect(policy, contains('Lahore'));
      expect(policy, contains('Islamabad'));
    });
  });

  group('AI Support Agent Multilingual & Tool Execution Tests', () {
    late AiSupportAgentEngine engine;

    setUp(() {
      engine = AiSupportAgentEngine();
    });

    test('English missing delivery query executes Order Status Tool', () async {
      final res = await engine.processMessage(
        userText: 'My groceries were supposed to arrive, but I have not received them. Where is my order?',
        customerId: 'usr_test_cust',
        customerName: 'Ayesha Tariq',
        customerPhone: '+92 300 9876543',
        threadId: 'th_01',
      );

      expect(res.text, isNotEmpty);
      expect(res.toolType, equals('order_status'));
      expect(res.toolData, isNotNull);
      expect(res.toolData!['orderNumber'], isNotNull);
      expect(res.toolData!['statusDisplay'], isNotNull);
    });

    test('Broken crockery query executes Return / Damage Claim Tool with registered ticket', () async {
      final res = await engine.processMessage(
        userText: 'I opened my parcel and two bone china soup bowls are completely shattered and broken.',
        customerId: 'usr_test_cust',
        customerName: 'Hamza Farooq',
        customerPhone: '+92 321 4567890',
        threadId: 'th_02',
      );

      expect(res.text, contains('Protection'));
      expect(res.toolType, equals('crockery_breakage'));
      expect(res.createdTicket, isNotNull);
      expect(res.createdTicket!.category, contains('crockeryDamage'));
      expect(res.createdTicket!.id, startsWith('TCK-BRK-'));
      expect(res.toolData!['ticketId'], startsWith('TCK-BRK-'));
    });

    test('Order cancellation query checks policy eligibility', () async {
      final res = await engine.processMessage(
        userText: 'I want to cancel my order please.',
        customerId: 'usr_test_cust',
        customerName: 'Hamza Farooq',
        customerPhone: '+92 321 4567890',
        threadId: 'th_03',
      );

      expect(res.toolType, equals('order_cancellation'));
      expect(res.toolData, isNotNull);
      expect(res.toolData!['canCancel'], isNotNull);
    });

    test('Human escalation query queues a live support ticket', () async {
      final res = await engine.processMessage(
        userText: 'I need to speak with a human support agent immediately.',
        customerId: 'usr_test_cust',
        customerName: 'Zainab Bibi',
        customerPhone: '+92 333 1112233',
        threadId: 'th_04',
      );

      expect(res.text.toLowerCase(), contains('escalated'));
      expect(res.toolType, equals('human_escalation'));
      expect(res.createdTicket, isNotNull);
      expect(res.createdTicket!.status.name, equals('waitingForAgent'));
      expect(res.createdTicket!.id, startsWith('TCK-ESC-'));
    });

    test('Roman Urdu query is understood and answered appropriately', () async {
      final res = await engine.processMessage(
        userText: 'mera parcel kahan pohancha hai rider kab tak aayega?',
        customerId: 'usr_test_cust',
        customerName: 'Usman Ghani',
        customerPhone: '+92 345 6789012',
        threadId: 'th_05',
      );

      expect(res.text, isNotEmpty);
      expect(res.toolType, equals('order_status'));
    });

    test('Urdu script query is recognized and answered in Urdu', () async {
      final res = await engine.processMessage(
        userText: 'میرا آرڈر کہاں ہے؟',
        customerId: 'usr_test_cust',
        customerName: 'عثمان',
        customerPhone: '+92 345 6789012',
        threadId: 'th_06',
      );

      expect(res.text, isNotEmpty);
      // Urdu script match
      expect(RegExp(r'[\u0600-\u06FF]').hasMatch(res.text), isTrue);
      expect(res.toolType, equals('order_status'));
    });
  });
}
