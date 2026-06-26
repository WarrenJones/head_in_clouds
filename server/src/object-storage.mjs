import crypto from "node:crypto";
import { ValidationError } from "./app-store.mjs";

export function createObjectStorageProvider(env = process.env) {
  const provider = (env.HIC_OBJECT_STORAGE_PROVIDER ?? "disabled").trim().toLowerCase();
  if (provider === "tencent_cos") {
    return new TencentCOSStorageProvider(env);
  }
  return new DisabledObjectStorageProvider();
}

class DisabledObjectStorageProvider {
  async putObject() {
    throw new ValidationError("object storage provider is not configured");
  }
}

class TencentCOSStorageProvider {
  constructor(env = process.env, fetchImpl = globalThis.fetch) {
    this.env = env;
    this.fetch = fetchImpl;
  }

  async putObject({ key, body, contentType = "application/octet-stream", isPublic = false }) {
    const config = tencentCOSConfig(this.env);
    const request = buildTencentCOSPutObjectRequest({
      ...config,
      key,
      body,
      contentType,
      isPublic
    });
    const response = await this.fetch(request.url, {
      method: "PUT",
      headers: request.headers,
      body
    });
    if (!response.ok) {
      throw new ValidationError("object storage upload failed");
    }
    return {
      provider: "tencent_cos",
      object_key: request.objectKey,
      public_url: request.publicURL,
      etag: response.headers.get("etag")
    };
  }
}

export function buildTencentCOSPutObjectRequest({
  bucket,
  region,
  secretID,
  secretKey,
  key,
  body,
  contentType = "application/octet-stream",
  isPublic = false,
  publicBaseURL,
  now = Math.floor(Date.now() / 1000),
  expiresInSeconds = 600
}) {
  const objectKey = normalizeObjectKey(key);
  const bodyLength = Buffer.byteLength(body ?? "");
  const host = `${bucket}.cos.${region}.myqcloud.com`;
  const url = `https://${host}/${encodeObjectPath(objectKey)}`;
  const signTime = `${now};${now + expiresInSeconds}`;
  const headers = {
    "content-length": String(bodyLength),
    "content-type": contentType,
    "host": host,
    ...(isPublic ? { "x-cos-acl": "public-read" } : {})
  };
  const authorization = buildTencentCOSAuthorization({
    method: "put",
    path: `/${encodeObjectPath(objectKey)}`,
    query: "",
    headers,
    signTime,
    secretID,
    secretKey
  });
  return {
    url,
    objectKey,
    publicURL: publicURLForObject(publicBaseURL, bucket, region, objectKey),
    headers: {
      "Authorization": authorization,
      "Content-Length": headers["content-length"],
      "Content-Type": headers["content-type"],
      ...(isPublic ? { "x-cos-acl": "public-read" } : {})
    }
  };
}

export function buildTencentCOSAuthorization({ method, path, query = "", headers, signTime, secretID, secretKey }) {
  const canonicalHeaders = canonicalizeCOSHeaders(headers);
  const headerList = Object.keys(canonicalHeaders).sort().join(";");
  const headerString = Object.entries(canonicalHeaders)
    .sort(([left], [right]) => left.localeCompare(right))
    .map(([key, value]) => `${key}=${encodeURIComponent(value)}`)
    .join("&");
  const httpString = [
    method.toLowerCase(),
    path,
    query,
    headerString,
    ""
  ].join("\n");
  const stringToSign = [
    "sha1",
    signTime,
    sha1Hex(httpString),
    ""
  ].join("\n");
  const signKey = hmacSHA1Hex(secretKey, signTime);
  const signature = hmacSHA1Hex(signKey, stringToSign);
  return [
    "q-sign-algorithm=sha1",
    `q-ak=${encodeURIComponent(secretID)}`,
    `q-sign-time=${signTime}`,
    `q-key-time=${signTime}`,
    `q-header-list=${headerList}`,
    "q-url-param-list=",
    `q-signature=${signature}`
  ].join("&");
}

function tencentCOSConfig(env) {
  return {
    bucket: requiredEnv(env, "COS_BUCKET"),
    region: requiredEnv(env, "COS_REGION"),
    secretID: requiredEnv(env, "COS_SECRET_ID"),
    secretKey: requiredEnv(env, "COS_SECRET_KEY"),
    publicBaseURL: optionalEnv(env, "COS_PUBLIC_BASE_URL")
  };
}

function requiredEnv(env, key) {
  const value = env[key]?.trim();
  if (!value) {
    throw new ValidationError("object storage provider is not configured");
  }
  return value;
}

function optionalEnv(env, key) {
  const value = env[key]?.trim();
  return value || undefined;
}

function canonicalizeCOSHeaders(headers) {
  const result = {};
  for (const [key, value] of Object.entries(headers)) {
    if (value === undefined || value === null) {
      continue;
    }
    result[key.toLowerCase()] = String(value).trim();
  }
  return result;
}

function normalizeObjectKey(key) {
  const trimmed = String(key ?? "").trim().replace(/^\/+/, "");
  if (!trimmed || trimmed.includes("..")) {
    throw new ValidationError("object key is invalid");
  }
  return trimmed;
}

function encodeObjectPath(key) {
  return key
    .split("/")
    .map((part) => encodeURIComponent(part))
    .join("/");
}

function publicURLForObject(publicBaseURL, bucket, region, objectKey) {
  const baseURL = publicBaseURL || `https://${bucket}.cos.${region}.myqcloud.com`;
  return `${baseURL.replace(/\/+$/, "")}/${encodeObjectPath(objectKey)}`;
}

function sha1Hex(value) {
  return crypto.createHash("sha1").update(value, "utf8").digest("hex");
}

function hmacSHA1Hex(key, value) {
  return crypto.createHmac("sha1", key).update(value, "utf8").digest("hex");
}
