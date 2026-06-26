import assert from "node:assert/strict";
import fs from "node:fs";
import path from "node:path";
import test from "node:test";

const schemaPath = path.resolve("schema/001_initial.sql");

test("schema includes owner isolation columns and analytics table", () => {
  const sql = fs.readFileSync(schemaPath, "utf8");

  for (const table of [
    "accounts",
    "flight_contexts",
    "flight_proofs",
    "cloud_posts",
    "comments",
    "reports",
    "blocks",
    "push_tokens",
    "notification_jobs",
    "subscriptions",
    "sms_challenges",
    "event_logs"
  ]) {
    assert.match(sql, new RegExp(`create table if not exists ${table}`));
  }

  assert.match(sql, /flight_proofs[\s\S]*account_id uuid references accounts/i);
  assert.match(sql, /cloud_posts[\s\S]*account_id uuid references accounts/i);
  assert.match(sql, /event_logs[\s\S]*properties jsonb/i);
  assert.match(sql, /accounts[\s\S]*phone_hash text/i);
  assert.match(sql, /accounts[\s\S]*wechat_union_id_hash text/i);
  assert.match(sql, /notification_jobs[\s\S]*payload jsonb/i);
  assert.match(sql, /notification_jobs[\s\S]*failed_at timestamptz/i);
  assert.match(sql, /subscriptions[\s\S]*transaction_id text not null unique/i);
  assert.match(sql, /subscriptions[\s\S]*environment text not null/i);
  assert.match(sql, /sms_challenges[\s\S]*phone_hash text not null/i);
  assert.match(sql, /sms_challenges[\s\S]*status text not null/i);
  assert.match(sql, /push_tokens[\s\S]*platform text not null/i);
  assert.match(sql, /idx_cloud_posts_account/);
  assert.match(sql, /idx_push_tokens_account/);
  assert.match(sql, /idx_notification_jobs_account/);
  assert.match(sql, /idx_notification_jobs_pending/);
  assert.match(sql, /idx_subscriptions_account/);
  assert.match(sql, /idx_sms_challenges_account/);
  assert.match(sql, /idx_event_logs_name_time/);
  assert.match(sql, /idx_accounts_phone_hash/);
  assert.match(sql, /idx_accounts_wechat_union_hash/);
});
