import { dispatchDueNotifications, InMemoryPushProvider } from "./notification-dispatcher.mjs";
import { APNSPushProvider } from "./apns-provider.mjs";
import { createRuntimeStoresFromEnv } from "./store-factory.mjs";

if (import.meta.url === `file://${process.argv[1]}`) {
  const summary = await runNotificationDispatch(process.env);
  console.log(JSON.stringify(summary));
}

export async function runNotificationDispatch(env = process.env) {
  const limit = Number(env.NOTIFICATION_DISPATCH_LIMIT || 50);
  const { appStore, eventStore } = await createRuntimeStoresFromEnv(env);
  const pushProvider = createPushProvider(env);

  const results = await dispatchDueNotifications({
    appStore,
    pushProvider,
    eventStore,
    limit
  });

  return {
    ok: true,
    dispatched: results.length,
    sent: results.filter((result) => result.status === "sent").length,
    failed: results.filter((result) => result.status === "failed").length
  };
}

export function createPushProvider(env = process.env) {
  if (env.HIC_PUSH_PROVIDER === "memory") {
    return new InMemoryPushProvider();
  }
  return new APNSPushProvider({
    teamID: env.APNS_TEAM_ID,
    keyID: env.APNS_KEY_ID,
    bundleID: env.APNS_BUNDLE_ID,
    privateKey: env.APNS_PRIVATE_KEY,
    useSandbox: env.APNS_USE_SANDBOX !== "false"
  });
}
