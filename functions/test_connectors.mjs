import test from 'node:test';
import assert from 'node:assert';
import { VendorConnectorValidator } from './lib/vendor_connectors.js';

test('VendorConnectorValidator enforces HTTPS protocol', () => {
  assert.throws(
    () => VendorConnectorValidator.validateStoreUrl('http://insecure-store.pk'),
    /Insecure protocol/
  );
  const valid = VendorConnectorValidator.validateStoreUrl('https://partner-mart.pk');
  assert.strictEqual(valid.protocol, 'https:');
  assert.strictEqual(valid.hostname, 'partner-mart.pk');
});

test('VendorConnectorValidator rejects localhost and private IP ranges', () => {
  assert.throws(
    () => VendorConnectorValidator.validateStoreUrl('https://localhost:8080'),
    /Disallowed local or private host/
  );
  assert.throws(
    () => VendorConnectorValidator.validateStoreUrl('https://127.0.0.1/admin'),
    /Disallowed local or private host/
  );
  assert.throws(
    () => VendorConnectorValidator.validateStoreUrl('https://internal.local'),
    /Disallowed local or private host/
  );
});

test('VendorConnectorValidator rejects embedded credentials in URLs', () => {
  assert.throws(
    () => VendorConnectorValidator.validateStoreUrl('https://admin:password123@partner-mart.pk'),
    /embedded basic auth credentials/
  );
});
