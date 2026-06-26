import assert from "node:assert/strict";
import test from "node:test";
import {
  WeChatOAuthProvider,
  buildWeChatAccessTokenRequest,
  createWeChatProvider
} from "../src/wechat-provider.mjs";

test("WeChat access-token request uses official code exchange parameters", () => {
  const request = buildWeChatAccessTokenRequest({
    appID: "wx-app-id",
    appSecret: "wx-secret",
    code: "auth-code"
  });
  const url = new URL(request.url);

  assert.equal(url.origin + url.pathname, "https://api.weixin.qq.com/sns/oauth2/access_token");
  assert.equal(url.searchParams.get("appid"), "wx-app-id");
  assert.equal(url.searchParams.get("secret"), "wx-secret");
  assert.equal(url.searchParams.get("code"), "auth-code");
  assert.equal(url.searchParams.get("grant_type"), "authorization_code");
});

test("WeChat provider fails closed until explicitly configured", async () => {
  const provider = createWeChatProvider({});

  await assert.rejects(
    provider.exchangeAuthorizationCode({ code: "auth-code" }),
    /wechat provider is not configured/
  );
});

test("WeChat OAuth provider exchanges code and returns only hashed identifiers", async () => {
  const provider = new WeChatOAuthProvider({
    appID: "wx-app-id",
    appSecret: "wx-secret",
    async fetchImpl(url, request) {
      assert.equal(request.method, "GET");
      assert.match(url, /appid=wx-app-id/);
      assert.match(url, /code=auth-code/);
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
    }
  });

  const identity = await provider.exchangeAuthorizationCode({ code: "auth-code" });

  assert.equal(identity.provider, "wechat");
  assert.equal(identity.scope, "snsapi_userinfo");
  assert.match(identity.provider_user_hash, /^[0-9a-f]{64}$/);
  assert.match(identity.wechat_open_id_hash, /^[0-9a-f]{64}$/);
  assert.ok(!JSON.stringify(identity).includes("openid-raw"));
  assert.ok(!JSON.stringify(identity).includes("unionid-raw"));
});

test("WeChat OAuth provider rejects WeChat error payloads", async () => {
  const provider = new WeChatOAuthProvider({
    appID: "wx-app-id",
    appSecret: "wx-secret",
    async fetchImpl() {
      return new Response(JSON.stringify({
        errcode: 40029,
        errmsg: "invalid code"
      }), {
        status: 200,
        headers: { "content-type": "application/json" }
      });
    }
  });

  await assert.rejects(
    provider.exchangeAuthorizationCode({ code: "bad-code" }),
    /wechat authorization failed/
  );
});
