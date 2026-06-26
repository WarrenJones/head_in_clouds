import { ValidationError } from "./app-store.mjs";

export function validateStoreKitSignedTransactionJWS(
  input = {},
  {
    expectedBundleID = process.env.IOS_BUNDLE_ID ?? process.env.APNS_BUNDLE_ID
  } = {}
) {
  if (input.environment === "local_mock") {
    return null;
  }

  const jws = requiredString(input.signed_transaction_jws, "signed_transaction_jws");
  const decoded = decodeJWS(jws);
  assertStoreKitHeader(decoded.header);
  assertStoreKitPayload(decoded.payload, input, expectedBundleID);
  return decoded.payload;
}

function decodeJWS(jws) {
  const segments = jws.split(".");
  if (segments.length !== 3 || segments.some((segment) => segment.length === 0)) {
    throw new ValidationError("signed_transaction_jws is invalid");
  }

  return {
    header: decodeBase64URLJSON(segments[0]),
    payload: decodeBase64URLJSON(segments[1]),
    signature: segments[2]
  };
}

function assertStoreKitHeader(header) {
  if (header.alg !== "ES256") {
    throw new ValidationError("signed_transaction_jws alg is invalid");
  }
  if (!Array.isArray(header.x5c) || header.x5c.length === 0) {
    throw new ValidationError("signed_transaction_jws certificate chain is missing");
  }
}

function assertStoreKitPayload(payload, input, expectedBundleID) {
  assertOptionalMatch(payload.transactionId, input.transaction_id, "transactionId");
  if (input.original_transaction_id) {
    assertOptionalMatch(payload.originalTransactionId, input.original_transaction_id, "originalTransactionId");
  }
  assertOptionalMatch(payload.productId, input.product_id, "productId");

  if (expectedBundleID) {
    assertOptionalMatch(payload.bundleId, expectedBundleID, "bundleId");
  }

  const payloadEnvironment = normalizePayloadEnvironment(payload.environment);
  if (payloadEnvironment !== input.environment) {
    throw new ValidationError("signed_transaction_jws environment does not match request");
  }
}

function assertOptionalMatch(actual, expected, fieldName) {
  if (actual === undefined || actual === null || actual === "") {
    throw new ValidationError(`signed_transaction_jws ${fieldName} is missing`);
  }
  if (String(actual).trim() !== String(expected).trim()) {
    throw new ValidationError(`signed_transaction_jws ${fieldName} does not match request`);
  }
}

function normalizePayloadEnvironment(value) {
  const normalized = String(value ?? "").trim().toLowerCase();
  if (normalized === "sandbox") {
    return "sandbox";
  }
  if (normalized === "production") {
    return "production";
  }
  throw new ValidationError("signed_transaction_jws environment is invalid");
}

function decodeBase64URLJSON(value) {
  try {
    const padded = value.padEnd(value.length + ((4 - (value.length % 4)) % 4), "=");
    const json = Buffer.from(padded.replace(/-/g, "+").replace(/_/g, "/"), "base64").toString("utf8");
    return JSON.parse(json);
  } catch {
    throw new ValidationError("signed_transaction_jws is invalid");
  }
}

function requiredString(value, fieldName) {
  if (typeof value !== "string" || value.trim().length === 0) {
    throw new ValidationError(`${fieldName} is required`);
  }
  return value.trim();
}
