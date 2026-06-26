import http from "node:http";
import crypto from "node:crypto";
import { renderAdminEventsDashboardHTML } from "./admin-dashboard.mjs";
import { FileAppStore } from "./app-store.mjs";
import { appleAppSiteAssociation } from "./associated-domains.mjs";
import { requireAccountID } from "./auth.mjs";
import { handleAPIRequest } from "./api.mjs";
import { FileEventStore } from "./event-store.mjs";
import { normalizeEvent } from "./events.mjs";
import { renderHomeHTML } from "./home-page.mjs";
import { readJSONBody, sendError, sendHTML, sendJSON, sendRawJSON, sendSVG } from "./http.mjs";
import { renderPrivacyHTML, renderTermsHTML } from "./legal-pages.mjs";
import { createObjectStorageProvider } from "./object-storage.mjs";
import { renderShareCardLandingHTML, renderShareCardOGSVG } from "./share-card-page.mjs";
import { createRuntimeStoresFromEnv } from "./store-factory.mjs";

export function createServer({
  store = new FileEventStore(),
  appStore = new FileAppStore(),
  now = () => new Date(),
  adminToken = process.env.HIC_ADMIN_TOKEN,
  objectStorageProvider = createObjectStorageProvider(),
  requestLogger = null
} = {}) {
  return http.createServer(async (req, res) => {
    const requestID = requestIDFromHeaders(req) ?? crypto.randomUUID();
    const startedAt = Date.now();
    res.setHeader("x-request-id", requestID);
    logRequestOnFinish({ req, res, requestID, startedAt, requestLogger });

    try {
      const url = new URL(req.url ?? "/", "http://localhost");

      if (req.method === "GET" && url.pathname === "/health") {
        return sendJSON(res, 200, { ok: true });
      }

      if (isReadMethod(req) && url.pathname === "/") {
        return sendHTML(res, 200, renderHomeHTML());
      }

      if (req.method === "GET" && url.pathname === "/health/ready") {
        return sendReadiness(res, { store, appStore });
      }

      if (isReadMethod(req) && url.pathname === "/privacy") {
        return sendHTML(res, 200, renderPrivacyHTML());
      }

      if (isReadMethod(req) && url.pathname === "/terms") {
        return sendHTML(res, 200, renderTermsHTML());
      }

      if (isReadMethod(req) && url.pathname === "/wechat/") {
        return sendHTML(res, 200, renderWeChatUniversalLinkHTML());
      }

      if (
        req.method === "GET" &&
        (url.pathname === "/.well-known/apple-app-site-association" || url.pathname === "/apple-app-site-association")
      ) {
        return sendRawJSON(res, 200, appleAppSiteAssociation());
      }

      if (req.method === "POST" && url.pathname === "/events") {
        const accountID = requireAccountID(req);
        const body = await readJSONBody(req);
        const event = normalizeEvent(body, now());
        if (!event.user_id_hash) {
          event.user_id_hash = stableHash(accountID);
        }
        await store.append(event);
        return sendJSON(res, 202, { ok: true, event_id: event.id });
      }

      if (req.method === "GET" && url.pathname === "/api/admin/events/recent") {
        const authStatus = authorizeAdminRequest(req, adminToken);
        if (authStatus === "disabled") {
          return sendJSON(res, 404, { ok: false, error: "not_found" });
        }
        if (authStatus === "unauthorized") {
          return sendAdminUnauthorized(res);
        }
        return sendJSON(res, 200, {
          ok: true,
          events: await store.recent({
            limit: url.searchParams.get("limit") ?? 50,
            eventName: url.searchParams.get("event_name") ?? undefined
          })
        });
      }

      if (req.method === "GET" && url.pathname === "/api/admin/events/summary") {
        const authStatus = authorizeAdminRequest(req, adminToken);
        if (authStatus === "disabled") {
          return sendJSON(res, 404, { ok: false, error: "not_found" });
        }
        if (authStatus === "unauthorized") {
          return sendAdminUnauthorized(res);
        }
        if (typeof store.summary !== "function") {
          return sendJSON(res, 501, { ok: false, error: "summary_not_supported" });
        }
        return sendJSON(res, 200, {
          ok: true,
          smoke_run_id: url.searchParams.get("smoke_run_id") ?? null,
          summary: await store.summary({
            smokeRunID: url.searchParams.get("smoke_run_id") ?? undefined,
            eventNames: parseCSV(url.searchParams.get("event_names"))
          })
        });
      }

      if (req.method === "GET" && url.pathname === "/api/admin/events/dashboard") {
        const authStatus = authorizeAdminRequest(req, adminToken);
        if (authStatus === "disabled") {
          return sendJSON(res, 404, { ok: false, error: "not_found" });
        }
        if (authStatus === "unauthorized") {
          return sendAdminUnauthorized(res);
        }
        if (typeof store.summary !== "function") {
          return sendJSON(res, 501, { ok: false, error: "summary_not_supported" });
        }
        const filters = {
          smoke_run_id: url.searchParams.get("smoke_run_id") ?? "",
          event_name: url.searchParams.get("event_name") ?? "",
          event_names: url.searchParams.get("event_names") ?? ""
        };
        const [summary, recentEvents] = await Promise.all([
          store.summary({
            smokeRunID: filters.smoke_run_id || undefined,
            eventNames: parseCSV(filters.event_names)
          }),
          store.recent({
            limit: url.searchParams.get("limit") ?? 50,
            eventName: filters.event_name || undefined
          })
        ]);
        return sendHTML(res, 200, renderAdminEventsDashboardHTML({
          summary,
          recentEvents,
          filters
        }));
      }

      const shareCardOGMatch = url.pathname.match(/^\/share\/cards\/([^/]+)\/og\.svg$/);
      if (req.method === "GET" && shareCardOGMatch) {
        const card = await appStore.getPublicShareCard(shareCardOGMatch[1]);
        return sendSVG(res, 200, renderShareCardOGSVG(card));
      }

      const shareCardMatch = url.pathname.match(/^\/share\/cards\/([^/]+)$/);
      if (req.method === "GET" && shareCardMatch) {
        const card = await appStore.getPublicShareCard(shareCardMatch[1]);
        if (wantsHTML(req, url)) {
          return sendHTML(res, 200, renderShareCardLandingHTML(card, { origin: requestOrigin(req) }));
        }
        return sendJSON(res, 200, { ok: true, card });
      }

      if (url.pathname.startsWith("/api/")) {
        const handled = await handleAPIRequest(req, res, appStore, now, store, objectStorageProvider);
        if (handled !== false) {
          return handled;
        }
      }

      sendJSON(res, 404, { ok: false, error: "not_found" });
    } catch (error) {
      sendError(res, error);
    }
  });
}

function wantsHTML(req, url) {
  if (url.searchParams.get("format") === "html") {
    return true;
  }
  if (url.searchParams.get("format") === "json") {
    return false;
  }
  return req.headers.accept?.includes("text/html") === true;
}

function isReadMethod(req) {
  return req.method === "GET" || req.method === "HEAD";
}

function requestOrigin(req) {
  const protoHeader = req.headers["x-forwarded-proto"];
  const hostHeader = req.headers["x-forwarded-host"] ?? req.headers.host ?? "localhost";
  const proto = Array.isArray(protoHeader) ? protoHeader[0] : protoHeader ?? "http";
  const host = Array.isArray(hostHeader) ? hostHeader[0] : hostHeader;
  return `${proto}://${host}`;
}

function renderWeChatUniversalLinkHTML() {
  return `<!doctype html>
<html lang="zh-CN">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <title>云上心事</title>
</head>
<body>
  <main>
    <h1>云上心事</h1>
    <p>微信 Universal Link 回跳入口已就绪。</p>
  </main>
</body>
</html>`;
}

function parseCSV(value) {
  if (!value) {
    return [];
  }
  return value
    .split(",")
    .map((item) => item.trim())
    .filter(Boolean);
}

function authorizeAdminRequest(req, adminToken) {
  if (!adminToken) {
    return "disabled";
  }
  const authorization = req.headers.authorization;
  if (authorization === `Bearer ${adminToken}`) {
    return "authorized";
  }
  if (isValidBasicAdminAuthorization(authorization, adminToken)) {
    return "authorized";
  }
  return "unauthorized";
}

function isValidBasicAdminAuthorization(authorization, adminToken) {
  if (typeof authorization !== "string" || !authorization.startsWith("Basic ")) {
    return false;
  }
  try {
    const decoded = Buffer.from(authorization.slice("Basic ".length), "base64").toString("utf8");
    const separatorIndex = decoded.indexOf(":");
    if (separatorIndex === -1) {
      return false;
    }
    const username = decoded.slice(0, separatorIndex);
    const password = decoded.slice(separatorIndex + 1);
    return username === "admin" && password === adminToken;
  } catch {
    return false;
  }
}

function sendAdminUnauthorized(res) {
  res.setHeader("www-authenticate", 'Basic realm="Head in the Clouds admin", charset="UTF-8"');
  return sendJSON(res, 401, { ok: false, error: "unauthorized" });
}

function stableHash(value) {
  return crypto.createHash("sha256").update(String(value).trim().toUpperCase()).digest("hex");
}

if (import.meta.url === `file://${process.argv[1]}`) {
  const port = Number(process.env.PORT || 8787);
  const host = process.env.HOST || "127.0.0.1";
  const { eventStore, appStore } = await createRuntimeStoresFromEnv(process.env);
  const requestLogger = process.env.HIC_REQUEST_LOGS === "false" ? null : console;
  const server = createServer({ store: eventStore, appStore, requestLogger });
  server.listen(port, host, () => {
    console.log(`Head in the Clouds server listening on http://${host}:${port}`);
  });
}

async function sendReadiness(res, { store, appStore }) {
  const checks = {
    event_store: await runHealthCheck(store),
    app_store: await runHealthCheck(appStore)
  };
  const ok = Object.values(checks).every((check) => check.ok);
  return sendJSON(res, ok ? 200 : 503, { ok, checks });
}

async function runHealthCheck(target) {
  if (typeof target?.health !== "function") {
    return { ok: true, kind: "unknown" };
  }
  try {
    return await target.health();
  } catch (error) {
    return {
      ok: false,
      error: "unavailable"
    };
  }
}

function logRequestOnFinish({ req, res, requestID, startedAt, requestLogger }) {
  if (!requestLogger || typeof requestLogger.log !== "function") {
    return;
  }
  const requestPath = new URL(req.url ?? "/", "http://localhost").pathname;
  res.on("finish", () => {
    requestLogger.log(JSON.stringify({
      level: "info",
      event: "http_request",
      request_id: requestID,
      method: req.method,
      path: requestPath,
      status_code: res.statusCode,
      duration_ms: Date.now() - startedAt
    }));
  });
}

function requestIDFromHeaders(req) {
  const header = req.headers["x-request-id"];
  const value = Array.isArray(header) ? header[0] : header;
  if (typeof value !== "string" || value.trim().length === 0) {
    return null;
  }
  return value.trim().slice(0, 128);
}
