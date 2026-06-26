import assert from "node:assert/strict";
import test from "node:test";
import { PostgresEventStore } from "../src/postgres-event-store.mjs";

test("PostgresEventStore writes sanitized normalized events to event_logs", async () => {
  const queries = [];
  const store = new PostgresEventStore({
    async query(sql, params) {
      queries.push({ sql, params });
      return { rows: [] };
    }
  });

  await store.append({
    id: "event-1",
    event_name: "private_card_generated",
    properties: { template_id: "boarding_postcard" },
    platform: "ios",
    app_version: "dev",
    user_id_hash: "user-hash",
    device_id_hash: "device-hash",
    client_time: "2026-05-21T00:00:00.000Z",
    received_at: "2026-05-21T00:00:01.000Z"
  });

  assert.match(queries[0].sql, /insert into event_logs/i);
  assert.equal(queries[0].params[0], "event-1");
  assert.equal(queries[0].params[1], "private_card_generated");
  assert.equal(queries[0].params[2], "{\"template_id\":\"boarding_postcard\"}");
});

test("PostgresEventStore recent reads bounded event evidence", async () => {
  const store = new PostgresEventStore({
    async query(sql, params) {
      assert.match(sql, /where event_name = \$1/i);
      assert.deepEqual(params, ["signup_completed", 20]);
      return {
        rows: [
          {
            id: "event-1",
            event_name: "signup_completed",
            properties: { signup_method: "phone" },
            platform: "ios",
            app_version: "dev",
            user_id_hash: "user-hash",
            device_id_hash: null,
            client_time: new Date("2026-05-21T00:00:00.000Z"),
            received_at: new Date("2026-05-21T00:00:01.000Z")
          }
        ]
      };
    }
  });

  const events = await store.recent({ limit: 20, eventName: "signup_completed" });

  assert.equal(events.length, 1);
  assert.equal(events[0].event_name, "signup_completed");
  assert.equal(events[0].properties.signup_method, "phone");
  assert.equal(events[0].device_id_hash, undefined);
  assert.equal(events[0].received_at, "2026-05-21T00:00:01.000Z");
});

test("PostgresEventStore summary groups events by smoke run", async () => {
  const store = new PostgresEventStore({
    async query(sql, params) {
      assert.match(sql, /properties->>'smoke_run_id' = \$1/i);
      assert.match(sql, /group by event_name/i);
      assert.deepEqual(params, ["summary-smoke"]);
      return {
        rows: [
          {
            event_name: "compose_started",
            event_count: 2,
            first_received_at: new Date("2026-05-21T00:00:00.000Z"),
            last_received_at: new Date("2026-05-21T00:01:00.000Z")
          },
          {
            event_name: "private_card_generated",
            event_count: 1,
            first_received_at: new Date("2026-05-21T00:02:00.000Z"),
            last_received_at: new Date("2026-05-21T00:02:00.000Z")
          }
        ]
      };
    }
  });

  const summary = await store.summary({
    smokeRunID: "summary-smoke",
    eventNames: ["compose_started", "private_card_generated", "subscription_created"]
  });

  assert.equal(summary.total_events, 3);
  assert.equal(summary.events_by_name.compose_started, 2);
  assert.equal(summary.events_by_name.private_card_generated, 1);
  assert.deepEqual(summary.missing_event_names, ["subscription_created"]);
  assert.equal(summary.first_received_at, "2026-05-21T00:00:00.000Z");
  assert.equal(summary.last_received_at, "2026-05-21T00:02:00.000Z");
});
