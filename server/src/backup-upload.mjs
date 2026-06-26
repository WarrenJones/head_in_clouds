import fs from "node:fs/promises";
import path from "node:path";
import { ValidationError } from "./app-store.mjs";
import { createObjectStorageProvider } from "./object-storage.mjs";

const BACKUP_BASENAME_PATTERN = /^head_in_clouds-\d{8}T\d{6}Z\.dump(?:\.sha256)?$/;

export async function uploadBackupFiles({
  files,
  storageProvider = createObjectStorageProvider(),
  prefix = process.env.HIC_BACKUP_OBJECT_PREFIX ?? "backups/postgres"
} = {}) {
  if (!Array.isArray(files) || files.length === 0) {
    throw new ValidationError("backup files are required");
  }

  const uploads = [];
  for (const filePath of files) {
    const objectKey = backupObjectKeyForPath(filePath, { prefix });
    const body = await fs.readFile(filePath);
    const result = await storageProvider.putObject({
      key: objectKey,
      body,
      contentType: contentTypeForBackup(filePath),
      isPublic: false
    });
    uploads.push({
      provider: result.provider,
      object_key: result.object_key ?? objectKey,
      etag: result.etag ?? null
    });
  }
  return uploads;
}

export function backupObjectKeyForPath(filePath, { prefix = "backups/postgres" } = {}) {
  const basename = path.basename(String(filePath ?? ""));
  if (!BACKUP_BASENAME_PATTERN.test(basename)) {
    throw new ValidationError("backup file name is invalid");
  }
  return `${normalizePrefix(prefix)}/${basename}`;
}

function normalizePrefix(prefix) {
  const normalized = String(prefix ?? "")
    .trim()
    .replace(/^\/+|\/+$/g, "");
  if (!normalized || normalized.includes("..")) {
    throw new ValidationError("backup object prefix is invalid");
  }
  return normalized;
}

function contentTypeForBackup(filePath) {
  if (String(filePath).endsWith(".sha256")) {
    return "text/plain; charset=utf-8";
  }
  return "application/octet-stream";
}
