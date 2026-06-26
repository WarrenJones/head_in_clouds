import crypto from "node:crypto";
import { ValidationError } from "./app-store.mjs";

const WECHAT_ACCESS_TOKEN_ENDPOINT = "https://api.weixin.qq.com/sns/oauth2/access_token";

export function createWeChatProvider(env = process.env, fetchImpl = globalThis.fetch) {
  const provider = (env.HIC_WECHAT_PROVIDER ?? "disabled").trim().toLowerCase();
  if (provider === "mock") {
    return new MockWeChatProvider();
  }
  if (provider === "wechat") {
    return new WeChatOAuthProvider({
      appID: env.HIC_WECHAT_APP_ID,
      appSecret: env.HIC_WECHAT_APP_SECRET,
      fetchImpl
    });
  }
  return new DisabledWeChatProvider();
}

export class DisabledWeChatProvider {
  async exchangeAuthorizationCode() {
    throw new ValidationError("wechat provider is not configured");
  }
}

export class MockWeChatProvider {
  async exchangeAuthorizationCode({ code }) {
    const safeCode = requiredString(code, "code");
    return identityFromWeChatPayload({
      openid: `mock-openid-${safeCode}`,
      unionid: `mock-unionid-${safeCode}`,
      scope: "snsapi_userinfo"
    }, "mock");
  }
}

export class WeChatOAuthProvider {
  constructor({ appID, appSecret, fetchImpl = globalThis.fetch } = {}) {
    this.appID = appID;
    this.appSecret = appSecret;
    this.fetch = fetchImpl;
  }

  async exchangeAuthorizationCode({ code }) {
    const request = buildWeChatAccessTokenRequest({
      appID: this.appID,
      appSecret: this.appSecret,
      code
    });
    const response = await this.fetch(request.url, { method: "GET" });
    let payload;
    try {
      payload = await response.json();
    } catch {
      throw new ValidationError("wechat authorization response is invalid");
    }
    if (!response.ok || payload.errcode) {
      throw new ValidationError("wechat authorization failed");
    }
    return identityFromWeChatPayload(payload, "wechat");
  }
}

export function buildWeChatAccessTokenRequest({ appID, appSecret, code }) {
  const appid = requiredString(appID, "HIC_WECHAT_APP_ID");
  const secret = requiredString(appSecret, "HIC_WECHAT_APP_SECRET");
  const authCode = requiredString(code, "code");
  const url = new URL(WECHAT_ACCESS_TOKEN_ENDPOINT);
  url.searchParams.set("appid", appid);
  url.searchParams.set("secret", secret);
  url.searchParams.set("code", authCode);
  url.searchParams.set("grant_type", "authorization_code");
  return { url: url.toString() };
}

function identityFromWeChatPayload(payload, provider) {
  const openid = requiredString(payload.openid, "openid");
  const unionid = stringOrNull(payload.unionid);
  const stableID = unionid ? `wechat:union:${unionid}` : `wechat:openid:${openid}`;
  return {
    provider,
    provider_user_hash: stableHash(stableID),
    wechat_open_id_hash: stableHash(`wechat:openid:${openid}`),
    scope: stringOrNull(payload.scope)
  };
}

function requiredString(value, fieldName) {
  if (typeof value !== "string" || value.trim().length === 0) {
    throw new ValidationError(`${fieldName} is required`);
  }
  return value.trim();
}

function stringOrNull(value) {
  if (typeof value !== "string") {
    return null;
  }
  const trimmed = value.trim();
  return trimmed.length > 0 ? trimmed : null;
}

function stableHash(value) {
  return crypto.createHash("sha256").update(String(value)).digest("hex");
}
