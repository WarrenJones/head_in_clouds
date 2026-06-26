import pg from "pg";
import { InMemoryAppStore } from "./app-store.mjs";

const { Pool } = pg;

export async function createPostgresAppStore({ connectionString, sslMode = "disable", max = 5 } = {}) {
  if (!connectionString) {
    throw new Error("DATABASE_URL is required for postgres app store");
  }
  const pool = new Pool({
    connectionString,
    max: Number(max) || 5,
    ssl: sslConfig(sslMode)
  });
  const snapshot = await readSnapshot(pool);
  return new PostgresSnapshotAppStore(pool, snapshot);
}

export class PostgresSnapshotAppStore extends InMemoryAppStore {
  constructor(pool, snapshot = {}) {
    super(snapshot);
    this.pool = pool;
    this.persisting = Promise.resolve();
  }

  async createFlightContext(accountID, input, now = new Date()) {
    const result = super.createFlightContext(accountID, input, now);
    await this.persist();
    return result;
  }

  async createFlightProof(accountID, input, now = new Date()) {
    const result = super.createFlightProof(accountID, input, now);
    await this.persist();
    return result;
  }

  async createPost(accountID, input, now = new Date()) {
    const result = super.createPost(accountID, input, now);
    await this.persist();
    return result;
  }

  async updateOwnPost(accountID, postID, patch) {
    const result = super.updateOwnPost(accountID, postID, patch);
    await this.persist();
    return result;
  }

  async deleteOwnPost(accountID, postID) {
    super.deleteOwnPost(accountID, postID);
    await this.persist();
  }

  async createComment(accountID, input, now = new Date()) {
    const result = super.createComment(accountID, input, now);
    await this.persist();
    return result;
  }

  async createReport(accountID, input, now = new Date()) {
    const result = super.createReport(accountID, input, now);
    await this.persist();
    return result;
  }

  async createBlock(accountID, input, now = new Date()) {
    const result = super.createBlock(accountID, input, now);
    await this.persist();
    return result;
  }

  async registerPushToken(accountID, input, now = new Date()) {
    const result = super.registerPushToken(accountID, input, now);
    await this.persist();
    return result;
  }

  async createBoardingReminderJob(accountID, input, now = new Date()) {
    const result = super.createBoardingReminderJob(accountID, input, now);
    await this.persist();
    return result;
  }

  async markNotificationJobSent(jobID, now = new Date()) {
    const result = super.markNotificationJobSent(jobID, now);
    await this.persist();
    return result;
  }

  async markNotificationJobFailed(jobID, reason, now = new Date()) {
    const result = super.markNotificationJobFailed(jobID, reason, now);
    await this.persist();
    return result;
  }

  async upgradeAccount(accountID, input, now = new Date()) {
    const result = super.upgradeAccount(accountID, input, now);
    await this.persist();
    return result;
  }

  async deleteAccount(accountID, input = {}, now = new Date()) {
    const result = super.deleteAccount(accountID, input, now);
    await this.persist();
    return result;
  }

  async verifyIAPTransaction(accountID, input = {}, now = new Date()) {
    const result = super.verifyIAPTransaction(accountID, input, now);
    await this.persist();
    return result;
  }

  async createSMSChallenge(accountID, input = {}, now = new Date(), code = "123456") {
    const result = super.createSMSChallenge(accountID, input, now, code);
    await this.persist();
    return result;
  }

  async verifySMSChallenge(accountID, input = {}, now = new Date()) {
    const result = super.verifySMSChallenge(accountID, input, now);
    await this.persist();
    return result;
  }

  async persist() {
    this.persisting = this.persisting.then(() => writeSnapshot(this.pool, this.snapshot()));
    return this.persisting;
  }

  async health() {
    await this.pool.query("select 1");
    return { ok: true, kind: "postgres" };
  }
}

async function readSnapshot(pool) {
  const client = await pool.connect();
  try {
    const accounts = await client.query("select * from accounts order by created_at asc");
    const flightContexts = await client.query("select * from flight_contexts order by created_at asc");
    const flightProofs = await client.query("select * from flight_proofs order by created_at asc");
    const posts = await client.query("select * from cloud_posts order by created_at asc");
    const comments = await client.query("select * from comments order by created_at asc");
    const reports = await client.query("select * from reports order by created_at asc");
    const blocks = await client.query("select * from blocks order by created_at asc");
    const pushTokens = await client.query("select * from push_tokens order by created_at asc");
    const notificationJobs = await client.query("select * from notification_jobs order by created_at asc");
    const subscriptions = await client.query("select * from subscriptions order by created_at asc");
    const smsChallenges = await client.query("select * from sms_challenges order by created_at asc");

    return {
      accounts: accounts.rows.map(mapAccount),
      flight_contexts: flightContexts.rows.map(mapFlightContext),
      flight_proofs: flightProofs.rows.map(mapFlightProof),
      posts: posts.rows.map(mapPost),
      comments: comments.rows.map(mapComment),
      reports: reports.rows.map(mapReport),
      blocks: blocks.rows.map(mapBlock),
      push_tokens: pushTokens.rows.map(mapPushToken),
      notification_jobs: notificationJobs.rows.map(mapNotificationJob),
      subscriptions: subscriptions.rows.map(mapSubscription),
      sms_challenges: smsChallenges.rows.map(mapSMSChallenge)
    };
  } finally {
    client.release();
  }
}

async function writeSnapshot(pool, snapshot) {
  const client = await pool.connect();
  try {
    await client.query("begin");
    await client.query("delete from subscriptions");
    await client.query("delete from sms_challenges");
    await client.query("delete from notification_jobs");
    await client.query("delete from push_tokens");
    await client.query("delete from blocks");
    await client.query("delete from reports");
    await client.query("delete from comments");
    await client.query("delete from cloud_posts");
    await client.query("delete from flight_proofs");
    await client.query("delete from flight_contexts");
    await client.query("delete from accounts");

    for (const account of snapshot.accounts ?? []) {
      await client.query(
        `insert into accounts (id, auth_method, phone_hash, wechat_open_id_hash, wechat_union_id_hash, created_at, upgraded_at, deleted_at)
         values ($1, $2, $3, $4, $5, $6, $7, $8)`,
        [
          account.id,
          account.auth_method,
          account.phone_hash ?? null,
          account.wechat_open_id_hash ?? null,
          account.wechat_union_id_hash ?? null,
          account.created_at,
          account.upgraded_at ?? null,
          account.deleted_at ?? null
        ]
      );
    }

    for (const context of snapshot.flight_contexts ?? []) {
      await client.query(
        `insert into flight_contexts (id, account_id, flight_number_hash, route, departure_date, verification_status, created_at, verified_at)
         values ($1, $2, $3, $4, $5, $6, $7, $8)`,
        [
          context.id,
          context.account_id ?? null,
          context.flight_number_hash ?? null,
          context.route ?? null,
          context.departure_date ?? null,
          context.verification_status,
          context.created_at,
          context.verified_at ?? null
        ]
      );
    }

    for (const proof of snapshot.flight_proofs ?? []) {
      await client.query(
        `insert into flight_proofs (id, flight_context_id, account_id, method, source_image_hash, redacted_object_key, created_at)
         values ($1, $2, $3, $4, $5, $6, $7)`,
        [
          proof.id,
          proof.flight_context_id,
          proof.account_id ?? null,
          proof.method,
          proof.source_image_hash ?? null,
          proof.redacted_object_key ?? null,
          proof.created_at
        ]
      );
    }

    for (const post of snapshot.posts ?? []) {
      await client.query(
        `insert into cloud_posts (id, account_id, flight_context_id, flight_proof_id, publish_scope, text_ciphertext, headline_quote, text_mode, card_template_id, offline_status, created_at, published_at)
         values ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12)`,
        [
          post.id,
          post.account_id ?? null,
          post.flight_context_id ?? null,
          post.flight_proof_id ?? null,
          post.publish_scope,
          post.text,
          post.headline_quote,
          post.text_mode,
          post.card_template_id,
          post.offline_status,
          post.created_at,
          post.published_at ?? null
        ]
      );
    }

    for (const comment of snapshot.comments ?? []) {
      await client.query(
        `insert into comments (id, post_id, account_id, body_ciphertext, created_at)
         values ($1, $2, $3, $4, $5)`,
        [comment.id, comment.post_id, comment.account_id ?? null, comment.body, comment.created_at]
      );
    }

    for (const report of snapshot.reports ?? []) {
      await client.query(
        `insert into reports (id, reporter_account_id, target_type, target_id, reason, status, created_at)
         values ($1, $2, $3, $4, $5, $6, $7)`,
        [
          report.id,
          report.reporter_account_id ?? null,
          report.target_type,
          report.target_id,
          report.reason,
          report.status,
          report.created_at
        ]
      );
    }

    for (const block of snapshot.blocks ?? []) {
      await client.query(
        `insert into blocks (account_id, blocked_account_id, created_at)
         values ($1, $2, $3)
         on conflict (account_id, blocked_account_id) do nothing`,
        [block.account_id, block.blocked_account_id, block.created_at]
      );
    }

    for (const pushToken of snapshot.push_tokens ?? []) {
      await client.query(
        `insert into push_tokens (id, account_id, platform, token, created_at, last_seen_at)
         values ($1, $2, $3, $4, $5, $6)`,
        [
          pushToken.id,
          pushToken.account_id,
          pushToken.platform,
          pushToken.token,
          pushToken.created_at,
          pushToken.last_seen_at
        ]
      );
    }

    for (const job of snapshot.notification_jobs ?? []) {
      await client.query(
        `insert into notification_jobs (id, account_id, flight_context_id, kind, scheduled_for, status, payload, created_at, sent_at, failed_at)
         values ($1, $2, $3, $4, $5, $6, $7::jsonb, $8, $9, $10)`,
        [
          job.id,
          job.account_id ?? null,
          job.flight_context_id ?? null,
          job.kind,
          job.scheduled_for,
          job.status,
          JSON.stringify(job.payload ?? {}),
          job.created_at,
          job.sent_at ?? null,
          job.failed_at ?? null
        ]
      );
    }

    for (const subscription of snapshot.subscriptions ?? []) {
      await client.query(
        `insert into subscriptions (id, account_id, transaction_id, original_transaction_id, product_id, plan, amount, currency, environment, status, created_at)
         values ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11)`,
        [
          subscription.id,
          subscription.account_id,
          subscription.transaction_id,
          subscription.original_transaction_id ?? null,
          subscription.product_id,
          subscription.plan,
          subscription.amount,
          subscription.currency,
          subscription.environment,
          subscription.status,
          subscription.created_at
        ]
      );
    }

    for (const challenge of snapshot.sms_challenges ?? []) {
      await client.query(
        `insert into sms_challenges (id, account_id, phone_country_code, phone_hash, code_hash, attempts, max_attempts, status, expires_at, resend_available_at, created_at, verified_at)
         values ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12)`,
        [
          challenge.id,
          challenge.account_id,
          challenge.phone_country_code,
          challenge.phone_hash,
          challenge.code_hash,
          challenge.attempts,
          challenge.max_attempts,
          challenge.status,
          challenge.expires_at,
          challenge.resend_available_at,
          challenge.created_at,
          challenge.verified_at ?? null
        ]
      );
    }
    await client.query("commit");
  } catch (error) {
    await client.query("rollback");
    throw error;
  } finally {
    client.release();
  }
}

function mapAccount(row) {
  return mapTimestamps(row, ["created_at", "upgraded_at", "deleted_at"]);
}

function mapFlightContext(row) {
  return mapTimestamps(row, ["created_at", "verified_at"]);
}

function mapFlightProof(row) {
  return mapTimestamps(row, ["created_at"]);
}

function mapPost(row) {
  const mapped = mapTimestamps(row, ["created_at", "published_at"]);
  mapped.text = mapped.text_ciphertext;
  delete mapped.text_ciphertext;
  return mapped;
}

function mapComment(row) {
  const mapped = mapTimestamps(row, ["created_at"]);
  mapped.body = mapped.body_ciphertext;
  delete mapped.body_ciphertext;
  return mapped;
}

function mapReport(row) {
  return mapTimestamps(row, ["created_at"]);
}

function mapBlock(row) {
  const mapped = mapTimestamps(row, ["created_at"]);
  mapped.id = `${mapped.account_id}:${mapped.blocked_account_id}`;
  return mapped;
}

function mapPushToken(row) {
  return mapTimestamps(row, ["created_at", "last_seen_at"]);
}

function mapNotificationJob(row) {
  const mapped = mapTimestamps(row, ["scheduled_for", "created_at", "sent_at", "failed_at"]);
  mapped.payload = mapped.payload ?? {};
  return mapped;
}

function mapSubscription(row) {
  const mapped = mapTimestamps(row, ["created_at"]);
  if (mapped.amount !== null && mapped.amount !== undefined) {
    mapped.amount = Number(mapped.amount);
  }
  return mapped;
}

function mapSMSChallenge(row) {
  return mapTimestamps(row, ["expires_at", "resend_available_at", "created_at", "verified_at"]);
}

function mapTimestamps(row, keys) {
  const mapped = { ...row };
  for (const key of keys) {
    if (mapped[key] instanceof Date) {
      mapped[key] = mapped[key].toISOString();
    }
  }
  return mapped;
}

function sslConfig(mode) {
  if (mode === "require") {
    return { rejectUnauthorized: true };
  }
  if (mode === "no-verify") {
    return { rejectUnauthorized: false };
  }
  return false;
}
