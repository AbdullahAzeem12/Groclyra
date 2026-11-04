import * as admin from "firebase-admin";
import { SecretManagerServiceClient } from "@google-cloud/secret-manager";
import {
  NormalizedVendorProduct,
  ShopifyAdminConnector,
  VendorConnectorValidator,
  WooCommerceConnector,
} from "./vendor_connectors";

const secretClient = new SecretManagerServiceClient();

export interface VendorIntegrationDoc {
  id: string;
  vendorId?: string;
  vendorName: string;
  provider: "wooCommerce" | "shopify" | "shopifyAdmin" | "openFoodFacts" | "customApi" | "manual";
  status: "active" | "pendingAuthorization" | "paused" | "error";
  commerceMode: "marketplace" | "catalogOnly" | "affiliate";
  externalStoreUrl?: string;
  domainOwnershipVerified?: boolean;
  vendorAuthorizationVerified?: boolean;
  catalogUseRightsVerified?: boolean;
  agreementRef?: string;
  secretVersionName?: string;
  defaultCategoryType?: "grocery" | "dairyBakery" | "fastFood" | "crockery";
  defaultCategoryName?: string;
  categoryMappings?: Record<string, "grocery" | "dairyBakery" | "fastFood" | "crockery">;
  currency?: string;
  syncIntervalMinutes?: number;
  maxProductsPerSync?: number;
  allowEmptyCatalogDeactivate?: boolean;
  publishToMainCatalog?: boolean;
  orderWorkflowReady?: boolean;
  inventoryMode?: "groclyra_authoritative" | "vendor_authoritative";
  inventoryReservationEnabled?: boolean;
  autoApproveCatalog?: boolean;
  groclyraSellerId?: string;
  lastSyncAt?: string;
  lastSyncStatus?: string;
  nextSyncAt?: string;
  totalProductsSynced?: number;
  currentSyncLease?: string;
  leaseExpiresAt?: number;
}

/**
 * Loads secret credentials safely from Google Secret Manager.
 * Never logs credentials or returns them to clients.
 */
async function loadSecretPayload(secretVersionName: string): Promise<Record<string, unknown>> {
  if (!secretVersionName || !secretVersionName.startsWith("projects/")) {
    throw new Error(`Invalid secretVersionName format: ${secretVersionName}`);
  }
  const [version] = await secretClient.accessSecretVersion({
    name: secretVersionName,
  });
  const payload = version.payload?.data?.toString();
  if (!payload) {
    throw new Error(`Secret ${secretVersionName} contained empty payload.`);
  }
  return JSON.parse(payload) as Record<string, unknown>;
}

/**
 * Authoritative Vendor Catalog Sync Execution Engine.
 * Enforces:
 * 1. Mutual exclusion sync lease per integration
 * 2. Strict verification gates (domain, merchant authorization, catalog rights)
 * 3. Secret Manager credential fetching
 * 4. Staging into vendorCatalogItems collection
 * 5. Publication gating before writing to public products collection
 * 6. Durable sync run history logging
 */
export async function executeVendorCatalogSync(
  db: admin.firestore.Firestore,
  integrationId: string,
  options?: {
    runId?: string;
    triggeredBy?: string;
    force?: boolean;
  }
): Promise<{
  runId: string;
  status: "succeeded" | "failed";
  productsFetched: number;
  productsCreated: number;
  productsUpdated: number;
  warnings: string[];
  error?: string;
}> {
  const startedAt = new Date();
  const runId = options?.runId || `sync_${integrationId}_${startedAt.getTime()}`;
  const triggeredBy = options?.triggeredBy || "system";
  const warnings: string[] = [];

  const integrationRef = db.collection("vendorIntegrations").doc(integrationId);
  const runRef = db.collection("catalogSyncRuns").doc(runId);

  // 1. Transactional Lease Acquisition to prevent race conditions & duplicate runs
  const integrationDoc = await db.runTransaction(async (transaction) => {
    const snap = await transaction.get(integrationRef);
    if (!snap.exists) {
      throw new Error(`Vendor integration ${integrationId} does not exist.`);
    }
    const data = snap.data() as VendorIntegrationDoc;
    const nowMs = Date.now();

    if (
      !options?.force &&
      data.currentSyncLease &&
      data.leaseExpiresAt &&
      data.leaseExpiresAt > nowMs
    ) {
      throw new Error(
        `Active sync lease ${data.currentSyncLease} is already held for integration ${integrationId}. Expires in ${Math.round((data.leaseExpiresAt - nowMs) / 1000)}s.`
      );
    }

    // Set 10-minute lease
    transaction.update(integrationRef, {
      currentSyncLease: runId,
      leaseExpiresAt: nowMs + 10 * 60 * 1000,
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    return data;
  });

  // Record initial run state in catalogSyncRuns
  await runRef.set({
    id: runId,
    integrationId: integrationId,
    vendorName: integrationDoc.vendorName || "Unknown Vendor",
    status: "running",
    triggeredBy: triggeredBy,
    productsFetched: 0,
    productsCreated: 0,
    productsUpdated: 0,
    startedAt: startedAt.toISOString(),
    provider: integrationDoc.provider,
    warnings: [],
  });

  try {
    // 2. Verification Gates (Strict authorization enforcement)
    if (
      integrationDoc.provider === "wooCommerce" ||
      integrationDoc.provider === "shopify" ||
      integrationDoc.provider === "shopifyAdmin"
    ) {
      if (!integrationDoc.domainOwnershipVerified) {
        throw new Error("Verification Gate Failed: Domain ownership is not verified for this store.");
      }
      if (!integrationDoc.vendorAuthorizationVerified) {
        throw new Error("Verification Gate Failed: Merchant authorization is not verified.");
      }
      if (!integrationDoc.catalogUseRightsVerified) {
        throw new Error("Verification Gate Failed: Catalog and product image use rights are not verified.");
      }
      if (!integrationDoc.agreementRef || integrationDoc.agreementRef.trim().length === 0) {
        throw new Error("Verification Gate Failed: Legal agreement reference is missing.");
      }
      if (!integrationDoc.secretVersionName) {
        throw new Error("Configuration Failed: Secret Manager reference (secretVersionName) is missing.");
      }
      if (!integrationDoc.externalStoreUrl) {
        throw new Error("Configuration Failed: externalStoreUrl is missing.");
      }

      // Enforce strict URL safety (HTTPS, non-localhost, non-private, valid ports)
      VendorConnectorValidator.validateStoreUrl(integrationDoc.externalStoreUrl);
    }

    // Explicit currency check
    if (!integrationDoc.currency || integrationDoc.currency.length !== 3) {
      warnings.push("Currency not specified or non-standard ISO code; defaulting to PKR.");
    }

    let normalizedProducts: NormalizedVendorProduct[] = [];

    // 3. Connector Invocation
    if (integrationDoc.provider === "wooCommerce") {
      const secrets = await loadSecretPayload(integrationDoc.secretVersionName!);
      const consumerKey = String(secrets.consumerKey || "");
      const consumerSecret = String(secrets.consumerSecret || "");

      if (!consumerKey || !consumerSecret) {
        throw new Error("WooCommerce secret payload is missing consumerKey or consumerSecret.");
      }

      normalizedProducts = await WooCommerceConnector.fetchCatalog({
        storeUrl: integrationDoc.externalStoreUrl!,
        consumerKey: consumerKey,
        consumerSecret: consumerSecret,
        categoryType: integrationDoc.defaultCategoryType || "grocery",
        perPage: Math.min(integrationDoc.maxProductsPerSync || 50, 100),
      });
    } else if (
      integrationDoc.provider === "shopify" ||
      integrationDoc.provider === "shopifyAdmin"
    ) {
      const secrets = await loadSecretPayload(integrationDoc.secretVersionName!);
      const accessToken = String(secrets.accessToken || "");

      if (!accessToken) {
        throw new Error("Shopify secret payload is missing accessToken.");
      }

      normalizedProducts = await ShopifyAdminConnector.fetchCatalog({
        shopDomain: integrationDoc.externalStoreUrl!,
        accessToken: accessToken,
        categoryType: integrationDoc.defaultCategoryType || "crockery",
        first: Math.min(integrationDoc.maxProductsPerSync || 50, 100),
      });
    } else {
      warnings.push(`Provider '${integrationDoc.provider}' is a manual or mocked staging adapter.`);
    }

    // 4. Empty Catalog Safeguard
    if (normalizedProducts.length === 0) {
      warnings.push("Connector returned 0 products from upstream vendor.");
      if (!integrationDoc.allowEmptyCatalogDeactivate) {
        warnings.push("Empty catalog deactivate safeguard active: Existing staged items preserved.");
      }
    }

    // 5. Staging into vendorCatalogItems
    let createdCount = 0;
    let updatedCount = 0;
    const batch = db.batch();

    const canPublishToMainCatalog =
      integrationDoc.publishToMainCatalog === true &&
      integrationDoc.commerceMode === "marketplace" &&
      integrationDoc.orderWorkflowReady === true &&
      integrationDoc.inventoryMode === "groclyra_authoritative" &&
      Boolean(integrationDoc.groclyraSellerId);

    if (integrationDoc.publishToMainCatalog && !canPublishToMainCatalog) {
      warnings.push(
        "Main-catalog publication blocked: Integration has not satisfied the full marketplace publication gate (order workflow, Groclyra inventory authority, and mapped seller ID required)."
      );
    }

    const nowIso = new Date().toISOString();

    for (const prod of normalizedProducts) {
      const stableItemId = `vendor_${integrationId}_${prod.externalId.replace(/[^a-zA-Z0-9_-]/g, "_")}`;
      const itemRef = db.collection("vendorCatalogItems").doc(stableItemId);

      const stagedData = {
        id: stableItemId,
        sourceStoreId: integrationId,
        sourceVendorId: integrationDoc.vendorId || "",
        sourceProductId: prod.externalId,
        sourceSku: prod.sku,
        title: prod.title,
        description: prod.description,
        brand: prod.brand,
        categoryType: prod.categoryType,
        categoryName: prod.categoryName,
        basePrice: prod.basePrice,
        salePrice: prod.salePrice,
        discountPercentage: prod.discountPercentage,
        stockStatus: prod.stockStatus,
        totalStock: prod.totalStock,
        images: prod.images,
        externalProductUrl: prod.externalProductUrl || "",
        sourceType: "vendor_api",
        sourceUpdatedAt: nowIso,
        lastSyncedAt: nowIso,
        catalogSyncStatus: "staged",
        currency: integrationDoc.currency || "PKR",
        active: prod.stockStatus === "in_stock",
      };

      batch.set(itemRef, stagedData, { merge: true });
      createdCount++;

      // If publication gate passed, replicate to public products collection
      if (canPublishToMainCatalog) {
        const publicProductRef = db.collection("products").doc(stableItemId);
        batch.set(
          publicProductRef,
          {
            ...stagedData,
            sellerId: integrationDoc.groclyraSellerId,
            sellerName: integrationDoc.vendorName,
            isApproved: integrationDoc.autoApproveCatalog === true,
            isFeatured: false,
            isFlashDeal: false,
            totalSold: 0,
            viewCount: 0,
            checkoutMode: "groclyra_marketplace",
            updatedAt: admin.firestore.FieldValue.serverTimestamp(),
          },
          { merge: true }
        );
      }
    }

    await batch.commit();

    const completedAt = new Date();
    const resultSummary = `Sync succeeded: ${createdCount} items normalized & staged.`;

    // 6. Update Run Record
    await runRef.update({
      status: "succeeded",
      productsFetched: normalizedProducts.length,
      productsCreated: createdCount,
      productsUpdated: updatedCount,
      completedAt: completedAt.toISOString(),
      warnings: warnings,
    });

    // 7. Update Integration State and Release Lease
    const syncIntervalMinutes = integrationDoc.syncIntervalMinutes || 30;
    const nextSyncAt = new Date(completedAt.getTime() + syncIntervalMinutes * 60 * 1000).toISOString();

    await integrationRef.update({
      currentSyncLease: admin.firestore.FieldValue.delete(),
      leaseExpiresAt: admin.firestore.FieldValue.delete(),
      lastSyncAt: completedAt.toISOString(),
      lastSyncStatus: resultSummary,
      nextSyncAt: nextSyncAt,
      totalProductsSynced: admin.firestore.FieldValue.increment(createdCount),
      status: "active",
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    return {
      runId: runId,
      status: "succeeded",
      productsFetched: normalizedProducts.length,
      productsCreated: createdCount,
      productsUpdated: updatedCount,
      warnings: warnings,
    };
  } catch (err: unknown) {
    const errorMsg = err instanceof Error ? err.message : String(err);
    const completedAt = new Date();

    // Log failure in sync run record
    await runRef.update({
      status: "failed",
      errorMessage: errorMsg,
      completedAt: completedAt.toISOString(),
      warnings: warnings,
    });

    // Release lease on failure and set status
    await integrationRef.update({
      currentSyncLease: admin.firestore.FieldValue.delete(),
      leaseExpiresAt: admin.firestore.FieldValue.delete(),
      lastSyncAt: completedAt.toISOString(),
      lastSyncStatus: `Sync failed: ${errorMsg.substring(0, 150)}`,
      status: "error",
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    return {
      runId: runId,
      status: "failed",
      productsFetched: 0,
      productsCreated: 0,
      productsUpdated: 0,
      warnings: warnings,
      error: errorMsg,
    };
  }
}
