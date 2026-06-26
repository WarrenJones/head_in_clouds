import assert from "node:assert/strict";
import test from "node:test";
import { once } from "node:events";
import { createServer } from "../src/server.mjs";

test("public website and legal pages render without auth", async () => {
  const server = createServer();
  server.listen(0, "127.0.0.1");
  await once(server, "listening");

  try {
    const { port } = server.address();
    const root = await fetch(`http://127.0.0.1:${port}/`);
    const privacy = await fetch(`http://127.0.0.1:${port}/privacy`);
    const terms = await fetch(`http://127.0.0.1:${port}/terms`);
    const rootBody = await root.text();

    assert.equal(root.status, 200);
    assert.equal(privacy.status, 200);
    assert.equal(terms.status, 200);
    assert.match(root.headers.get("content-type"), /text\/html/);
    assert.match(rootBody, /云上心事/);
    assert.match(rootBody, /给这一趟飞行，留下一句话/);
  } finally {
    server.close();
  }
});
