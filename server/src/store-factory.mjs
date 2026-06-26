import { FileAppStore } from "./app-store.mjs";
import { FileEventStore } from "./event-store.mjs";
import { createPostgresAppStore } from "./postgres-app-store.mjs";
import { createPostgresEventStore } from "./postgres-event-store.mjs";

export async function createRuntimeStoresFromEnv(env = process.env) {
  return {
    appStore: await createAppStoreFromEnv(env),
    eventStore: await createEventStoreFromEnv(env)
  };
}

async function createAppStoreFromEnv(env) {
  const mode = env.HIC_APP_STORE || (env.DATABASE_URL ? "postgres" : "file");
  if (mode === "postgres") {
    return createPostgresAppStore({
      connectionString: env.DATABASE_URL,
      sslMode: env.DATABASE_SSL_MODE,
      max: env.DATABASE_POOL_MAX
    });
  }
  if (mode === "file") {
    return new FileAppStore(env.HIC_APP_STORE_PATH);
  }
  throw new Error("HIC_APP_STORE must be file or postgres");
}

async function createEventStoreFromEnv(env) {
  const mode = env.HIC_EVENT_STORE || (env.DATABASE_URL ? "postgres" : "file");
  if (mode === "postgres") {
    return createPostgresEventStore({
      connectionString: env.DATABASE_URL,
      sslMode: env.DATABASE_SSL_MODE,
      max: env.DATABASE_POOL_MAX
    });
  }
  if (mode === "file") {
    return new FileEventStore(env.HIC_EVENT_LOG_PATH);
  }
  throw new Error("HIC_EVENT_STORE must be file or postgres");
}
