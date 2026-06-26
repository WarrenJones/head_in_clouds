import assert from "node:assert/strict";
import test from "node:test";
import { checkDeployConfig } from "../src/deploy-config.mjs";

const BASE_ENV = Object.freeze({
  DATABASE_URL: "postgres://user:pass@localhost:5432/head_in_clouds",
  HIC_ADMIN_TOKEN: "admin-token",
  POSTGRES_DB: "head_in_clouds",
  POSTGRES_USER: "hic_app",
  POSTGRES_PASSWORD: "password"
});

test("deploy config accepts the minimal staging configuration", () => {
  const result = checkDeployConfig(BASE_ENV, { profile: "staging" });

  assert.equal(result.ok, true);
  assert.deepEqual(result.missing_required, []);
  assert.deepEqual(result.config_errors, []);
  assert.deepEqual(result.missing_production, []);
  assert.equal(result.event_store, "postgres");
});

test("deploy config fails closed for malformed IAP catalog JSON", () => {
  const result = checkDeployConfig({
    ...BASE_ENV,
    HIC_IAP_PRODUCTS_JSON: "{not-json"
  });

  assert.equal(result.ok, false);
  assert.deepEqual(result.config_errors, [
    "HIC_IAP_PRODUCTS_JSON: HIC_IAP_PRODUCTS_JSON must be valid JSON"
  ]);
});

test("deploy config requires APNs credentials for production profile", () => {
  const result = checkDeployConfig(BASE_ENV, { profile: "production" });

  assert.equal(result.ok, false);
  assert.deepEqual(result.missing_production, [
    "APNS_TEAM_ID",
    "APNS_KEY_ID",
    "APNS_BUNDLE_ID",
    "APNS_PRIVATE_KEY_OR_FILE"
  ]);
});

test("deploy config rejects backup upload without Tencent COS provider", () => {
  const result = checkDeployConfig({
    ...BASE_ENV,
    UPLOAD_BACKUP_TO_OBJECT_STORAGE: "true"
  });

  assert.equal(result.ok, false);
  assert.deepEqual(result.config_errors, [
    "UPLOAD_BACKUP_TO_OBJECT_STORAGE=true requires HIC_OBJECT_STORAGE_PROVIDER=tencent_cos"
  ]);
});

test("deploy config rejects incomplete Tencent COS configuration", () => {
  const result = checkDeployConfig({
    ...BASE_ENV,
    HIC_OBJECT_STORAGE_PROVIDER: "tencent_cos",
    COS_BUCKET: "headsincould-1305013589",
    COS_REGION: "ap-shanghai"
  });

  assert.equal(result.ok, false);
  assert.deepEqual(result.config_errors, [
    "COS_SECRET_ID: required when HIC_OBJECT_STORAGE_PROVIDER=tencent_cos",
    "COS_SECRET_KEY: required when HIC_OBJECT_STORAGE_PROVIDER=tencent_cos"
  ]);
});

test("deploy config accepts complete Tencent COS configuration", () => {
  const result = checkDeployConfig({
    ...BASE_ENV,
    HIC_OBJECT_STORAGE_PROVIDER: "tencent_cos",
    COS_BUCKET: "headsincould-1305013589",
    COS_REGION: "ap-shanghai",
    COS_SECRET_ID: "secret-id",
    COS_SECRET_KEY: "secret-key",
    UPLOAD_BACKUP_TO_OBJECT_STORAGE: "true"
  });

  assert.equal(result.ok, true);
  assert.deepEqual(result.config_errors, []);
});
