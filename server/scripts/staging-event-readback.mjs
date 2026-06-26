import assert from "node:assert/strict";

const baseURL = cleanURL(process.env.HIC_STAGING_BASE_URL ?? process.env.HIC_API_BASE_URL ?? "http://127.0.0.1:8787");
const adminToken = process.env.HIC_STAGING_ADMIN_TOKEN ?? process.env.HIC_ADMIN_TOKEN;
const smokeRunID = process.env.HIC_SMOKE_RUN_ID;
const expectedEvents = (process.env.HIC_EXPECTED_EVENTS ?? "")
  .split(",")
  .map((eventName) => eventName.trim())
  .filter(Boolean);

if (!adminToken) {
  throw new Error("Set HIC_STAGING_ADMIN_TOKEN or HIC_ADMIN_TOKEN before running staging event readback.");
}

const readback = await readRecentEvents();
const events = smokeRunID
  ? readback.events.filter((event) => event.properties?.smoke_run_id === smokeRunID)
  : readback.events;

for (const eventName of expectedEvents) {
  assert.ok(
    events.some((event) => event.event_name === eventName),
    `${eventName} should be visible in admin event readback${smokeRunID ? ` for ${smokeRunID}` : ""}`
  );
}

console.log(JSON.stringify({
  ok: true,
  base_url: baseURL,
  smoke_run_id: smokeRunID ?? null,
  expected_events: expectedEvents,
  events: events.map((event) => ({
    id: event.id,
    event_name: event.event_name,
    app_version: event.app_version,
    platform: event.platform,
    received_at: event.received_at
  })),
  total_events: events.length
}, null, 2));

async function readRecentEvents() {
  const response = await fetch(`${baseURL}/api/admin/events/recent?limit=200`, {
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

function cleanURL(rawValue) {
  return rawValue.replace(/\/+$/, "");
}
