import fs from "node:fs/promises";
import dns from "node:dns";
import http from "node:http";
import https from "node:https";
import net from "node:net";
import path from "node:path";
import { fileURLToPath } from "node:url";

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const serverRoot = path.resolve(__dirname, "..");
const projectRoot = path.resolve(serverRoot, "..");

const baseURL = trimTrailingSlash(process.env.HIC_RELEASE_BASE_URL ?? "https://headinclouds.cn");
const wwwURL = trimTrailingSlash(process.env.HIC_RELEASE_WWW_URL ?? "https://www.headinclouds.cn");
const apiURL = trimTrailingSlash(process.env.HIC_RELEASE_API_URL ?? "https://api.headinclouds.cn");
const expectedAPIBaseURL = process.env.HIC_EXPECTED_API_BASE_URL ?? apiURL;
const expectedEventsURL = process.env.HIC_EXPECTED_EVENTS_URL ?? `${apiURL}/events`;
const expectedShareURL = process.env.HIC_EXPECTED_SHARE_BASE_URL ?? baseURL;
const expectedAppleTeamID = process.env.HIC_EXPECTED_APPLE_TEAM_ID ?? "K338A7B5QX";
const resolveIP = process.env.HIC_PREFLIGHT_RESOLVE_IP;

const results = [];

await checkHTTPSHealth("root health", `${baseURL}/health`);
await checkHTTPSHealth("www health", `${wwwURL}/health`);
await checkHTTPSHealth("api health", `${apiURL}/health`);
await checkHomepage(`${baseURL}/`);
await checkHTTPRedirect("root http redirects to canonical https", `${baseURL.replace(/^https:/, "http:")}/health`, baseURL);
await checkReadiness(`${apiURL}/health/ready`);
await checkIAPForgeryGuard(`${apiURL}/api/iap/transactions/verify`);
await checkLegalPage("privacy page", `${baseURL}/privacy`, "隐私政策");
await checkLegalPage("terms page", `${baseURL}/terms`, "用户协议");
await checkAASA(`${baseURL}/.well-known/apple-app-site-association`);
await checkIOSProject();

printResults(results);

if (results.some((result) => result.status === "FAIL" || result.status === "BLOCKED")) {
  process.exitCode = 1;
}

async function checkHTTPSHealth(name, url) {
  try {
    const payload = await fetchJSON(url);
    if (payload.ok === true) {
      pass(name, `${url} ok=true`);
      return;
    }
    fail(name, `${url} returned JSON without ok=true`);
  } catch (error) {
    fail(name, `${url} unavailable: ${error.message}`);
  }
}

async function checkHTTPRedirect(name, url, expectedOrigin) {
  try {
    const response = await fetchWithTimeout(url, { redirect: "manual" });
    const location = response.headers.get("location") ?? "";
    if ([301, 302, 307, 308].includes(response.status) && isCanonicalHTTPSRedirect(location)) {
      pass(name, `${response.status} -> ${location}`);
      return;
    }
    if (location.includes("dnspod.qcloud.com/static/webblock")) {
      blocked(name, `${response.status} -> ${location}`, "ICP/domain HTTP access");
      return;
    }
    fail(name, `expected HTTP redirect to ${expectedOrigin}, got ${response.status} location=${location || "none"}`);
  } catch (error) {
    fail(name, `${url} unavailable: ${error.message}`);
  }

  function isCanonicalHTTPSRedirect(location) {
    if (!location.startsWith("https://")) {
      return false;
    }
    try {
      const redirected = new URL(location);
      const expected = new URL(expectedOrigin);
      return redirected.protocol === "https:" && redirected.hostname === expected.hostname;
    } catch {
      return false;
    }
  }
}

async function checkHomepage(url) {
  try {
    const { response, body } = await fetchText(url);
    if (response.status === 200 && body.includes("云上心事") && body.includes("给这一趟飞行，留下一句话")) {
      pass("homepage", `${url} renders app intro`);
      return;
    }
    fail("homepage", `${url} status=${response.status}, required app intro missing`);
  } catch (error) {
    fail("homepage", `${url} unavailable: ${error.message}`);
  }
}

async function checkReadiness(url) {
  try {
    const payload = await fetchJSON(url);
    if (payload.ok !== true) {
      fail("api readiness", `${url} ok=false`);
      return;
    }
    const eventKind = payload.checks?.event_store?.kind;
    const appKind = payload.checks?.app_store?.kind;
    if (eventKind === "postgres" && appKind === "postgres") {
      pass("api readiness", "event_store=postgres app_store=postgres");
      return;
    }
    fail("api readiness", `expected postgres stores, got event_store=${eventKind} app_store=${appKind}`);
  } catch (error) {
    fail("api readiness", `${url} unavailable: ${error.message}`);
  }
}

async function checkIAPForgeryGuard(url) {
  try {
    const response = await fetchWithTimeout(url, {
      method: "POST",
      headers: {
        authorization: `Bearer ${process.env.HIC_RELEASE_IAP_SMOKE_ACCOUNT_ID ?? "99999999-9999-4999-8999-999999999999"}`,
        "content-type": "application/json"
      },
      body: JSON.stringify({
        transaction_id: "release-preflight-placeholder-jws",
        product_id: "hic.postcard.plus",
        environment: "sandbox",
        signed_transaction_jws: "header.payload.signature"
      })
    });
    const body = await response.text();
    if (response.status === 400 && body.includes("signed_transaction_jws is invalid")) {
      pass("IAP placeholder JWS guard", "sandbox verification rejects placeholder StoreKit JWS with HTTP 400");
      return;
    }
    fail("IAP placeholder JWS guard", `expected HTTP 400 invalid JWS, got status=${response.status} body=${truncate(body)}`);
  } catch (error) {
    fail("IAP placeholder JWS guard", `${url} unavailable: ${error.message}`);
  }
}

async function checkLegalPage(name, url, requiredText) {
  try {
    const { response, body } = await fetchText(url);
    if (response.status === 200 && body.includes(requiredText)) {
      pass(name, `${url} contains required copy`);
      return;
    }
    fail(name, `${url} status=${response.status}, required copy missing`);
  } catch (error) {
    fail(name, `${url} unavailable: ${error.message}`);
  }
}

async function checkAASA(url) {
  try {
    const payload = await fetchJSON(url);
    const details = Array.isArray(payload.applinks?.details) ? payload.applinks.details : [];
    const appIDs = details.map((detail) => String(detail.appID ?? ""));
    const paths = details.flatMap((detail) => Array.isArray(detail.paths) ? detail.paths : []);

    if (details.length === 0 || appIDs.length === 0) {
      fail("AASA endpoint", "no applinks.details entries");
      return;
    }
    if (appIDs.some((appID) => appID.startsWith("TEAMID.") || appID.includes("TEAMID"))) {
      blocked("AASA app id", `placeholder appID still served: ${appIDs.join(", ")}`, "Apple Developer Team ID");
    } else {
      pass("AASA app id", appIDs.join(", "));
    }
    if (appIDs.some((appID) => appID.endsWith(".dev") || appID.includes(".dev."))) {
      fail("AASA bundle id", `AASA must not point to a dev bundle id: ${appIDs.join(", ")}`);
    }
    for (const requiredPath of ["/share/*", "/wechat/*", "/flight-spaces/*", "/cards/*"]) {
      if (!paths.includes(requiredPath)) {
        fail("AASA paths", `missing ${requiredPath}`);
        return;
      }
    }
    pass("AASA paths", paths.join(", "));
  } catch (error) {
    fail("AASA endpoint", `${url} unavailable or invalid JSON: ${error.message}`);
  }
}

async function checkIOSProject() {
  const pbxPath = path.join(projectRoot, "ios/HeadInClouds.xcodeproj/project.pbxproj");
  const infoPath = path.join(projectRoot, "ios/App/Info.plist");
  const entitlementPath = path.join(projectRoot, "ios/App/HeadInClouds.entitlements");
  const [pbx, info, entitlements] = await Promise.all([
    fs.readFile(pbxPath, "utf8"),
    fs.readFile(infoPath, "utf8"),
    fs.readFile(entitlementPath, "utf8")
  ]);

  expectContains("iOS API base URL", pbx, `HEAD_IN_CLOUDS_API_BASE_URL = "${expectedAPIBaseURL}";`);
  expectContains("iOS events URL", pbx, `HEAD_IN_CLOUDS_EVENTS_URL = "${expectedEventsURL}";`);
  expectContains("iOS share base URL", pbx, `HEAD_IN_CLOUDS_SHARE_BASE_URL = "${expectedShareURL}";`);
  expectContains("iOS debug bundle id", pbx, "PRODUCT_BUNDLE_IDENTIFIER = com.headintheclouds.app.dev;");
  expectContains("iOS release bundle id", pbx, "PRODUCT_BUNDLE_IDENTIFIER = com.headintheclouds.app;");
  expectContains("iOS signing team", pbx, `DEVELOPMENT_TEAM = ${expectedAppleTeamID};`);
  expectContains("iOS entitlements configured", pbx, "CODE_SIGN_ENTITLEMENTS = App/HeadInClouds.entitlements;");
  expectContains("APNs entitlement", entitlements, "<key>aps-environment</key>");
  expectContains("APNs debug environment", pbx, "APS_ENVIRONMENT = development;");
  expectContains("APNs release environment", pbx, "APS_ENVIRONMENT = production;");
  expectContains("Associated Domains entitlement root", entitlements, "applinks:headinclouds.cn");
  expectContains("Associated Domains entitlement www", entitlements, "applinks:www.headinclouds.cn");

  if (info.includes("NSExceptionDomains")) {
    fail("iOS ATS policy", "Info.plist still contains NSExceptionDomains");
  } else {
    pass("iOS ATS policy", "no domain/IP ATS exception in Info.plist");
  }
  if (pbx.includes("http://101.43.4.247") || info.includes("http://101.43.4.247")) {
    fail("iOS IP staging config", "iOS bundle config still references http://101.43.4.247");
  } else {
    pass("iOS IP staging config", "bundle config uses HTTPS domains");
  }
}

function expectContains(name, body, expected) {
  if (body.includes(expected)) {
    pass(name, expected);
    return;
  }
  fail(name, `missing ${expected}`);
}

async function fetchJSON(url) {
  const { response, body } = await fetchText(url, {
    headers: {
      accept: "application/json"
    }
  });
  if (response.status !== 200) {
    throw new Error(`status=${response.status}`);
  }
  return JSON.parse(body);
}

async function fetchText(url, init = {}) {
  const response = await fetchWithTimeout(url, init);
  const body = await response.text();
  return { response, body };
}

async function fetchWithTimeout(url, init = {}) {
  const target = new URL(url);
  const timeoutMS = Number(process.env.HIC_PREFLIGHT_TIMEOUT_MS ?? 8000);
  const transport = target.protocol === "http:" ? http : https;
  const requestBody = init.body ? Buffer.from(String(init.body)) : undefined;
  const requestHeaders = {
    ...(init.headers ?? {}),
    ...(requestBody ? { "content-length": String(requestBody.length) } : {})
  };

  return new Promise((resolve, reject) => {
    const request = transport.request({
      protocol: target.protocol,
      hostname: target.hostname,
      port: target.port || undefined,
      path: `${target.pathname}${target.search}`,
      method: init.method ?? "GET",
      headers: requestHeaders,
      agent: false,
      lookup: createLookup(target.hostname)
    }, (response) => {
      const chunks = [];
      response.on("data", (chunk) => chunks.push(chunk));
      response.on("end", () => {
        clearTimeout(totalTimeout);
        const body = Buffer.concat(chunks).toString("utf8");
        resolve({
          status: response.statusCode ?? 0,
          headers: {
            get(name) {
              const value = response.headers[String(name).toLowerCase()];
              return Array.isArray(value) ? value.join(", ") : value ?? null;
            }
          },
          text: async () => body
        });
      });
    });

    const totalTimeout = setTimeout(() => {
      request.destroy(new Error(`request timed out after ${timeoutMS}ms`));
    }, timeoutMS);
    request.setTimeout(timeoutMS, () => {
      request.destroy(new Error(`request timed out after ${timeoutMS}ms`));
    });
    request.on("error", (error) => {
      clearTimeout(totalTimeout);
      reject(error);
    });
    if (requestBody) {
      request.write(requestBody);
    }
    request.end();
  });
}

function createLookup(hostname) {
  if (!resolveIP || !shouldOverrideHost(hostname)) {
    return dns.lookup;
  }
  const family = net.isIP(resolveIP);
  if (family === 0) {
    throw new Error(`HIC_PREFLIGHT_RESOLVE_IP is not a valid IP address: ${resolveIP}`);
  }
  return (_host, options, callback) => {
    const done = typeof options === "function" ? options : callback;
    const lookupOptions = typeof options === "function" ? {} : options;
    if (lookupOptions?.all) {
      done(null, [{ address: resolveIP, family }]);
      return;
    }
    done(null, resolveIP, family);
  };
}

function shouldOverrideHost(hostname) {
  return hostname === "headinclouds.cn" ||
    hostname === "www.headinclouds.cn" ||
    hostname === "api.headinclouds.cn";
}

function pass(name, detail) {
  results.push({ status: "PASS", name, detail });
}

function fail(name, detail) {
  results.push({ status: "FAIL", name, detail });
}

function blocked(name, detail, owner) {
  results.push({ status: "BLOCKED", name, detail, owner });
}

function printResults(entries) {
  const counts = entries.reduce((acc, result) => {
    acc[result.status] = (acc[result.status] ?? 0) + 1;
    return acc;
  }, {});

  for (const result of entries) {
    const owner = result.owner ? ` owner=${result.owner}` : "";
    console.log(`[${result.status}] ${result.name}: ${result.detail}${owner}`);
  }
  console.log(`[SUMMARY] pass=${counts.PASS ?? 0} blocked=${counts.BLOCKED ?? 0} fail=${counts.FAIL ?? 0}`);
}

function trimTrailingSlash(value) {
  return value.replace(/\/+$/, "");
}

function truncate(value, maxLength = 160) {
  const text = String(value ?? "").replace(/\s+/g, " ").trim();
  return text.length > maxLength ? `${text.slice(0, maxLength)}...` : text;
}
