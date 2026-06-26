import assert from "node:assert/strict";
import { CONTRACT_EVENT_NAMES } from "./contract-event-smoke.mjs";

const baseURL = cleanURL(process.env.HIC_STAGING_BASE_URL ?? process.env.HIC_API_BASE_URL ?? "http://127.0.0.1:8787");
const adminToken = process.env.HIC_STAGING_ADMIN_TOKEN ?? process.env.HIC_ADMIN_TOKEN;
const smokeRunID = process.env.HIC_SMOKE_RUN_ID;
const explicitExpectedEvents = (process.env.HIC_EXPECTED_EVENTS ?? "")
  .split(",")
  .map((eventName) => eventName.trim())
  .filter(Boolean);
const expectedEvents = explicitExpectedEvents.length > 0
  ? explicitExpectedEvents
  : process.env.HIC_EVENT_CONTRACT === "prd" ? CONTRACT_EVENT_NAMES : [];

if (!adminToken) {
  throw new Error("Set HIC_STAGING_ADMIN_TOKEN or HIC_ADMIN_TOKEN before running staging event summary.");
}

const params = new URLSearchParams();
if (smokeRunID) {
  params.set("smoke_run_id", smokeRunID);
}
if (expectedEvents.length > 0) {
  params.set("event_names", expectedEvents.join(","));
}

const response = await fetch(`${baseURL}/api/admin/events/summary?${params}`, {
  headers: { authorization: `Bearer ${adminToken}` }
});
await assertStatus(response, 200, "admin event summary should be authorized");
const body = await response.json();

if (expectedEvents.length > 0) {
  assert.deepEqual(body.summary.missing_event_names, [], "expected events should all be present");
}

console.log(JSON.stringify({
  ok: true,
  base_url: baseURL,
  smoke_run_id: smokeRunID ?? null,
  total_events: body.summary.total_events,
  missing_event_names: body.summary.missing_event_names,
  first_received_at: body.summary.first_received_at,
  last_received_at: body.summary.last_received_at,
  events_by_name: body.summary.events_by_name
}, null, 2));

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
