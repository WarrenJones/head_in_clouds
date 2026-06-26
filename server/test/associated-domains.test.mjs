import assert from "node:assert/strict";
import test from "node:test";
import { once } from "node:events";
import { appleAppSiteAssociation } from "../src/associated-domains.mjs";
import { createServer } from "../src/server.mjs";

test("appleAppSiteAssociation renders universal link app id and paths", () => {
  const aasa = appleAppSiteAssociation({
    appIDPrefix: "TEAM123",
    bundleID: "com.headintheclouds.app",
    paths: "/share/*,/wechat/*"
  });

  assert.equal(aasa.applinks.details[0].appID, "TEAM123.com.headintheclouds.app");
  assert.deepEqual(aasa.applinks.details[0].paths, ["/share/*", "/wechat/*"]);
});

test("AASA endpoint is public JSON without auth", async () => {
  const server = createServer();
  server.listen(0, "127.0.0.1");
  await once(server, "listening");

  const { port } = server.address();
  const response = await fetch(`http://127.0.0.1:${port}/.well-known/apple-app-site-association`);
  const body = await response.json();

  assert.equal(response.status, 200);
  assert.equal(response.headers.get("content-type"), "application/json");
  assert.equal(body.applinks.apps.length, 0);
  assert.ok(body.applinks.details[0].paths.includes("/share/*"));
  server.close();
});

test("WeChat universal link callback path is public HTML", async () => {
  const server = createServer();
  server.listen(0, "127.0.0.1");
  await once(server, "listening");

  try {
    const { port } = server.address();
    const response = await fetch(`http://127.0.0.1:${port}/wechat/`);
    const html = await response.text();

    assert.equal(response.status, 200);
    assert.match(response.headers.get("content-type"), /text\/html/);
    assert.match(html, /微信 Universal Link/);
  } finally {
    server.close();
  }
});
