import assert from "node:assert/strict";
import test from "node:test";
import { InMemoryAppStore } from "../src/app-store.mjs";
import { APNSPushProvider } from "../src/apns-provider.mjs";
import { createPushProvider } from "../src/dispatch-notifications.mjs";
import { InMemoryEventStore } from "../src/event-store.mjs";
import { dispatchDueNotifications, InMemoryPushProvider } from "../src/notification-dispatcher.mjs";

const ACCOUNT_A = "11111111-1111-4111-8111-111111111111";

test("createPushProvider uses APNs by default and memory only when explicit", () => {
  assert.ok(createPushProvider({}) instanceof APNSPushProvider);
  assert.ok(createPushProvider({ HIC_PUSH_PROVIDER: "memory" }) instanceof InMemoryPushProvider);
});

test("dispatchDueNotifications sends only due pending jobs", async () => {
  const appStore = new InMemoryAppStore();
  const eventStore = new InMemoryEventStore();
  const context = appStore.createFlightContext(ACCOUNT_A, {
    flight_number_hash: "flight-hash",
    route: "SHA -> CTU"
  });
  const due = appStore.createBoardingReminderJob(ACCOUNT_A, {
    flight_context_id: context.id,
    scheduled_for: "2026-05-21T00:00:00.000Z"
  });
  const future = appStore.createBoardingReminderJob(ACCOUNT_A, {
    flight_context_id: context.id,
    scheduled_for: "2026-05-21T01:00:00.000Z"
  });
  appStore.registerPushToken(ACCOUNT_A, {
    platform: "ios",
    token: "apns-token-a"
  });
  const pushProvider = new InMemoryPushProvider();

  const results = await dispatchDueNotifications({
    appStore,
    pushProvider,
    eventStore,
    now: () => new Date("2026-05-21T00:30:00.000Z")
  });

  assert.equal(results.length, 1);
  assert.equal(results[0].job.id, due.id);
  assert.equal(results[0].status, "sent");
  assert.equal(pushProvider.sent.length, 1);
  assert.equal(pushProvider.sent[0].push_tokens[0].token, "apns-token-a");
  assert.equal(appStore.notificationJobs.get(due.id).status, "sent");
  assert.equal(appStore.notificationJobs.get(future.id).status, "pending");
  assert.equal(eventStore.events.length, 1);
  assert.equal(eventStore.events[0].event_name, "boarding_reminder_sent");
  assert.equal(eventStore.events[0].platform, "server");
  assert.equal(eventStore.events[0].properties.flight_number_hash, "flight-hash");
  assert.equal(eventStore.events[0].properties.$lib, "server");
});

test("dispatchDueNotifications records same-flight notification sent events", async () => {
  const appStore = new InMemoryAppStore();
  const eventStore = new InMemoryEventStore();
  const sourceContext = appStore.createFlightContext(ACCOUNT_A, {
    flight_number_hash: "flight-hash",
    route: "SHA -> CTU",
    departure_date: "2026-05-21",
    verification_status: "verified"
  });
  const targetAccount = "22222222-2222-4222-8222-222222222222";
  appStore.createFlightContext(targetAccount, {
    flight_number_hash: "flight-hash",
    route: "SHA -> CTU",
    departure_date: "2026-05-21",
    verification_status: "verified"
  });
  const proof = appStore.createFlightProof(ACCOUNT_A, {
    flight_context_id: sourceContext.id,
    method: "manual",
      source_image_hash: "hash"
    });
  const post = appStore.createPost(ACCOUNT_A, {
    flight_context_id: sourceContext.id,
    flight_proof_id: proof.id,
    publish_scope: "same_flight",
    text: "这次终于不是出差。"
  }, new Date("2026-05-21T00:00:00.000Z"));
  appStore.registerPushToken(targetAccount, {
    platform: "ios",
    token: "apns-token-b"
  });

  const results = await dispatchDueNotifications({
    appStore,
    pushProvider: new InMemoryPushProvider(),
    eventStore,
    now: () => new Date("2026-05-21T02:30:00.000Z")
  });

  assert.equal(post.publish_scope, "same_flight");
  assert.equal(results.length, 1);
  assert.equal(results[0].job.kind, "same_flight_new_post");
  assert.equal(eventStore.events.length, 1);
  assert.equal(eventStore.events[0].event_name, "same_flight_note_notification_sent");
  assert.equal(eventStore.events[0].properties.flight_number_hash, "flight-hash");
  assert.equal(eventStore.events[0].properties.hours_after_post, 2);
  assert.equal(eventStore.events[0].properties.$lib, "server");
});

test("dispatchDueNotifications marks provider failures without dropping the job", async () => {
  const appStore = new InMemoryAppStore();
  const context = appStore.createFlightContext(ACCOUNT_A, {
    flight_number_hash: "flight-hash",
    route: "SHA -> CTU"
  });
  const due = appStore.createBoardingReminderJob(ACCOUNT_A, {
    flight_context_id: context.id,
    scheduled_for: "2026-05-21T00:00:00.000Z"
  });
  appStore.registerPushToken(ACCOUNT_A, {
    platform: "ios",
    token: "apns-token-a"
  });

  const results = await dispatchDueNotifications({
    appStore,
    pushProvider: {
      async send() {
        throw new Error("apns_unavailable");
      }
    },
    now: () => new Date("2026-05-21T00:30:00.000Z")
  });

  const failed = appStore.notificationJobs.get(due.id);
  assert.equal(results.length, 1);
  assert.equal(results[0].status, "failed");
  assert.equal(failed.status, "failed");
  assert.equal(failed.payload.last_error, "apns_unavailable");
});

test("dispatchDueNotifications fails due jobs without a registered push token", async () => {
  const appStore = new InMemoryAppStore();
  const context = appStore.createFlightContext(ACCOUNT_A, {
    flight_number_hash: "flight-hash",
    route: "SHA -> CTU"
  });
  const due = appStore.createBoardingReminderJob(ACCOUNT_A, {
    flight_context_id: context.id,
    scheduled_for: "2026-05-21T00:00:00.000Z"
  });

  const results = await dispatchDueNotifications({
    appStore,
    pushProvider: new InMemoryPushProvider(),
    now: () => new Date("2026-05-21T00:30:00.000Z")
  });

  const failed = appStore.notificationJobs.get(due.id);
  assert.equal(results.length, 1);
  assert.equal(results[0].status, "failed");
  assert.equal(failed.status, "failed");
  assert.equal(failed.payload.last_error, "no_push_token");
});
