import { loadIAPProductCatalog } from "./iap-products.mjs";

const REQUIRED = [
  "DATABASE_URL",
  "HIC_ADMIN_TOKEN",
  "POSTGRES_DB",
  "POSTGRES_USER",
  "POSTGRES_PASSWORD"
];

const RECOMMENDED = [
  "HOST",
  "PORT",
  "HIC_EVENT_STORE",
  "DATABASE_SSL_MODE",
  "DATABASE_POOL_MAX",
  "HEAD_IN_CLOUDS_API_BASE_URL",
  "HEAD_IN_CLOUDS_SHARE_BASE_URL",
  "COS_BUCKET",
  "COS_REGION",
  "COS_PUBLIC_BASE_URL",
  "HIC_IAP_PRODUCTS_JSON"
];

const PRODUCTION_ONLY = [
  "APNS_TEAM_ID",
  "APNS_KEY_ID",
  "APNS_BUNDLE_ID"
];

export function checkDeployConfig(env = process.env, { profile = "staging" } = {}) {
  const missingRequired = REQUIRED.filter((key) => !env[key]);
  const configErrors = [];
  validateIAPProductCatalog(env, configErrors);
  validateObjectStorageConfig(env, configErrors);

  const missingProduction = profile === "production"
    ? [
        ...PRODUCTION_ONLY.filter((key) => !env[key]),
        ...(env.APNS_PRIVATE_KEY || env.APNS_PRIVATE_KEY_FILE ? [] : ["APNS_PRIVATE_KEY_OR_FILE"])
      ]
    : [];

  return {
    ok: missingRequired.length === 0 && missingProduction.length === 0 && configErrors.length === 0,
    profile,
    missing_required: missingRequired,
    missing_production: missingProduction,
    config_errors: configErrors,
    event_store: env.HIC_EVENT_STORE || "postgres",
    has_admin_token: Boolean(env.HIC_ADMIN_TOKEN),
    recommended_missing: RECOMMENDED.filter((key) => !env[key]),
    production_missing_but_not_required_for_staging: profile === "staging"
      ? [
          ...PRODUCTION_ONLY.filter((key) => !env[key]),
          ...(env.APNS_PRIVATE_KEY || env.APNS_PRIVATE_KEY_FILE ? [] : ["APNS_PRIVATE_KEY_OR_FILE"])
        ]
      : []
  };
}

function validateIAPProductCatalog(env, errors) {
  try {
    loadIAPProductCatalog(env);
  } catch (error) {
    errors.push(`HIC_IAP_PRODUCTS_JSON: ${error.message}`);
  }
}

function validateObjectStorageConfig(env, errors) {
  const provider = (env.HIC_OBJECT_STORAGE_PROVIDER ?? "disabled").trim().toLowerCase();
  const uploadBackups = (env.UPLOAD_BACKUP_TO_OBJECT_STORAGE ?? "false").trim().toLowerCase() === "true";

  if (!["disabled", "tencent_cos"].includes(provider)) {
    errors.push(`HIC_OBJECT_STORAGE_PROVIDER: unsupported provider ${provider}`);
    return;
  }

  if (uploadBackups && provider !== "tencent_cos") {
    errors.push("UPLOAD_BACKUP_TO_OBJECT_STORAGE=true requires HIC_OBJECT_STORAGE_PROVIDER=tencent_cos");
  }

  if (provider !== "tencent_cos") {
    return;
  }

  for (const key of ["COS_BUCKET", "COS_REGION", "COS_SECRET_ID", "COS_SECRET_KEY"]) {
    if (!env[key]) {
      errors.push(`${key}: required when HIC_OBJECT_STORAGE_PROVIDER=tencent_cos`);
    }
  }
}
