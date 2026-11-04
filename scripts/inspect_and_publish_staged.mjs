#!/usr/bin/env node

/**
 * Groclyra Staged Products Inspector & Publication Gate
 *
 * Inspects staged vendor items in `vendorCatalogItems` and enforces the strict
 * 5-point publication gate before promoting them to the customer-facing `products` collection.
 *
 * Usage:
 *   # Inspect staged products for an integration (Read-Only)
 *   node scripts/inspect_and_publish_staged.mjs --integration wc_pilot_grocer_01
 *
 *   # Dry-run publish simulation
 *   node scripts/inspect_and_publish_staged.mjs --integration wc_pilot_grocer_01 --publish --dry-run
 *
 *   # Live publish (Only permitted if all gates pass!)
 *   node scripts/inspect_and_publish_staged.mjs --integration wc_pilot_grocer_01 --publish
 */

import { loadFirebaseAdmin } from './helpers.mjs';

function parseArgs() {
  const args = process.argv.slice(2);
  const result = {};
  for (let i = 0; i < args.length; i++) {
    if (args[i].startsWith('--')) {
      const key = args[i].substring(2);
      const next = args[i + 1];
      if (next && !next.startsWith('--')) {
        result[key] = next;
        i++;
      } else {
        result[key] = true;
      }
    }
  }
  return result;
}

const params = parseArgs();
const integrationId = params.integration || params.integrationId || 'wc_pilot_grocer_01';
const isPublish = Boolean(params.publish);
const isDryRun = Boolean(params['dry-run']);

console.log('═══════════════════════════════════════════════════════════════');
console.log('   GROCLYRA STAGED CATALOG INSPECTOR & PUBLICATION GATE');
console.log('═══════════════════════════════════════════════════════════════');
console.log(` Target Integration: ${integrationId}`);
console.log(` Mode:               ${isPublish ? (isDryRun ? '🔍 PUBLISH DRY-RUN' : '⚠️  LIVE PUBLISH') : '👁️  READ-ONLY INSPECTION'}\n`);

async function main() {
  const admin = await loadFirebaseAdmin();

  if (!admin.apps.length) {
    try {
      admin.initializeApp();
    } catch (err) {
      console.error('❌ Firebase Admin initialization note:', err.message);
    }
  }

  const db = admin.firestore();

  // 1. Fetch Integration Document
  console.log(`🔍 Step 1: Checking integration record for "${integrationId}"...`);
  let integrationData = {};

  if (!isDryRun) {
    try {
      const integrationSnap = await db.collection('vendorIntegrations').doc(integrationId).get();
      if (integrationSnap.exists) {
        integrationData = integrationSnap.data() || {};
        console.log(`   ✅ Integration found: "${integrationData.vendorName}" (${integrationData.provider})`);
        console.log(`   • Commerce Mode:         ${integrationData.commerceMode}`);
        console.log(`   • Order Workflow Ready:  ${integrationData.orderWorkflowReady}`);
        console.log(`   • Inventory Mode:        ${integrationData.inventoryMode}`);
        console.log(`   • Mapped Seller ID:      ${integrationData.groclyraSellerId || 'None (Unmapped)'}`);
        console.log(`   • Publish to Catalog:    ${integrationData.publishToMainCatalog}`);
      }
    } catch (err) {
      console.log(`   ⚠️  Could not connect to live database (${err.message}).`);
    }
  }

  if (!integrationData.vendorName) {
    console.log(`   ℹ️  Operating in simulation mode for "${integrationId}".`);
    integrationData = {
      vendorName: 'Al-Fatah Gourmet Pilot Mart',
      commerceMode: 'catalogOnly',
      orderWorkflowReady: false,
      inventoryMode: 'vendor_authoritative',
      publishToMainCatalog: false,
      domainOwnershipVerified: true,
      vendorAuthorizationVerified: true,
      catalogUseRightsVerified: true,
    };
    console.log(`   • Commerce Mode:         ${integrationData.commerceMode}`);
    console.log(`   • Order Workflow Ready:  ${integrationData.orderWorkflowReady}`);
    console.log(`   • Inventory Mode:        ${integrationData.inventoryMode}`);
    console.log(`   • Mapped Seller ID:      None (Unmapped)`);
    console.log(`   • Publish to Catalog:    ${integrationData.publishToMainCatalog}`);
  }

  // 2. Fetch Staged Products
  console.log('\n📦 Step 2: Fetching staged products from "vendorCatalogItems"...');
  let stagedDocs = [];
  try {
    const snap = await db.collection('vendorCatalogItems').where('sourceStoreId', '==', integrationId).get();
    stagedDocs = snap.docs;
  } catch (err) {
    console.log(`   Note: Could not query Firestore directly (${err.message}).`);
  }

  if (stagedDocs.length === 0 && isDryRun) {
    console.log('   🔍 [DRY-RUN] Simulating inspection of 5 sample staged catalog items:\n');
    const mockItems = [
      { id: 'item_1', title: 'Olper\'s Full Cream Milk 1 Litre (12 Pack)', sku: 'DAIRY-OLP-01', basePrice: 3450, salePrice: 3200, categoryType: 'dairyBakery', stockStatus: 'in_stock', images: ['https://images.unsplash.com/photo-1550583724-b2692b85b150'] },
      { id: 'item_2', title: 'Nestle Everyday Dairy Powder 900g Pouch', sku: 'DAIRY-NST-02', basePrice: 1850, salePrice: 1750, categoryType: 'dairyBakery', stockStatus: 'in_stock', images: ['https://images.unsplash.com/photo-1528750997573-59b89d56f4f7'] },
      { id: 'item_3', title: 'Guard Supreme Basmati Rice 5kg Pouch', sku: 'GROC-GRD-05', basePrice: 2850, salePrice: 2650, categoryType: 'grocery', stockStatus: 'in_stock', images: ['https://images.unsplash.com/photo-1586201375761-83865001e31c'] },
      { id: 'item_4', title: 'Imperial Fine Bone China 16-Pc Teaset', sku: 'CROCK-IMP-16', basePrice: 9500, salePrice: 8499, categoryType: 'crockery', stockStatus: 'in_stock', images: ['https://images.unsplash.com/photo-1610701596007-11502861dcfa'] },
      { id: 'item_5', title: 'Dawn Bread Bran Loaf (Large)', sku: 'BAK-DWN-01', basePrice: 220, salePrice: 220, categoryType: 'dairyBakery', stockStatus: 'in_stock', images: ['https://images.unsplash.com/photo-1509440159596-0249088772ff'] },
    ];

    console.log('┌───────────────────────────────────────────────────┬──────────────┬─────────────┬──────────────┬────────────┐');
    console.log('│ Product Title                                     │ SKU          │ Category    │ Price (PKR)  │ Status     │');
    console.log('├───────────────────────────────────────────────────┼──────────────┼─────────────┼──────────────┼────────────┤');
    for (const item of mockItems) {
      console.log(`│ ${item.title.padEnd(49).substring(0, 49)} │ ${item.sku.padEnd(12)} │ ${item.categoryType.padEnd(11)} │ Rs. ${String(item.salePrice).padEnd(8)} │ ${item.stockStatus.padEnd(10)} │`);
    }
    console.log('└───────────────────────────────────────────────────┴──────────────┴─────────────┴──────────────┴────────────┘');
  } else if (stagedDocs.length > 0) {
    console.log(`   Found ${stagedDocs.length} staged product(s) in staging.`);
    for (const d of stagedDocs) {
      const p = d.data();
      console.log(`   • [${p.sourceSku || 'NO-SKU'}] ${p.title} (Rs. ${p.salePrice} / ${p.categoryType}) - ${p.stockStatus}`);
    }
  }

  // 3. Evaluate Publication Gates
  console.log('\n🔒 Step 3: Evaluating Marketplace Publication Gates...');

  const gates = [
    { name: 'Commerce Mode is "marketplace"', passed: integrationData.commerceMode === 'marketplace' },
    { name: 'Order Workflow Ready (Tested & Confirmed)', passed: integrationData.orderWorkflowReady === true },
    { name: 'Inventory Mode is "groclyra_authoritative"', passed: integrationData.inventoryMode === 'groclyra_authoritative' },
    { name: 'Groclyra Seller Account Mapped', passed: Boolean(integrationData.groclyraSellerId) },
    { name: 'Admin Publish Toggle (publishToMainCatalog: true)', passed: integrationData.publishToMainCatalog === true },
  ];

  let allGatesPassed = true;
  for (const g of gates) {
    if (g.passed) {
      console.log(`   🟢 PASS: ${g.name}`);
    } else {
      console.log(`   🔴 BLOCK: ${g.name}`);
      allGatesPassed = false;
    }
  }

  // 4. Publication Decision
  console.log('\n───────────────────────────────────────────────────────────────');
  console.log('   PUBLICATION DECISION');
  console.log('───────────────────────────────────────────────────────────────');

  if (!allGatesPassed) {
    console.log('⛔ MAIN CATALOG PUBLICATION IS BLOCKED.');
    console.log('   Reason: Staged products cannot be exposed to customers until order workflow');
    console.log('   and inventory authority are contractually verified and tested.');
    console.log('   Products will remain safely isolated inside "vendorCatalogItems".');
  } else {
    console.log('✅ ALL PUBLICATION GATES PASSED.');
    if (isPublish) {
      if (isDryRun) {
        console.log('   🔍 [DRY-RUN] Products would be replicated into public "products" collection.');
      } else {
        console.log('   🚀 Replicating staged items to public "products" collection...');
        const batch = db.batch();
        for (const doc of stagedDocs) {
          const item = doc.data();
          const publicRef = db.collection('products').doc(doc.id);
          batch.set(publicRef, {
            ...item,
            sellerId: integrationData.groclyraSellerId,
            sellerName: integrationData.vendorName,
            isApproved: true,
            updatedAt: admin.firestore.FieldValue.serverTimestamp(),
          }, { merge: true });
        }
        await batch.commit();
        console.log(`   🎉 Successfully published ${stagedDocs.length} products to customer catalog!`);
      }
    } else {
      console.log('   ℹ️  To execute publication, run with the "--publish" flag.');
    }
  }

  console.log('───────────────────────────────────────────────────────────────\n');
}

main().catch((err) => {
  console.error('Fatal error in inspector:', err);
  process.exit(1);
});
