import assert from "node:assert/strict";
import crypto from "node:crypto";

const DEFAULT_ACCOUNT_ID = "22222222-2222-4222-8222-222222222222";
const REQUIRED_EVENTS = [
  "signup_completed",
  "user_returned",
  "core_action_completed",
  "paywall_viewed",
  "checkout_started",
  "subscription_created"
];

const baseURL = cleanURL(process.env.HIC_STAGING_BASE_URL ?? process.env.HIC_API_BASE_URL ?? "http://127.0.0.1:8787");
const adminToken = process.env.HIC_STAGING_ADMIN_TOKEN ?? process.env.HIC_ADMIN_TOKEN;
const accountID = process.env.HIC_STAGING_ACCOUNT_ID ?? DEFAULT_ACCOUNT_ID;
const smokeRunID = process.env.HIC_SMOKE_RUN_ID ?? `staging-smoke-${Date.now()}-${crypto.randomUUID().slice(0, 8)}`;
const transactionID = `iap-${smokeRunID}`;

if (!adminToken) {
  throw new Error("Set HIC_STAGING_ADMIN_TOKEN or HIC_ADMIN_TOKEN before running staging event smoke.");
}

await postEvent("signup_completed", {
  smoke_run_id: smokeRunID,
  user_id: accountID,
  signup_method: "phone",
  utm_source: "direct",
  utm_medium: "direct",
  utm_campaign: "none",
  referrer: "app",
  email: "unsafe@example.com"
});
await postEvent("user_returned", {
  smoke_run_id: smokeRunID,
  user_id: accountID,
  days_since_signup: "1"
});
await postEvent("core_action_completed", {
  smoke_run_id: smokeRunID,
  user_id: accountID,
  action_name: "private_card_generated"
});
await postEvent("paywall_viewed", {
  smoke_run_id: smokeRunID,
  user_id: accountID,
  plan_shown: "postcard_plus",
  source_page: "card_studio"
});
await postEvent("checkout_started", {
  smoke_run_id: smokeRunID,
  user_id: accountID,
  plan: "postcard_plus",
  price_cny: "12",
  seat_number: "14A"
});
await verifyIAPTransaction();

const readback = await readRecentEvents();
const evidence = {};
for (const eventName of REQUIRED_EVENTS) {
  const event = findSmokeEvent(readback.events, eventName);
  assert.ok(event, `${eventName} should be visible in admin event readback for ${smokeRunID}`);
  evidence[eventName] = event.id;
}

const signup = findSmokeEvent(readback.events, "signup_completed");
const checkout = findSmokeEvent(readback.events, "checkout_started");
const subscription = findSmokeEvent(readback.events, "subscription_created");
assert.equal(signup.properties.email, undefined, "signup event should not keep raw email");
assert.equal(checkout.properties.seat_number, undefined, "checkout event should not keep exact seat");
assert.equal(subscription.platform, "server", "subscription_created should be server-side");
assert.equal(subscription.properties.$lib, "server", "subscription_created should mark server library");
assert.equal(subscription.properties.transaction_id, transactionID, "subscription_created should be tied to this smoke run");

console.log(JSON.stringify({
  ok: true,
  base_url: baseURL,
  smoke_run_id: smokeRunID,
  checked_events: REQUIRED_EVENTS,
  evidence,
  total_readback_events: readback.events.length
}, null, 2));

async function postEvent(eventName, properties) {
  const response = await fetch(`${baseURL}/events`, {
    method: "POST",
    headers: {
      ...authHeaders(),
      "content-type": "application/json"
    },
    body: JSON.stringify({
      event_name: eventName,
      properties,
      app_version: "staging-smoke",
      platform: "ios",
      user_id_hash: `smoke-user-${smokeRunID}`,
      device_id_hash: `smoke-device-${smokeRunID}`,
      client_time: new Date().toISOString()
    })
  });
  assert.equal(response.status, 202, `${eventName} should be accepted`);
}

async function verifyIAPTransaction() {
  const response = await fetch(`${baseURL}/api/iap/transactions/verify`, {
    method: "POST",
    headers: {
      ...authHeaders(),
      "content-type": "application/json"
    },
    body: JSON.stringify({
      transaction_id: transactionID,
      original_transaction_id: `original-${smokeRunID}`,
      product_id: "hic.postcard.plus",
      plan: "postcard_plus",
      amount: 12,
      currency: "CNY",
      environment: "local_mock",
      smoke_run_id: smokeRunID
    })
  });
  await assertStatus(response, 200, "IAP verification should be accepted");
}

async function readRecentEvents() {
  const response = await fetch(`${baseURL}/api/admin/events/recent?limit=100`, {
    headers: { authorization: `Bearer ${adminToken}` }
  });
  assert.equal(response.status, 200, "admin event readback should be authorized");
  return response.json();
}

function findSmokeEvent(events, eventName) {
  return events.find((event) => {
    if (event.event_name !== eventName) {
      return false;
    }
    if (eventName === "subscription_created") {
      return event.properties?.transaction_id === transactionID;
    }
    return event.properties?.smoke_run_id === smokeRunID;
  });
}

function authHeaders() {
  return { authorization: `Bearer ${accountID}` };
}

async function assertStatus(response, expectedStatus, message) {
  if (response.status === expectedStatus) {
    return;
  }
  const body = await response.text();
  assert.equal(response.status, expectedStatus, `${message}: ${body}`);
}

function cleanURL(rawValue) {
  return rawValue.replace(/\/+$/, "");
}
