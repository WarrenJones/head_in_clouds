import assert from "node:assert/strict";
import test from "node:test";
import { ValidationError } from "../src/app-store.mjs";
import { validateStoreKitSignedTransactionJWS } from "../src/storekit-jws.mjs";

test("StoreKit JWS guard accepts matching sandbox payload fields", () => {
  const payload = validateStoreKitSignedTransactionJWS({
    transaction_id: "200000001",
    original_transaction_id: "100000001",
    product_id: "hic.postcard.plus",
    environment: "sandbox",
    signed_transaction_jws: makeStoreKitJWS({
      transactionId: "200000001",
      originalTransactionId: "100000001",
      productId: "hic.postcard.plus",
      bundleId: "com.headintheclouds.app",
      environment: "Sandbox"
    })
  }, {
    expectedBundleID: "com.headintheclouds.app"
  });

  assert.equal(payload.transactionId, "200000001");
});

test("StoreKit JWS guard skips local mock transactions", () => {
  const payload = validateStoreKitSignedTransactionJWS({
    transaction_id: "local-tx-001",
    product_id: "hic.postcard.plus",
    environment: "local_mock"
  });

  assert.equal(payload, null);
});

test("StoreKit JWS guard rejects placeholder or mismatched transactions", () => {
  assert.throws(
    () => validateStoreKitSignedTransactionJWS({
      transaction_id: "200000001",
      product_id: "hic.postcard.plus",
      environment: "sandbox",
      signed_transaction_jws: "header.payload.signature"
    }),
    ValidationError
  );

  assert.throws(
    () => validateStoreKitSignedTransactionJWS({
      transaction_id: "200000001",
      product_id: "hic.postcard.plus",
      environment: "sandbox",
      signed_transaction_jws: makeStoreKitJWS({
        transactionId: "different",
        productId: "hic.postcard.plus",
        environment: "Sandbox"
      })
    }),
    ValidationError
  );

  assert.throws(
    () => validateStoreKitSignedTransactionJWS({
      transaction_id: "200000001",
      product_id: "hic.postcard.plus",
      environment: "production",
      signed_transaction_jws: makeStoreKitJWS({
        transactionId: "200000001",
        productId: "hic.postcard.plus",
        environment: "Sandbox"
      })
    }),
    ValidationError
  );
});

test("StoreKit JWS guard rejects missing certificate chain", () => {
  assert.throws(
    () => validateStoreKitSignedTransactionJWS({
      transaction_id: "200000001",
      product_id: "hic.postcard.plus",
      environment: "sandbox",
      signed_transaction_jws: makeStoreKitJWS({
        transactionId: "200000001",
        productId: "hic.postcard.plus",
        environment: "Sandbox"
      }, {
        x5c: []
      })
    }),
    ValidationError
  );
});

function makeStoreKitJWS(payload, headerOverrides = {}) {
  const header = {
    alg: "ES256",
    x5c: ["test-certificate"],
    ...headerOverrides
  };
  return [
    base64URLJSON(header),
    base64URLJSON(payload),
    "test-signature"
  ].join(".");
}

function base64URLJSON(value) {
  return Buffer.from(JSON.stringify(value), "utf8")
    .toString("base64")
    .replace(/=/g, "")
    .replace(/\+/g, "-")
    .replace(/\//g, "_");
}
