create table if not exists accounts (
  id uuid primary key,
  auth_method text not null check (auth_method in ('guest', 'wechat', 'phone', 'apple')),
  phone_hash text,
  wechat_open_id_hash text,
  wechat_union_id_hash text,
  created_at timestamptz not null default now(),
  upgraded_at timestamptz,
  deleted_at timestamptz
);

create table if not exists flight_contexts (
  id uuid primary key,
  account_id uuid references accounts(id) on delete set null,
  flight_number_hash text,
  route text,
  departure_date date,
  verification_status text not null check (verification_status in ('unverified', 'pending', 'verified', 'failed')),
  created_at timestamptz not null default now(),
  verified_at timestamptz
);

create table if not exists flight_proofs (
  id uuid primary key,
  flight_context_id uuid not null references flight_contexts(id) on delete cascade,
  account_id uuid references accounts(id) on delete set null,
  method text not null check (method in ('manual', 'boarding_pass_photo', 'ticket_screenshot', 'itinerary_screenshot')),
  source_image_hash text,
  redacted_object_key text,
  created_at timestamptz not null default now()
);

create table if not exists cloud_posts (
  id uuid primary key,
  account_id uuid references accounts(id) on delete set null,
  flight_context_id uuid references flight_contexts(id) on delete set null,
  flight_proof_id uuid references flight_proofs(id) on delete set null,
  publish_scope text not null check (publish_scope in ('private_card', 'same_flight')),
  text_ciphertext text not null,
  headline_quote text not null,
  text_mode text not null check (text_mode in ('one_line', 'template', 'voice_transcript', 'free_text')),
  card_template_id text not null,
  offline_status text not null check (offline_status in ('local_only', 'syncing', 'synced', 'sync_failed')),
  created_at timestamptz not null default now(),
  published_at timestamptz
);

create table if not exists comments (
  id uuid primary key,
  post_id uuid not null references cloud_posts(id) on delete cascade,
  account_id uuid references accounts(id) on delete set null,
  body_ciphertext text not null,
  created_at timestamptz not null default now()
);

create table if not exists reports (
  id uuid primary key,
  reporter_account_id uuid references accounts(id) on delete set null,
  target_type text not null check (target_type in ('post', 'comment', 'user')),
  target_id uuid not null,
  reason text not null,
  status text not null default 'open' check (status in ('open', 'reviewed', 'actioned', 'rejected')),
  created_at timestamptz not null default now()
);

create table if not exists blocks (
  account_id uuid not null references accounts(id) on delete cascade,
  blocked_account_id uuid not null references accounts(id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (account_id, blocked_account_id)
);

create table if not exists push_tokens (
  id text primary key,
  account_id uuid not null references accounts(id) on delete cascade,
  platform text not null check (platform in ('ios', 'android', 'harmony')),
  token text not null,
  created_at timestamptz not null default now(),
  last_seen_at timestamptz not null default now(),
  unique (account_id, platform, token)
);

create table if not exists notification_jobs (
  id uuid primary key,
  account_id uuid references accounts(id) on delete cascade,
  flight_context_id uuid references flight_contexts(id) on delete cascade,
  kind text not null check (kind in ('boarding_reminder', 'same_flight_new_post')),
  scheduled_for timestamptz not null,
  status text not null default 'pending' check (status in ('pending', 'sent', 'failed', 'cancelled')),
  payload jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  sent_at timestamptz,
  failed_at timestamptz
);

create table if not exists subscriptions (
  id uuid primary key,
  account_id uuid not null references accounts(id) on delete cascade,
  transaction_id text not null unique,
  original_transaction_id text,
  product_id text not null,
  plan text not null,
  amount numeric(12, 2) not null,
  currency text not null,
  environment text not null check (environment in ('local_mock', 'sandbox', 'production')),
  status text not null default 'active' check (status in ('active', 'cancelled', 'expired', 'refunded')),
  created_at timestamptz not null default now()
);

create table if not exists sms_challenges (
  id uuid primary key,
  account_id uuid not null references accounts(id) on delete cascade,
  phone_country_code text not null,
  phone_hash text not null,
  code_hash text not null,
  attempts integer not null default 0,
  max_attempts integer not null default 3,
  status text not null default 'pending' check (status in ('pending', 'verified', 'expired', 'locked')),
  expires_at timestamptz not null,
  resend_available_at timestamptz not null,
  created_at timestamptz not null default now(),
  verified_at timestamptz
);

create table if not exists event_logs (
  id uuid primary key,
  event_name text not null,
  properties jsonb not null default '{}'::jsonb,
  platform text not null check (platform in ('ios', 'android', 'harmony', 'web', 'server')),
  app_version text not null,
  user_id_hash text,
  device_id_hash text,
  client_time timestamptz not null,
  received_at timestamptz not null default now()
);

create index if not exists idx_cloud_posts_flight_context on cloud_posts(flight_context_id, created_at desc);
create index if not exists idx_flight_contexts_account on flight_contexts(account_id, created_at desc);
create index if not exists idx_flight_contexts_same_flight on flight_contexts(flight_number_hash, departure_date, route, verification_status);
create index if not exists idx_flight_proofs_account on flight_proofs(account_id, created_at desc);
create index if not exists idx_cloud_posts_account on cloud_posts(account_id, created_at desc);
create index if not exists idx_comments_account on comments(account_id, created_at desc);
create index if not exists idx_push_tokens_account on push_tokens(account_id, platform);
create index if not exists idx_notification_jobs_account on notification_jobs(account_id, scheduled_for desc);
create index if not exists idx_notification_jobs_pending on notification_jobs(status, scheduled_for);
create index if not exists idx_subscriptions_account on subscriptions(account_id, created_at desc);
create index if not exists idx_sms_challenges_account on sms_challenges(account_id, created_at desc);
create index if not exists idx_sms_challenges_phone_hash on sms_challenges(phone_hash, created_at desc);
create index if not exists idx_event_logs_name_time on event_logs(event_name, received_at desc);
create index if not exists idx_event_logs_user_time on event_logs(user_id_hash, received_at desc);
create unique index if not exists idx_accounts_phone_hash on accounts(phone_hash) where phone_hash is not null;
create unique index if not exists idx_accounts_wechat_union_hash on accounts(wechat_union_id_hash) where wechat_union_id_hash is not null;
