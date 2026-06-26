import { ValidationError } from "./app-store.mjs";
import crypto from "node:crypto";

const TENCENT_SMS_ENDPOINT = "sms.tencentcloudapi.com";
const TENCENT_SMS_SERVICE = "sms";
const TENCENT_SMS_VERSION = "2021-01-11";
const TENCENT_SMS_ACTION = "SendSms";

export function createSMSProvider(env = process.env) {
  const provider = (env.HIC_SMS_PROVIDER ?? "disabled").trim().toLowerCase();
  if (provider === "mock") {
    return new MockSMSProvider(env.HIC_SMS_MOCK_CODE ?? "123456");
  }
  if (provider === "tencent") {
    return new TencentSMSProvider(env);
  }
  return new DisabledSMSProvider();
}

class DisabledSMSProvider {
  async sendVerificationCode() {
    throw new ValidationError("sms provider is not configured");
  }
}

class TencentSMSProvider {
  constructor(env = process.env, fetchImpl = globalThis.fetch) {
    this.env = env;
    this.fetch = fetchImpl;
  }

  async sendVerificationCode(input = {}) {
    const config = tencentSMSConfig(this.env);
    const code = randomSMSCode();
    const phoneNumber = normalizeE164Phone(input.phone_country_code ?? "+86", input.phone);
    const request = buildTencentSMSSendRequest({
      ...config,
      code,
      phoneNumber,
      timestamp: Math.floor(Date.now() / 1000)
    });

    const response = await this.fetch(`https://${TENCENT_SMS_ENDPOINT}`, {
      method: "POST",
      headers: request.headers,
      body: request.body
    });
    if (!response.ok) {
      throw new ValidationError("sms provider request failed");
    }
    const payload = await response.json();
    const sendStatus = payload?.Response?.SendStatusSet?.[0];
    if (sendStatus?.Code !== "Ok") {
      throw new ValidationError("sms delivery failed");
    }
    return {
      provider: "tencent",
      delivery_status: sendStatus.Code,
      provider_request_id: payload?.Response?.RequestId ?? null,
      code
    };
  }
}

class MockSMSProvider {
  constructor(code) {
    this.code = String(code).trim() || "123456";
  }

  async sendVerificationCode() {
    return {
      provider: "mock",
      delivery_status: "mocked",
      code: this.code
    };
  }
}

export function buildTencentSMSSendRequest({
  secretID,
  secretKey,
  sdkAppID,
  signName,
  templateID,
  phoneNumber,
  code,
  region = "ap-guangzhou",
  timestamp = Math.floor(Date.now() / 1000)
}) {
  const body = JSON.stringify({
    PhoneNumberSet: [phoneNumber],
    SmsSdkAppId: sdkAppID,
    SignName: signName,
    TemplateId: templateID,
    TemplateParamSet: [code]
  });
  const date = new Date(timestamp * 1000).toISOString().slice(0, 10);
  const contentType = "application/json; charset=utf-8";
  const signedHeaders = "content-type;host;x-tc-action";
  const canonicalHeaders = [
    `content-type:${contentType}`,
    `host:${TENCENT_SMS_ENDPOINT}`,
    `x-tc-action:${TENCENT_SMS_ACTION.toLowerCase()}`,
    ""
  ].join("\n");
  const canonicalRequest = [
    "POST",
    "/",
    "",
    canonicalHeaders,
    signedHeaders,
    sha256Hex(body)
  ].join("\n");
  const credentialScope = `${date}/${TENCENT_SMS_SERVICE}/tc3_request`;
  const stringToSign = [
    "TC3-HMAC-SHA256",
    String(timestamp),
    credentialScope,
    sha256Hex(canonicalRequest)
  ].join("\n");
  const secretDate = hmacSHA256(`TC3${secretKey}`, date);
  const secretService = hmacSHA256(secretDate, TENCENT_SMS_SERVICE);
  const secretSigning = hmacSHA256(secretService, "tc3_request");
  const signature = hmacSHA256Hex(secretSigning, stringToSign);
  const authorization = [
    "TC3-HMAC-SHA256",
    `Credential=${secretID}/${credentialScope},`,
    `SignedHeaders=${signedHeaders},`,
    `Signature=${signature}`
  ].join(" ");

  return {
    body,
    headers: {
      "Authorization": authorization,
      "Content-Type": contentType,
      "Host": TENCENT_SMS_ENDPOINT,
      "X-TC-Action": TENCENT_SMS_ACTION,
      "X-TC-Region": region,
      "X-TC-Timestamp": String(timestamp),
      "X-TC-Version": TENCENT_SMS_VERSION
    }
  };
}

function tencentSMSConfig(env) {
  return {
    secretID: requiredEnv(env, "TENCENTCLOUD_SECRET_ID"),
    secretKey: requiredEnv(env, "TENCENTCLOUD_SECRET_KEY"),
    sdkAppID: requiredEnv(env, "HIC_TENCENT_SMS_SDK_APP_ID"),
    signName: requiredEnv(env, "HIC_TENCENT_SMS_SIGN_NAME"),
    templateID: requiredEnv(env, "HIC_TENCENT_SMS_TEMPLATE_ID"),
    region: (env.HIC_TENCENT_SMS_REGION ?? "ap-guangzhou").trim() || "ap-guangzhou"
  };
}

function requiredEnv(env, key) {
  const value = env[key]?.trim();
  if (!value) {
    throw new ValidationError("tencent sms provider is not configured");
  }
  return value;
}

function normalizeE164Phone(countryCode, value) {
  const code = String(countryCode).trim();
  const digits = String(value ?? "").replace(/\D/g, "");
  if (code === "+86" && !/^1\d{10}$/.test(digits)) {
    throw new ValidationError("phone is invalid");
  }
  if (digits.length < 6 || digits.length > 16) {
    throw new ValidationError("phone is invalid");
  }
  return `${code}${digits}`;
}

function randomSMSCode() {
  return String(crypto.randomInt(0, 1_000_000)).padStart(6, "0");
}

function sha256Hex(value) {
  return crypto.createHash("sha256").update(value, "utf8").digest("hex");
}

function hmacSHA256(key, value) {
  return crypto.createHmac("sha256", key).update(value, "utf8").digest();
}

function hmacSHA256Hex(key, value) {
  return crypto.createHmac("sha256", key).update(value, "utf8").digest("hex");
}
