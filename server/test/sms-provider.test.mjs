import assert from "node:assert/strict";
import test from "node:test";
import { createSMSProvider, buildTencentSMSSendRequest } from "../src/sms-provider.mjs";

test("Tencent SMS request uses official SendSms shape and TC3 headers", () => {
  const request = buildTencentSMSSendRequest({
    secretID: "secret-id",
    secretKey: "secret-key",
    sdkAppID: "1400006666",
    signName: "云上心事",
    templateID: "123456",
    phoneNumber: "+8613800138000",
    code: "654321",
    region: "ap-guangzhou",
    timestamp: 1779696000
  });

  const body = JSON.parse(request.body);
  assert.deepEqual(body.PhoneNumberSet, ["+8613800138000"]);
  assert.equal(body.SmsSdkAppId, "1400006666");
  assert.equal(body.SignName, "云上心事");
  assert.equal(body.TemplateId, "123456");
  assert.deepEqual(body.TemplateParamSet, ["654321"]);
  assert.equal(request.headers.Host, "sms.tencentcloudapi.com");
  assert.equal(request.headers["X-TC-Action"], "SendSms");
  assert.equal(request.headers["X-TC-Version"], "2021-01-11");
  assert.equal(request.headers["X-TC-Region"], "ap-guangzhou");
  assert.equal(request.headers["X-TC-Timestamp"], "1779696000");
  assert.match(request.headers.Authorization, /^TC3-HMAC-SHA256 Credential=secret-id\//);
  assert.ok(!request.body.includes("secret-key"));
});

test("Tencent SMS provider fails closed until required env is configured", async () => {
  const provider = createSMSProvider({ HIC_SMS_PROVIDER: "tencent" });
  await assert.rejects(
    provider.sendVerificationCode({ phone_country_code: "+86", phone: "13800138000" }),
    /tencent sms provider is not configured/
  );
});

test("Tencent SMS provider sends through configured first-party server provider", async () => {
  const previousFetch = globalThis.fetch;
  let capturedURL;
  let capturedRequest;
  globalThis.fetch = async (url, request) => {
    capturedURL = url;
    capturedRequest = request;
    return new Response(
      JSON.stringify({
        Response: {
          RequestId: "request-id-1",
          SendStatusSet: [{
            Code: "Ok",
            Message: "send success",
            PhoneNumber: "+8613800138000"
          }]
        }
      }),
      { status: 200, headers: { "content-type": "application/json" } }
    );
  };

  try {
    const provider = createSMSProvider({
      HIC_SMS_PROVIDER: "tencent",
      TENCENTCLOUD_SECRET_ID: "secret-id",
      TENCENTCLOUD_SECRET_KEY: "secret-key",
      HIC_TENCENT_SMS_SDK_APP_ID: "1400006666",
      HIC_TENCENT_SMS_SIGN_NAME: "云上心事",
      HIC_TENCENT_SMS_TEMPLATE_ID: "123456",
      HIC_TENCENT_SMS_REGION: "ap-guangzhou"
    });

    const result = await provider.sendVerificationCode({
      phone_country_code: "+86",
      phone: "13800138000"
    });

    const body = JSON.parse(capturedRequest.body);
    assert.equal(capturedURL, "https://sms.tencentcloudapi.com");
    assert.equal(body.PhoneNumberSet[0], "+8613800138000");
    assert.match(body.TemplateParamSet[0], /^\d{6}$/);
    assert.equal(capturedRequest.headers["X-TC-Action"], "SendSms");
    assert.equal(result.provider, "tencent");
    assert.equal(result.delivery_status, "Ok");
    assert.match(result.code, /^\d{6}$/);
  } finally {
    globalThis.fetch = previousFetch;
  }
});
