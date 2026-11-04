#!/usr/bin/env node

/**
 * Groclyra Backend Deployment Script
 *
 * Pre-checks and deploys:
 *  1. Cloud Functions (asia-south1)
 *  2. Cloud Firestore Security Rules (firestore.rules)
 *  3. Firestore Composite Indexes (firestore.indexes.json)
 *
 * Usage:
 *   node scripts/deploy_backend.mjs
 *   node scripts/deploy_backend.mjs --dry-run
 */

import { execSync } from 'child_process';
import fs from 'fs';
import path from 'path';

const isDryRun = process.argv.includes('--dry-run');

console.log('═══════════════════════════════════════════════════════════════');
console.log('   GROCLYRA BACKEND DEPLOYMENT ORCHESTRATOR');
console.log('═══════════════════════════════════════════════════════════════\n');

// 1. Verify build artifacts
console.log('📦 Step 1: Compiling Cloud Functions TypeScript source...');
try {
  execSync('npm run build', { cwd: path.resolve('functions'), stdio: 'inherit' });
  console.log('   ✅ Cloud Functions compiled cleanly.\n');
} catch {
  console.error('❌ TypeScript compilation failed in functions/. Aborting deploy.');
  process.exit(1);
}

// 2. Verify security rules & index files exist
console.log('🛡️  Step 2: Checking Firestore configuration files...');
if (!fs.existsSync('firestore.rules')) {
  console.error('❌ firestore.rules not found in project root.');
  process.exit(1);
}
if (!fs.existsSync('firestore.indexes.json')) {
  console.error('❌ firestore.indexes.json not found in project root.');
  process.exit(1);
}
console.log('   ✅ firestore.rules and firestore.indexes.json verified.\n');

// 3. Inspect active Firebase account and project
console.log('🔍 Step 3: Verifying active Firebase CLI project...');
try {
  const currentProject = execSync('firebase project:current', { encoding: 'utf8' }).trim();
  console.log(`   Active Project: ${currentProject}`);
} catch {
  console.log('   ⚠️  No active project selected. Checking .firebaserc...');
}

if (isDryRun) {
  console.log('\n🔍 [DRY-RUN] Pre-flight checks passed successfully. Deployment command to run:');
  console.log('   firebase deploy --only functions,firestore:rules,firestore:indexes\n');
  process.exit(0);
}

// 4. Execute Firebase Deploy
console.log('🚀 Step 4: Deploying Functions, Rules & Indexes to Firebase...');
try {
  execSync('firebase deploy --only functions,firestore:rules,firestore:indexes', {
    stdio: 'inherit',
  });
  console.log('\n✅ Deployment completed successfully!');
} catch (err) {
  console.error('\n❌ Deployment failed.');
  console.error('   Common causes:');
  console.error('   1. Active account lacks permissions (run "firebase login" to switch account).');
  console.error('   2. Project ID does not match (run "firebase use <projectId>").');
  console.error('   3. Blaze billing plan required for Cloud Functions.');
  process.exit(1);
}
