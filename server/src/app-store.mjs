import crypto from "node:crypto";
import fs from "node:fs";
import path from "node:path";
import { sanitizePublicText } from "./sanitize.mjs";

const UUID_PATTERN = /^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;

export class InMemoryAppStore {
  constructor(snapshot = {}) {
    this.accounts = new Map();
    this.flightContexts = new Map();
    this.flightProofs = new Map();
    this.posts = new Map();
    this.comments = new Map();
    this.reports = new Map();
    this.blocks = new Map();
    this.pushTokens = new Map();
    this.notificationJobs = new Map();
    this.subscriptions = new Map();
    this.smsChallenges = new Map();
    this.loadSnapshot(snapshot);
  }

  health() {
    return { ok: true, kind: "memory" };
  }

  ensureAccount(accountID) {
    if (!this.accounts.has(accountID)) {
      this.accounts.set(accountID, {
        id: accountID,
        auth_method: "guest",
        phone_hash: null,
        wechat_open_id_hash: null,
        wechat_union_id_hash: null,
        created_at: new Date().toISOString()
      });
    }
    return this.accounts.get(accountID);
  }

  upgradeAccount(accountID, input, now = new Date()) {
    const current = this.ensureAccount(accountID);
    const method = requiredEnumValue(input.method, ["wechat", "phone"], "method");
    const providerUserHash = requiredString(input.provider_user_hash, "provider_user_hash");
    const providerField = method === "wechat" ? "wechat_union_id_hash" : "phone_hash";
    const existing = Array.from(this.accounts.values()).find((account) => {
      return account.id !== accountID && account[providerField] === providerUserHash;
    });

    if (existing) {
      const migrated = this.migrateAccountData(accountID, existing.id);
      const upgraded = {
        ...existing,
        auth_method: method,
        [providerField]: providerUserHash,
        wechat_open_id_hash: method === "wechat" ? stringOrNull(input.wechat_open_id_hash) ?? existing.wechat_open_id_hash ?? null : existing.wechat_open_id_hash ?? null,
        upgraded_at: existing.upgraded_at ?? now.toISOString(),
        deleted_at: null
      };
      this.accounts.set(existing.id, upgraded);
      this.accounts.delete(accountID);
      return {
        account: publicAccount(upgraded),
        merge: {
          merged_with_existing: true,
          previous_account_id: accountID,
          target_account_id: existing.id,
          merged_post_count: migrated.posts
        }
      };
    }

    const upgraded = {
      ...current,
      auth_method: method,
      [providerField]: providerUserHash,
      wechat_open_id_hash: method === "wechat" ? stringOrNull(input.wechat_open_id_hash) : current.wechat_open_id_hash ?? null,
      upgraded_at: now.toISOString(),
      deleted_at: null
    };
    this.accounts.set(accountID, upgraded);
    return {
      account: publicAccount(upgraded),
      merge: {
        merged_with_existing: false,
        previous_account_id: null,
        target_account_id: accountID,
        merged_post_count: 0
      }
    };
  }

  deleteAccount(accountID, input = {}, now = new Date()) {
    const account = this.ensureAccount(accountID);
    if (account.deleted_at) {
      return {
        account: publicAccount(account),
        recovery_deadline: recoveryDeadline(account.deleted_at)
      };
    }

    const reauthMethod = requiredEnumValue(input.reauth_method, ["guest", "wechat", "phone"], "reauth_method");
    if (account.auth_method !== reauthMethod) {
      throw new ForbiddenError("reauth method does not match account");
    }

    const deletedAt = now.toISOString();
    const deleted = {
      ...account,
      deleted_at: deletedAt
    };
    this.accounts.set(accountID, deleted);
    this.removePushTokens(accountID);
    this.cancelPendingNotificationJobs(accountID, now);
    return {
      account: publicAccount(deleted),
      recovery_deadline: recoveryDeadline(deletedAt)
    };
  }

  verifyIAPTransaction(accountID, input = {}, now = new Date()) {
    this.assertActiveAccount(accountID);
    const transactionID = requiredString(input.transaction_id, "transaction_id");
    const existing = this.subscriptions.get(transactionID);
    if (existing) {
      if (existing.account_id !== accountID) {
        throw new ForbiddenError("transaction does not belong to account");
      }
      return {
        subscription: publicSubscription(existing),
        created: false
      };
    }

    const environment = enumValue(input.environment, ["local_mock", "sandbox", "production"], "local_mock", "environment");
    if (environment !== "local_mock") {
      requiredString(input.signed_transaction_jws, "signed_transaction_jws");
    }

    const subscription = {
      id: crypto.randomUUID(),
      account_id: accountID,
      transaction_id: transactionID,
      original_transaction_id: stringOrNull(input.original_transaction_id),
      product_id: requiredString(input.product_id, "product_id"),
      plan: requiredString(input.plan, "plan"),
      amount: requiredNumber(input.amount, "amount"),
      currency: requiredString(input.currency ?? "CNY", "currency").toUpperCase(),
      environment,
      status: "active",
      created_at: now.toISOString()
    };
    this.subscriptions.set(transactionID, subscription);
    return {
      subscription: publicSubscription(subscription),
      created: true
    };
  }

  createSMSChallenge(accountID, input = {}, now = new Date(), code = "123456") {
    this.assertActiveAccount(accountID);
    const phoneCountryCode = requiredString(input.phone_country_code ?? "+86", "phone_country_code");
    const normalizedPhone = normalizePhoneNumber(input.phone, phoneCountryCode);
    const id = crypto.randomUUID();
    const expiresAt = new Date(now.getTime() + 5 * 60 * 1000).toISOString();
    const resendAvailableAt = new Date(now.getTime() + 60 * 1000).toISOString();
    const challenge = {
      id,
      account_id: accountID,
      phone_country_code: phoneCountryCode,
      phone_hash: hashPhone(phoneCountryCode, normalizedPhone),
      code_hash: hashSMSCode(id, code),
      attempts: 0,
      max_attempts: 3,
      status: "pending",
      expires_at: expiresAt,
      resend_available_at: resendAvailableAt,
      created_at: now.toISOString(),
      verified_at: null
    };
    this.smsChallenges.set(id, challenge);
    return publicSMSChallenge(challenge);
  }

  verifySMSChallenge(accountID, input = {}, now = new Date()) {
    this.assertActiveAccount(accountID);
    const challengeID = requiredString(input.challenge_id, "challenge_id");
    const code = requiredString(input.code, "code");
    const challenge = this.smsChallenges.get(challengeID);
    if (!challenge || challenge.account_id !== accountID) {
      throw new NotFoundError("sms challenge not found");
    }
    if (challenge.status === "verified") {
      return publicVerifiedSMSChallenge(challenge);
    }
    if (challenge.status === "locked") {
      throw new RateLimitError("sms challenge is locked");
    }
    if (new Date(challenge.expires_at).getTime() <= now.getTime()) {
      const expired = {
        ...challenge,
        status: "expired"
      };
      this.smsChallenges.set(challengeID, expired);
      throw new ValidationError("sms challenge expired");
    }
    if (hashSMSCode(challengeID, code) !== challenge.code_hash) {
      const attempts = challenge.attempts + 1;
      const failed = {
        ...challenge,
        attempts,
        status: attempts >= challenge.max_attempts ? "locked" : "pending"
      };
      this.smsChallenges.set(challengeID, failed);
      if (failed.status === "locked") {
        throw new RateLimitError("sms challenge is locked");
      }
      throw new ValidationError("sms code is invalid");
    }

    const verified = {
      ...challenge,
      status: "verified",
      verified_at: now.toISOString()
    };
    this.smsChallenges.set(challengeID, verified);
    return publicVerifiedSMSChallenge(verified);
  }

  createFlightContext(accountID, input, now = new Date()) {
    this.assertActiveAccount(accountID);
    const id = validClientIDOrRandom(input.id);
    const existing = this.flightContexts.get(id);
    if (existing) {
      if (existing.account_id !== accountID) {
        throw new NotFoundError("flight context not found");
      }
      return existing;
    }

    const context = {
      id,
      account_id: accountID,
      flight_number_hash: stringOrNull(input.flight_number_hash),
      route: stringOrNull(input.route),
      departure_date: stringOrNull(input.departure_date),
      verification_status: enumValue(input.verification_status, ["unverified", "pending", "verified", "failed"], "unverified", "verification_status"),
      created_at: now.toISOString(),
      verified_at: input.verification_status === "verified" ? now.toISOString() : null
    };
    this.flightContexts.set(context.id, context);
    return context;
  }

  createFlightProof(accountID, input, now = new Date()) {
    const context = this.flightContexts.get(input.flight_context_id);
    if (!context || context.account_id !== accountID) {
      throw new NotFoundError("flight context not found");
    }

    const proof = {
      id: crypto.randomUUID(),
      flight_context_id: context.id,
      account_id: accountID,
      method: enumValue(input.method, ["manual", "boarding_pass_photo", "ticket_screenshot", "itinerary_screenshot"], "manual", "method"),
      source_image_hash: stringOrNull(input.source_image_hash),
      redacted_object_key: stringOrNull(input.redacted_object_key),
      created_at: now.toISOString()
    };
    this.flightProofs.set(proof.id, proof);

    context.verification_status = "verified";
    context.verified_at = now.toISOString();
    this.flightContexts.set(context.id, context);
    return proof;
  }

  createPost(accountID, input, now = new Date()) {
    this.assertActiveAccount(accountID);
    if (input.flight_context_id) {
      this.assertOwnsFlightContext(accountID, input.flight_context_id);
    }
    const id = validClientIDOrRandom(input.id);
    const existing = this.posts.get(id);
    if (existing) {
      if (existing.account_id !== accountID) {
        throw new NotFoundError("post not found");
      }
      return existing;
    }
    const publishScope = enumValue(input.publish_scope, ["private_card", "same_flight"], "private_card", "publish_scope");

    const flightContext = input.flight_context_id ? this.flightContexts.get(input.flight_context_id) : null;
    if (publishScope === "same_flight") {
      if (!canUseSameFlightContext(flightContext, accountID)) {
        throw new ForbiddenError("verified same-flight context required");
      }
      const proof = input.flight_proof_id ? this.flightProofs.get(input.flight_proof_id) : null;
      if (!proof || proof.account_id !== accountID || proof.flight_context_id !== flightContext.id) {
        throw new ForbiddenError("same-flight publish requires matching flight proof");
      }
    }

    const post = {
      id,
      account_id: accountID,
      flight_context_id: stringOrNull(input.flight_context_id),
      flight_proof_id: stringOrNull(input.flight_proof_id),
      publish_scope: publishScope,
      text: requiredString(input.text, "text"),
      headline_quote: input.headline_quote ?? defaultHeadline(input.text),
      text_mode: enumValue(input.text_mode, ["one_line", "template", "voice_transcript", "free_text"], "one_line", "text_mode"),
      card_template_id: input.card_template_id ?? "boarding_postcard",
      offline_status: enumValue(input.offline_status, ["local_only", "syncing", "synced", "sync_failed"], "synced", "offline_status"),
      created_at: now.toISOString(),
      published_at: publishScope === "same_flight" ? now.toISOString() : null
    };
    this.posts.set(post.id, post);
    if (post.publish_scope === "same_flight") {
      this.enqueueSameFlightNewPostNotifications(post, now);
    }
    return post;
  }

  getOwnPost(accountID, postID) {
    this.assertActiveAccount(accountID);
    const post = this.posts.get(postID);
    if (!post || post.account_id !== accountID) {
      throw new NotFoundError("post not found");
    }
    return post;
  }

  getPublicShareCard(postID) {
    const post = this.posts.get(postID);
    if (!post) {
      throw new NotFoundError("share card not found");
    }
    const context = post.flight_context_id ? this.flightContexts.get(post.flight_context_id) : null;
    return {
      post_id: post.id,
      headline_quote: sanitizePublicText(post.headline_quote),
      text: sanitizePublicText(post.text),
      template_id: post.card_template_id,
      route: context?.route ?? null,
      flight_context_status: context?.verification_status ?? "none",
      created_at: post.created_at
    };
  }

  listSameFlightPosts(accountID, flightContextID) {
    const viewerContext = this.flightContexts.get(flightContextID);
    if (!viewerContext || viewerContext.account_id !== accountID) {
      throw new NotFoundError("flight context not found");
    }
    if (!canUseSameFlightContext(viewerContext, accountID)) {
      throw new ForbiddenError("verified same-flight context required");
    }

    return Array.from(this.posts.values())
      .filter((post) => {
        if (post.publish_scope !== "same_flight") {
          return false;
        }
        if (isBlockedBetween(this.blocks, accountID, post.account_id)) {
          return false;
        }
        const postContext = post.flight_context_id ? this.flightContexts.get(post.flight_context_id) : null;
        return postContext?.verification_status === "verified" && sameFlightKeyMatches(viewerContext, postContext);
      })
      .sort((a, b) => new Date(b.published_at ?? b.created_at).getTime() - new Date(a.published_at ?? a.created_at).getTime())
      .map((post) => this.toFlightSpacePost(post));
  }

  updateOwnPost(accountID, postID, patch) {
    const post = this.getOwnPost(accountID, postID);
    const updated = {
      ...post,
      text: patch.text === undefined ? post.text : requiredString(patch.text, "text"),
      headline_quote: patch.headline_quote === undefined ? post.headline_quote : requiredString(patch.headline_quote, "headline_quote")
    };
    this.posts.set(postID, updated);
    return updated;
  }

  deleteOwnPost(accountID, postID) {
    this.getOwnPost(accountID, postID);
    this.posts.delete(postID);
  }

  createComment(accountID, input, now = new Date()) {
    this.assertActiveAccount(accountID);
    const post = this.posts.get(input.post_id);
    if (!post || post.publish_scope !== "same_flight") {
      throw new ForbiddenError("comments require same-flight post");
    }

    const postContext = this.flightContexts.get(post.flight_context_id);
    const commenterContext = this.flightContexts.get(input.flight_context_id);
    if (!canUseSameFlightContext(commenterContext, accountID) || !postContext || !sameFlightKeyMatches(commenterContext, postContext)) {
      throw new ForbiddenError("verified same-flight context required");
    }

    const id = validClientIDOrRandom(input.id);
    const existing = this.comments.get(id);
    if (existing) {
      if (existing.account_id !== accountID) {
        throw new NotFoundError("comment not found");
      }
      return existing;
    }

    const comment = {
      id,
      post_id: post.id,
      account_id: accountID,
      body: requiredString(input.body, "body"),
      created_at: now.toISOString()
    };
    this.comments.set(comment.id, comment);
    return comment;
  }

  createReport(accountID, input, now = new Date()) {
    this.assertActiveAccount(accountID);
    const id = validClientIDOrRandom(input.id);
    const existing = this.reports.get(id);
    if (existing) {
      if (existing.reporter_account_id !== accountID) {
        throw new NotFoundError("report not found");
      }
      return existing;
    }

    const report = {
      id,
      reporter_account_id: accountID,
      target_type: requiredString(input.target_type, "target_type"),
      target_id: requiredString(input.target_id, "target_id"),
      reason: requiredString(input.reason, "reason"),
      status: "open",
      created_at: now.toISOString()
    };
    this.reports.set(report.id, report);
    return report;
  }

  createBlock(accountID, input = {}, now = new Date()) {
    this.assertActiveAccount(accountID);
    const blockedAccountID = this.resolveBlockedAccountID(accountID, input);
    if (blockedAccountID === accountID) {
      throw new ValidationError("blocked_account_id cannot be self");
    }
    const id = `${accountID}:${blockedAccountID}`;
    const existing = this.blocks.get(id);
    if (existing) {
      return existing;
    }

    const block = {
      id,
      account_id: accountID,
      blocked_account_id: blockedAccountID,
      created_at: now.toISOString()
    };
    this.blocks.set(id, block);
    return block;
  }

  resolveBlockedAccountID(accountID, input) {
    const explicitAccountID = stringOrNull(input.blocked_account_id);
    if (explicitAccountID) {
      return explicitAccountID;
    }

    const postID = stringOrNull(input.post_id);
    if (!postID) {
      throw new ValidationError("blocked_account_id or post_id is required");
    }

    const post = this.posts.get(postID);
    if (!post || post.deleted_at) {
      throw new NotFoundError("post not found");
    }
    if (!post.account_id) {
      throw new ValidationError("post has no blockable owner");
    }
    return post.account_id;
  }

  registerPushToken(accountID, input, now = new Date()) {
    this.assertActiveAccount(accountID);
    const platform = enumValue(input.platform, ["ios", "android", "harmony"], null, "platform");
    const token = requiredString(input.token, "token");
    const id = `${accountID}:${platform}:${token}`;
    const existing = this.pushTokens.get(id);
    if (existing) {
      const updated = {
        ...existing,
        last_seen_at: now.toISOString()
      };
      this.pushTokens.set(id, updated);
      return updated;
    }

    const pushToken = {
      id,
      account_id: accountID,
      platform,
      token,
      created_at: now.toISOString(),
      last_seen_at: now.toISOString()
    };
    this.pushTokens.set(id, pushToken);
    return pushToken;
  }

  pushTokensForAccount(accountID, platform = null) {
    return Array.from(this.pushTokens.values()).filter((pushToken) => {
      return pushToken.account_id === accountID && (platform === null || pushToken.platform === platform);
    });
  }

  createBoardingReminderJob(accountID, input, now = new Date()) {
    this.assertActiveAccount(accountID);
    const context = this.flightContexts.get(input.flight_context_id);
    if (!context || context.account_id !== accountID) {
      throw new NotFoundError("flight context not found");
    }

    const scheduledFor = input.scheduled_for ? new Date(input.scheduled_for) : now;
    if (Number.isNaN(scheduledFor.getTime())) {
      throw new ValidationError("scheduled_for must be ISO-8601");
    }

    const id = validClientIDOrRandom(input.id);
    const existing = this.notificationJobs.get(id);
    if (existing) {
      if (existing.account_id !== accountID) {
        throw new NotFoundError("notification job not found");
      }
      return existing;
    }

    const job = {
      id,
      account_id: accountID,
      flight_context_id: context.id,
      kind: "boarding_reminder",
      status: "pending",
      payload: {
        flight_number_hash: context.flight_number_hash,
        route: context.route,
        reminder_offset_minutes: Number(input.reminder_offset_minutes ?? 30)
      },
      scheduled_for: scheduledFor.toISOString(),
      created_at: now.toISOString(),
      sent_at: null
    };
    this.notificationJobs.set(job.id, job);
    return job;
  }

  enqueueSameFlightNewPostNotifications(post, now = new Date()) {
    const postContext = this.flightContexts.get(post.flight_context_id);
    if (!postContext || postContext.verification_status !== "verified") {
      return [];
    }

    const jobs = [];
    for (const context of this.flightContexts.values()) {
      if (
        context.account_id === post.account_id ||
        context.verification_status !== "verified" ||
        !sameFlightKeyMatches(context, postContext)
      ) {
        continue;
      }

      const job = {
        id: crypto.randomUUID(),
        account_id: context.account_id,
        flight_context_id: context.id,
        kind: "same_flight_new_post",
        status: "pending",
        payload: {
          post_id: post.id,
          source_account_id: post.account_id,
          source_post_created_at: post.published_at ?? post.created_at,
          flight_number_hash: postContext.flight_number_hash
        },
        scheduled_for: now.toISOString(),
        created_at: now.toISOString(),
        sent_at: null
      };
      this.notificationJobs.set(job.id, job);
      jobs.push(job);
    }
    return jobs;
  }

  pendingNotificationJobs(now = new Date(), limit = 50) {
    const nowTime = now.getTime();
    return Array.from(this.notificationJobs.values())
      .filter((job) => {
        const scheduledTime = new Date(job.scheduled_for).getTime();
        return job.status === "pending" && Number.isFinite(scheduledTime) && scheduledTime <= nowTime;
      })
      .sort((a, b) => new Date(a.scheduled_for).getTime() - new Date(b.scheduled_for).getTime())
      .slice(0, limit);
  }

  markNotificationJobSent(jobID, now = new Date()) {
    const job = this.notificationJobs.get(jobID);
    if (!job) {
      throw new NotFoundError("notification job not found");
    }
    const updated = {
      ...job,
      status: "sent",
      sent_at: now.toISOString()
    };
    this.notificationJobs.set(jobID, updated);
    return updated;
  }

  markNotificationJobFailed(jobID, reason, now = new Date()) {
    const job = this.notificationJobs.get(jobID);
    if (!job) {
      throw new NotFoundError("notification job not found");
    }
    const updated = {
      ...job,
      status: "failed",
      payload: {
        ...job.payload,
        last_error: String(reason || "unknown_error")
      },
      sent_at: null,
      failed_at: now.toISOString()
    };
    this.notificationJobs.set(jobID, updated);
    return updated;
  }

  migrateAccountData(fromAccountID, toAccountID) {
    if (fromAccountID === toAccountID) {
      return { posts: 0 };
    }

    let postCount = 0;
    for (const row of this.flightContexts.values()) {
      if (row.account_id === fromAccountID) {
        row.account_id = toAccountID;
      }
    }
    for (const row of this.flightProofs.values()) {
      if (row.account_id === fromAccountID) {
        row.account_id = toAccountID;
      }
    }
    for (const row of this.posts.values()) {
      if (row.account_id === fromAccountID) {
        row.account_id = toAccountID;
        postCount += 1;
      }
    }
    for (const row of this.comments.values()) {
      if (row.account_id === fromAccountID) {
        row.account_id = toAccountID;
      }
    }
    for (const row of this.reports.values()) {
      if (row.reporter_account_id === fromAccountID) {
        row.reporter_account_id = toAccountID;
      }
    }
    for (const row of this.notificationJobs.values()) {
      if (row.account_id === fromAccountID) {
        row.account_id = toAccountID;
      }
      if (row.payload?.source_account_id === fromAccountID) {
        row.payload.source_account_id = toAccountID;
      }
    }
    for (const row of this.subscriptions.values()) {
      if (row.account_id === fromAccountID) {
        row.account_id = toAccountID;
      }
    }
    this.rekeyPushTokens(fromAccountID, toAccountID);
    this.rekeyBlocks(fromAccountID, toAccountID);
    return { posts: postCount };
  }

  rekeyPushTokens(fromAccountID, toAccountID) {
    for (const [key, token] of Array.from(this.pushTokens.entries())) {
      if (token.account_id !== fromAccountID) {
        continue;
      }
      this.pushTokens.delete(key);
      const updated = {
        ...token,
        account_id: toAccountID,
        id: `${toAccountID}:${token.platform}:${token.token}`
      };
      this.pushTokens.set(updated.id, updated);
    }
  }

  rekeyBlocks(fromAccountID, toAccountID) {
    for (const block of Array.from(this.blocks.values())) {
      const accountID = block.account_id === fromAccountID ? toAccountID : block.account_id;
      const blockedAccountID = block.blocked_account_id === fromAccountID ? toAccountID : block.blocked_account_id;
      this.blocks.delete(block.id);
      if (accountID !== blockedAccountID) {
        const id = `${accountID}:${blockedAccountID}`;
        this.blocks.set(id, {
          ...block,
          id,
          account_id: accountID,
          blocked_account_id: blockedAccountID
        });
      }
    }
  }

  removePushTokens(accountID) {
    for (const [key, token] of Array.from(this.pushTokens.entries())) {
      if (token.account_id === accountID) {
        this.pushTokens.delete(key);
      }
    }
  }

  cancelPendingNotificationJobs(accountID, now = new Date()) {
    for (const [jobID, job] of this.notificationJobs.entries()) {
      if (job.account_id === accountID && job.status === "pending") {
        this.notificationJobs.set(jobID, {
          ...job,
          status: "cancelled",
          payload: {
            ...job.payload,
            cancelled_reason: "account_deleted"
          },
          failed_at: now.toISOString()
        });
      }
    }
  }

  assertActiveAccount(accountID) {
    const account = this.ensureAccount(accountID);
    if (account.deleted_at) {
      throw new ForbiddenError("account is deleted");
    }
    return account;
  }

  assertOwnsFlightContext(accountID, flightContextID) {
    this.assertActiveAccount(accountID);
    const context = this.flightContexts.get(flightContextID);
    if (!context || context.account_id !== accountID) {
      throw new NotFoundError("flight context not found");
    }
  }

  toFlightSpacePost(post) {
    return {
      id: post.id,
      flight_context_id: post.flight_context_id,
      publish_scope: post.publish_scope,
      text: sanitizePublicText(post.text),
      headline_quote: sanitizePublicText(post.headline_quote),
      text_mode: post.text_mode,
      card_template_id: post.card_template_id,
      public_identity_label: "同机乘客",
      comment_count: Array.from(this.comments.values()).filter((comment) => comment.post_id === post.id).length,
      created_at: post.created_at,
      published_at: post.published_at
    };
  }

  snapshot() {
    return {
      accounts: Array.from(this.accounts.values()),
      flight_contexts: Array.from(this.flightContexts.values()),
      flight_proofs: Array.from(this.flightProofs.values()),
      posts: Array.from(this.posts.values()),
      comments: Array.from(this.comments.values()),
      reports: Array.from(this.reports.values()),
      blocks: Array.from(this.blocks.values()),
      push_tokens: Array.from(this.pushTokens.values()),
      notification_jobs: Array.from(this.notificationJobs.values()),
      subscriptions: Array.from(this.subscriptions.values()),
      sms_challenges: Array.from(this.smsChallenges.values())
    };
  }

  loadSnapshot(snapshot = {}) {
    loadMap(this.accounts, snapshot.accounts);
    loadMap(this.flightContexts, snapshot.flight_contexts);
    loadMap(this.flightProofs, snapshot.flight_proofs);
    loadMap(this.posts, snapshot.posts);
    loadMap(this.comments, snapshot.comments);
    loadMap(this.reports, snapshot.reports);
    loadMap(this.blocks, snapshot.blocks);
    loadMap(this.pushTokens, snapshot.push_tokens);
    loadMap(this.notificationJobs, snapshot.notification_jobs);
    for (const row of snapshot.subscriptions ?? []) {
      if (row?.transaction_id) {
        this.subscriptions.set(row.transaction_id, row);
      }
    }
    loadMap(this.smsChallenges, snapshot.sms_challenges);
  }
}

export class FileAppStore extends InMemoryAppStore {
  constructor(filePath = path.resolve(".local/app-store.json")) {
    super(readSnapshot(filePath));
    this.filePath = filePath;
  }

  createFlightContext(accountID, input, now = new Date()) {
    const result = super.createFlightContext(accountID, input, now);
    this.persist();
    return result;
  }

  createFlightProof(accountID, input, now = new Date()) {
    const result = super.createFlightProof(accountID, input, now);
    this.persist();
    return result;
  }

  createPost(accountID, input, now = new Date()) {
    const result = super.createPost(accountID, input, now);
    this.persist();
    return result;
  }

  updateOwnPost(accountID, postID, patch) {
    const result = super.updateOwnPost(accountID, postID, patch);
    this.persist();
    return result;
  }

  deleteOwnPost(accountID, postID) {
    super.deleteOwnPost(accountID, postID);
    this.persist();
  }

  createComment(accountID, input, now = new Date()) {
    const result = super.createComment(accountID, input, now);
    this.persist();
    return result;
  }

  createReport(accountID, input, now = new Date()) {
    const result = super.createReport(accountID, input, now);
    this.persist();
    return result;
  }

  createBlock(accountID, input, now = new Date()) {
    const result = super.createBlock(accountID, input, now);
    this.persist();
    return result;
  }

  registerPushToken(accountID, input, now = new Date()) {
    const result = super.registerPushToken(accountID, input, now);
    this.persist();
    return result;
  }

  createBoardingReminderJob(accountID, input, now = new Date()) {
    const result = super.createBoardingReminderJob(accountID, input, now);
    this.persist();
    return result;
  }

  markNotificationJobSent(jobID, now = new Date()) {
    const result = super.markNotificationJobSent(jobID, now);
    this.persist();
    return result;
  }

  markNotificationJobFailed(jobID, reason, now = new Date()) {
    const result = super.markNotificationJobFailed(jobID, reason, now);
    this.persist();
    return result;
  }

  upgradeAccount(accountID, input, now = new Date()) {
    const result = super.upgradeAccount(accountID, input, now);
    this.persist();
    return result;
  }

  deleteAccount(accountID, input = {}, now = new Date()) {
    const result = super.deleteAccount(accountID, input, now);
    this.persist();
    return result;
  }

  verifyIAPTransaction(accountID, input = {}, now = new Date()) {
    const result = super.verifyIAPTransaction(accountID, input, now);
    this.persist();
    return result;
  }

  createSMSChallenge(accountID, input = {}, now = new Date(), code = "123456") {
    const result = super.createSMSChallenge(accountID, input, now, code);
    this.persist();
    return result;
  }

  verifySMSChallenge(accountID, input = {}, now = new Date()) {
    const result = super.verifySMSChallenge(accountID, input, now);
    this.persist();
    return result;
  }

  persist() {
    fs.mkdirSync(path.dirname(this.filePath), { recursive: true });
    const tempPath = `${this.filePath}.tmp`;
    fs.writeFileSync(tempPath, JSON.stringify(this.snapshot(), null, 2), "utf8");
    fs.renameSync(tempPath, this.filePath);
  }
}

function stringOrNull(value) {
  if (typeof value !== "string") {
    return null;
  }
  const trimmed = value.trim();
  return trimmed.length > 0 ? trimmed : null;
}

function requiredString(value, fieldName) {
  if (typeof value !== "string" || value.trim().length === 0) {
    throw new ValidationError(`${fieldName} is required`);
  }
  return value.trim();
}

function requiredNumber(value, fieldName) {
  const number = Number(value);
  if (!Number.isFinite(number) || number < 0) {
    throw new ValidationError(`${fieldName} is invalid`);
  }
  return number;
}

function enumValue(value, allowedValues, defaultValue, fieldName) {
  if (value === undefined || value === null || value === "") {
    return defaultValue;
  }
  if (typeof value !== "string" || !allowedValues.includes(value)) {
    throw new ValidationError(`${fieldName} is invalid`);
  }
  return value;
}

function requiredEnumValue(value, allowedValues, fieldName) {
  if (typeof value !== "string" || !allowedValues.includes(value)) {
    throw new ValidationError(`${fieldName} is invalid`);
  }
  return value;
}

function publicAccount(account) {
  return {
    id: account.id,
    auth_method: account.auth_method,
    created_at: account.created_at,
    upgraded_at: account.upgraded_at ?? null,
    deleted_at: account.deleted_at ?? null
  };
}

function publicSubscription(subscription) {
  return {
    id: subscription.id,
    transaction_id: subscription.transaction_id,
    original_transaction_id: subscription.original_transaction_id,
    product_id: subscription.product_id,
    plan: subscription.plan,
    amount: subscription.amount,
    currency: subscription.currency,
    environment: subscription.environment,
    status: subscription.status,
    created_at: subscription.created_at
  };
}

function publicSMSChallenge(challenge) {
  return {
    id: challenge.id,
    status: challenge.status,
    phone_country_code: challenge.phone_country_code,
    expires_at: challenge.expires_at,
    resend_available_at: challenge.resend_available_at,
    max_attempts: challenge.max_attempts
  };
}

function publicVerifiedSMSChallenge(challenge) {
  return {
    ...publicSMSChallenge(challenge),
    verified_at: challenge.verified_at,
    provider_user_hash: challenge.phone_hash
  };
}

function recoveryDeadline(deletedAt) {
  const deadline = new Date(deletedAt);
  deadline.setUTCDate(deadline.getUTCDate() + 30);
  return deadline.toISOString();
}

function defaultHeadline(text) {
  const value = requiredString(text, "text");
  return value.length > 28 ? `${value.slice(0, 28)}...` : value;
}

function canUseSameFlightContext(context, accountID) {
  return (
    context?.account_id === accountID &&
    context.verification_status === "verified" &&
    typeof context.flight_number_hash === "string" &&
    context.flight_number_hash.length > 0 &&
    typeof context.departure_date === "string" &&
    context.departure_date.length > 0
  );
}

function sameFlightKeyMatches(left, right) {
  if (!left || !right || !left.flight_number_hash || !right.flight_number_hash || !left.departure_date || !right.departure_date) {
    return false;
  }
  if (left.flight_number_hash !== right.flight_number_hash || left.departure_date !== right.departure_date) {
    return false;
  }
  if (left.route && right.route && left.route !== right.route) {
    return false;
  }
  return true;
}

function isBlockedBetween(blocks, viewerAccountID, authorAccountID) {
  return blocks.has(`${viewerAccountID}:${authorAccountID}`) || blocks.has(`${authorAccountID}:${viewerAccountID}`);
}

function validClientIDOrRandom(value) {
  if (typeof value === "string" && UUID_PATTERN.test(value)) {
    return value;
  }
  return crypto.randomUUID();
}

function normalizePhoneNumber(value, countryCode) {
  const digits = requiredString(value, "phone").replace(/\D/g, "");
  if (countryCode === "+86" && !/^1\d{10}$/.test(digits)) {
    throw new ValidationError("phone is invalid");
  }
  if (digits.length < 6 || digits.length > 16) {
    throw new ValidationError("phone is invalid");
  }
  return digits;
}

function hashPhone(countryCode, phoneDigits) {
  return crypto.createHash("sha256").update(`phone:${countryCode}:${phoneDigits}`).digest("hex");
}

function hashSMSCode(challengeID, code) {
  return crypto.createHash("sha256").update(`${challengeID}:${String(code).trim()}`).digest("hex");
}

function loadMap(map, rows = []) {
  if (!Array.isArray(rows)) {
    return;
  }
  for (const row of rows) {
    if (row?.id) {
      map.set(row.id, row);
    }
  }
}

function readSnapshot(filePath) {
  if (!fs.existsSync(filePath)) {
    return {};
  }
  return JSON.parse(fs.readFileSync(filePath, "utf8"));
}

export class ValidationError extends Error {
  constructor(message) {
    super(message);
    this.name = "ValidationError";
  }
}

export class ForbiddenError extends Error {
  constructor(message) {
    super(message);
    this.name = "ForbiddenError";
  }
}

export class RateLimitError extends Error {
  constructor(message) {
    super(message);
    this.name = "RateLimitError";
  }
}

export class NotFoundError extends Error {
  constructor(message) {
    super(message);
    this.name = "NotFoundError";
  }
}
