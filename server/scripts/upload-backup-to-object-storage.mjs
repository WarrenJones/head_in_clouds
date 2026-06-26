#!/usr/bin/env node
import { uploadBackupFiles } from "../src/backup-upload.mjs";

const files = process.argv.slice(2);

try {
  if (files.length === 0) {
    throw new Error("Usage: upload-backup-to-object-storage.mjs <dump-path> [checksum-path]");
  }

  const uploads = await uploadBackupFiles({ files });
  console.log(JSON.stringify({ ok: true, uploads }, null, 2));
} catch (error) {
  console.error(JSON.stringify({
    ok: false,
    error: error.message
  }, null, 2));
  process.exitCode = 1;
}
