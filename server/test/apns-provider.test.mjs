import assert from "node:assert/strict";
import fs from "node:fs";
import os from "node:os";
import path from "node:path";
import test from "node:test";
import { APNSPushProvider, buildAPNSNotification, resolveAPNSPrivateKey } from "../src/apns-provider.mjs";

test("buildAPNSNotification creates boarding reminder payload without leaking raw user data", () => {
  const notification = buildAPNSNotification(
    {
      id: "job-a",
      kind: "boarding_reminder",
      flight_context_id: "context-a",
      payload: {
        flight_number_hash: "flight-hash",
        route: "SHA -> CTU"
      }
    },
    { id: "token-a", token: "apns-token-a" },
    { bundleID: "com.headintheclouds.app.dev" }
  );
  const body = JSON.parse(notification.body);

  assert.equal(notification.path, "/3/device/apns-token-a");
  assert.equal(notification.headers["apns-topic"], "com.headintheclouds.app.dev");
  assert.equal(body.route, "compose");
  assert.equal(body.flight_context_id, "context-a");
  assert.doesNotMatch(notification.body, /SHA -> CTU/);
  assert.doesNotMatch(notification.body, /flight-hash/);
});

test("buildAPNSNotification creates same-flight new post payload", () => {
  const notification = buildAPNSNotification(
    {
      id: "job-b",
      kind: "same_flight_new_post",
      flight_context_id: "context-b",
      payload: {
        post_id: "post-b",
        source_account_id: "account-b"
      }
    },
    { id: "token-b", token: "apns-token-b" },
    { bundleID: "com.headintheclouds.app.dev" }
  );
  const body = JSON.parse(notification.body);

  assert.equal(body.route, "flight_space");
  assert.equal(body.flight_context_id, "context-b");
  assert.equal(body.post_id, "post-b");
  assert.doesNotMatch(notification.body, /account-b/);
});

test("APNSPushProvider fails closed until Apple credentials are configured", async () => {
  const provider = new APNSPushProvider({
    teamID: "",
    keyID: "",
    bundleID: "",
    privateKey: "",
    fetchImpl: async () => ({ ok: true, status: 200 })
  });

  await assert.rejects(
    () => provider.send({ id: "job-a", kind: "boarding_reminder" }, [{ id: "token-a", token: "apns-token-a" }]),
    /apns_not_configured/
  );
});

test("resolveAPNSPrivateKey supports escaped env values and private key files", () => {
  const pem = "-----BEGIN PRIVATE KEY-----\nabc\n-----END PRIVATE KEY-----\n";
  const escaped = pem.replaceAll("\n", "\\n");
  assert.equal(resolveAPNSPrivateKey({ privateKey: escaped }), pem);

  const tempDir = fs.mkdtempSync(path.join(os.tmpdir(), "hic-apns-"));
  const tempFile = path.join(tempDir, "AuthKey_TEST.p8");
  fs.writeFileSync(tempFile, pem, { mode: 0o600 });
  assert.equal(resolveAPNSPrivateKey({ privateKeyFile: tempFile }), pem);
});
