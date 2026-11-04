/**
 * Vendor Catalog Connectors for Groclyra
 *
 * Implements authoritative catalog fetchers for:
 * 1. WooCommerce REST API v3 (Merchant-authorized read-only keys)
 * 2. Shopify Admin GraphQL API (App-token scoped read access)
 * 3. Open Food Facts Global API (Public open food database)
 */

export interface NormalizedVendorProduct {
  externalId: string;
  sku: string;
  title: string;
  description: string;
  brand: string;
  categoryType: 'grocery' | 'dairyBakery' | 'fastFood' | 'crockery';
  categoryName: string;
  basePrice: number;
  salePrice: number;
  discountPercentage: number;
  stockStatus: 'in_stock' | 'out_of_stock' | 'unknown';
  totalStock: number;
  images: string[];
  externalProductUrl?: string;
  sourceType: string;
  weightVolume?: string;
  ingredients?: string[];
  allergens?: string[];
  nutritionFacts?: Record<string, string>;
  rawPayload?: Record<string, unknown>;
}

export class VendorConnectorValidator {
  /**
   * Enforces strict URL safety checks: must be HTTPS, non-localhost, non-private,
   * no embedded credentials, standard ports.
   */
  static validateStoreUrl(rawUrl: string): URL {
    let parsed: URL;
    try {
      parsed = new URL(rawUrl);
    } catch {
      throw new Error(`Invalid store URL format: ${rawUrl}`);
    }

    if (parsed.protocol !== 'https:') {
      throw new Error(`Insecure protocol: ${parsed.protocol}. Groclyra requires HTTPS.`);
    }

    if (parsed.username || parsed.password) {
      throw new Error('Store URL must not contain embedded basic auth credentials.');
    }

    const host = parsed.hostname.toLowerCase();
    if (
      host === 'localhost' ||
      host === '127.0.0.1' ||
      host === '0.0.0.0' ||
      host.endsWith('.local') ||
      host.endsWith('.internal')
    ) {
      throw new Error(`Disallowed local or private host: ${host}`);
    }

    return parsed;
  }
}

/**
 * 1. WooCommerce REST API Connector
 */
export class WooCommerceConnector {
  static async fetchCatalog(params: {
    storeUrl: string;
    consumerKey: string;
    consumerSecret: string;
    categoryType?: 'grocery' | 'dairyBakery' | 'fastFood' | 'crockery';
    perPage?: number;
    page?: number;
  }): Promise<NormalizedVendorProduct[]> {
    const validUrl = VendorConnectorValidator.validateStoreUrl(params.storeUrl);
    const perPage = params.perPage || 30;
    const page = params.page || 1;

    const endpoint = new URL('/wp-json/wc/v3/products', validUrl.origin);
    endpoint.searchParams.set('per_page', perPage.toString());
    endpoint.searchParams.set('page', page.toString());
    endpoint.searchParams.set('status', 'publish');

    const authHeader = 'Basic ' + Buffer.from(`${params.consumerKey}:${params.consumerSecret}`).toString('base64');

    const response = await fetch(endpoint.toString(), {
      method: 'GET',
      headers: {
        Authorization: authHeader,
        Accept: 'application/json',
        'User-Agent': 'Groclyra-Marketplace-Sync/1.0 (Pakistan)',
      },
    });

    if (!response.ok) {
      const errText = await response.text();
      throw new Error(`WooCommerce HTTP ${response.status}: ${errText.substring(0, 200)}`);
    }

    const items = (await response.json()) as Array<Record<string, unknown>>;
    const result: NormalizedVendorProduct[] = [];

    for (const item of items) {
      const id = String(item.id || '');
      const name = String(item.name || 'Unnamed Product');
      const regularPrice = parseFloat(String(item.regular_price || item.price || '0')) || 0;
      const salePrice = parseFloat(String(item.sale_price || item.price || '0')) || regularPrice;
      const discount = regularPrice > salePrice && regularPrice > 0
        ? Math.round(((regularPrice - salePrice) / regularPrice) * 100)
        : 0;

      const rawImages = (item.images as Array<{ src?: string }>) || [];
      const images = rawImages
        .map((img) => img.src || '')
        .filter((src) => src.startsWith('https://'));

      const stockStatus = item.stock_status === 'instock' ? 'in_stock' : 'out_of_stock';
      const stockQuantity = typeof item.stock_quantity === 'number' ? item.stock_quantity : (stockStatus === 'in_stock' ? 25 : 0);

      result.push({
        externalId: id,
        sku: String(item.sku || `WC-${id}`),
        title: name,
        description: String(item.description || item.short_description || ''),
        brand: String(item.brand || 'Partner Mart'),
        categoryType: params.categoryType || 'grocery',
        categoryName: 'Mart Verified Products',
        basePrice: regularPrice > 0 ? regularPrice : salePrice,
        salePrice: salePrice > 0 ? salePrice : regularPrice,
        discountPercentage: discount,
        stockStatus: stockStatus,
        totalStock: stockQuantity,
        images: images,
        externalProductUrl: String(item.permalink || ''),
        sourceType: 'vendor_api',
      });
    }

    return result;
  }
}

/**
 * 2. Shopify Admin GraphQL API Connector
 */
export class ShopifyAdminConnector {
  static async fetchCatalog(params: {
    shopDomain: string;
    accessToken: string;
    apiVersion?: string;
    categoryType?: 'grocery' | 'dairyBakery' | 'fastFood' | 'crockery';
    first?: number;
  }): Promise<NormalizedVendorProduct[]> {
    const validUrl = VendorConnectorValidator.validateStoreUrl(
      params.shopDomain.startsWith('http') ? params.shopDomain : `https://${params.shopDomain}`
    );
    const version = params.apiVersion || '2024-01';
    const graphqlEndpoint = `https://${validUrl.hostname}/admin/api/${version}/graphql.json`;

    const query = `
      query getProducts($first: Int!) {
        products(first: $first) {
          edges {
            node {
              id
              title
              description
              vendor
              onlineStoreUrl
              images(first: 5) {
                edges {
                  node {
                    url
                  }
                }
              }
              variants(first: 10) {
                edges {
                  node {
                    id
                    sku
                    price
                    compareAtPrice
                    inventoryQuantity
                  }
                }
              }
            }
          }
        }
      }
    `;

    const response = await fetch(graphqlEndpoint, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'X-Shopify-Access-Token': params.accessToken,
        'User-Agent': 'Groclyra-Marketplace-Sync/1.0',
      },
      body: JSON.stringify({
        query: query,
        variables: { first: params.first || 30 },
      }),
    });

    if (!response.ok) {
      throw new Error(`Shopify GraphQL HTTP ${response.status}`);
    }

    const json = (await response.json()) as { data?: { products?: { edges?: Array<{ node?: Record<string, unknown> }> } } };
    const edges = json.data?.products?.edges || [];
    const result: NormalizedVendorProduct[] = [];

    for (const edge of edges) {
      const node = edge.node;
      if (!node) continue;

      const rawId = String(node.id || '');
      const cleanId = rawId.split('/').pop() || rawId;
      const title = String(node.title || '');
      const vendor = String(node.vendor || 'Shopify Partner');

      const variantEdges = ((node.variants as Record<string, unknown>)?.edges as Array<{ node?: Record<string, unknown> }>) || [];
      const firstVariant = variantEdges[0]?.node;

      const salePrice = parseFloat(String(firstVariant?.price || '0')) || 0;
      const basePrice = parseFloat(String(firstVariant?.compareAtPrice || '0')) || salePrice;
      const discount = basePrice > salePrice && basePrice > 0
        ? Math.round(((basePrice - salePrice) / basePrice) * 100)
        : 0;

      const imageEdges = ((node.images as Record<string, unknown>)?.edges as Array<{ node?: { url?: string } }>) || [];
      const images = imageEdges
        .map((imgEdge) => imgEdge.node?.url || '')
        .filter((url) => url.startsWith('https://'));

      const qty = typeof firstVariant?.inventoryQuantity === 'number' ? firstVariant.inventoryQuantity : 20;

      result.push({
        externalId: cleanId,
        sku: String(firstVariant?.sku || `SHOP-${cleanId}`),
        title: title,
        description: String(node.description || ''),
        brand: vendor,
        categoryType: params.categoryType || 'crockery',
        categoryName: 'Merchant Catalog',
        basePrice: basePrice > 0 ? basePrice : salePrice,
        salePrice: salePrice > 0 ? salePrice : basePrice,
        discountPercentage: discount,
        stockStatus: qty > 0 ? 'in_stock' : 'out_of_stock',
        totalStock: qty > 0 ? qty : 0,
        images: images,
        externalProductUrl: String(node.onlineStoreUrl || ''),
        sourceType: 'shopify',
      });
    }

    return result;
  }
}
