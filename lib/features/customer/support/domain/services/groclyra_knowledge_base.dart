class GroclyraPolicyItem {
  final String topic;
  final String title;
  final String summary;
  final String details;

  const GroclyraPolicyItem({
    required this.topic,
    required this.title,
    required this.summary,
    required this.details,
  });
}

class GroclyraKnowledgeBase {
  static const List<GroclyraPolicyItem> policies = [
    GroclyraPolicyItem(
      topic: 'crockery_breakage',
      title: '🍽️ Crockery Transit & Damage Guarantee',
      summary: '48-hour free replacement guarantee for any broken or chipped items.',
      details:
          'All fine tableware, dinner sets, bone china, porcelain, and glassware are shipped in 5-ply reinforced honeycomb shockproof packaging. If any piece arrives damaged, chipped, broken, or suffering transit breakage, customers are entitled to a 100% free immediate replacement or full refund within 48 hours of delivery.',
    ),
    GroclyraPolicyItem(
      topic: 'grocery_freshness',
      title: '🥬 Freshness & 100% Halal Guarantee',
      summary: 'Daily fresh produce inspection and 100% certified Halal products.',
      details:
          'All dairy, vegetables, fruits, and meats undergo strict quality inspection at our temperature-controlled regional fulfillment centers. Perishable grocery items can be returned within 24 hours of delivery if quality or taste does not meet expectations.',
    ),
    GroclyraPolicyItem(
      topic: 'delivery_coverage',
      title: '🚚 Pakistan Delivery Coverage & Timelines',
      summary: '30-45 min Express in major hubs; 24-48 hr Standard delivery nationwide.',
      details:
          'Groclyra operates active micro-fulfillment hubs across Karachi, Lahore, Islamabad, Rawalpindi, Faisalabad, Multan, Peshawar, Gujranwala, and Hyderabad offering 30-45 min Express delivery. Standard delivery across all other verified districts of Punjab, Sindh, KP, and ICT arrives within 24 to 48 hours. Orders above Rs. 3,000 receive 100% FREE delivery (otherwise flat Rs. 150).',
    ),
    GroclyraPolicyItem(
      topic: 'cancellation_policy',
      title: '❌ Order Cancellation Policy',
      summary: 'Instant cancellation permitted while order is packing or payment pending.',
      details:
          'You may cancel your order at zero charge as long as the status is "Payment Pending" or "Seller Packing". Once an order is cancelled or a rider is dispatched or the shipment is in transit, cancellation is locked to protect transit safety, but you can request a return upon delivery.',
    ),
    GroclyraPolicyItem(
      topic: 'refund_timelines',
      title: '💳 Refund Turnaround & Payment Channels',
      summary: 'Refunds credited within 3-5 business days via JazzCash, Easypaisa, or Bank.',
      details:
          'Approved cancellations or return refunds are credited back to the customer account within 3 to 5 business days via PayFast card refund, JazzCash mobile wallet, Easypaisa account, or direct IBAN transfer.',
    ),
  ];

  static String get crockeryBreakagePolicy =>
      policies.firstWhere((p) => p.topic == 'crockery_breakage').details;

  static String get groceryReturnPolicy =>
      policies.firstWhere((p) => p.topic == 'grocery_freshness').details;

  static String get cancellationPolicy =>
      policies.firstWhere((p) => p.topic == 'cancellation_policy').details;

  static String get deliveryCoveragePolicy =>
      policies.firstWhere((p) => p.topic == 'delivery_coverage').details;

  static String get refundPolicy =>
      policies.firstWhere((p) => p.topic == 'refund_timelines').details;
}
