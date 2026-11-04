import path from 'path';
import { pathToFileURL } from 'url';

/**
 * Resolves Firebase Admin SDK from functions/node_modules or standard node_modules.
 */
export async function loadFirebaseAdmin() {
  try {
    const mod = await import('firebase-admin');
    return mod.default || mod;
  } catch {
    const adminPath = path.resolve('functions/node_modules/firebase-admin/lib/index.js');
    const mod = await import(pathToFileURL(adminPath).href);
    return mod.default || mod;
  }
}

/**
 * Resolves Secret Manager SDK from functions/node_modules or standard node_modules.
 */
export async function loadSecretManager() {
  try {
    const mod = await import('@google-cloud/secret-manager');
    return mod.SecretManagerServiceClient;
  } catch {
    const smPath = path.resolve('functions/node_modules/@google-cloud/secret-manager/build/src/index.js');
    const mod = await import(pathToFileURL(smPath).href);
    return mod.SecretManagerServiceClient;
  }
}
