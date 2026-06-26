import { ValidationError as EventValidationError } from "./events.mjs";
import { ValidationError as AppValidationError, ForbiddenError, NotFoundError, RateLimitError } from "./app-store.mjs";
import { AuthError } from "./auth.mjs";

const MAX_BODY_BYTES = 64 * 1024;

export function readJSONBody(req) {
  return new Promise((resolve, reject) => {
    let body = "";
    let settled = false;

    req.on("data", (chunk) => {
      if (settled) {
        return;
      }
      body += chunk;
      if (Buffer.byteLength(body) > MAX_BODY_BYTES) {
        const error = new Error("body too large");
        error.code = "BODY_TOO_LARGE";
        settled = true;
        req.resume();
        reject(error);
      }
    });

    req.on("end", () => {
      if (settled) {
        return;
      }
      settled = true;
      try {
        resolve(JSON.parse(body || "{}"));
      } catch {
        reject(new EventValidationError("request body must be valid JSON"));
      }
    });
    req.on("error", (error) => {
      if (settled) {
        return;
      }
      settled = true;
      reject(error);
    });
  });
}

export function sendJSON(res, statusCode, payload) {
  res.writeHead(statusCode, { "content-type": "application/json; charset=utf-8" });
  res.end(JSON.stringify(payload));
}

export function sendRawJSON(res, statusCode, payload) {
  res.writeHead(statusCode, { "content-type": "application/json" });
  res.end(JSON.stringify(payload));
}

export function sendHTML(res, statusCode, html) {
  res.writeHead(statusCode, { "content-type": "text/html; charset=utf-8" });
  res.end(html);
}

export function sendSVG(res, statusCode, svg) {
  res.writeHead(statusCode, {
    "content-type": "image/svg+xml; charset=utf-8",
    "cache-control": "public, max-age=300"
  });
  res.end(svg);
}

export function sendError(res, error) {
  if (error instanceof AuthError) {
    return sendJSON(res, 401, { ok: false, error: "unauthorized" });
  }
  if (error instanceof ForbiddenError) {
    return sendJSON(res, 403, { ok: false, error: error.message });
  }
  if (error instanceof NotFoundError) {
    return sendJSON(res, 404, { ok: false, error: error.message });
  }
  if (error instanceof RateLimitError) {
    return sendJSON(res, 429, { ok: false, error: error.message });
  }
  if (error instanceof EventValidationError || error instanceof AppValidationError) {
    return sendJSON(res, 400, { ok: false, error: error.message });
  }
  if (error.code === "BODY_TOO_LARGE") {
    return sendJSON(res, 413, { ok: false, error: "body_too_large" });
  }
  return sendJSON(res, 500, { ok: false, error: "internal_error" });
}
