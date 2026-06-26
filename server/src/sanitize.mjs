export const FORBIDDEN_PROPERTY_KEYS = new Set([
  "password",
  "email",
  "phone_e164",
  "credit_card",
  "id_card",
  "passport_no",
  "ticket_no",
  "api_token",
  "seat_number",
  "ocr_raw_text"
]);

const EMAIL_PATTERN = /[^\s@]+@[^\s@]+\.[^\s@]+/;
const EMAIL_TEXT_PATTERN = /[^\s@]+@[^\s@]+\.[^\s@]+/g;
const EXACT_SEAT_PATTERN = /(^|[^0-9A-Za-z])(?:[1-9]|[1-9]\d)[A-F](?=$|[^0-9A-Za-z])/i;
const EXACT_SEAT_TEXT_PATTERN = /(^|[^0-9A-Za-z])(?:[1-9]|[1-9]\d)[A-F](?=$|[^0-9A-Za-z])/gi;

export function sanitizeProperties(properties) {
  if (!properties || typeof properties !== "object" || Array.isArray(properties)) {
    return {};
  }

  const sanitized = {};
  for (const [rawKey, value] of Object.entries(properties)) {
    const key = String(rawKey).trim();
    if (!key || FORBIDDEN_PROPERTY_KEYS.has(key.toLowerCase())) {
      continue;
    }

    if (!isAllowedPropertyValue(value)) {
      continue;
    }

    if (typeof value === "string" && isSensitivePropertyValue(value)) {
      continue;
    }

    sanitized[key] = value;
  }
  return sanitized;
}

export function sanitizePublicText(value) {
  if (typeof value !== "string") {
    return "";
  }
  return value
    .replaceAll(EMAIL_TEXT_PATTERN, "已隐藏联系方式")
    .replaceAll(EXACT_SEAT_TEXT_PATTERN, "$1某个座位");
}

function isAllowedPropertyValue(value) {
  return (
    value === null ||
    typeof value === "string" ||
    typeof value === "number" ||
    typeof value === "boolean"
  );
}

function isSensitivePropertyValue(value) {
  return EMAIL_PATTERN.test(value) || EXACT_SEAT_PATTERN.test(value);
}
