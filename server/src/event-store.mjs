import fs from "node:fs";
import path from "node:path";

export class FileEventStore {
  constructor(logPath = path.resolve(".local/event-log.jsonl")) {
    this.logPath = logPath;
  }

  append(event) {
    fs.mkdirSync(path.dirname(this.logPath), { recursive: true });
    fs.appendFileSync(this.logPath, `${JSON.stringify(event)}\n`, "utf8");
  }

  recent({ limit = 50, eventName } = {}) {
    if (!fs.existsSync(this.logPath)) {
      return [];
    }

    const boundedLimit = Math.min(Math.max(Number(limit) || 50, 1), 200);
    return fs
      .readFileSync(this.logPath, "utf8")
      .split("\n")
      .filter(Boolean)
      .map((line) => JSON.parse(line))
      .filter((event) => !eventName || event.event_name === eventName)
      .slice(-boundedLimit)
      .reverse();
  }

  summary({ smokeRunID, eventNames = [] } = {}) {
    return summarizeEvents(readEventsFromFile(this.logPath), { smokeRunID, eventNames });
  }

  health() {
    return { ok: true, kind: "file" };
  }
}

export class InMemoryEventStore {
  constructor() {
    this.events = [];
  }

  append(event) {
    this.events.push(event);
  }

  recent({ limit = 50, eventName } = {}) {
    const boundedLimit = Math.min(Math.max(Number(limit) || 50, 1), 200);
    return this.events
      .filter((event) => !eventName || event.event_name === eventName)
      .slice(-boundedLimit)
      .reverse();
  }

  summary({ smokeRunID, eventNames = [] } = {}) {
    return summarizeEvents(this.events, { smokeRunID, eventNames });
  }

  health() {
    return { ok: true, kind: "memory" };
  }
}

export function summarizeEvents(events, { smokeRunID, eventNames = [] } = {}) {
  const expectedEventNames = normalizeEventNames(eventNames);
  const filtered = events.filter((event) => {
    return !smokeRunID || event.properties?.smoke_run_id === smokeRunID;
  });
  const eventsByName = {};
  let firstReceivedAt = null;
  let lastReceivedAt = null;

  for (const event of filtered) {
    eventsByName[event.event_name] = (eventsByName[event.event_name] ?? 0) + 1;
    const receivedAt = event.received_at ?? event.client_time;
    if (!receivedAt) {
      continue;
    }
    if (!firstReceivedAt || new Date(receivedAt) < new Date(firstReceivedAt)) {
      firstReceivedAt = receivedAt;
    }
    if (!lastReceivedAt || new Date(receivedAt) > new Date(lastReceivedAt)) {
      lastReceivedAt = receivedAt;
    }
  }

  return {
    total_events: filtered.length,
    expected_event_names: expectedEventNames,
    missing_event_names: expectedEventNames.filter((eventName) => !eventsByName[eventName]),
    events_by_name: sortObject(eventsByName),
    first_received_at: firstReceivedAt,
    last_received_at: lastReceivedAt
  };
}

function readEventsFromFile(logPath) {
  if (!fs.existsSync(logPath)) {
    return [];
  }
  return fs
    .readFileSync(logPath, "utf8")
    .split("\n")
    .filter(Boolean)
    .map((line) => JSON.parse(line));
}

function normalizeEventNames(eventNames) {
  if (!Array.isArray(eventNames)) {
    return [];
  }
  return [...new Set(eventNames.map((eventName) => String(eventName).trim()).filter(Boolean))].sort();
}

function sortObject(value) {
  return Object.fromEntries(Object.entries(value).sort(([left], [right]) => left.localeCompare(right)));
}
