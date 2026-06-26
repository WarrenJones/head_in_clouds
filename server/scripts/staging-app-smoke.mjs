import assert from "node:assert/strict";
import crypto from "node:crypto";

const baseURL = cleanURL(process.env.HIC_STAGING_BASE_URL ?? process.env.HIC_API_BASE_URL ?? "http://127.0.0.1:8787");
const accountID = process.env.HIC_STAGING_ACCOUNT_ID ?? "33333333-3333-4333-8333-333333333333";
const smokeRunID = process.env.HIC_APP_SMOKE_RUN_ID ?? `app-smoke-${Date.now()}-${crypto.randomUUID().slice(0, 8)}`;
const flightContextID = deterministicUUID("flight", smokeRunID);
const postID = deterministicUUID("post", smokeRunID);

const flightContext = await postJSON("/api/flight-contexts/create", {
  id: flightContextID,
  flight_number_hash: sha256("MU5301"),
  route: "SHA → CTU",
  departure_date: "2026-06-15",
  verification_status: "unverified"
}, 201);
assert.equal(flightContext.flight_context.id, flightContextID);

const post = await postJSON("/api/posts/create", {
  id: postID,
  flight_context_id: flightContextID,
  publish_scope: "private_card",
  text: `staging app smoke ${smokeRunID}`,
  headline_quote: "我把没有说出口的话，带过了云层。",
  text_mode: "one_line",
  card_template_id: "boarding_postcard",
  offline_status: "synced"
}, 201);
assert.equal(post.post.id, postID);

const ownPost = await getJSON(`/api/posts/${postID}`);
assert.equal(ownPost.post.id, postID);
assert.equal(ownPost.post.account_id, accountID);

const share = await getJSON(`/share/cards/${postID}?format=json`, false);
assert.equal(share.card.post_id, postID);
assert.equal(share.card.headline_quote, "我把没有说出口的话，带过了云层。");

console.log(JSON.stringify({
  ok: true,
  base_url: baseURL,
  smoke_run_id: smokeRunID,
  account_id: accountID,
  flight_context_id: flightContextID,
  post_id: postID
}, null, 2));

async function postJSON(path, payload, expectedStatus = 200) {
  const response = await fetch(`${baseURL}${path}`, {
    method: "POST",
    headers: {
      ...authHeaders(),
      "content-type": "application/json"
    },
    body: JSON.stringify(payload)
  });
  await assertStatus(response, expectedStatus, `${path} should return ${expectedStatus}`);
  return response.json();
}

async function getJSON(path, includeAuth = true) {
  const response = await fetch(`${baseURL}${path}`, {
    headers: includeAuth ? authHeaders() : {}
  });
  await assertStatus(response, 200, `${path} should return 200`);
  return response.json();
}

async function assertStatus(response, expectedStatus, message) {
  if (response.status === expectedStatus) {
    return;
  }
  const body = await response.text();
  assert.equal(response.status, expectedStatus, `${message}: ${body}`);
}

function authHeaders() {
  return { authorization: `Bearer ${accountID}` };
}

function sha256(value) {
  return crypto.createHash("sha256").update(value).digest("hex");
}

function deterministicUUID(prefix, value) {
  const hex = crypto.createHash("sha256").update(`${prefix}:${value}`).digest("hex");
  return `${hex.slice(0, 8)}-${hex.slice(8, 12)}-4${hex.slice(13, 16)}-8${hex.slice(17, 20)}-${hex.slice(20, 32)}`;
}

function cleanURL(rawValue) {
  return rawValue.replace(/\/+$/, "");
}
