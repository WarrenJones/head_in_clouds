import assert from "node:assert/strict";
import fs from "node:fs";
import os from "node:os";
import path from "node:path";
import test from "node:test";
import { FileAppStore } from "../src/app-store.mjs";

const ACCOUNT_A = "11111111-1111-4111-8111-111111111111";

test("FileAppStore persists local app state across instances", () => {
  const dir = fs.mkdtempSync(path.join(os.tmpdir(), "hic-store-"));
  const filePath = path.join(dir, "app-store.json");

  const storeA = new FileAppStore(filePath);
  const context = storeA.createFlightContext(
    ACCOUNT_A,
    {
      flight_number_hash: "flight-hash",
      route: "SHA -> CTU",
      verification_status: "verified"
    },
    new Date("2026-05-21T00:00:01.000Z")
  );
  const post = storeA.createPost(
    ACCOUNT_A,
    {
      flight_context_id: context.id,
      text: "我把没有说出口的话，带过了云层。",
      publish_scope: "private_card"
    },
    new Date("2026-05-21T00:00:02.000Z")
  );

  const storeB = new FileAppStore(filePath);
  assert.equal(storeB.getOwnPost(ACCOUNT_A, post.id).text, "我把没有说出口的话，带过了云层。");
  assert.equal(storeB.flightContexts.get(context.id).verification_status, "verified");
});
