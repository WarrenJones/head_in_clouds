import assert from "node:assert/strict";
import crypto from "node:crypto";

const DEFAULT_ACCOUNT_ID = "55555555-5555-4555-8555-555555555555";

const baseURL = cleanURL(process.env.HIC_STAGING_BASE_URL ?? process.env.HIC_API_BASE_URL ?? "http://127.0.0.1:8787");
const adminToken = process.env.HIC_STAGING_ADMIN_TOKEN ?? process.env.HIC_ADMIN_TOKEN;
const accountID = process.env.HIC_STAGING_ACCOUNT_ID ?? DEFAULT_ACCOUNT_ID;
const bundleID = process.env.IOS_BUNDLE_ID ?? process.env.APNS_BUNDLE_ID ?? "com.headintheclouds.app";
const smokeRunID = process.env.HIC_SMOKE_RUN_ID ?? `assn-smoke-${Date.now()}-${crypto.randomUUID().slice(0, 8)}`;
const transactionID = `assn-tx-${smokeRunID}`;
const originalTransactionID = `assn-original-${smokeRunID}`;
const notificationUUID = smokeRunID;

if (!adminToken) {
  throw new Error("Set HIC_STAGING_ADMIN_TOKEN or HIC_ADMIN_TOKEN before running App Store notification smoke.");
}

const signedTransactionInfo = makeStoreKitJWS({
  transactionId: transactionID,
  originalTransactionId: originalTransactionID,
  productId: "hic.postcard.plus",
  bundleId: bundleID,
  environment: "Sandbox",
  appAccountToken: accountID
});
const signedPayload = makeStoreKitJWS({
  notificationType: "SUBSCRIBED",
  subtype: "INITIAL_BUY",
  notificationUUID,
  version: "2.0",
  signedDate: Date.now(),
  data: {
    bundleId: bundleID,
    environment: "Sandbox",
    signedTransactionInfo
  }
});

const notificationResponse = await fetch(`${baseURL}/api/iap/app-store/notifications`, {
  method: "POST",
  headers: { "content-type": "application/json" },
  body: JSON.stringify({ signedPayload })
});
await assertStatus(notificationResponse, 200, "App Store notification should be accepted");
const notificationBody = await notificationResponse.json();

assert.equal(notificationBody.notification.notification_type, "SUBSCRIBED");
assert.equal(notificationBody.notification.account_linked, true);
assert.equal(notificationBody.subscription_created, true);
assert.equal(notificationBody.subscription.transaction_id, transactionID);
assert.equal(notificationBody.subscription.plan, "postcard_plus");
assert.equal(notificationBody.subscription.amount, 12);
assert.equal(notificationBody.subscription.currency, "CNY");

const readback = await readRecentEvents();
const notificationEvent = readback.events.find((event) => {
  return event.event_name === "app_store_server_notification_received" &&
    event.properties?.notification_uuid === notificationUUID;
});
const subscriptionEvent = readback.events.find((event) => {
  return event.event_name === "subscription_created" &&
    event.properties?.transaction_id === transactionID;
});

assert.ok(notificationEvent, `app_store_server_notification_received should be visible for ${notificationUUID}`);
assert.ok(subscriptionEvent, `subscription_created should be visible for ${transactionID}`);
assert.equal(notificationEvent.platform, "server");
assert.equal(subscriptionEvent.platform, "server");
assert.equal(notificationEvent.properties.account_linked, "true");
assert.equal(subscriptionEvent.properties.source, "app_store_server_notification");
assert.equal(subscriptionEvent.properties.$lib, "server");

console.log(JSON.stringify({
  ok: true,
  base_url: baseURL,
  smoke_run_id: smokeRunID,
  notification_uuid: notificationUUID,
  transaction_id: transactionID,
  evidence: {
    app_store_server_notification_received: notificationEvent.id,
    subscription_created: subscriptionEvent.id
  },
  total_readback_events: readback.events.length
}, null, 2));

async function readRecentEvents() {
  const response = await fetch(`${baseURL}/api/admin/events/recent?limit=100`, {
    headers: { authorization: `Bearer ${adminToken}` }
  });
  await assertStatus(response, 200, "admin event readback should be authorized");
  return response.json();
}

async function assertStatus(response, expectedStatus, message) {
  if (response.status === expectedStatus) {
    return;
  }
  const body = await response.text();
  assert.equal(response.status, expectedStatus, `${message}: ${body}`);
}

function makeStoreKitJWS(payload, headerOverrides = {}) {
  const header = {
    alg: "ES256",
    x5c: ["test-certificate"],
    ...headerOverrides
  };
  return [
    base64URLJSON(header),
    base64URLJSON(payload),
    "signature"
  ].join(".");
}

function base64URLJSON(value) {
  return Buffer.from(JSON.stringify(value))
    .toString("base64url");
}

function cleanURL(rawValue) {
  return rawValue.replace(/\/+$/, "");
}
