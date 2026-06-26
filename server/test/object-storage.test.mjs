import assert from "node:assert/strict";
import test from "node:test";
import {
  createObjectStorageProvider,
  buildTencentCOSAuthorization,
  buildTencentCOSPutObjectRequest
} from "../src/object-storage.mjs";

test("Tencent COS PUT Object request signs the expected host, headers, and object key", () => {
  const request = buildTencentCOSPutObjectRequest({
    bucket: "headsincould-1305013589",
    region: "ap-shanghai",
    secretID: "secret-id",
    secretKey: "secret-key",
    key: "cloud-cards/test card.svg",
    body: "<svg></svg>",
    contentType: "image/svg+xml",
    isPublic: true,
    publicBaseURL: "https://headsincould-1305013589.cos.ap-shanghai.myqcloud.com",
    now: 1779696000
  });

  assert.equal(
    request.url,
    "https://headsincould-1305013589.cos.ap-shanghai.myqcloud.com/cloud-cards/test%20card.svg"
  );
  assert.equal(
    request.publicURL,
    "https://headsincould-1305013589.cos.ap-shanghai.myqcloud.com/cloud-cards/test%20card.svg"
  );
  assert.equal(request.headers["Content-Type"], "image/svg+xml");
  assert.equal(request.headers["Content-Length"], "11");
  assert.equal(request.headers["x-cos-acl"], "public-read");
  assert.match(request.headers.Authorization, /^q-sign-algorithm=sha1&q-ak=secret-id/);
  assert.ok(request.headers.Authorization.includes("q-header-list=content-length;content-type;host;x-cos-acl"));
});

test("Tencent COS authorization is deterministic for a fixed request", () => {
  const authorization = buildTencentCOSAuthorization({
    method: "put",
    path: "/cloud-cards/test.svg",
    headers: {
      host: "headsincould-1305013589.cos.ap-shanghai.myqcloud.com",
      "content-type": "image/svg+xml",
      "content-length": "11"
    },
    signTime: "1779696000;1779696600",
    secretID: "secret-id",
    secretKey: "secret-key"
  });

  assert.equal(
    authorization,
    "q-sign-algorithm=sha1&q-ak=secret-id&q-sign-time=1779696000;1779696600&q-key-time=1779696000;1779696600&q-header-list=content-length;content-type;host&q-url-param-list=&q-signature=1a5a1fee364ba3916ec088f4f01b044ab8e9efbd"
  );
});

test("Object storage provider fails closed until COS env is configured", async () => {
  const provider = createObjectStorageProvider({ HIC_OBJECT_STORAGE_PROVIDER: "tencent_cos" });
  await assert.rejects(
    provider.putObject({ key: "cloud-cards/a.svg", body: "<svg></svg>" }),
    /object storage provider is not configured/
  );
});

test("Tencent COS provider uploads through configured server-side credentials", async () => {
  const previousFetch = globalThis.fetch;
  let capturedURL;
  let capturedRequest;
  globalThis.fetch = async (url, request) => {
    capturedURL = url;
    capturedRequest = request;
    return new Response("", {
      status: 200,
      headers: { etag: "\"etag-1\"" }
    });
  };

  try {
    const provider = createObjectStorageProvider({
      HIC_OBJECT_STORAGE_PROVIDER: "tencent_cos",
      COS_BUCKET: "headsincould-1305013589",
      COS_REGION: "ap-shanghai",
      COS_PUBLIC_BASE_URL: "https://headsincould-1305013589.cos.ap-shanghai.myqcloud.com",
      COS_SECRET_ID: "secret-id",
      COS_SECRET_KEY: "secret-key"
    });

    const result = await provider.putObject({
      key: "cloud-cards/card-1.svg",
      body: "<svg></svg>",
      contentType: "image/svg+xml",
      isPublic: true
    });

    assert.equal(capturedURL, "https://headsincould-1305013589.cos.ap-shanghai.myqcloud.com/cloud-cards/card-1.svg");
    assert.equal(capturedRequest.method, "PUT");
    assert.equal(capturedRequest.headers["Content-Type"], "image/svg+xml");
    assert.equal(capturedRequest.headers["x-cos-acl"], "public-read");
    assert.equal(result.provider, "tencent_cos");
    assert.equal(result.object_key, "cloud-cards/card-1.svg");
    assert.equal(result.public_url, "https://headsincould-1305013589.cos.ap-shanghai.myqcloud.com/cloud-cards/card-1.svg");
    assert.equal(result.etag, "\"etag-1\"");
  } finally {
    globalThis.fetch = previousFetch;
  }
});
