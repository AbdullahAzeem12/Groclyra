#!/usr/bin/env node

/**
 * Groclyra Production Catalog Migration Script
 *
 * Safely marks the 21 known legacy demonstration/mock products as retired & unapproved
 * in the Firestore `products` collection WITHOUT deleting documents, preserving customer
 * order histories, audit trails, and foreign key references.
 *
 * SAFETY FIRST:
 *  - Default mode is DRY-RUN (read-only inspection, zero database writes).
 *  - To execute changes, supply the explicit `--apply` flag.
 *  - Target IDs are strictly constrained to the 21 known mock catalog IDs.
 *
 * Usage:
 *   node scripts/retire_legacy_demo_catalog.mjs            # Dry-run inspection
 *   node scripts/retire_legacy_demo_catalog.mjs --dry-run  # Explicit dry-run
 *   node scripts/retire_legacy_demo_catalog.mjs --apply    # Execute retirement in Firestore
 */

import { loadFirebaseAdmin } from './helpers.mjs';

// The 21 known legacy demo product IDs seeded by MockCatalogData
export const LEGACY_DEMO_PRODUCT_IDS = [
  'prod_crock_01',
  'prod_crock_02',
  'prod_crock_03',
  'prod_groc_01',
  'prod_groc_02',
  'prod_groc_03',
  'prod_food_01',
  'prod_food_02',
  'prod_food_03',
  'prod_food_04',
  'prod_food_05',
  'prod_bak_01',
  'prod_bak_02',
  'prod_bak_03',
  'prod_bak_04',
  'prod_dairy_01',
  'prod_dairy_02',
  'prod_dairy_03',
  'prod_dairy_04',
  'prod_dairy_05',
  'prod_dairy_06',
];

async function main() {
  const args = process.argv.slice(2);
  const isApply = args.includes('--apply');
  const isDryRun = !isApply || args.includes('--dry-run');

  console.log('═══════════════════════════════════════════════════════════════');
  console.log('   GROCLYRA DEMO CATALOG RETIREMENT MIGRATION TOOL');
  console.log('═══════════════════════════════════════════════════════════════');
  console.log(` Mode: ${isDryRun ? '🔍 DRY-RUN (Read-Only Simulation)' : '⚠️  LIVE APPLY (Writing to Firestore)'}`);
  console.log(` Target Demo Products: ${LEGACY_DEMO_PRODUCT_IDS.length} items`);
  console.log('───────────────────────────────────────────────────────────────\n');

  const admin = await loadFirebaseAdmin();

  // Initialize Firebase Admin if not already initialized
  if (!admin.apps.length) {
    try {
      admin.initializeApp();
    } catch (err) {
      console.error('❌ Failed to initialize Firebase Admin SDK.');
      console.error('   Ensure GOOGLE_APPLICATION_CREDENTIALS or gcloud auth is configured.');
      console.error(err);
      process.exit(1);
    }
  }

  const db = admin.firestore();
  let foundCount = 0;
  let alreadyRetiredCount = 0;
  let toRetireCount = 0;
  let notFoundCount = 0;

  console.log('Inspecting Firestore "products" collection for legacy demo documents...\n');

  for (const productId of LEGACY_DEMO_PRODUCT_IDS) {
    const docRef = db.collection('products').doc(productId);
    let docSnap;
    try {
      docSnap = await docRef.get();
    } catch (e) {
      console.error(`❌ Error reading product '${productId}':`, e.message);
      continue;
    }

    if (!docSnap.exists) {
      console.log(`  ⚪ [NOT FOUND] ${productId.padEnd(16)} (Not present in database)`);
      notFoundCount++;
      continue;
    }

    foundCount++;
    const data = docSnap.data() || {};
    const title = data.title || data.name || 'Unnamed Product';
    const isApproved = data.isApproved === true;
    const isArchived = data.isArchived === true;

    if (!isApproved && isArchived) {
      console.log(`  🟡 [ALREADY RETIRED] ${productId.padEnd(16)} "${title}"`);
      alreadyRetiredCount++;
      continue;
    }

    toRetireCount++;
    if (isDryRun) {
      console.log(
        `  🔵 [DRY-RUN] Would retire: ${productId.padEnd(16)} "${title}" (isApproved: ${isApproved} -> false, isArchived: ${isArchived} -> true)`
      );
    } else {
      try {
        await docRef.update({
          isApproved: false,
          isArchived: true,
          isDemoProduct: true,
          catalogSyncStatus: 'retired_demo',
          retiredAt: admin.firestore.FieldValue.serverTimestamp(),
          updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        });
        console.log(`  🟢 [RETIRED] ${productId.padEnd(16)} "${title}" updated successfully.`);
      } catch (err) {
        console.error(`  ❌ [FAILED] Could not retire ${productId}:`, err.message);
      }
    }
  }

  console.log('\n───────────────────────────────────────────────────────────────');
  console.log('   MIGRATION SUMMARY');
  console.log('───────────────────────────────────────────────────────────────');
  console.log(` Total Scanned:       ${LEGACY_DEMO_PRODUCT_IDS.length}`);
  console.log(` Found in Database:   ${foundCount}`);
  console.log(` Already Retired:     ${alreadyRetiredCount}`);
  console.log(` ${isDryRun ? 'Would Be Retired:   ' : 'Successfully Retired:'} ${toRetireCount}`);
  console.log(` Not Found:           ${notFoundCount}`);
  console.log('───────────────────────────────────────────────────────────────');

  if (isDryRun && toRetireCount > 0) {
    console.log('\n💡 To execute this migration for real, run:');
    console.log('   node scripts/retire_legacy_demo_catalog.mjs --apply\n');
  } else if (!isDryRun) {
    console.log('\n✅ Demo catalog retirement completed safely.\n');
  }
}

main().catch((err) => {
  console.error('\n❌ Fatal migration error:', err);
  process.exit(1);
});
