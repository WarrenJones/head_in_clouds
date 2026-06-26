import assert from "node:assert/strict";
import test from "node:test";
import { once } from "node:events";
import { InMemoryAppStore, ValidationError } from "../src/app-store.mjs";
import { InMemoryEventStore } from "../src/event-store.mjs";
import { createServer } from "../src/server.mjs";

const ACCOUNT_A = "11111111-1111-4111-8111-111111111111";
const ACCOUNT_B = "22222222-2222-4222-8222-222222222222";
const TEST_BUNDLE_ID = process.env.IOS_BUNDLE_ID ?? process.env.APNS_BUNDLE_ID ?? "com.headintheclouds.app";

test("protected write endpoints reject unauthenticated requests", async () => {
  const { server, baseURL } = await startTestServer();
  try {
    for (const path of ["/api/accounts/upgrade", "/api/accounts/delete", "/api/auth/sms/send", "/api/auth/sms/verify", "/api/auth/wechat/exchange", "/api/iap/transactions/verify", "/api/share-cards/render", "/api/posts/create", "/api/flight-proof/create", "/api/comments/create", "/api/blocks/create", "/api/push-tokens/register"]) {
      const response = await fetch(`${baseURL}${path}`, {
        method: "POST",
        headers: { "content-type": "application/json" },
        body: JSON.stringify({})
      });
      assert.equal(response.status, 401, `${path} should reject missing token`);
    }
  } finally {
    server.close();
  }
});

test("SMS verification is explicit-provider only and rate limits invalid codes", async () => {
  const previousProvider = process.env.HIC_SMS_PROVIDER;
  const previousCode = process.env.HIC_SMS_MOCK_CODE;
  const { server, baseURL } = await startTestServer();
  try {
    delete process.env.HIC_SMS_PROVIDER;
    const disabled = await fetch(`${baseURL}/api/auth/sms/send`, {
      method: "POST",
      headers: jsonAuthHeaders(ACCOUNT_A),
      body: JSON.stringify({
        phone_country_code: "+86",
        phone: "13800138000"
      })
    });
    assert.equal(disabled.status, 400);

    process.env.HIC_SMS_PROVIDER = "mock";
    process.env.HIC_SMS_MOCK_CODE = "654321";
    const sent = await requestJSON(baseURL, "/api/auth/sms/send", {
      accountID: ACCOUNT_A,
      body: {
        phone_country_code: "+86",
        phone: "13800138000"
      }
    });
    assert.equal(sent.delivery.provider, "mock");
    assert.equal(sent.delivery.status, "mocked");
    assert.equal(sent.sms_challenge.status, "pending");
    assert.equal(sent.sms_challenge.max_attempts, 3);
    assert.equal(sent.sms_challenge.provider_user_hash, undefined);

    const invalid = await fetch(`${baseURL}/api/auth/sms/verify`, {
      method: "POST",
      headers: jsonAuthHeaders(ACCOUNT_A),
      body: JSON.stringify({
        challenge_id: sent.sms_challenge.id,
        code: "000000"
      })
    });
    assert.equal(invalid.status, 400);

    const verified = await requestJSON(baseURL, "/api/auth/sms/verify", {
      accountID: ACCOUNT_A,
      body: {
        challenge_id: sent.sms_challenge.id,
        code: "654321"
      }
    });
    assert.equal(verified.sms_challenge.status, "verified");
    assert.ok(verified.sms_challenge.provider_user_hash);

    const locked = await requestJSON(baseURL, "/api/auth/sms/send", {
      accountID: ACCOUNT_B,
      body: {
        phone_country_code: "+86",
        phone: "13900139000"
      }
    });
    for (let attempt = 0; attempt < 2; attempt += 1) {
      const response = await fetch(`${baseURL}/api/auth/sms/verify`, {
        method: "POST",
        headers: jsonAuthHeaders(ACCOUNT_B),
        body: JSON.stringify({
          challenge_id: locked.sms_challenge.id,
          code: "111111"
        })
      });
      assert.equal(response.status, 400);
    }
    const rateLimited = await fetch(`${baseURL}/api/auth/sms/verify`, {
      method: "POST",
      headers: jsonAuthHeaders(ACCOUNT_B),
      body: JSON.stringify({
        challenge_id: locked.sms_challenge.id,
        code: "111111"
      })
    });
    assert.equal(rateLimited.status, 429);
  } finally {
    if (previousProvider === undefined) {
      delete process.env.HIC_SMS_PROVIDER;
    } else {
      process.env.HIC_SMS_PROVIDER = previousProvider;
    }
    if (previousCode === undefined) {
      delete process.env.HIC_SMS_MOCK_CODE;
    } else {
      process.env.HIC_SMS_MOCK_CODE = previousCode;
    }
    server.close();
  }
});

test("IAP transaction verification is idempotent and writes server subscription event", async () => {
  const appStore = new InMemoryAppStore();
  const eventStore = new InMemoryEventStore();
  const { server, baseURL } = await startTestServer({ appStore, eventStore });
  try {
    const payload = {
      transaction_id: "local-tx-001",
      original_transaction_id: "local-original-001",
      product_id: "hic.postcard.plus",
      plan: "postcard_plus",
      amount: 12,
      currency: "CNY",
      environment: "local_mock",
      smoke_run_id: "iap-smoke-test"
    };

    const first = await requestJSON(baseURL, "/api/iap/transactions/verify", {
      accountID: ACCOUNT_A,
      body: payload
    });
    const retry = await requestJSON(baseURL, "/api/iap/transactions/verify", {
      accountID: ACCOUNT_A,
      body: payload
    });
    const crossAccount = await fetch(`${baseURL}/api/iap/transactions/verify`, {
      method: "POST",
      headers: jsonAuthHeaders(ACCOUNT_B),
      body: JSON.stringify(payload)
    });

    assert.equal(first.created, true);
    assert.equal(retry.created, false);
    assert.equal(first.subscription.transaction_id, "local-tx-001");
    assert.equal(first.subscription.plan, "postcard_plus");
    assert.equal(first.subscription.amount, 12);
    assert.equal(crossAccount.status, 403);
    assert.equal(eventStore.events.length, 1);
    assert.equal(eventStore.events[0].event_name, "subscription_created");
    assert.equal(eventStore.events[0].platform, "server");
    assert.equal(eventStore.events[0].properties.plan, "postcard_plus");
    assert.equal(eventStore.events[0].properties.currency, "CNY");
    assert.equal(eventStore.events[0].properties.smoke_run_id, "iap-smoke-test");
    assert.equal(eventStore.events[0].properties.$lib, "server");
    assert.ok(eventStore.events[0].user_id_hash);
  } finally {
    server.close();
  }
});

test("IAP sandbox or production verification requires StoreKit signed transaction JWS", async () => {
  const { server, baseURL } = await startTestServer();
  try {
    const missingSignedJWS = await fetch(`${baseURL}/api/iap/transactions/verify`, {
      method: "POST",
      headers: jsonAuthHeaders(ACCOUNT_A),
      body: JSON.stringify({
        transaction_id: "sandbox-tx-001",
        product_id: "hic.postcard.plus",
        plan: "postcard_plus",
        amount: 12,
        currency: "CNY",
        environment: "sandbox"
      })
    });
    const accepted = await requestJSON(baseURL, "/api/iap/transactions/verify", {
      accountID: ACCOUNT_A,
      body: {
        transaction_id: "sandbox-tx-001",
        original_transaction_id: "sandbox-original-001",
        product_id: "hic.postcard.plus",
        plan: "postcard_plus",
        amount: 12,
        currency: "CNY",
        environment: "sandbox",
        signed_transaction_jws: makeStoreKitJWS({
          transactionId: "sandbox-tx-001",
          originalTransactionId: "sandbox-original-001",
          productId: "hic.postcard.plus",
          bundleId: TEST_BUNDLE_ID,
          environment: "Sandbox"
        })
      }
    });

    assert.equal(missingSignedJWS.status, 400);
    assert.equal(accepted.subscription.environment, "sandbox");
    assert.equal(accepted.created, true);
  } finally {
    server.close();
  }
});

test("IAP sandbox verification rejects placeholder StoreKit JWS strings", async () => {
  const { server, baseURL } = await startTestServer();
  try {
    const response = await fetch(`${baseURL}/api/iap/transactions/verify`, {
      method: "POST",
      headers: jsonAuthHeaders(ACCOUNT_A),
      body: JSON.stringify({
        transaction_id: "placeholder-jws-tx-001",
        product_id: "hic.postcard.plus",
        environment: "sandbox",
        signed_transaction_jws: "header.payload.signature"
      })
    });

    assert.equal(response.status, 400);
  } finally {
    server.close();
  }
});

test("IAP transaction verification rejects product catalog mismatches", async () => {
  const { server, baseURL } = await startTestServer();
  try {
    const tamperedAmount = await fetch(`${baseURL}/api/iap/transactions/verify`, {
      method: "POST",
      headers: jsonAuthHeaders(ACCOUNT_A),
      body: JSON.stringify({
        transaction_id: "tampered-tx-001",
        product_id: "hic.postcard.plus",
        plan: "postcard_plus",
        amount: 1,
        currency: "CNY",
        environment: "local_mock"
      })
    });
    const unknownProduct = await fetch(`${baseURL}/api/iap/transactions/verify`, {
      method: "POST",
      headers: jsonAuthHeaders(ACCOUNT_A),
      body: JSON.stringify({
        transaction_id: "unknown-tx-001",
        product_id: "unknown.product",
        environment: "local_mock"
      })
    });

    assert.equal(tamperedAmount.status, 400);
    assert.equal(unknownProduct.status, 400);
  } finally {
    server.close();
  }
});

test("account upgrade merges guest data into existing provider account", async () => {
  const { server, baseURL } = await startTestServer();
  try {
    const upgradedA = await requestJSON(baseURL, "/api/accounts/upgrade", {
      accountID: ACCOUNT_A,
      body: {
        method: "phone",
        provider_user_hash: "phone-hash-a"
      }
    });
    assert.equal(upgradedA.account.id, ACCOUNT_A);
    assert.equal(upgradedA.account.auth_method, "phone");
    assert.equal(upgradedA.account.phone_hash, undefined);
    assert.equal(upgradedA.merge.merged_with_existing, false);

    const createdAsB = await requestJSON(baseURL, "/api/posts/create", {
      accountID: ACCOUNT_B,
      body: {
        text: "换手机之前写下的一句话。",
        publish_scope: "private_card"
      }
    });

    const merged = await requestJSON(baseURL, "/api/accounts/upgrade", {
      accountID: ACCOUNT_B,
      body: {
        method: "phone",
        provider_user_hash: "phone-hash-a"
      }
    });

    assert.equal(merged.account.id, ACCOUNT_A);
    assert.equal(merged.merge.merged_with_existing, true);
    assert.equal(merged.merge.previous_account_id, ACCOUNT_B);
    assert.equal(merged.merge.merged_post_count, 1);

    const readAsA = await fetch(`${baseURL}/api/posts/${createdAsB.post.id}`, {
      headers: authHeaders(ACCOUNT_A)
    });
    assert.equal(readAsA.status, 200);

    const readAsB = await fetch(`${baseURL}/api/posts/${createdAsB.post.id}`, {
      headers: authHeaders(ACCOUNT_B)
    });
    assert.equal(readAsB.status, 404);
  } finally {
    server.close();
  }
});

test("WeChat exchange endpoint upgrades account without exposing raw provider ids", async () => {
  const previousProvider = process.env.HIC_WECHAT_PROVIDER;
  const previousAppID = process.env.HIC_WECHAT_APP_ID;
  const previousSecret = process.env.HIC_WECHAT_APP_SECRET;
  const previousFetch = globalThis.fetch;
  const appStore = new InMemoryAppStore();
  const { server, baseURL } = await startTestServer({ appStore });
  let capturedURL;

  globalThis.fetch = async (url, request) => {
    if (!String(url).includes("api.weixin.qq.com")) {
      return previousFetch(url, request);
    }
    capturedURL = String(url);
    return new Response(JSON.stringify({
      access_token: "access-token",
      expires_in: 7200,
      refresh_token: "refresh-token",
      openid: "openid-raw",
      unionid: "unionid-raw",
      scope: "snsapi_userinfo"
    }), {
      status: 200,
      headers: { "content-type": "application/json" }
    });
  };

  try {
    process.env.HIC_WECHAT_PROVIDER = "wechat";
    process.env.HIC_WECHAT_APP_ID = "wx-app-id";
    process.env.HIC_WECHAT_APP_SECRET = "wx-secret";

    const exchanged = await requestJSON(baseURL, "/api/auth/wechat/exchange", {
      accountID: ACCOUNT_A,
      body: {
        code: "auth-code"
      }
    });
    const rawBody = JSON.stringify(exchanged);
    const storedAccount = appStore.accounts.get(ACCOUNT_A);

    assert.match(capturedURL, /api\.weixin\.qq\.com\/sns\/oauth2\/access_token/);
    assert.match(capturedURL, /appid=wx-app-id/);
    assert.match(capturedURL, /code=auth-code/);
    assert.equal(exchanged.provider, "wechat");
    assert.equal(exchanged.account.auth_method, "wechat");
    assert.equal(exchanged.merge.merged_with_existing, false);
    assert.match(storedAccount.wechat_union_id_hash, /^[0-9a-f]{64}$/);
    assert.match(storedAccount.wechat_open_id_hash, /^[0-9a-f]{64}$/);
    assert.ok(!rawBody.includes("openid-raw"));
    assert.ok(!rawBody.includes("unionid-raw"));
    assert.ok(!rawBody.includes("access-token"));
  } finally {
    if (previousProvider === undefined) {
      delete process.env.HIC_WECHAT_PROVIDER;
    } else {
      process.env.HIC_WECHAT_PROVIDER = previousProvider;
    }
    if (previousAppID === undefined) {
      delete process.env.HIC_WECHAT_APP_ID;
    } else {
      process.env.HIC_WECHAT_APP_ID = previousAppID;
    }
    if (previousSecret === undefined) {
      delete process.env.HIC_WECHAT_APP_SECRET;
    } else {
      process.env.HIC_WECHAT_APP_SECRET = previousSecret;
    }
    globalThis.fetch = previousFetch;
    server.close();
  }
});

test("WeChat exchange endpoint fails closed when provider is disabled", async () => {
  const previousProvider = process.env.HIC_WECHAT_PROVIDER;
  const { server, baseURL } = await startTestServer();
  try {
    process.env.HIC_WECHAT_PROVIDER = "disabled";
    const response = await fetch(`${baseURL}/api/auth/wechat/exchange`, {
      method: "POST",
      headers: jsonAuthHeaders(ACCOUNT_A),
      body: JSON.stringify({ code: "auth-code" })
    });

    assert.equal(response.status, 400);
    assert.equal((await response.json()).error, "wechat provider is not configured");
  } finally {
    if (previousProvider === undefined) {
      delete process.env.HIC_WECHAT_PROVIDER;
    } else {
      process.env.HIC_WECHAT_PROVIDER = previousProvider;
    }
    server.close();
  }
});

test("account deletion soft-deletes account and blocks further private access", async () => {
  const appStore = new InMemoryAppStore();
  const { server, baseURL } = await startTestServer({ appStore });
  try {
    await requestJSON(baseURL, "/api/accounts/upgrade", {
      accountID: ACCOUNT_A,
      body: {
        method: "phone",
        provider_user_hash: "phone-hash-a"
      }
    });
    const post = await requestJSON(baseURL, "/api/posts/create", {
      accountID: ACCOUNT_A,
      body: {
        text: "删除前写下的一句话。",
        publish_scope: "private_card"
      }
    });
    const context = await requestJSON(baseURL, "/api/flight-contexts/create", {
      accountID: ACCOUNT_A,
      body: {
        flight_number_hash: "flight-hash",
        route: "SHA -> CTU",
        verification_status: "unverified"
      }
    });
    await requestJSON(baseURL, "/api/notification-jobs/boarding-reminder/create", {
      accountID: ACCOUNT_A,
      body: {
        flight_context_id: context.flight_context.id,
        scheduled_for: "2026-05-21T00:30:00.000Z"
      }
    });
    await requestJSON(baseURL, "/api/push-tokens/register", {
      accountID: ACCOUNT_A,
      body: {
        platform: "ios",
        token: "apns-token-a"
      }
    });

    const wrongReauth = await fetch(`${baseURL}/api/accounts/delete`, {
      method: "POST",
      headers: jsonAuthHeaders(ACCOUNT_A),
      body: JSON.stringify({ reauth_method: "wechat" })
    });
    assert.equal(wrongReauth.status, 403);

    const deleted = await requestJSON(baseURL, "/api/accounts/delete", {
      accountID: ACCOUNT_A,
      body: {
        reauth_method: "phone"
      }
    });

    assert.equal(deleted.account.id, ACCOUNT_A);
    assert.equal(deleted.account.deleted_at, "2026-05-21T00:00:01.000Z");
    assert.equal(deleted.recovery_deadline, "2026-06-20T00:00:01.000Z");
    assert.equal(appStore.pushTokensForAccount(ACCOUNT_A).length, 0);
    assert.equal(Array.from(appStore.notificationJobs.values())[0].status, "cancelled");

    const readDeletedPost = await fetch(`${baseURL}/api/posts/${post.post.id}`, {
      headers: authHeaders(ACCOUNT_A)
    });
    assert.equal(readDeletedPost.status, 403);

    const createAfterDelete = await fetch(`${baseURL}/api/posts/create`, {
      method: "POST",
      headers: jsonAuthHeaders(ACCOUNT_A),
      body: JSON.stringify({
        text: "删除后不应该再写入。",
        publish_scope: "private_card"
      })
    });
    assert.equal(createAfterDelete.status, 403);
  } finally {
    server.close();
  }
});

test("private posts are isolated by account", async () => {
  const { server, baseURL } = await startTestServer();
  try {
    const created = await requestJSON(baseURL, "/api/posts/create", {
      accountID: ACCOUNT_A,
      body: {
        text: "我把没有说出口的话，带过了云层。",
        publish_scope: "private_card"
      }
    });
    const postID = created.post.id;

    const readAsA = await fetch(`${baseURL}/api/posts/${postID}`, {
      headers: authHeaders(ACCOUNT_A)
    });
    assert.equal(readAsA.status, 200);

    const readAsB = await fetch(`${baseURL}/api/posts/${postID}`, {
      headers: authHeaders(ACCOUNT_B)
    });
    assert.equal(readAsB.status, 404);

    const patchAsB = await fetch(`${baseURL}/api/posts/${postID}`, {
      method: "PATCH",
      headers: jsonAuthHeaders(ACCOUNT_B),
      body: JSON.stringify({ text: "should not update" })
    });
    assert.equal(patchAsB.status, 404);

    const deleteAsB = await fetch(`${baseURL}/api/posts/${postID}`, {
      method: "DELETE",
      headers: authHeaders(ACCOUNT_B)
    });
    assert.equal(deleteAsB.status, 404);

    const readAfterBMutation = await requestJSON(baseURL, `/api/posts/${postID}`, {
      accountID: ACCOUNT_A,
      method: "GET"
    });
    assert.equal(readAfterBMutation.post.text, "我把没有说出口的话，带过了云层。");
  } finally {
    server.close();
  }
});

test("public share card endpoint exposes only card-safe fields", async () => {
  const { server, baseURL } = await startTestServer();
  try {
    const context = await requestJSON(baseURL, "/api/flight-contexts/create", {
      accountID: ACCOUNT_A,
      body: {
        flight_number_hash: "flight-hash",
        route: "SHA -> CTU",
        departure_date: "2026-05-21",
        verification_status: "verified"
      }
    });
    const created = await requestJSON(baseURL, "/api/posts/create", {
      accountID: ACCOUNT_A,
      body: {
        flight_context_id: context.flight_context.id,
        text: "我把没有说出口的话，带过了云层。",
        publish_scope: "private_card"
      }
    });

    const response = await fetch(`${baseURL}/share/cards/${created.post.id}`);
    const body = await response.json();

    assert.equal(response.status, 200);
    assert.equal(body.card.post_id, created.post.id);
    assert.equal(body.card.route, "SHA -> CTU");
    assert.equal(body.card.account_id, undefined);
    assert.equal(body.card.flight_proof_id, undefined);
  } finally {
    server.close();
  }
});

test("share card render endpoint uploads owner card SVG through object storage", async () => {
  const uploads = [];
  const objectStorageProvider = {
    async putObject(input) {
      uploads.push(input);
      return {
        provider: "test",
        object_key: input.key,
        public_url: `https://cdn.example/${input.key}`,
        etag: "\"etag-test\""
      };
    }
  };
  const { server, baseURL } = await startTestServer({ objectStorageProvider });
  try {
    const created = await requestJSON(baseURL, "/api/posts/create", {
      accountID: ACCOUNT_A,
      body: {
        text: "我坐在14A，把没有说出口的话带过了云层。",
        headline_quote: "14A窗边的话",
        publish_scope: "private_card"
      }
    });

    const rendered = await requestJSON(baseURL, "/api/share-cards/render", {
      accountID: ACCOUNT_A,
      body: {
        post_id: created.post.id,
        channel: "wechat_moments"
      }
    });
    const crossAccount = await fetch(`${baseURL}/api/share-cards/render`, {
      method: "POST",
      headers: jsonAuthHeaders(ACCOUNT_B),
      body: JSON.stringify({ post_id: created.post.id })
    });

    assert.equal(uploads.length, 1);
    assert.equal(uploads[0].key, `cloud-cards/${created.post.id}.svg`);
    assert.equal(uploads[0].contentType, "image/svg+xml");
    assert.equal(uploads[0].isPublic, true);
    assert.match(uploads[0].body, /某个座位/);
    assert.doesNotMatch(uploads[0].body, /14A/i);
    assert.equal(rendered.share_card.post_id, created.post.id);
    assert.equal(rendered.share_card.share_image_url, `https://cdn.example/cloud-cards/${created.post.id}.svg`);
    assert.equal(rendered.share_card.channel, "wechat_moments");
    assert.equal(crossAccount.status, 404);
  } finally {
    server.close();
  }
});

test("share card render endpoint fails closed when object storage is not configured", async () => {
  const objectStorageProvider = {
    async putObject() {
      throw new ValidationError("object storage provider is not configured");
    }
  };
  const { server, baseURL } = await startTestServer({ objectStorageProvider });
  try {
    const created = await requestJSON(baseURL, "/api/posts/create", {
      accountID: ACCOUNT_A,
      body: {
        text: "这是一张只在配置对象存储后才能上传的卡。",
        publish_scope: "private_card"
      }
    });
    const response = await fetch(`${baseURL}/api/share-cards/render`, {
      method: "POST",
      headers: jsonAuthHeaders(ACCOUNT_A),
      body: JSON.stringify({ post_id: created.post.id })
    });
    const body = await response.json();

    assert.equal(response.status, 400);
    assert.equal(body.error, "object storage provider is not configured");
  } finally {
    server.close();
  }
});

test("public share card endpoint renders HTML landing page for browsers", async () => {
  const { server, baseURL } = await startTestServer();
  try {
    const created = await requestJSON(baseURL, "/api/posts/create", {
      accountID: ACCOUNT_A,
      body: {
        text: "我把没有说出口的话，带过了云层。",
        headline_quote: "我把没有说出口的话，带过了云层。",
        publish_scope: "private_card"
      }
    });

    const response = await fetch(`${baseURL}/share/cards/${created.post.id}`, {
      headers: { accept: "text/html" }
    });
    const html = await response.text();

    assert.equal(response.status, 200);
    assert.match(response.headers.get("content-type"), /text\/html/);
    assert.ok(Buffer.byteLength(html) > 1000);
    assert.match(html, /og:image/);
    assert.match(html, /\/share\/cards\/.+\/og\.svg/);
    assert.match(html, /看同班机笔记/);
    assert.doesNotMatch(html, /App Store/i);
    assert.doesNotMatch(html, /account_id/);
    assert.doesNotMatch(html, /flight_proof_id/);
  } finally {
    server.close();
  }
});

test("public share card OG endpoint renders a non-empty safe SVG image", async () => {
  const { server, baseURL } = await startTestServer();
  try {
    const created = await requestJSON(baseURL, "/api/posts/create", {
      accountID: ACCOUNT_A,
      body: {
        text: "飞机晚点了，累死。",
        headline_quote: "飞机晚点了，累死。",
        publish_scope: "private_card"
      }
    });

    const response = await fetch(`${baseURL}/share/cards/${created.post.id}/og.svg`);
    const svg = await response.text();

    assert.equal(response.status, 200);
    assert.match(response.headers.get("content-type"), /image\/svg\+xml/);
    assert.ok(Buffer.byteLength(svg) > 1000);
    assert.match(svg, /HEAD IN THE CLOUDS/);
    assert.doesNotMatch(svg, /account_id/);
    assert.doesNotMatch(svg, /flight_proof_id/);
    assert.doesNotMatch(svg, /14A/);
  } finally {
    server.close();
  }
});

test("same-flight comments require verified context for the same flight", async () => {
  const { server, baseURL } = await startTestServer();
  try {
    const contextA = await requestJSON(baseURL, "/api/flight-contexts/create", {
      accountID: ACCOUNT_A,
      body: {
        flight_number_hash: "flight-hash",
        route: "SHA -> CTU",
        departure_date: "2026-05-21",
        verification_status: "verified"
      }
    });
    const proofA = await requestJSON(baseURL, "/api/flight-proof/create", {
      accountID: ACCOUNT_A,
      body: {
        flight_context_id: contextA.flight_context.id,
        method: "manual",
        source_image_hash: "proof-a"
      }
    });

    const post = await requestJSON(baseURL, "/api/posts/create", {
      accountID: ACCOUNT_A,
      body: {
        flight_context_id: contextA.flight_context.id,
        flight_proof_id: proofA.flight_proof.id,
        text: "今天的云像一封没寄出的信。",
        publish_scope: "same_flight"
      }
    });

    const blocked = await fetch(`${baseURL}/api/comments/create`, {
      method: "POST",
      headers: jsonAuthHeaders(ACCOUNT_B),
      body: JSON.stringify({
        post_id: post.post.id,
        flight_context_id: contextA.flight_context.id,
        body: "我也在这趟航班上。"
      })
    });
    assert.equal(blocked.status, 403);

    const contextB = await requestJSON(baseURL, "/api/flight-contexts/create", {
      accountID: ACCOUNT_B,
      body: {
        flight_number_hash: "flight-hash",
        route: "SHA -> CTU",
        departure_date: "2026-05-21",
        verification_status: "verified"
      }
    });

    const accepted = await requestJSON(baseURL, "/api/comments/create", {
      accountID: ACCOUNT_B,
      body: {
        post_id: post.post.id,
        flight_context_id: contextB.flight_context.id,
        body: "我也在这趟航班上。"
      }
    });

    assert.equal(accepted.comment.post_id, post.post.id);
    assert.equal(accepted.comment.account_id, ACCOUNT_B);
  } finally {
    server.close();
  }
});

test("same-flight post only enqueues notifications for verified same-flight accounts", async () => {
  const appStore = new InMemoryAppStore();
  const { server, baseURL } = await startTestServer({ appStore });
  try {
    const authorContext = await requestJSON(baseURL, "/api/flight-contexts/create", {
      accountID: ACCOUNT_A,
      body: {
        flight_number_hash: "flight-hash",
        route: "SHA -> CTU",
        departure_date: "2026-05-21",
        verification_status: "verified"
      }
    });
    const authorProof = await requestJSON(baseURL, "/api/flight-proof/create", {
      accountID: ACCOUNT_A,
      body: {
        flight_context_id: authorContext.flight_context.id,
        method: "manual",
        source_image_hash: "author-proof"
      }
    });

    await requestJSON(baseURL, "/api/flight-contexts/create", {
      accountID: ACCOUNT_B,
      body: {
        flight_number_hash: "flight-hash",
        route: "SHA -> CTU",
        departure_date: "2026-05-21",
        verification_status: "verified"
      }
    });

    await requestJSON(baseURL, "/api/flight-contexts/create", {
      accountID: "33333333-3333-4333-8333-333333333333",
      body: {
        flight_number_hash: "flight-hash",
        route: "SHA -> CTU",
        departure_date: "2026-05-21",
        verification_status: "unverified"
      }
    });

    const post = await requestJSON(baseURL, "/api/posts/create", {
      accountID: ACCOUNT_A,
      body: {
        flight_context_id: authorContext.flight_context.id,
        flight_proof_id: authorProof.flight_proof.id,
        text: "降落前想起了一句话。",
        publish_scope: "same_flight"
      }
    });

    const jobs = Array.from(appStore.notificationJobs.values());
    assert.equal(jobs.length, 1);
    assert.equal(jobs[0].account_id, ACCOUNT_B);
    assert.equal(jobs[0].kind, "same_flight_new_post");
    assert.equal(jobs[0].payload.post_id, post.post.id);
  } finally {
    server.close();
  }
});

test("same-flight publish is rejected without a verified flight context", async () => {
  const { server, baseURL } = await startTestServer();
  try {
    const context = await requestJSON(baseURL, "/api/flight-contexts/create", {
      accountID: ACCOUNT_A,
      body: {
        flight_number_hash: "flight-hash",
        route: "SHA -> CTU",
        departure_date: "2026-05-21",
        verification_status: "unverified"
      }
    });

    const blocked = await fetch(`${baseURL}/api/posts/create`, {
      method: "POST",
      headers: jsonAuthHeaders(ACCOUNT_A),
      body: JSON.stringify({
        flight_context_id: context.flight_context.id,
        text: "未验证不应该进入同班机。",
        publish_scope: "same_flight"
      })
    });

    assert.equal(blocked.status, 403);
  } finally {
    server.close();
  }
});

test("same-flight publish requires a matching flight proof", async () => {
  const { server, baseURL } = await startTestServer();
  try {
    const context = await requestJSON(baseURL, "/api/flight-contexts/create", {
      accountID: ACCOUNT_A,
      body: {
        flight_number_hash: "flight-hash",
        route: "SHA -> CTU",
        departure_date: "2026-05-21",
        verification_status: "verified"
      }
    });

    const missingProof = await fetch(`${baseURL}/api/posts/create`, {
      method: "POST",
      headers: jsonAuthHeaders(ACCOUNT_A),
      body: JSON.stringify({
        flight_context_id: context.flight_context.id,
        text: "没有 proof 不应该进入同班机。",
        publish_scope: "same_flight"
      })
    });
    assert.equal(missingProof.status, 403);

    const proof = await requestJSON(baseURL, "/api/flight-proof/create", {
      accountID: ACCOUNT_A,
      body: {
        flight_context_id: context.flight_context.id,
        method: "manual",
        source_image_hash: "proof-a"
      }
    });
    const accepted = await requestJSON(baseURL, "/api/posts/create", {
      accountID: ACCOUNT_A,
      body: {
        flight_context_id: context.flight_context.id,
        flight_proof_id: proof.flight_proof.id,
        text: "带 proof 的内容可以进入同班机。",
        publish_scope: "same_flight"
      }
    });
    assert.equal(accepted.post.flight_proof_id, proof.flight_proof.id);
  } finally {
    server.close();
  }
});

test("same-flight feed lists only verified same-flight posts with safe fields", async () => {
  const { server, baseURL } = await startTestServer();
  try {
    const viewerContext = await requestJSON(baseURL, "/api/flight-contexts/create", {
      accountID: ACCOUNT_A,
      body: {
        flight_number_hash: "flight-hash",
        route: "SHA -> CTU",
        departure_date: "2026-05-21",
        verification_status: "verified"
      }
    });
    const authorContext = await requestJSON(baseURL, "/api/flight-contexts/create", {
      accountID: ACCOUNT_B,
      body: {
        flight_number_hash: "flight-hash",
        route: "SHA -> CTU",
        departure_date: "2026-05-21",
        verification_status: "verified"
      }
    });
    const authorProof = await requestJSON(baseURL, "/api/flight-proof/create", {
      accountID: ACCOUNT_B,
      body: {
        flight_context_id: authorContext.flight_context.id,
        method: "manual",
        source_image_hash: "author-proof"
      }
    });
    const otherFlightContext = await requestJSON(baseURL, "/api/flight-contexts/create", {
      accountID: "33333333-3333-4333-8333-333333333333",
      body: {
        flight_number_hash: "other-flight-hash",
        route: "SHA -> PEK",
        departure_date: "2026-05-21",
        verification_status: "verified"
      }
    });
    const otherFlightProof = await requestJSON(baseURL, "/api/flight-proof/create", {
      accountID: "33333333-3333-4333-8333-333333333333",
      body: {
        flight_context_id: otherFlightContext.flight_context.id,
        method: "manual",
        source_image_hash: "other-proof"
      }
    });

    const visiblePost = await requestJSON(baseURL, "/api/posts/create", {
      accountID: ACCOUNT_B,
      body: {
        flight_context_id: authorContext.flight_context.id,
        flight_proof_id: authorProof.flight_proof.id,
        text: "我把没有说出口的话，带过了云层。",
        headline_quote: "我把没有说出口的话，带过了云层。",
        publish_scope: "same_flight"
      }
    });
    await requestJSON(baseURL, "/api/posts/create", {
      accountID: "33333333-3333-4333-8333-333333333333",
      body: {
        flight_context_id: otherFlightContext.flight_context.id,
        flight_proof_id: otherFlightProof.flight_proof.id,
        text: "另一趟飞机上的内容。",
        publish_scope: "same_flight"
      }
    });
    await requestJSON(baseURL, "/api/comments/create", {
      accountID: ACCOUNT_A,
      body: {
        post_id: visiblePost.post.id,
        flight_context_id: viewerContext.flight_context.id,
        body: "我也在这趟航班上。"
      }
    });

    const response = await fetch(`${baseURL}/api/flight-spaces/${viewerContext.flight_context.id}/posts`, {
      headers: authHeaders(ACCOUNT_A)
    });
    const body = await response.json();

    assert.equal(response.status, 200);
    assert.equal(body.posts.length, 1);
    assert.equal(body.posts[0].id, visiblePost.post.id);
    assert.equal(body.posts[0].headline_quote, "我把没有说出口的话，带过了云层。");
    assert.equal(body.posts[0].public_identity_label, "同机乘客");
    assert.equal(body.posts[0].comment_count, 1);
    assert.equal(body.posts[0].account_id, undefined);
    assert.equal(body.posts[0].flight_proof_id, undefined);
  } finally {
    server.close();
  }
});

test("same-flight feed rejects unverified or cross-account flight contexts", async () => {
  const { server, baseURL } = await startTestServer();
  try {
    const context = await requestJSON(baseURL, "/api/flight-contexts/create", {
      accountID: ACCOUNT_A,
      body: {
        flight_number_hash: "flight-hash",
        route: "SHA -> CTU",
        departure_date: "2026-05-21",
        verification_status: "unverified"
      }
    });

    const unverified = await fetch(`${baseURL}/api/flight-spaces/${context.flight_context.id}/posts`, {
      headers: authHeaders(ACCOUNT_A)
    });
    assert.equal(unverified.status, 403);

    const crossAccount = await fetch(`${baseURL}/api/flight-spaces/${context.flight_context.id}/posts`, {
      headers: authHeaders(ACCOUNT_B)
    });
    assert.equal(crossAccount.status, 404);
  } finally {
    server.close();
  }
});

test("boarding reminder job is scoped to the owner flight context", async () => {
  const { server, baseURL } = await startTestServer();
  try {
    const context = await requestJSON(baseURL, "/api/flight-contexts/create", {
      accountID: ACCOUNT_A,
      body: {
        flight_number_hash: "flight-hash",
        route: "SHA -> CTU",
        verification_status: "unverified"
      }
    });

    const blocked = await fetch(`${baseURL}/api/notification-jobs/boarding-reminder/create`, {
      method: "POST",
      headers: jsonAuthHeaders(ACCOUNT_B),
      body: JSON.stringify({
        flight_context_id: context.flight_context.id,
        scheduled_for: "2026-05-21T00:30:00.000Z"
      })
    });
    assert.equal(blocked.status, 404);

    const accepted = await requestJSON(baseURL, "/api/notification-jobs/boarding-reminder/create", {
      accountID: ACCOUNT_A,
      body: {
        flight_context_id: context.flight_context.id,
        scheduled_for: "2026-05-21T00:30:00.000Z",
        reminder_offset_minutes: 30
      }
    });

    assert.equal(accepted.notification_job.kind, "boarding_reminder");
    assert.equal(accepted.notification_job.account_id, ACCOUNT_A);
    assert.equal(accepted.notification_job.flight_context_id, context.flight_context.id);
    assert.equal(accepted.notification_job.payload.flight_number_hash, "flight-hash");
  } finally {
    server.close();
  }
});

test("client-generated post ids make offline retries idempotent", async () => {
  const { server, baseURL } = await startTestServer();
  try {
    const postID = "44444444-4444-4444-8444-444444444444";
    const body = {
      id: postID,
      text: "离线写下的一句话。",
      publish_scope: "private_card"
    };

    const first = await requestJSON(baseURL, "/api/posts/create", {
      accountID: ACCOUNT_A,
      body
    });
    const retry = await requestJSON(baseURL, "/api/posts/create", {
      accountID: ACCOUNT_A,
      body
    });

    assert.equal(first.post.id, postID);
    assert.equal(retry.post.id, postID);
    assert.equal(retry.post.created_at, first.post.created_at);

    const blocked = await fetch(`${baseURL}/api/posts/create`, {
      method: "POST",
      headers: jsonAuthHeaders(ACCOUNT_B),
      body: JSON.stringify(body)
    });
    assert.equal(blocked.status, 404);
  } finally {
    server.close();
  }
});

test("post enum fields must use server contract values", async () => {
  const { server, baseURL } = await startTestServer();
  try {
    const invalid = await fetch(`${baseURL}/api/posts/create`, {
      method: "POST",
      headers: jsonAuthHeaders(ACCOUNT_A),
      body: JSON.stringify({
        text: "错误枚举不应该被静默写入。",
        publish_scope: "privateCard"
      })
    });
    assert.equal(invalid.status, 400);

    const valid = await requestJSON(baseURL, "/api/posts/create", {
      accountID: ACCOUNT_A,
      body: {
        text: "正确枚举可以写入。",
        publish_scope: "private_card",
        text_mode: "one_line",
        offline_status: "synced"
      }
    });
    assert.equal(valid.post.publish_scope, "private_card");
    assert.equal(valid.post.text_mode, "one_line");
    assert.equal(valid.post.offline_status, "synced");
  } finally {
    server.close();
  }
});

test("App Store Server Notification records server event and subscription without client bearer", async () => {
  const appStore = new InMemoryAppStore();
  const eventStore = new InMemoryEventStore();
  const { server, baseURL } = await startTestServer({ appStore, eventStore });
  try {
    const signedTransactionInfo = makeStoreKitJWS({
      transactionId: "app-store-server-tx-001",
      originalTransactionId: "app-store-server-original-001",
      productId: "hic.postcard.plus",
      bundleId: TEST_BUNDLE_ID,
      environment: "Sandbox",
      appAccountToken: ACCOUNT_A
    });
    const signedPayload = makeStoreKitJWS({
      notificationType: "SUBSCRIBED",
      subtype: "INITIAL_BUY",
      notificationUUID: "33333333-3333-4333-8333-333333333333",
      version: "2.0",
      signedDate: 1770000000000,
      data: {
        bundleId: TEST_BUNDLE_ID,
        environment: "Sandbox",
        signedTransactionInfo
      }
    });

    const response = await fetch(`${baseURL}/api/iap/app-store/notifications`, {
      method: "POST",
      headers: { "content-type": "application/json" },
      body: JSON.stringify({ signedPayload })
    });
    const body = await response.json();

    assert.equal(response.status, 200);
    assert.equal(body.notification.notification_type, "SUBSCRIBED");
    assert.equal(body.notification.account_linked, true);
    assert.equal(body.subscription_created, true);
    assert.equal(body.subscription.transaction_id, "app-store-server-tx-001");
    assert.equal(body.subscription.plan, "postcard_plus");
    assert.equal(eventStore.events.length, 2);
    assert.deepEqual(eventStore.events.map((event) => event.event_name), [
      "app_store_server_notification_received",
      "subscription_created"
    ]);
    assert.equal(eventStore.events[0].properties.account_linked, "true");
    assert.equal(eventStore.events[1].properties.source, "app_store_server_notification");
    assert.equal(eventStore.events[1].properties.$lib, "server");
  } finally {
    server.close();
  }
});

test("App Store Server Notification fails closed for invalid signed payloads", async () => {
  const { server, baseURL } = await startTestServer();
  try {
    const response = await fetch(`${baseURL}/api/iap/app-store/notifications`, {
      method: "POST",
      headers: { "content-type": "application/json" },
      body: JSON.stringify({ signedPayload: "header.payload.signature" })
    });

    assert.equal(response.status, 400);
  } finally {
    server.close();
  }
});

test("App Store Server Notification does not create active subscription for refund notifications", async () => {
  const appStore = new InMemoryAppStore();
  const eventStore = new InMemoryEventStore();
  const { server, baseURL } = await startTestServer({ appStore, eventStore });
  try {
    const signedTransactionInfo = makeStoreKitJWS({
      transactionId: "refund-tx-001",
      originalTransactionId: "refund-original-001",
      productId: "hic.postcard.plus",
      bundleId: TEST_BUNDLE_ID,
      environment: "Sandbox",
      appAccountToken: ACCOUNT_A
    });
    const signedPayload = makeStoreKitJWS({
      notificationType: "REFUND",
      notificationUUID: "44444444-4444-4444-8444-444444444444",
      data: {
        bundleId: TEST_BUNDLE_ID,
        environment: "Sandbox",
        signedTransactionInfo
      }
    });

    const body = await requestRawJSON(baseURL, "/api/iap/app-store/notifications", {
      body: { signedPayload }
    });

    assert.equal(body.subscription, null);
    assert.equal(body.subscription_created, false);
    assert.equal(eventStore.events.length, 1);
    assert.equal(eventStore.events[0].event_name, "app_store_server_notification_received");
  } finally {
    server.close();
  }
});

test("blocks are account scoped and idempotent", async () => {
  const { server, baseURL } = await startTestServer();
  try {
    const postByB = await requestJSON(baseURL, "/api/posts/create", {
      accountID: ACCOUNT_B,
      body: {
        text: "今天的云像一封没寄出的信。",
        publish_scope: "private_card"
      }
    });
    const postByA = await requestJSON(baseURL, "/api/posts/create", {
      accountID: ACCOUNT_A,
      body: {
        text: "我自己的卡片不能用来屏蔽自己。",
        publish_scope: "private_card"
      }
    });
    const selfBlock = await fetch(`${baseURL}/api/blocks/create`, {
      method: "POST",
      headers: jsonAuthHeaders(ACCOUNT_A),
      body: JSON.stringify({ blocked_account_id: ACCOUNT_A })
    });
    const selfBlockByPost = await fetch(`${baseURL}/api/blocks/create`, {
      method: "POST",
      headers: jsonAuthHeaders(ACCOUNT_A),
      body: JSON.stringify({ post_id: postByA.post.id })
    });
    assert.equal(selfBlock.status, 400);
    assert.equal(selfBlockByPost.status, 400);

    const first = await requestJSON(baseURL, "/api/blocks/create", {
      accountID: ACCOUNT_A,
      body: { blocked_account_id: ACCOUNT_B }
    });
    const retry = await requestJSON(baseURL, "/api/blocks/create", {
      accountID: ACCOUNT_A,
      body: { blocked_account_id: ACCOUNT_B }
    });

    assert.equal(first.block.account_id, ACCOUNT_A);
    assert.equal(first.block.blocked_account_id, ACCOUNT_B);
    assert.equal(retry.block.id, first.block.id);
    assert.equal(retry.block.created_at, first.block.created_at);

    const byPost = await requestJSON(baseURL, "/api/blocks/create", {
      accountID: ACCOUNT_A,
      body: { post_id: postByB.post.id }
    });
    assert.equal(byPost.block.blocked_account_id, ACCOUNT_B);
    assert.equal(byPost.block.id, first.block.id);
  } finally {
    server.close();
  }
});

test("push token registration is authenticated and idempotent", async () => {
  const { server, baseURL } = await startTestServer();
  try {
    const first = await requestJSON(baseURL, "/api/push-tokens/register", {
      accountID: ACCOUNT_A,
      body: {
        platform: "ios",
        token: "apns-token-a"
      }
    });
    const retry = await requestJSON(baseURL, "/api/push-tokens/register", {
      accountID: ACCOUNT_A,
      body: {
        platform: "ios",
        token: "apns-token-a"
      }
    });

    assert.equal(first.push_token.account_id, ACCOUNT_A);
    assert.equal(first.push_token.platform, "ios");
    assert.equal(first.push_token.token, "apns-token-a");
    assert.equal(retry.push_token.id, first.push_token.id);

    const invalid = await fetch(`${baseURL}/api/push-tokens/register`, {
      method: "POST",
      headers: jsonAuthHeaders(ACCOUNT_A),
      body: JSON.stringify({ platform: "web", token: "token" })
    });
    assert.equal(invalid.status, 400);
  } finally {
    server.close();
  }
});

async function startTestServer({ appStore = new InMemoryAppStore(), eventStore = undefined, objectStorageProvider = undefined } = {}) {
  const server = createServer({
    appStore,
    store: eventStore,
    objectStorageProvider,
    now: () => new Date("2026-05-21T00:00:01.000Z")
  });
  server.listen(0, "127.0.0.1");
  await once(server, "listening");
  const { port } = server.address();
  return { server, baseURL: `http://127.0.0.1:${port}` };
}

async function requestJSON(baseURL, path, { accountID, method = "POST", body } = {}) {
  const response = await fetch(`${baseURL}${path}`, {
    method,
    headers: jsonAuthHeaders(accountID),
    body: body === undefined ? undefined : JSON.stringify(body)
  });
  assert.ok(response.status >= 200 && response.status < 300, `${path} returned ${response.status}`);
  return response.json();
}

async function requestRawJSON(baseURL, path, { method = "POST", body } = {}) {
  const response = await fetch(`${baseURL}${path}`, {
    method,
    headers: { "content-type": "application/json" },
    body: body === undefined ? undefined : JSON.stringify(body)
  });
  assert.ok(response.status >= 200 && response.status < 300, `${path} returned ${response.status}`);
  return response.json();
}

function authHeaders(accountID) {
  return { authorization: `Bearer ${accountID}` };
}

function jsonAuthHeaders(accountID) {
  return {
    ...authHeaders(accountID),
    "content-type": "application/json"
  };
}

function makeStoreKitJWS(payload, headerOverrides = {}) {
  const header = {
    alg: "ES256",
    x5c: ["test-certificate"],
    ...headerOverrides
  };
  return [
    base64URLJSON(header),
    base64URLJSON(payload),
    "test-signature"
  ].join(".");
}

function base64URLJSON(value) {
  return Buffer.from(JSON.stringify(value), "utf8")
    .toString("base64")
    .replace(/=/g, "")
    .replace(/\+/g, "-")
    .replace(/\//g, "_");
}
