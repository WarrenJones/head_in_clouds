import { ValidationError } from "./app-store.mjs";

const DEFAULT_PRODUCT_CATALOG = Object.freeze({
  "hic.postcard.plus": Object.freeze({
    product_id: "hic.postcard.plus",
    plan: "postcard_plus",
    amount: 12,
    currency: "CNY"
  })
});

export function normalizeIAPTransactionInput(input = {}, env = process.env) {
  const productID = requiredString(input.product_id, "product_id");
  const catalog = loadIAPProductCatalog(env);
  const product = catalog.get(productID);
  if (!product) {
    throw new ValidationError("product_id is not configured");
  }

  assertOptionalMatch(input.plan, product.plan, "plan");
  assertOptionalMatch(input.currency?.toUpperCase(), product.currency, "currency");
  assertOptionalAmountMatch(input.amount, product.amount);

  return {
    ...input,
    product_id: product.product_id,
    plan: product.plan,
    amount: product.amount,
    currency: product.currency
  };
}

export function loadIAPProductCatalog(env = process.env) {
  const raw = env.HIC_IAP_PRODUCTS_JSON;
  if (!raw || raw.trim().length === 0) {
    return buildCatalog(DEFAULT_PRODUCT_CATALOG);
  }

  try {
    return buildCatalog(JSON.parse(raw));
  } catch (error) {
    if (error instanceof ValidationError) {
      throw error;
    }
    throw new ValidationError("HIC_IAP_PRODUCTS_JSON must be valid JSON");
  }
}

function buildCatalog(rawCatalog) {
  const products = Array.isArray(rawCatalog)
    ? rawCatalog
    : Object.entries(rawCatalog ?? {}).map(([productID, product]) => ({
        product_id: productID,
        ...product
      }));

  const catalog = new Map();
  for (const product of products) {
    const normalized = normalizeProduct(product);
    if (catalog.has(normalized.product_id)) {
      throw new ValidationError(`duplicate IAP product_id: ${normalized.product_id}`);
    }
    catalog.set(normalized.product_id, normalized);
  }

  if (catalog.size === 0) {
    throw new ValidationError("IAP product catalog cannot be empty");
  }
  return catalog;
}

function normalizeProduct(product = {}) {
  const productID = requiredString(product.product_id, "product_id");
  const plan = requiredString(product.plan, "plan");
  const amount = requiredAmount(product.amount, "amount");
  const currency = requiredString(product.currency ?? "CNY", "currency").toUpperCase();

  if (!/^[A-Z]{3}$/.test(currency)) {
    throw new ValidationError("currency is invalid");
  }

  return {
    product_id: productID,
    plan,
    amount,
    currency
  };
}

function assertOptionalMatch(actual, expected, fieldName) {
  if (actual === undefined || actual === null || actual === "") {
    return;
  }
  if (String(actual).trim() !== expected) {
    throw new ValidationError(`${fieldName} does not match configured product`);
  }
}

function assertOptionalAmountMatch(actual, expected) {
  if (actual === undefined || actual === null || actual === "") {
    return;
  }
  if (requiredAmount(actual, "amount") !== expected) {
    throw new ValidationError("amount does not match configured product");
  }
}

function requiredString(value, fieldName) {
  if (typeof value !== "string" || value.trim().length === 0) {
    throw new ValidationError(`${fieldName} is required`);
  }
  return value.trim();
}

function requiredAmount(value, fieldName) {
  const amount = Number(value);
  if (!Number.isFinite(amount) || amount <= 0) {
    throw new ValidationError(`${fieldName} is invalid`);
  }
  return amount;
}
