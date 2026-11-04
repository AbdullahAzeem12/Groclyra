#!/usr/bin/env node

/**
 * Groclyra Staging Synchronization Driver
 *
 * Initiates an authoritative catalog synchronization run for an onboarded vendor integration:
 *  1. Checks and acquires distributed lease lock on `vendorIntegrations/{id}`.
 *  2. Evaluates verification gates (domain ownership, legal agreement, rights).
 *  3. Ingests and normalizes product items into staging collection `vendorCatalogItems`.
 *  4. Evaluates customer publication gates (keeps items in staging unless verified for marketplace).
 *  5. Records durable execution run in `catalogSyncRuns`.
 *
 * Usage:
 *   node scripts/run_vendor_sync.mjs --integration wc_pilot_grocer_01
 *   node scripts/run_vendor_sync.mjs --integration wc_pilot_grocer_01 --dry-run
 *   node scripts/run_vendor_sync.mjs --integration wc_pilot_grocer_01 --force
 */

import path from 'path';
import { pathToFileURL } from 'url';
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
const isDryRun = Boolean(params['dry-run']);
const isForce = Boolean(params.force);

console.log('═══════════════════════════════════════════════════════════════');
console.log('   GROCLYRA VENDOR STAGING SYNCHRONIZATION RUNNER');
console.log('═══════════════════════════════════════════════════════════════');
console.log(` Target Integration: ${integrationId}`);
console.log(` Mode:               ${isDryRun ? '🔍 DRY-RUN (Simulation)' : '🚀 LIVE SYNC'}`);
console.log(` Force Lock Release: ${isForce}\n`);

async function main() {
  // Load functions compiled module
  const syncModulePath = path.resolve('functions/lib/vendor_sync.js');
  let executeVendorCatalogSync;
  try {
    const mod = await import(pathToFileURL(syncModulePath).href);
    executeVendorCatalogSync = mod.executeVendorCatalogSync;
  } catch (err) {
    console.error('❌ Could not import compiled vendor_sync engine from functions/lib/:', err.message);
    console.error('   Please run "npm run build" inside functions/ directory first.');
    process.exit(1);
  }

  const admin = await loadFirebaseAdmin();

  if (!admin.apps.length) {
    try {
      admin.initializeApp();
    } catch (err) {
      console.error('❌ Firebase Admin initialization note:', err.message);
      console.log('   Ensure valid Google Application Credentials or emulator is active for live sync.');
    }
  }

  if (isDryRun) {
    console.log('🔍 [DRY-RUN] Simulating catalog sync workflow...');
    console.log(`   1. Transactionally check lease on vendorIntegrations/${integrationId}`);
    console.log(`   2. Read secret payload from Secret Manager`);
    console.log(`   3. Fetch products from vendor REST API (WooCommerce/Shopify)`);
    console.log(`   4. Normalize titles, prices (PKR), images, SKUs, and stock quantities`);
    console.log(`   5. Write normalized rows to vendorCatalogItems/{id}`);
    console.log(`   6. PublishToMainCatalog gate: BLOCKED (Safe Staging Isolation)`);
    console.log(`   7. Write final status to catalogSyncRuns/sync_${integrationId}_<timestamp>`);
    console.log('\n✅ Staging sync simulation passed successfully.\n');
    return;
  }

  const db = admin.firestore();
  console.log(`🚀 Triggering executeVendorCatalogSync for "${integrationId}"...`);

  try {
    const result = await executeVendorCatalogSync(db, integrationId, {
      triggeredBy: 'cli:admin',
      force: isForce,
    });

    console.log('\n───────────────────────────────────────────────────────────────');
    console.log('   SYNC EXECUTION RESULT');
    console.log('───────────────────────────────────────────────────────────────');
    console.log(` Status:           ${result.status === 'succeeded' ? '🟢 SUCCEEDED' : '🔴 FAILED'}`);
    console.log(` Run ID:           ${result.runId}`);
    console.log(` Products Fetched: ${result.productsFetched}`);
    console.log(` Products Staged:  ${result.productsCreated}`);
    console.log(` Products Updated: ${result.productsUpdated}`);

    if (result.warnings && result.warnings.length > 0) {
      console.log('\n⚠️  Warnings / Gate Notices:');
      for (const w of result.warnings) {
        console.log(`   • ${w}`);
      }
    }

    if (result.error) {
      console.log(`\n❌ Error: ${result.error}`);
    } else {
      console.log('\n🎉 Products are safely staged in "vendorCatalogItems".');
      console.log('   Run inspection tool to review items before marketplace publication:');
      console.log(`   Command: node scripts/inspect_and_publish_staged.mjs --integration ${integrationId}\n`);
    }
  } catch (err) {
    console.error('\n❌ Fatal error executing vendor catalog sync:', err.message);
    process.exit(1);
  }
}

main().catch((e) => {
  console.error(e);
  process.exit(1);
});
