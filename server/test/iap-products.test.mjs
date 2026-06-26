import assert from "node:assert/strict";
import test from "node:test";
import { loadIAPProductCatalog, normalizeIAPTransactionInput } from "../src/iap-products.mjs";
import { ValidationError } from "../src/app-store.mjs";

test("IAP product catalog falls back to the default postcard plus product", () => {
  const catalog = loadIAPProductCatalog({});
  assert.deepEqual(catalog.get("hic.postcard.plus"), {
    product_id: "hic.postcard.plus",
    plan: "postcard_plus",
    amount: 12,
    currency: "CNY"
  });
});

test("IAP product catalog can be configured from JSON object", () => {
  const catalog = loadIAPProductCatalog({
    HIC_IAP_PRODUCTS_JSON: JSON.stringify({
      "hic.postcard.plus": {
        plan: "postcard_plus",
        amount: 18,
        currency: "cny"
      }
    })
  });

  assert.deepEqual(catalog.get("hic.postcard.plus"), {
    product_id: "hic.postcard.plus",
    plan: "postcard_plus",
    amount: 18,
    currency: "CNY"
  });
});

test("IAP transaction input is normalized from server-side product catalog", () => {
  const normalized = normalizeIAPTransactionInput(
    {
      transaction_id: "tx-001",
      product_id: "hic.postcard.plus",
      environment: "local_mock"
    },
    {}
  );

  assert.equal(normalized.plan, "postcard_plus");
  assert.equal(normalized.amount, 12);
  assert.equal(normalized.currency, "CNY");
});

test("IAP transaction input rejects catalog drift or tampering", () => {
  assert.throws(
    () => normalizeIAPTransactionInput({
      transaction_id: "tx-002",
      product_id: "hic.postcard.plus",
      plan: "postcard_plus",
      amount: 1,
      currency: "CNY",
      environment: "local_mock"
    }, {}),
    ValidationError
  );

  assert.throws(
    () => normalizeIAPTransactionInput({
      transaction_id: "tx-003",
      product_id: "unknown.product",
      environment: "local_mock"
    }, {}),
    ValidationError
  );
});
