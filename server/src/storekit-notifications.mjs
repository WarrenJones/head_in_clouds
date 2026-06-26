import { ValidationError } from "./app-store.mjs";

const UUID_PATTERN = /^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;
const ENTITLEMENT_ACTIVE_NOTIFICATION_TYPES = new Set([
  "SUBSCRIBED",
  "DID_RENEW",
  "DID_RECOVER",
  "ONE_TIME_CHARGE"
]);

export function validateAppStoreServerNotification(
  input = {},
  {
    expectedBundleID = process.env.IOS_BUNDLE_ID ?? process.env.APNS_BUNDLE_ID
  } = {}
) {
  const signedPayload = requiredString(input.signedPayload ?? input.signed_payload, "signedPayload");
  const decoded = decodeJWS(signedPayload, "signedPayload");
  assertJWSHeader(decoded.header, "signedPayload");

  const payload = decoded.payload;
  const notificationType = requiredString(payload.notificationType, "notificationType");
  const notificationUUID = requiredString(payload.notificationUUID, "notificationUUID");
  const data = objectOrNull(payload.data);
  const bundleID = data ? requiredString(data.bundleId, "data.bundleId") : null;
  const environment = data ? normalizePayloadEnvironment(data.environment, "data.environment") : null;

  if (expectedBundleID && bundleID && bundleID !== expectedBundleID) {
    throw new ValidationError("signedPayload bundleId does not match configured app");
  }

  const signedTransactionInfo = data?.signedTransactionInfo;
  const transaction = signedTransactionInfo
    ? validateSignedTransactionInfo(signedTransactionInfo, { bundleID, environment })
    : null;

  return {
    notification_type: notificationType,
    subtype: stringOrNull(payload.subtype),
    notification_uuid: notificationUUID,
    version: stringOrNull(payload.version),
    signed_date: typeof payload.signedDate === "number" ? payload.signedDate : null,
    bundle_id: bundleID,
    environment,
    signed_payload: signedPayload,
    signed_transaction_jws: signedTransactionInfo ?? null,
    transaction_payload: transaction
  };
}

export function accountIDFromAppStoreNotification(notification) {
  const token = String(notification?.transaction_payload?.appAccountToken ?? "").trim().toLowerCase();
  return UUID_PATTERN.test(token) ? token : null;
}

export function iapTransactionInputFromAppStoreNotification(notification) {
  const transaction = notification?.transaction_payload;
  if (!transaction || !notification?.signed_transaction_jws || !notification?.environment) {
    return null;
  }
  return {
    transaction_id: requiredString(transaction.transactionId, "transactionId"),
    original_transaction_id: stringOrNull(transaction.originalTransactionId),
    product_id: requiredString(transaction.productId, "productId"),
    environment: notification.environment,
    signed_transaction_jws: notification.signed_transaction_jws
  };
}

export function shouldMaterializeSubscriptionFromNotification(notification) {
  return ENTITLEMENT_ACTIVE_NOTIFICATION_TYPES.has(notification?.notification_type);
}

function validateSignedTransactionInfo(jws, { bundleID, environment } = {}) {
  const decoded = decodeJWS(jws, "signedTransactionInfo");
  assertJWSHeader(decoded.header, "signedTransactionInfo");
  const payload = decoded.payload;

  requiredString(payload.transactionId, "transactionId");
  requiredString(payload.productId, "productId");

  if (bundleID && payload.bundleId !== bundleID) {
    throw new ValidationError("signedTransactionInfo bundleId does not match notification");
  }
  if (environment && normalizePayloadEnvironment(payload.environment, "transaction.environment") !== environment) {
    throw new ValidationError("signedTransactionInfo environment does not match notification");
  }

  return payload;
}

function decodeJWS(jws, fieldName) {
  const segments = String(jws).split(".");
  if (segments.length !== 3 || segments.some((segment) => segment.length === 0)) {
    throw new ValidationError(`${fieldName} is invalid`);
  }
  return {
    header: decodeBase64URLJSON(segments[0], fieldName),
    payload: decodeBase64URLJSON(segments[1], fieldName),
    signature: segments[2]
  };
}

function assertJWSHeader(header, fieldName) {
  if (header.alg !== "ES256") {
    throw new ValidationError(`${fieldName} alg is invalid`);
  }
  if (!Array.isArray(header.x5c) || header.x5c.length === 0) {
    throw new ValidationError(`${fieldName} certificate chain is missing`);
  }
}

function decodeBase64URLJSON(value, fieldName) {
  try {
    const padded = value.padEnd(value.length + ((4 - (value.length % 4)) % 4), "=");
    const json = Buffer.from(padded.replace(/-/g, "+").replace(/_/g, "/"), "base64").toString("utf8");
    return JSON.parse(json);
  } catch {
    throw new ValidationError(`${fieldName} is invalid`);
  }
}

function normalizePayloadEnvironment(value, fieldName) {
  const normalized = String(value ?? "").trim().toLowerCase();
  if (normalized === "sandbox") {
    return "sandbox";
  }
  if (normalized === "production") {
    return "production";
  }
  throw new ValidationError(`${fieldName} is invalid`);
}

function objectOrNull(value) {
  if (!value || typeof value !== "object" || Array.isArray(value)) {
    return null;
  }
  return value;
}

function stringOrNull(value) {
  if (typeof value !== "string") {
    return null;
  }
  const trimmed = value.trim();
  return trimmed.length > 0 ? trimmed : null;
}

function requiredString(value, fieldName) {
  if (typeof value !== "string" || value.trim().length === 0) {
    throw new ValidationError(`${fieldName} is required`);
  }
  return value.trim();
}
