import * as functions from "firebase-functions";
import * as admin from "firebase-admin";
import { executeVendorCatalogSync } from "./vendor_sync";

admin.initializeApp();
const db = admin.firestore();
const messaging = admin.messaging();

// ═══════════════════════════════════════════════════════════════════════════
// 1. EVENT-TRIGGERED NOTIFICATIONS (ORDER UPDATES & FCM DELIVERY)
// ═══════════════════════════════════════════════════════════════════════════

export const onOrderStatusChanged = functions.firestore
  .document("orders/{orderId}")
  .onUpdate(async (change, context) => {
    const before = change.before.data();
    const after = change.after.data();
    const orderId = context.params.orderId;

    if (!before || !after) return null;
    if (before.status === after.status && before.paymentStatus === after.paymentStatus) {
      return null;
    }

    const customerId = after.customerId;
    if (!customerId) return null;

    // Check user preferences
    const prefSnap = await db
      .collection("users")
      .doc(customerId)
      .collection("notificationPreferences")
      .doc("main")
      .get();

    const prefs = prefSnap.exists ? prefSnap.data() : { orderUpdates: true, pushChannelEnabled: true };
    if (prefs && prefs.orderUpdates === false) {
      console.log(`Order updates muted for user ${customerId}`);
      return null;
    }

    const newStatus = after.status;
    const eventId = `order_${orderId}_${newStatus}_${Date.now()}`;

    let title = "Order Update";
    let body = `Your order #${orderId.substring(0, 8)} status is now ${newStatus}.`;

    switch (newStatus) {
      case "placed":
      case "confirmed":
        title = "Order Confirmed! 🛒";
        body = `Your order #${orderId.substring(0, 8)} has been confirmed and sent to the store.`;
        break;
      case "packing":
      case "readyForPickup":
        title = "Order Being Packed 📦";
        body = `Our team is carefully packing your grocery & crockery items.`;
        break;
      case "outForDelivery":
      case "inTransit":
        title = "Out for Delivery! 🛵";
        body = `Your Groclyra rider is on the way to your delivery address.`;
        break;
      case "delivered":
        title = "Delivered! 🎉";
        body = `Your order #${orderId.substring(0, 8)} has been safely delivered. Enjoy your shopping!`;
        break;
      case "cancelled":
        title = "Order Cancelled";
        body = `Order #${orderId.substring(0, 8)} has been cancelled.`;
        break;
    }

    // Write persistent notification in Firestore
    const notifRef = db.collection("notifications").doc(eventId);
    await notifRef.set({
      id: eventId,
      recipientId: customerId,
      kind: "order",
      type: "order_status",
      title: title,
      body: body,
      data: {
        orderId: orderId,
        newStatus: newStatus,
        deepLink: `/orders/${orderId}`,
      },
      isRead: false,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    // Send FCM push if enabled and device registered
    if (prefs && prefs.pushChannelEnabled !== false) {
      const userDoc = await db.collection("users").doc(customerId).get();
      const userData = userDoc.data();
      const fcmTokens: string[] = (userData && userData.fcmTokens) || [];

      if (fcmTokens.length > 0) {
        const payload: admin.messaging.MulticastMessage = {
          tokens: fcmTokens,
          notification: {
            title: title,
            body: body,
          },
          data: {
            orderId: orderId,
            type: "order_status",
            click_action: "FLUTTER_NOTIFICATION_CLICK",
          },
        };

        try {
          const response = await messaging.sendEachForMulticast(payload);
          console.log(`Successfully sent ${response.successCount} FCM push messages for order ${orderId}`);
        } catch (err) {
          console.error("Error sending FCM notification:", err);
        }
      }
    }

    return null;
  });

// ═══════════════════════════════════════════════════════════════════════════
// 2. WISHLIST PRICE DROP & RESTOCK MONITORS
// ═══════════════════════════════════════════════════════════════════════════

export const onProductPriceOrStockChanged = functions.firestore
  .document("products/{productId}")
  .onUpdate(async (change, context) => {
    const before = change.before.data();
    const after = change.after.data();
    const productId = context.params.productId;

    if (!before || !after) return null;

    const oldPrice = Number(before.price || 0);
    const newPrice = Number(after.price || 0);
    const wasInStock = Boolean(before.inStock);
    const isNowInStock = Boolean(after.inStock);

    const isPriceDrop = newPrice > 0 && newPrice < oldPrice;
    const isRestocked = !wasInStock && isNowInStock;

    if (!isPriceDrop && !isRestocked) return null;

    // Scan users who saved this product in wishlist
    const wishlistsQuery = await db.collectionGroup("wishlist")
      .where("productId", "==", productId)
      .get();

    for (const doc of wishlistsQuery.docs) {
      const wishData = doc.data();
      const uid = doc.ref.parent.parent?.id;
      if (!uid) continue;

      if (isPriceDrop && wishData.priceDropAlertsEnabled !== false) {
        const dropAmount = oldPrice - newPrice;
        const eventId = `pricedrop_${productId}_${newPrice}_${uid}`;

        await db.collection("notifications").doc(eventId).set({
          id: eventId,
          recipientId: uid,
          kind: "price_drop",
          type: "wishlist_alert",
          title: "Price Drop Alert! 📉",
          body: `${wishData.productName || "An item in your wishlist"} dropped by Rs. ${dropAmount.toFixed(0)}! Current price: Rs. ${newPrice}.`,
          data: {
            productId: productId,
            oldPrice: oldPrice.toString(),
            newPrice: newPrice.toString(),
            deepLink: `/product/${productId}`,
          },
          isRead: false,
          createdAt: admin.firestore.FieldValue.serverTimestamp(),
          updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        });
      }

      if (isRestocked && wishData.backInStockAlertsEnabled !== false) {
        const eventId = `restock_${productId}_${uid}`;

        await db.collection("notifications").doc(eventId).set({
          id: eventId,
          recipientId: uid,
          kind: "restock",
          type: "wishlist_alert",
          title: "Back in Stock! ✨",
          body: `${wishData.productName || "An item in your wishlist"} is back in stock. Order before it runs out!`,
          data: {
            productId: productId,
            deepLink: `/product/${productId}`,
          },
          isRead: false,
          createdAt: admin.firestore.FieldValue.serverTimestamp(),
          updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        });
      }
    }

    return null;
  });

// ═══════════════════════════════════════════════════════════════════════════
// 3. AI SUPPORT AGENT WITH VERIFIED BUSINESS ACTIONS
// ═══════════════════════════════════════════════════════════════════════════

export const aiSupportAgent = functions.https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError(
      "unauthenticated",
      "User must be authenticated to talk to Groclyra AI Support."
    );
  }

  const uid = context.auth.uid;
  const threadId = data.threadId || `thread_${uid}`;
  const userMessage = (data.message || "").trim();
  const language = data.language || "en";

  if (!userMessage) {
    throw new functions.https.HttpsError("invalid-argument", "Message cannot be empty.");
  }

  const lower = userMessage.toLowerCase();

  // Tool 1: Order Status Check
  if (lower.includes("where is my order") || lower.includes("order status") || lower.includes("kahan hai") || lower.includes("track")) {
    const ordersSnap = await db
      .collection("orders")
      .where("customerId", "==", uid)
      .orderBy("createdAt", "desc")
      .limit(1)
      .get();

    if (ordersSnap.empty) {
      return {
        reply: language === "ur"
          ? "آپ کا کوئی فعال آرڈر نہیں ملا۔"
          : "You don't have any recent orders on record.",
        actionCardType: "none",
      };
    }

    const latestOrder = ordersSnap.docs[0].data();
    const orderId = ordersSnap.docs[0].id;

    return {
      reply: language === "ur"
        ? `آپ کا آرڈر #${orderId.substring(0, 8)} اس وقت ${latestOrder.status} مرحلے پر ہے۔`
        : `Your order #${orderId.substring(0, 8)} is currently ${latestOrder.status}. Expected delivery is underway.`,
      actionCardType: "orderStatus",
      actionCardPayload: {
        orderId: orderId,
        status: latestOrder.status,
        totalAmount: latestOrder.totalAmount || latestOrder.total || 0,
        itemCount: latestOrder.items?.length || 1,
      },
    };
  }

  // Tool 2: Crockery Breakage / Perishable Damage Claim
  if (lower.includes("broken") || lower.includes("damaged") || lower.includes("toot") || lower.includes("damage")) {
    const ticketId = `TCK-${Date.now().toString().substring(7)}`;
    await db.collection("supportTickets").doc(ticketId).set({
      id: ticketId,
      threadId: threadId,
      customerId: uid,
      category: "crockeryDamage",
      priority: "high",
      status: "open",
      title: "Broken / Damaged Item Claim",
      description: userMessage,
      claimType: "crockeryBreakage",
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    return {
      reply: language === "ur"
        ? `ہمیں آپ کے نقصان پر افسوس ہے۔ آپ کی شکایت نمبر ${ticketId} درج کر لی گئی ہے۔ ہماری کراکری پروٹیکشن کے تحت مفت متبادل فراہم کیا جائے گا۔`
        : `We are truly sorry about the broken item! Ticket #${ticketId} has been registered under Groclyra's 48-Hour Crockery Breakage Protection. Our team will verify and dispatch a replacement.`,
      actionCardType: "claimRegistered",
      actionCardPayload: {
        ticketId: ticketId,
        category: "crockeryDamage",
        priority: "high",
      },
    };
  }

  // Tool 3: Order Cancellation
  if (lower.includes("cancel") || lower.includes("mansookh")) {
    const ordersSnap = await db
      .collection("orders")
      .where("customerId", "==", uid)
      .where("status", "in", ["placed", "confirmed"])
      .orderBy("createdAt", "desc")
      .limit(1)
      .get();

    if (ordersSnap.empty) {
      return {
        reply: language === "ur"
          ? "منسوخ کرنے کے لیے کوئی آرڈر نہیں ملا جو پیکنگ سے پہلے کے مرحلے میں ہو۔"
          : "No cancellable orders found. Orders that have already been packed or dispatched cannot be cancelled directly.",
        actionCardType: "none",
      };
    }

    const orderDoc = ordersSnap.docs[0];
    await orderDoc.ref.update({
      status: "cancelled",
      cancellationReason: "Cancelled by customer via AI Support",
      cancelledAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    return {
      reply: language === "ur"
        ? `آپ کا آرڈر #${orderDoc.id.substring(0, 8)} کامیابی سے منسوخ کر دیا گیا ہے۔`
        : `Your order #${orderDoc.id.substring(0, 8)} has been cancelled successfully.`,
      actionCardType: "orderCancelled",
      actionCardPayload: {
        orderId: orderDoc.id,
        status: "cancelled",
      },
    };
  }

  // Tool 4: Human Escalation
  if (lower.includes("human") || lower.includes("agent") || lower.includes("representative") || lower.includes("numainda")) {
    const ticketId = `ESC-${Date.now().toString().substring(7)}`;
    await db.collection("supportTickets").doc(ticketId).set({
      id: ticketId,
      threadId: threadId,
      customerId: uid,
      category: "humanEscalation",
      priority: "high",
      status: "waitingForAgent",
      title: "Customer Requested Human Support Representative",
      description: userMessage,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    return {
      reply: language === "ur"
        ? `آپ کا کیس ہمارے انسانی نمائندے کو بھیج دیا گیا ہے۔ ٹکٹ نمبر: ${ticketId}۔ جلد ہی ایک نمائندہ آپ سے رابطہ کرے گا۔`
        : `I have escalated your conversation to a live Groclyra support specialist. Escalation Ticket: #${ticketId}. An agent will join shortly.`,
      actionCardType: "escalated",
      actionCardPayload: {
        ticketId: ticketId,
        status: "waitingForAgent",
      },
    };
  }

  // Fallback Knowledge Base Response
  return {
    reply: language === "ur"
      ? "میں گروکلائیرا کا سمارٹ سپورٹ ایجنٹ ہوں۔ میں آرڈر ٹریکنگ، کراکری ریپلیسمنٹ، کینسلیشن، اور ڈیلیوری کی معلومات میں آپ کی مدد کر سکتا ہوں۔"
      : "I am Groclyra's verified AI Assistant. I can track your orders, register 48-hr crockery breakage claims, process cancellations, or connect you to human staff. How can I help you today?",
    actionCardType: "none",
  };
});

// ═══════════════════════════════════════════════════════════════════════════
// 4. PAKISTAN DELIVERY SERVICEABILITY VALIDATION
// ═══════════════════════════════════════════════════════════════════════════

export const checkDeliveryServiceability = functions.https.onCall(async (data, context) => {
  const lat = Number(data.latitude);
  const lng = Number(data.longitude);
  const city = (data.city || "").trim();

  if (isNaN(lat) || isNaN(lng)) {
    throw new functions.https.HttpsError("invalid-argument", "Latitude and Longitude are required.");
  }

  // Groclyra Pakistan Micro-Hubs
  const hubs = [
    { name: "Karachi Clifton / DHA Hub", lat: 24.8138, lng: 67.0299, maxExpressKm: 15 },
    { name: "Lahore Gulberg / DHA Hub", lat: 31.5204, lng: 74.3587, maxExpressKm: 20 },
    { name: "Islamabad F-7 Hub", lat: 33.7294, lng: 73.0551, maxExpressKm: 20 },
    { name: "Rawalpindi Saddar Hub", lat: 33.5973, lng: 73.0479, maxExpressKm: 18 },
    { name: "Peshawar University Town Hub", lat: 34.0040, lng: 71.5348, maxExpressKm: 15 },
    { name: "Multan Cantt Hub", lat: 30.1984, lng: 71.4687, maxExpressKm: 15 },
    { name: "Faisalabad D-Ground Hub", lat: 31.4180, lng: 73.0790, maxExpressKm: 15 },
  ];

  function haversineKm(lat1: number, lon1: number, lat2: number, lon2: number): number {
    const R = 6371;
    const dLat = (lat2 - lat1) * Math.PI / 180;
    const dLon = (lon2 - lon1) * Math.PI / 180;
    const a =
      Math.sin(dLat / 2) * Math.sin(dLat / 2) +
      Math.cos(lat1 * Math.PI / 180) * Math.cos(lat2 * Math.PI / 180) *
      Math.sin(dLon / 2) * Math.sin(dLon / 2);
    const c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
    return R * c;
  }

  let minDistance = 99999;
  let closestHub = hubs[0];

  for (const hub of hubs) {
    const dist = haversineKm(lat, lng, hub.lat, hub.lng);
    if (dist < minDistance) {
      minDistance = dist;
      closestHub = hub;
    }
  }

  const isExpress = minDistance <= closestHub.maxExpressKm;
  const isCitySupported = ["karachi", "lahore", "islamabad", "rawalpindi", "faisalabad", "peshawar", "multan", "quetta", "gujranwala", "sialkot", "hyderabad", "abbottabad"].includes(city.toLowerCase());

  return {
    isServiceable: true,
    tier: isExpress ? "express30m" : isCitySupported ? "standardSameDay" : "nationwide3To5Days",
    estimatedDeliveryTime: isExpress ? "30-45 Minutes" : isCitySupported ? "Same-Day Delivery" : "3-5 Business Days",
    closestHub: closestHub.name,
    distanceKm: Math.round(minDistance * 10) / 10,
  };
});

// ═══════════════════════════════════════════════════════════════════════════
// 5. VENDOR CATALOG INTEGRATION & AUTHORITATIVE SYNCHRONIZATION
// ═══════════════════════════════════════════════════════════════════════════

/**
 * OnCall callable endpoint to manually trigger a vendor catalog sync.
 * Region: asia-south1.
 * Strict RBAC: Requires trusted admin custom claim or active admin user record.
 */
export const requestVendorCatalogSync = functions
  .region("asia-south1")
  .https.onCall(async (data, context) => {
    if (!context.auth) {
      throw new functions.https.HttpsError(
        "unauthenticated",
        "Authentication is required to trigger a vendor catalog sync."
      );
    }

    const isAdminClaim = context.auth.token.admin === true;
    if (!isAdminClaim) {
      const userDoc = await db.collection("users").doc(context.auth.uid).get();
      if (!userDoc.exists || userDoc.data()?.role !== "admin") {
        throw new functions.https.HttpsError(
          "permission-denied",
          "Only verified platform administrators can initiate vendor catalog sync."
        );
      }
    }

    const integrationId = String(data?.integrationId || "").trim();
    if (!integrationId) {
      throw new functions.https.HttpsError(
        "invalid-argument",
        "A valid 'integrationId' is required."
      );
    }

    const force = Boolean(data?.force);

    try {
      const syncResult = await executeVendorCatalogSync(db, integrationId, {
        triggeredBy: `admin:${context.auth.uid}`,
        force: force,
      });

      return syncResult;
    } catch (err: unknown) {
      const msg = err instanceof Error ? err.message : String(err);
      throw new functions.https.HttpsError("internal", msg);
    }
  });

/**
 * Background worker triggered when a vendor sync request is enqueued.
 * Reads vendorSyncRequests/{requestId} and runs authoritative catalog sync.
 */
export const processVendorSyncQueue = functions
  .region("asia-south1")
  .firestore.document("vendorSyncRequests/{requestId}")
  .onCreate(async (snap, context) => {
    const data = snap.data();
    if (!data) return null;

    const requestId = context.params.requestId;
    const integrationId = String(data.integrationId || "").trim();

    if (!integrationId) {
      await snap.ref.update({
        status: "failed",
        error: "Missing required integrationId",
        completedAt: admin.firestore.FieldValue.serverTimestamp(),
      });
      return null;
    }

    await snap.ref.update({
      status: "processing",
      startedAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    try {
      const result = await executeVendorCatalogSync(db, integrationId, {
        runId: data.runId || `queue_${requestId}`,
        triggeredBy: `queue:${data.requestedBy || "system"}`,
        force: Boolean(data.force),
      });

      await snap.ref.update({
        status: result.status === "succeeded" ? "completed" : "failed",
        result: result,
        completedAt: admin.firestore.FieldValue.serverTimestamp(),
      });
    } catch (err: unknown) {
      const msg = err instanceof Error ? err.message : String(err);
      await snap.ref.update({
        status: "failed",
        error: msg,
        completedAt: admin.firestore.FieldValue.serverTimestamp(),
      });
    }

    return null;
  });

/**
 * Scheduled cron function running every 15 minutes.
 * Checks active vendor integrations and schedules sync for eligible stores.
 */
export const scheduledVendorCatalogSync = functions
  .region("asia-south1")
  .pubsub.schedule("every 15 minutes")
  .timeZone("Asia/Karachi")
  .onRun(async () => {
    console.log("Starting scheduled vendor catalog check...");
    const activeIntegrationsSnap = await db
      .collection("vendorIntegrations")
      .where("status", "==", "active")
      .get();

    if (activeIntegrationsSnap.empty) {
      console.log("No active vendor integrations found.");
      return null;
    }

    const now = Date.now();
    for (const doc of activeIntegrationsSnap.docs) {
      const integration = doc.data();
      const nextSyncAtIso = integration.nextSyncAt;
      const shouldSync = !nextSyncAtIso || new Date(nextSyncAtIso).getTime() <= now;

      if (shouldSync) {
        console.log(`Enqueueing scheduled sync for integration: ${doc.id}`);
        // Create durable queue request
        await db.collection("vendorSyncRequests").add({
          integrationId: doc.id,
          requestedBy: "scheduler",
          status: "pending",
          force: false,
          createdAt: admin.firestore.FieldValue.serverTimestamp(),
        });
      }
    }

    return null;
  });

