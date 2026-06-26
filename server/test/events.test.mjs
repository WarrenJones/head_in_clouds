import assert from "node:assert/strict";
import test from "node:test";
import { once } from "node:events";
import { InMemoryEventStore, summarizeEvents } from "../src/event-store.mjs";
import { normalizeEvent } from "../src/events.mjs";
import { sanitizeProperties, sanitizePublicText } from "../src/sanitize.mjs";
import { createServer } from "../src/server.mjs";

const ACCOUNT_ID = "11111111-1111-4111-8111-111111111111";

function authHeaders() {
  return { authorization: `Bearer ${ACCOUNT_ID}` };
}

test("sanitizeProperties removes PII and exact seat values", () => {
  const result = sanitizeProperties({
    email: "user@example.com",
    seat_number: "14A",
    source: "compose",
    step: "00a",
    flight_number_hash: "123456",
    note: "I was in 14A",
    nested: { unsafe: true }
  });

  assert.deepEqual(result, {
    source: "compose",
    step: "00a",
    flight_number_hash: "123456"
  });
});

test("sanitizePublicText redacts public exact seat and contact values", () => {
  const result = sanitizePublicText("我坐在14A，落地后联系 user@example.com。");
  assert.equal(result, "我坐在某个座位，落地后联系 已隐藏联系方式");
});

test("normalizeEvent accepts a first-party mobile envelope", () => {
  const event = normalizeEvent(
    {
      event_name: "compose_started",
      properties: { source: "opening" },
      app_version: "dev",
      platform: "ios",
      user_id_hash: "user-hash",
      device_id_hash: "device-hash",
      client_time: "2026-05-21T00:00:00.000Z"
    },
    new Date("2026-05-21T00:00:01.000Z")
  );

  assert.equal(event.event_name, "compose_started");
  assert.equal(event.properties.source, "opening");
  assert.equal(event.app_version, "dev");
  assert.equal(event.platform, "ios");
  assert.equal(event.user_id_hash, "user-hash");
  assert.equal(event.device_id_hash, "device-hash");
  assert.equal(event.client_time, "2026-05-21T00:00:00.000Z");
  assert.equal(event.received_at, "2026-05-21T00:00:01.000Z");
});

test("normalizeEvent accepts PRD screen-prefixed event names", () => {
  const event = normalizeEvent(
    {
      event_name: "01a_landing_viewed",
      properties: { is_returning: "false", post_count: "0" },
      app_version: "dev",
      platform: "ios"
    },
    new Date("2026-05-21T00:00:01.000Z")
  );

  assert.equal(event.event_name, "01a_landing_viewed");
  assert.equal(event.properties.is_returning, "false");
});

test("summarizeEvents reports missing expected events by smoke run", () => {
  const summary = summarizeEvents(
    [
      {
        event_name: "compose_started",
        properties: { smoke_run_id: "smoke-a" },
        received_at: "2026-05-21T00:00:01.000Z"
      },
      {
        event_name: "private_card_generated",
        properties: { smoke_run_id: "smoke-a" },
        received_at: "2026-05-21T00:00:03.000Z"
      },
      {
        event_name: "compose_started",
        properties: { smoke_run_id: "smoke-b" },
        received_at: "2026-05-21T00:00:04.000Z"
      }
    ],
    {
      smokeRunID: "smoke-a",
      eventNames: ["compose_started", "private_card_generated", "subscription_created"]
    }
  );

  assert.equal(summary.total_events, 2);
  assert.deepEqual(summary.events_by_name, {
    compose_started: 1,
    private_card_generated: 1
  });
  assert.deepEqual(summary.missing_event_names, ["subscription_created"]);
  assert.equal(summary.first_received_at, "2026-05-21T00:00:01.000Z");
  assert.equal(summary.last_received_at, "2026-05-21T00:00:03.000Z");
});

test("POST /events requires account auth and stores a sanitized event", async () => {
  const store = new InMemoryEventStore();
  const server = createServer({
    store,
    now: () => new Date("2026-05-21T00:00:01.000Z")
  });
  server.listen(0, "127.0.0.1");
  await once(server, "listening");

  const { port } = server.address();
  const unauthorized = await fetch(`http://127.0.0.1:${port}/events`, {
    method: "POST",
    headers: { "content-type": "application/json" },
    body: JSON.stringify({
      event_name: "private_card_generated",
      properties: {},
      app_version: "dev",
      platform: "ios"
    })
  });
  const response = await fetch(`http://127.0.0.1:${port}/events`, {
    method: "POST",
    headers: {
      ...authHeaders(),
      "content-type": "application/json"
    },
    body: JSON.stringify({
      event_name: "private_card_generated",
      properties: {
        template_id: "boarding_postcard",
        email: "user@example.com"
      },
      app_version: "dev",
      platform: "ios"
    })
  });

  assert.equal(unauthorized.status, 401);
  assert.equal(response.status, 202);
  assert.equal(store.events.length, 1);
  assert.equal(store.events[0].event_name, "private_card_generated");
  assert.equal(store.events[0].properties.template_id, "boarding_postcard");
  assert.equal(store.events[0].properties.email, undefined);
  assert.ok(store.events[0].user_id_hash, "server fills user_id_hash from bearer account when missing");
  server.close();
});

test("POST /events rejects oversized JSON with HTTP 413", async () => {
  const server = createServer({
    store: new InMemoryEventStore(),
    now: () => new Date("2026-05-21T00:00:01.000Z")
  });
  server.listen(0, "127.0.0.1");
  await once(server, "listening");

  try {
    const { port } = server.address();
    const response = await fetch(`http://127.0.0.1:${port}/events`, {
      method: "POST",
      headers: {
        ...authHeaders(),
        "content-type": "application/json"
      },
      body: JSON.stringify({
        event_name: "private_card_generated",
        properties: {
          oversized_note: "x".repeat(70 * 1024)
        },
        app_version: "dev",
        platform: "ios"
      })
    });
    const body = await response.json();

    assert.equal(response.status, 413);
    assert.equal(body.error, "body_too_large");
  } finally {
    server.close();
  }
});

test("admin event log endpoint is disabled unless an admin token is configured", async () => {
  const server = createServer({
    store: new InMemoryEventStore(),
    adminToken: ""
  });
  server.listen(0, "127.0.0.1");
  await once(server, "listening");

  const { port } = server.address();
  const response = await fetch(`http://127.0.0.1:${port}/api/admin/events/recent`);

  assert.equal(response.status, 404);
  server.close();
});

test("admin event log endpoint returns recent sanitized events with bearer token", async () => {
  const store = new InMemoryEventStore();
  const server = createServer({
    store,
    adminToken: "test-admin-token",
    now: () => new Date("2026-05-21T00:00:01.000Z")
  });
  server.listen(0, "127.0.0.1");
  await once(server, "listening");

  const { port } = server.address();
  const writeResponse = await fetch(`http://127.0.0.1:${port}/events`, {
    method: "POST",
    headers: {
      ...authHeaders(),
      "content-type": "application/json"
    },
    body: JSON.stringify({
      event_name: "share_landing_opened",
      properties: {
        source: "qr",
        seat_number: "14A"
      },
      app_version: "dev",
      platform: "ios"
    })
  });
  const unauthorizedResponse = await fetch(`http://127.0.0.1:${port}/api/admin/events/recent`);
  const readResponse = await fetch(
    `http://127.0.0.1:${port}/api/admin/events/recent?event_name=share_landing_opened&limit=1`,
    {
      headers: { authorization: "Bearer test-admin-token" }
    }
  );
  const body = await readResponse.json();

  assert.equal(writeResponse.status, 202);
  assert.equal(unauthorizedResponse.status, 401);
  assert.equal(readResponse.status, 200);
  assert.equal(body.events.length, 1);
  assert.equal(body.events[0].event_name, "share_landing_opened");
  assert.equal(body.events[0].properties.source, "qr");
  assert.equal(body.events[0].properties.seat_number, undefined);
  server.close();
});

test("admin event summary endpoint returns counts and missing expected events", async () => {
  const store = new InMemoryEventStore();
  const server = createServer({
    store,
    adminToken: "test-admin-token",
    now: () => new Date("2026-05-21T00:00:01.000Z")
  });
  server.listen(0, "127.0.0.1");
  await once(server, "listening");

  const { port } = server.address();
  for (const eventName of ["compose_started", "private_card_generated"]) {
    const writeResponse = await fetch(`http://127.0.0.1:${port}/events`, {
      method: "POST",
      headers: {
        ...authHeaders(),
        "content-type": "application/json"
      },
      body: JSON.stringify({
        event_name: eventName,
        properties: {
          smoke_run_id: "summary-smoke"
        },
        app_version: "dev",
        platform: "ios"
      })
    });
    assert.equal(writeResponse.status, 202);
  }

  const response = await fetch(
    `http://127.0.0.1:${port}/api/admin/events/summary?smoke_run_id=summary-smoke&event_names=compose_started,private_card_generated,subscription_created`,
    {
      headers: { authorization: "Bearer test-admin-token" }
    }
  );
  const body = await response.json();

  assert.equal(response.status, 200);
  assert.equal(body.summary.total_events, 2);
  assert.equal(body.summary.events_by_name.compose_started, 1);
  assert.equal(body.summary.events_by_name.private_card_generated, 1);
  assert.deepEqual(body.summary.missing_event_names, ["subscription_created"]);
  server.close();
});

test("admin event dashboard renders protected staging evidence", async () => {
  const store = new InMemoryEventStore();
  const server = createServer({
    store,
    adminToken: "test-admin-token",
    now: () => new Date("2026-05-21T00:00:01.000Z")
  });
  server.listen(0, "127.0.0.1");
  await once(server, "listening");

  try {
    const { port } = server.address();
    const writeResponse = await fetch(`http://127.0.0.1:${port}/events`, {
      method: "POST",
      headers: {
        ...authHeaders(),
        "content-type": "application/json"
      },
      body: JSON.stringify({
        event_name: "private_card_generated",
        properties: {
          smoke_run_id: "dashboard-smoke",
          template_id: "boarding_postcard",
          seat_number: "14A"
        },
        app_version: "dev",
        platform: "ios"
      })
    });
    const unauthorized = await fetch(`http://127.0.0.1:${port}/api/admin/events/dashboard`);
    const dashboard = await fetch(
      `http://127.0.0.1:${port}/api/admin/events/dashboard?smoke_run_id=dashboard-smoke&event_names=private_card_generated,subscription_created`,
      {
        headers: {
          authorization: `Basic ${Buffer.from("admin:test-admin-token").toString("base64")}`
        }
      }
    );
    const html = await dashboard.text();

    assert.equal(writeResponse.status, 202);
    assert.equal(unauthorized.status, 401);
    assert.equal(unauthorized.headers.get("www-authenticate")?.includes("Head in the Clouds admin"), true);
    assert.equal(dashboard.status, 200);
    assert.equal(dashboard.headers.get("content-type"), "text/html; charset=utf-8");
    assert.match(html, /Event Dashboard/);
    assert.match(html, /private_card_generated/);
    assert.match(html, /subscription_created/);
    assert.match(html, /Missing expected events/);
    assert.doesNotMatch(html, /14A/);
  } finally {
    server.close();
  }
});

test("readiness endpoint checks app and event stores", async () => {
  const server = createServer({
    store: new InMemoryEventStore(),
    appStore: {
      health() {
        return { ok: false, kind: "test" };
      }
    }
  });
  server.listen(0, "127.0.0.1");
  await once(server, "listening");

  const { port } = server.address();
  const response = await fetch(`http://127.0.0.1:${port}/health/ready`);
  const body = await response.json();

  assert.equal(response.status, 503);
  assert.equal(body.ok, false);
  assert.equal(body.checks.event_store.ok, true);
  assert.equal(body.checks.app_store.ok, false);
  server.close();
});

test("legal pages are public HTML", async () => {
  const server = createServer({ store: new InMemoryEventStore() });
  server.listen(0, "127.0.0.1");
  await once(server, "listening");

  const { port } = server.address();
  const privacy = await fetch(`http://127.0.0.1:${port}/privacy`);
  const privacyHead = await fetch(`http://127.0.0.1:${port}/privacy`, { method: "HEAD" });
  const terms = await fetch(`http://127.0.0.1:${port}/terms`);
  const privacyHTML = await privacy.text();
  const termsHTML = await terms.text();

  assert.equal(privacy.status, 200);
  assert.equal(privacyHead.status, 200);
  assert.equal(privacy.headers.get("content-type"), "text/html; charset=utf-8");
  assert.match(privacyHTML, /隐私政策/);
  assert.match(privacyHTML, /票证原图默认不保存/);
  assert.equal(terms.status, 200);
  assert.match(termsHTML, /用户协议/);
  assert.match(termsHTML, /同班机空间/);
  server.close();
});

test("request logging emits non-PII path-only JSON", async () => {
  const logs = [];
  const server = createServer({
    store: new InMemoryEventStore(),
    requestLogger: {
      log(line) {
        logs.push(JSON.parse(line));
      }
    }
  });
  server.listen(0, "127.0.0.1");
  await once(server, "listening");

  const { port } = server.address();
  const response = await fetch(`http://127.0.0.1:${port}/health?token=secret`, {
    headers: { "x-request-id": "test-request-id" }
  });
  await response.text();

  assert.equal(response.status, 200);
  assert.equal(response.headers.get("x-request-id"), "test-request-id");
  assert.equal(logs.length, 1);
  assert.equal(logs[0].event, "http_request");
  assert.equal(logs[0].request_id, "test-request-id");
  assert.equal(logs[0].path, "/health");
  assert.equal(logs[0].path.includes("secret"), false);
  assert.equal(logs[0].status_code, 200);
  assert.equal(typeof logs[0].duration_ms, "number");
  server.close();
});
