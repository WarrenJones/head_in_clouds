import fs from "node:fs";
import path from "node:path";

const connectionString = process.env.DATABASE_URL;
if (!connectionString) {
  console.error("DATABASE_URL is required");
  process.exit(1);
}

const { Client } = await import("pg");
const schemaPath = path.resolve("schema/001_initial.sql");
const sql = fs.readFileSync(schemaPath, "utf8");
const client = new Client({
  connectionString,
  ssl: sslConfig(process.env.DATABASE_SSL_MODE)
});

await client.connect();
try {
  await client.query(sql);
  console.log(JSON.stringify({ ok: true, schema: schemaPath }, null, 2));
} finally {
  await client.end();
}

function sslConfig(mode) {
  if (!mode || mode === "disable") {
    return false;
  }
  if (mode === "require") {
    return { rejectUnauthorized: true };
  }
  if (mode === "no-verify") {
    return { rejectUnauthorized: false };
  }
  throw new Error("DATABASE_SSL_MODE must be disable, require, or no-verify");
}
