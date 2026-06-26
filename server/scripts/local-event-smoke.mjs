import assert from "node:assert/strict";
import { once } from "node:events";
import { InMemoryAppStore } from "../src/app-store.mjs";
import { InMemoryEventStore } from "../src/event-store.mjs";
import { createServer } from "../src/server.mjs";

const ACCOUNT_ID = "11111111-1111-4111-8111-111111111111";
const ADMIN_TOKEN = "local-event-smoke-admin";
const REQUIRED_EVENTS = [
  "signup_completed",
  "user_returned",
  "core_action_completed",
  "paywall_viewed",
  "checkout_started",
  "subscription_created"
];

const eventStore = new InMemoryEventStore();
const server = createServer({
  appStore: new InMemoryAppStore(),
  store: eventStore,
  adminToken: ADMIN_TOKEN,
  now: () => new Date("2026-05-21T00:00:01.000Z")
});

server.listen(0, "127.0.0.1");
await once(server, "listening");

try {
  const { port } = server.address();
  const baseURL = `http://127.0.0.1:${port}`;

  await postEvent(baseURL, "signup_completed", {
    user_id: ACCOUNT_ID,
    signup_method: "phone",
    utm_source: "direct",
    utm_medium: "direct",
    utm_campaign: "none",
    referrer: "app",
    email: "unsafe@example.com"
  });
  await postEvent(baseURL, "user_returned", {
    user_id: ACCOUNT_ID,
    days_since_signup: "1"
  });
  await postEvent(baseURL, "core_action_completed", {
    user_id: ACCOUNT_ID,
    action_name: "private_card_generated"
  });
  await postEvent(baseURL, "paywall_viewed", {
    user_id: ACCOUNT_ID,
    plan_shown: "postcard_plus",
    source_page: "card_studio"
  });
  await postEvent(baseURL, "checkout_started", {
    user_id: ACCOUNT_ID,
    plan: "postcard_plus",
    price_cny: "12",
    seat_number: "14A"
  });
  await verifyIAPTransaction(baseURL);

  const readback = await readRecentEvents(baseURL);
  for (const eventName of REQUIRED_EVENTS) {
    assert.ok(
      readback.events.some((event) => event.event_name === eventName),
      `${eventName} should be visible in admin event readback`
    );
  }

  const signup = readback.events.find((event) => event.event_name === "signup_completed");
  const checkout = readback.events.find((event) => event.event_name === "checkout_started");
  const subscription = readback.events.find((event) => event.event_name === "subscription_created");
  assert.equal(signup.properties.email, undefined, "signup event should not keep raw email");
  assert.equal(checkout.properties.seat_number, undefined, "checkout event should not keep exact seat");
  assert.equal(subscription.platform, "server", "subscription_created should be server-side");
  assert.equal(subscription.properties.$lib, "server", "subscription_created should mark server library");

  console.log(
    JSON.stringify(
      {
        ok: true,
        checked_events: REQUIRED_EVENTS,
        total_events: readback.events.length
      },
      null,
      2
    )
  );
} finally {
  server.close();
}

async function postEvent(baseURL, eventName, properties) {
  const response = await fetch(`${baseURL}/events`, {
    method: "POST",
    headers: {
      ...authHeaders(),
      "content-type": "application/json"
    },
    body: JSON.stringify({
      event_name: eventName,
      properties,
      app_version: "dev",
      platform: "ios",
      user_id_hash: "user-hash",
      device_id_hash: "device-hash",
      client_time: "2026-05-21T00:00:00.000Z"
    })
  });
  assert.equal(response.status, 202, `${eventName} should be accepted`);
}

async function verifyIAPTransaction(baseURL) {
  const response = await fetch(`${baseURL}/api/iap/transactions/verify`, {
    method: "POST",
    headers: {
      ...authHeaders(),
      "content-type": "application/json"
    },
    body: JSON.stringify({
      transaction_id: "local-smoke-tx-001",
      original_transaction_id: "local-smoke-original-001",
      product_id: "hic.postcard.plus",
      plan: "postcard_plus",
      amount: 12,
      currency: "CNY",
      environment: "local_mock",
      smoke_run_id: "local-event-smoke"
    })
  });
  assert.equal(response.status, 200, "IAP verification should be accepted");
}

async function readRecentEvents(baseURL) {
  const response = await fetch(`${baseURL}/api/admin/events/recent?limit=20`, {
    headers: { authorization: `Bearer ${ADMIN_TOKEN}` }
  });
  assert.equal(response.status, 200, "admin event readback should be authorized");
  return response.json();
}

function authHeaders() {
  return { authorization: `Bearer ${ACCOUNT_ID}` };
}
