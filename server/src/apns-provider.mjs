import crypto from "node:crypto";
import fs from "node:fs";

const APNS_PRODUCTION_ENDPOINT = "https://api.push.apple.com";
const APNS_SANDBOX_ENDPOINT = "https://api.sandbox.push.apple.com";

export function buildAPNSNotification(job, pushToken, { bundleID }) {
  if (!bundleID) {
    throw new Error("apns_bundle_id_required");
  }
  const token = pushToken?.token;
  if (!token) {
    throw new Error("apns_token_required");
  }

  const payload = payloadForJob(job);
  return {
    path: `/3/device/${token}`,
    headers: {
      "apns-topic": bundleID,
      "apns-push-type": "alert",
      "apns-priority": "10",
      "content-type": "application/json"
    },
    body: JSON.stringify(payload)
  };
}

export class APNSPushProvider {
  constructor({
    teamID = process.env.APNS_TEAM_ID,
    keyID = process.env.APNS_KEY_ID,
    bundleID = process.env.APNS_BUNDLE_ID,
    privateKey = process.env.APNS_PRIVATE_KEY,
    privateKeyFile = process.env.APNS_PRIVATE_KEY_FILE,
    useSandbox = process.env.APNS_USE_SANDBOX !== "false",
    fetchImpl = globalThis.fetch
  } = {}) {
    this.teamID = teamID;
    this.keyID = keyID;
    this.bundleID = bundleID;
    this.privateKey = resolveAPNSPrivateKey({ privateKey, privateKeyFile });
    this.endpoint = useSandbox ? APNS_SANDBOX_ENDPOINT : APNS_PRODUCTION_ENDPOINT;
    this.fetchImpl = fetchImpl;
  }

  async send(job, pushTokens = []) {
    if (!this.teamID || !this.keyID || !this.bundleID || !this.privateKey) {
      throw new Error("apns_not_configured");
    }
    if (!this.fetchImpl) {
      throw new Error("fetch_not_available");
    }

    const authorization = `bearer ${createProviderToken({
      teamID: this.teamID,
      keyID: this.keyID,
      privateKey: this.privateKey
    })}`;

    const results = [];
    for (const pushToken of pushTokens) {
      const notification = buildAPNSNotification(job, pushToken, { bundleID: this.bundleID });
      const response = await this.fetchImpl(`${this.endpoint}${notification.path}`, {
        method: "POST",
        headers: {
          ...notification.headers,
          authorization
        },
        body: notification.body
      });
      if (!response.ok) {
        throw new Error(`apns_${response.status}`);
      }
      results.push({ token_id: pushToken.id, status: response.status });
    }

    return { delivered: results.length, results };
  }
}

function payloadForJob(job) {
  switch (job.kind) {
    case "boarding_reminder":
      return {
        aps: {
          alert: {
            title: "准备登机了吗？",
            body: "登机前 30 分钟，给这趟飞行留一句话"
          },
          sound: "default"
        },
        route: "compose",
        flight_context_id: job.flight_context_id
      };
    case "same_flight_new_post":
      return {
        aps: {
          alert: {
            title: "同班机有人留下了一条笔记",
            body: "打开看看这段共享时空里的新心事"
          },
          sound: "default"
        },
        route: "flight_space",
        flight_context_id: job.flight_context_id,
        post_id: job.payload?.post_id
      };
    default:
      return {
        aps: {
          alert: {
            title: "云上心事",
            body: "有新的飞行提醒"
          },
          sound: "default"
        },
        route: "compose",
        flight_context_id: job.flight_context_id
      };
  }
}

export function resolveAPNSPrivateKey({ privateKey, privateKeyFile } = {}) {
  if (typeof privateKey === "string" && privateKey.trim().length > 0) {
    return privateKey.includes("\\n") ? privateKey.replaceAll("\\n", "\n") : privateKey;
  }
  if (typeof privateKeyFile === "string" && privateKeyFile.trim().length > 0) {
    return fs.readFileSync(privateKeyFile.trim(), "utf8");
  }
  return privateKey;
}

function createProviderToken({ teamID, keyID, privateKey }) {
  const header = base64url(JSON.stringify({ alg: "ES256", kid: keyID }));
  const payload = base64url(JSON.stringify({ iss: teamID, iat: Math.floor(Date.now() / 1000) }));
  const unsigned = `${header}.${payload}`;
  const sign = crypto.createSign("SHA256");
  sign.update(unsigned);
  sign.end();
  return `${unsigned}.${sign.sign(privateKey, "base64url")}`;
}

function base64url(value) {
  return Buffer.from(value).toString("base64url");
}
