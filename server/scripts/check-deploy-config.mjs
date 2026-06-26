import { checkDeployConfig } from "../src/deploy-config.mjs";

const profile = process.argv.includes("--profile=production") ? "production" : "staging";
const result = checkDeployConfig(process.env, { profile });

if (!result.ok) {
  console.error(JSON.stringify({
    ok: false,
    profile: result.profile,
    missing_required: result.missing_required,
    missing_production: result.missing_production,
    config_errors: result.config_errors
  }, null, 2));
  process.exit(1);
}

console.log(JSON.stringify({
  ok: true,
  profile: result.profile,
  event_store: result.event_store,
  has_admin_token: result.has_admin_token,
  recommended_missing: result.recommended_missing,
  production_missing_but_not_required_for_staging: result.production_missing_but_not_required_for_staging
}, null, 2));
