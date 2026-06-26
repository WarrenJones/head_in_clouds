import assert from "node:assert/strict";
import crypto from "node:crypto";
import { once } from "node:events";
import { InMemoryAppStore } from "../src/app-store.mjs";
import { InMemoryEventStore } from "../src/event-store.mjs";
import { createServer } from "../src/server.mjs";

const DEFAULT_ACCOUNT_ID = "44444444-4444-4444-8444-444444444444";
const LOCAL_ADMIN_TOKEN = "local-contract-smoke-admin";
const localMode = process.env.HIC_CONTRACT_SMOKE_LOCAL === "1";
const accountID = process.env.HIC_STAGING_ACCOUNT_ID ?? DEFAULT_ACCOUNT_ID;
const smokeRunID = process.env.HIC_SMOKE_RUN_ID ?? `contract-smoke-${Date.now()}-${crypto.randomUUID().slice(0, 8)}`;
const transactionID = `contract-iap-${smokeRunID}`;

async function main() {
  const runtime = localMode ? await startLocalServer() : stagingRuntime();

  try {
    for (const eventCase of EVENT_CASES) {
      await postEvent(runtime.baseURL, eventCase);
    }
    await verifyIAPTransaction(runtime.baseURL);

    const readback = await readRecentEvents(runtime.baseURL, runtime.adminToken);
    const evidence = {};

    for (const eventCase of EVENT_CASES) {
      const event = findSmokeEvent(readback.events, eventCase.name);
      assert.ok(event, `${eventCase.name} should be visible in admin event readback for ${smokeRunID}`);
      assertRequiredProperties(event, eventCase.required ?? []);
      assertNoSensitiveProperties(event);
      evidence[eventCase.name] = event.id;
    }

    const subscriptionEvent = readback.events.find((event) => {
      return event.event_name === "subscription_created" && event.properties?.transaction_id === transactionID;
    });
    assert.ok(subscriptionEvent, `subscription_created should be visible for transaction ${transactionID}`);
    assert.equal(subscriptionEvent.platform, "server", "subscription_created should be server-side");
    assert.equal(subscriptionEvent.properties.$lib, "server", "subscription_created should mark server library");
    assertNoSensitiveProperties(subscriptionEvent);
    evidence.subscription_created = subscriptionEvent.id;

    console.log(JSON.stringify({
      ok: true,
      mode: localMode ? "local" : "staging",
      base_url: runtime.baseURL,
      smoke_run_id: smokeRunID,
      checked_events: [...EVENT_CASES.map((eventCase) => eventCase.name), "subscription_created"],
      checked_event_count: EVENT_CASES.length + 1,
      evidence,
      total_readback_events: readback.events.length
    }, null, 2));
  } finally {
    runtime.server?.close();
  }
}

async function startLocalServer() {
  const server = createServer({
    appStore: new InMemoryAppStore(),
    store: new InMemoryEventStore(),
    adminToken: LOCAL_ADMIN_TOKEN,
    now: () => new Date("2026-05-21T00:00:01.000Z")
  });
  server.listen(0, "127.0.0.1");
  await once(server, "listening");
  const { port } = server.address();
  return {
    baseURL: `http://127.0.0.1:${port}`,
    adminToken: LOCAL_ADMIN_TOKEN,
    server
  };
}

function stagingRuntime() {
  const baseURL = cleanURL(process.env.HIC_STAGING_BASE_URL ?? process.env.HIC_API_BASE_URL ?? "http://127.0.0.1:8787");
  const adminToken = process.env.HIC_STAGING_ADMIN_TOKEN ?? process.env.HIC_ADMIN_TOKEN;
  if (!adminToken) {
    throw new Error("Set HIC_STAGING_ADMIN_TOKEN or HIC_ADMIN_TOKEN before running contract event smoke.");
  }
  return { baseURL, adminToken };
}

async function postEvent(baseURL, eventCase) {
  const response = await fetch(`${baseURL}/events`, {
    method: "POST",
    headers: {
      ...authHeaders(),
      "content-type": "application/json"
    },
    body: JSON.stringify({
      event_name: eventCase.name,
      properties: {
        smoke_run_id: smokeRunID,
        ...eventCase.properties
      },
      app_version: "contract-smoke",
      platform: eventCase.platform ?? "ios",
      user_id_hash: `contract-user-${smokeRunID}`,
      device_id_hash: `contract-device-${smokeRunID}`,
      client_time: new Date().toISOString()
    })
  });
  await assertStatus(response, 202, `${eventCase.name} should be accepted`);
}

async function verifyIAPTransaction(baseURL) {
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

async function readRecentEvents(baseURL, adminToken) {
  const response = await fetch(`${baseURL}/api/admin/events/recent?limit=500`, {
    headers: { authorization: `Bearer ${adminToken}` }
  });
  await assertStatus(response, 200, "admin event readback should be authorized");
  return response.json();
}

function findSmokeEvent(events, eventName) {
  return events.find((event) => {
    return event.event_name === eventName && event.properties?.smoke_run_id === smokeRunID;
  });
}

function assertRequiredProperties(event, requiredKeys) {
  for (const key of requiredKeys) {
    assert.notEqual(event.properties?.[key], undefined, `${event.event_name}.${key} should be present`);
  }
}

function assertNoSensitiveProperties(event) {
  const serializedProperties = JSON.stringify(event.properties ?? {});
  assert.doesNotMatch(serializedProperties, /unsafe@example\.com/i, `${event.event_name} should not keep raw email`);
  assert.doesNotMatch(serializedProperties, /\b14A\b/i, `${event.event_name} should not keep exact seat`);
  for (const forbiddenKey of ["email", "phone_e164", "id_card", "passport_no", "ticket_no", "api_token", "seat_number", "ocr_raw_text"]) {
    assert.equal(event.properties?.[forbiddenKey], undefined, `${event.event_name}.${forbiddenKey} should be stripped`);
  }
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

export const EVENT_CASES = [
  eventCase("signup_completed", {
    user_id: accountID,
    signup_method: "phone",
    method: "phone",
    utm_source: "direct",
    utm_medium: "direct",
    utm_campaign: "none",
    referrer: "app",
    email: "unsafe@example.com"
  }, ["user_id", "signup_method", "utm_source"]),
  eventCase("user_returned", { user_id: accountID, days_since_signup: "1" }, ["user_id", "days_since_signup"]),
  eventCase("core_action_completed", { user_id: accountID, action_name: "private_card_generated" }, ["user_id", "action_name"]),
  eventCase("paywall_viewed", { user_id: accountID, plan_shown: "postcard_plus", source_page: "card_studio" }, ["user_id", "plan_shown", "source_page"]),
  eventCase("checkout_started", { user_id: accountID, plan: "postcard_plus", price_cny: "12", seat_number: "14A" }, ["user_id", "plan", "price_cny"]),
  eventCase("app_first_launched", { device_id: "device-contract", app_version: "contract-smoke" }, ["device_id", "app_version"]),
  eventCase("onboarding_step_viewed", { step: "00a" }, ["step"]),
  eventCase("onboarding_completed", { duration_ms: "12000", guest: "true" }, ["duration_ms", "guest"]),
  eventCase("permission_granted", { type: "notification", source_screen: "15" }, ["type", "source_screen"]),
  eventCase("permission_denied", { type: "camera", source_screen: "02" }, ["type", "source_screen"]),
  eventCase("guest_mode_chosen", { device_id: "device-contract", source: "00d" }, ["device_id", "source"]),
  eventCase("01a_landing_viewed", { is_returning: "false", post_count: "0" }, ["is_returning", "post_count"]),
  eventCase("01b_landing_viewed", { is_returning: "true", post_count: "2" }, ["is_returning", "post_count"]),
  eventCase("landing_viewed", { is_returning: "false", post_count: "0" }, ["is_returning", "post_count"]),
  eventCase("compose_started", { source: "opening" }, ["source"]),
  eventCase("compose_mode_selected", { mode: "one_line" }, ["mode"]),
  eventCase("template_prompt_selected", { template_id: "flying_to_because" }, ["template_id"]),
  eventCase("voice_recording_started", { source: "compose" }, ["source"]),
  eventCase("voice_transcribed", { success: "true", duration_ms: "3200" }, ["success", "duration_ms"]),
  eventCase("draft_resumed", { draft_age_ms: "60000", source: "cold_start" }, ["draft_age_ms", "source"]),
  eventCase("offline_draft_saved", { content_length: "12", has_flight_context: "false" }, ["content_length", "has_flight_context"]),
  eventCase("private_card_generated", { template_id: "boarding_postcard", has_flight_context: "false", verified: "false" }, ["template_id", "verified"]),
  eventCase("cloud_card_rendered", { template_id: "boarding_postcard", offline: "false" }, ["template_id", "offline"]),
  eventCase("headline_quote_edited", { auto_generated_before: "true", length: "11" }, ["auto_generated_before", "length"]),
  eventCase("private_card_saved", { template_id: "boarding_postcard", channel: "save_image" }, ["template_id", "channel"]),
  eventCase("cloud_card_saved", { template_id: "boarding_postcard", channel: "save_image" }, ["template_id", "channel"]),
  eventCase("private_card_shared", { channel: "wechat_moments", template_id: "boarding_postcard" }, ["channel", "template_id"]),
  eventCase("card_shared", { channel: "copy_link", template_id: "boarding_postcard" }, ["channel", "template_id"]),
  eventCase("offline_sync_started", { queue_id: "queue-contract" }, ["queue_id"]),
  eventCase("offline_sync_completed", { queue_id: "queue-contract" }, ["queue_id"]),
  eventCase("offline_sync_failed", { queue_id: "queue-contract", reason: "network_timeout" }, ["queue_id", "reason"]),
  eventCase("flight_intent_created", { source: "15", flight_number_hash: "flight-hash", reminder_offset_minutes: "30" }, ["source", "flight_number_hash"]),
  eventCase("flight_verification_started", { source: "02", method: "ticket_screenshot" }, ["source", "method"]),
  eventCase("capture_started", { proof_source_type: "ticket_screenshot", upload_method: "photo_library" }, ["proof_source_type", "upload_method"]),
  eventCase("capture_completed", { proof_source_type: "ticket_screenshot", upload_method: "photo_library" }, ["proof_source_type", "upload_method"]),
  eventCase("ocr_failed", { proof_source_type: "ticket_screenshot", upload_method: "photo_library", reason: "low_confidence", ocr_raw_text: "unsafe raw" }, ["reason"]),
  eventCase("flight_confirmed", { method: "manual", success: "true", ocr_corrected: "false" }, ["method", "success"]),
  eventCase("flight_proof_created", { method: "manual", success: "true", ocr_corrected: "false" }, ["method", "success"]),
  eventCase("flight_verification_completed", { method: "manual", success: "true", ocr_corrected: "false" }, ["method", "success"]),
  eventCase("same_flight_publish_started", { verified: "true" }, ["verified"]),
  eventCase("same_flight_publish_blocked", { reason: "unverified" }, ["reason"]),
  eventCase("same_flight_publish_completed", { flight_space_id: "flight-space-contract", template_id: "boarding_postcard" }, ["flight_space_id", "template_id"]),
  eventCase("flight_space_viewed", { source: "same_flight_publish", verified: "true" }, ["source", "verified"]),
  eventCase("post_detail_viewed", { source: "same_flight", can_comment: "true" }, ["source", "can_comment"]),
  eventCase("comment_written", { is_same_flight: "true", comment_length: "12" }, ["is_same_flight", "comment_length"]),
  eventCase("boarding_reminder_scheduled", { flight_number_hash: "flight-hash", reminder_at: "2026-05-21T00:30:00.000Z" }, ["flight_number_hash", "reminder_at"]),
  eventCase("boarding_reminder_sent", { flight_number_hash: "flight-hash", notification_job_id: "job-contract", "$lib": "server" }, ["flight_number_hash", "$lib"], "server"),
  eventCase("boarding_reminder_opened", { flight_number_hash: "flight-hash", source: "local_notification" }, ["flight_number_hash"]),
  eventCase("share_landing_opened", { source: "qr", flight_number_hash: "flight-hash", route: "SHA-CTU" }, ["source", "flight_number_hash", "route"]),
  eventCase("share_landing_same_flight_tapped", { installed_app: "true", route: "SHA-CTU" }, ["installed_app", "route"]),
  eventCase("share_landing_reminder_started", { flight_number_hash: "flight-hash" }, ["flight_number_hash"]),
  eventCase("same_flight_note_notification_sent", { flight_number_hash: "flight-hash", hours_after_post: "24", "$lib": "server" }, ["flight_number_hash", "hours_after_post", "$lib"], "server"),
  eventCase("same_flight_note_notification_opened", { flight_number_hash: "flight-hash", hours_after_post: "24" }, ["flight_number_hash", "hours_after_post"]),
  eventCase("same_flight_notes_viewed", { source: "notification" }, ["source"]),
  eventCase("account_upgrade_prompt_shown", { variant: "soft", trigger: "same_flight_post_count" }, ["variant", "trigger"]),
  eventCase("account_upgrade_prompt_dismissed", { variant: "soft", trigger: "same_flight_post_count" }, ["variant", "trigger"]),
  eventCase("account_upgrade_started", { method: "phone", source: "08b", merged_with_existing: "false" }, ["method", "source"]),
  eventCase("account_upgrade_completed", { method: "phone", source: "08b", merged_with_existing: "false", merged_post_count: "0" }, ["method", "merged_with_existing"]),
  eventCase("account_settings_viewed", { account_type: "guest" }, ["account_type"]),
  eventCase("sign_in_started", { method: "phone", source: "14" }, ["method", "source"]),
  eventCase("sign_in_succeeded", { method: "phone", source: "14" }, ["method", "source"]),
  eventCase("sign_in_failed", { method: "phone", source: "14", reason: "invalid_code" }, ["method", "reason"]),
  eventCase("sms_code_sent", { phone_country_code: "+86", source: "14" }, ["phone_country_code"]),
  eventCase("sms_code_verified", { phone_country_code: "+86", source: "14" }, ["phone_country_code"]),
  eventCase("sms_code_resend", { phone_country_code: "+86", source: "14" }, ["phone_country_code"]),
  eventCase("wechat_auth_initiated", { source: "14", status: "started" }, ["source"]),
  eventCase("wechat_auth_callback_received", { source: "14", status: "success" }, ["source", "status"]),
  eventCase("sign_out_completed", { method: "phone" }, ["method"]),
  eventCase("account_deletion_requested", { reauth_method: "phone" }, ["reauth_method"]),
  eventCase("account_deletion_confirmed", { reauth_method: "phone" }, ["reauth_method"]),
  eventCase("account_deletion_completed", { reauth_method: "phone" }, ["reauth_method"]),
  eventCase("discovery_viewed", { tab_name: "same_route" }, ["tab_name"]),
  eventCase("report_submitted", { target_type: "post", reason: "spam" }, ["target_type", "reason"]),
  eventCase("block_user", { target_type: "account", reason: "harassment" }, ["target_type", "reason"])
];

function eventCase(name, properties, required = [], platform = "ios") {
  return { name, properties, required, platform };
}

export const CONTRACT_EVENT_NAMES = [...EVENT_CASES.map((eventCase) => eventCase.name), "subscription_created"];

if (import.meta.url === `file://${process.argv[1]}`) {
  await main();
}
