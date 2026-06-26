import crypto from "node:crypto";
import { sanitizeProperties } from "./sanitize.mjs";

const EVENT_NAME_PATTERN = /^[a-z0-9][a-z0-9_]{1,80}$/;
const SUPPORTED_PLATFORMS = new Set(["ios", "android", "harmony", "web", "server"]);

export function normalizeEvent(input, now = new Date()) {
  if (!input || typeof input !== "object" || Array.isArray(input)) {
    throw new ValidationError("event payload must be an object");
  }

  const eventName = input.event_name ?? input.eventName;
  if (typeof eventName !== "string" || !EVENT_NAME_PATTERN.test(eventName)) {
    throw new ValidationError("event_name must be snake_case");
  }

  const appVersion = input.app_version ?? input.appVersion;
  if (typeof appVersion !== "string" || appVersion.trim().length === 0) {
    throw new ValidationError("app_version is required");
  }

  const platform = input.platform ?? "ios";
  if (typeof platform !== "string" || !SUPPORTED_PLATFORMS.has(platform)) {
    throw new ValidationError("platform is not supported");
  }

  const clientTime = parseClientTime(input.client_time ?? input.clientTime, now);
  const normalized = {
    id: typeof input.id === "string" && input.id.length > 0 ? input.id : crypto.randomUUID(),
    event_name: eventName,
    properties: sanitizeProperties(input.properties),
    client_time: clientTime.toISOString(),
    received_at: now.toISOString(),
    app_version: appVersion,
    platform
  };

  if (typeof input.user_id_hash === "string" && input.user_id_hash.length > 0) {
    normalized.user_id_hash = input.user_id_hash;
  }
  if (typeof input.device_id_hash === "string" && input.device_id_hash.length > 0) {
    normalized.device_id_hash = input.device_id_hash;
  }

  return normalized;
}

function parseClientTime(value, fallback) {
  if (value === undefined || value === null || value === "") {
    return fallback;
  }
  const parsed = new Date(value);
  if (Number.isNaN(parsed.getTime())) {
    throw new ValidationError("client_time must be ISO-8601");
  }
  return parsed;
}

export class ValidationError extends Error {
  constructor(message) {
    super(message);
    this.name = "ValidationError";
  }
}
