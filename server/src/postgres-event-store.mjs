export class PostgresEventStore {
  constructor(client) {
    if (!client || typeof client.query !== "function") {
      throw new TypeError("postgres client with query(sql, params) is required");
    }
    this.client = client;
  }

  async append(event) {
    await this.client.query(
      `insert into event_logs (
        id,
        event_name,
        properties,
        platform,
        app_version,
        user_id_hash,
        device_id_hash,
        client_time,
        received_at
      ) values ($1, $2, $3::jsonb, $4, $5, $6, $7, $8, $9)`,
      [
        event.id,
        event.event_name,
        JSON.stringify(event.properties ?? {}),
        event.platform,
        event.app_version,
        event.user_id_hash ?? null,
        event.device_id_hash ?? null,
        event.client_time,
        event.received_at
      ]
    );
  }

  async recent({ limit = 50, eventName } = {}) {
    const boundedLimit = Math.min(Math.max(Number(limit) || 50, 1), 200);
    const hasEventName = typeof eventName === "string" && eventName.trim().length > 0;
    const result = await this.client.query(
      `select
        id,
        event_name,
        properties,
        platform,
        app_version,
        user_id_hash,
        device_id_hash,
        client_time,
        received_at
      from event_logs
      ${hasEventName ? "where event_name = $1" : ""}
      order by received_at desc
      limit ${hasEventName ? "$2" : "$1"}`,
      hasEventName ? [eventName, boundedLimit] : [boundedLimit]
    );

    return result.rows.map((row) => ({
      id: row.id,
      event_name: row.event_name,
      properties: parseProperties(row.properties),
      platform: row.platform,
      app_version: row.app_version,
      user_id_hash: row.user_id_hash ?? undefined,
      device_id_hash: row.device_id_hash ?? undefined,
      client_time: toISOString(row.client_time),
      received_at: toISOString(row.received_at)
    }));
  }

  async summary({ smokeRunID, eventNames = [] } = {}) {
    const expectedEventNames = normalizeEventNames(eventNames);
    const filters = [];
    const params = [];
    if (typeof smokeRunID === "string" && smokeRunID.trim().length > 0) {
      params.push(smokeRunID);
      filters.push(`properties->>'smoke_run_id' = $${params.length}`);
    }
    const whereClause = filters.length > 0 ? `where ${filters.join(" and ")}` : "";
    const result = await this.client.query(
      `select
        event_name,
        count(*)::int as event_count,
        min(received_at) as first_received_at,
        max(received_at) as last_received_at
      from event_logs
      ${whereClause}
      group by event_name
      order by event_name asc`,
      params
    );

    const eventsByName = {};
    let firstReceivedAt = null;
    let lastReceivedAt = null;
    let totalEvents = 0;
    for (const row of result.rows) {
      const eventCount = Number(row.event_count);
      eventsByName[row.event_name] = eventCount;
      totalEvents += eventCount;
      if (row.first_received_at && (!firstReceivedAt || new Date(row.first_received_at) < new Date(firstReceivedAt))) {
        firstReceivedAt = toISOString(row.first_received_at);
      }
      if (row.last_received_at && (!lastReceivedAt || new Date(row.last_received_at) > new Date(lastReceivedAt))) {
        lastReceivedAt = toISOString(row.last_received_at);
      }
    }

    return {
      total_events: totalEvents,
      expected_event_names: expectedEventNames,
      missing_event_names: expectedEventNames.filter((eventName) => !eventsByName[eventName]),
      events_by_name: eventsByName,
      first_received_at: firstReceivedAt,
      last_received_at: lastReceivedAt
    };
  }

  async health() {
    await this.client.query("select 1");
    return { ok: true, kind: "postgres" };
  }

  async close() {
    if (typeof this.client.end === "function") {
      await this.client.end();
    }
  }
}

export async function createPostgresEventStore({
  connectionString = process.env.DATABASE_URL,
  sslMode = process.env.DATABASE_SSL_MODE,
  max = process.env.DATABASE_POOL_MAX
} = {}) {
  if (!connectionString) {
    throw new Error("DATABASE_URL is required for postgres event store");
  }

  const { Pool } = await import("pg");
  const pool = new Pool({
    connectionString,
    max: Number(max || 5),
    ssl: sslConfig(sslMode)
  });
  return new PostgresEventStore(pool);
}

function parseProperties(value) {
  if (!value) {
    return {};
  }
  if (typeof value === "string") {
    return JSON.parse(value);
  }
  return value;
}

function toISOString(value) {
  if (value instanceof Date) {
    return value.toISOString();
  }
  return new Date(value).toISOString();
}

function normalizeEventNames(eventNames) {
  if (!Array.isArray(eventNames)) {
    return [];
  }
  return [...new Set(eventNames.map((eventName) => String(eventName).trim()).filter(Boolean))].sort();
}

function sslConfig(mode) {
  if (!mode || mode === "disable") {
    return false;
  }
  if (mode === "require") {
    return { rejectUnauthorized: true };
  }
  if (mode === "no-verify") {
    return { rejectUnauthorized: false };
  }
  throw new Error("DATABASE_SSL_MODE must be disable, require, or no-verify");
}
