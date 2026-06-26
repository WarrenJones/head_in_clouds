import crypto from "node:crypto";
import { normalizeEvent } from "./events.mjs";

export class InMemoryPushProvider {
  constructor() {
    this.sent = [];
  }

  async send(job, pushTokens = []) {
    this.sent.push({ job, push_tokens: pushTokens });
    return { provider_message_id: `local-${job.id}` };
  }
}

export async function dispatchDueNotifications({
  appStore,
  pushProvider,
  eventStore = null,
  now = () => new Date(),
  limit = 50
}) {
  const dueJobs = await appStore.pendingNotificationJobs(now(), limit);
  const results = [];

  for (const job of dueJobs) {
    try {
      const pushTokens = await appStore.pushTokensForAccount(job.account_id, "ios");
      if (pushTokens.length === 0) {
        throw new Error("no_push_token");
      }
      const providerResult = await pushProvider.send(job, pushTokens);
      const sent = await appStore.markNotificationJobSent(job.id, now());
      await appendNotificationSentEvent(eventStore, sent, now());
      results.push({ job: sent, status: "sent", provider_result: providerResult });
    } catch (error) {
      const failed = await appStore.markNotificationJobFailed(job.id, error?.message ?? "push_send_failed", now());
      results.push({ job: failed, status: "failed" });
    }
  }

  return results;
}

async function appendNotificationSentEvent(eventStore, job, timestamp) {
  if (!eventStore || typeof eventStore.append !== "function") {
    return;
  }

  const eventName = notificationEventName(job.kind);
  if (!eventName) {
    return;
  }

  await eventStore.append(normalizeEvent({
    event_name: eventName,
    properties: notificationEventProperties(job),
    app_version: "server",
    platform: "server",
    user_id_hash: stableHash(job.account_id),
    client_time: timestamp.toISOString()
  }, timestamp));
}

function notificationEventName(kind) {
  switch (kind) {
    case "boarding_reminder":
      return "boarding_reminder_sent";
    case "same_flight_new_post":
      return "same_flight_note_notification_sent";
    default:
      return null;
  }
}

function notificationEventProperties(job) {
  if (job.kind === "boarding_reminder") {
    return {
      notification_job_id: job.id,
      flight_number_hash: job.payload.flight_number_hash ?? "unknown",
      reminder_offset_minutes: String(job.payload.reminder_offset_minutes ?? 30),
      "$lib": "server"
    };
  }

  return {
    notification_job_id: job.id,
    flight_context_id: job.flight_context_id,
    flight_number_hash: job.payload.flight_number_hash ?? "unknown",
    hours_after_post: hoursBetween(job.payload.source_post_created_at, job.sent_at ?? job.scheduled_for),
    "$lib": "server"
  };
}

function stableHash(value) {
  return crypto.createHash("sha256").update(String(value).trim().toUpperCase()).digest("hex");
}

function hoursBetween(start, end) {
  const startTime = new Date(start ?? 0).getTime();
  const endTime = new Date(end ?? 0).getTime();
  if (!Number.isFinite(startTime) || !Number.isFinite(endTime) || endTime < startTime) {
    return 0;
  }
  return Math.floor((endTime - startTime) / (60 * 60 * 1000));
}
