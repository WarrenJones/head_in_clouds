import assert from "node:assert/strict";
import fs from "node:fs/promises";
import os from "node:os";
import path from "node:path";
import test from "node:test";
import {
  backupObjectKeyForPath,
  uploadBackupFiles
} from "../src/backup-upload.mjs";

test("backup upload writes dump and checksum as private COS objects", async () => {
  const tmpDir = await fs.mkdtemp(path.join(os.tmpdir(), "hic-backup-"));
  const dumpPath = path.join(tmpDir, "head_in_clouds-20260526T050000Z.dump");
  const checksumPath = `${dumpPath}.sha256`;
  await fs.writeFile(dumpPath, "dump-bytes");
  await fs.writeFile(checksumPath, "checksum  head_in_clouds-20260526T050000Z.dump\n");

  const uploads = [];
  const storageProvider = {
    async putObject(input) {
      uploads.push(input);
      return {
        provider: "fake",
        object_key: input.key,
        etag: `"etag-${uploads.length}"`
      };
    }
  };

  try {
    const result = await uploadBackupFiles({
      files: [dumpPath, checksumPath],
      storageProvider
    });

    assert.deepEqual(result, [
      {
        provider: "fake",
        object_key: "backups/postgres/head_in_clouds-20260526T050000Z.dump",
        etag: "\"etag-1\""
      },
      {
        provider: "fake",
        object_key: "backups/postgres/head_in_clouds-20260526T050000Z.dump.sha256",
        etag: "\"etag-2\""
      }
    ]);
    assert.equal(uploads[0].contentType, "application/octet-stream");
    assert.equal(uploads[0].isPublic, false);
    assert.equal(uploads[0].body.toString("utf8"), "dump-bytes");
    assert.equal(uploads[1].contentType, "text/plain; charset=utf-8");
    assert.equal(uploads[1].isPublic, false);
    assert.match(uploads[1].body.toString("utf8"), /^checksum/);
  } finally {
    await fs.rm(tmpDir, { recursive: true, force: true });
  }
});

test("backup object key allows only expected postgres dump filenames", () => {
  assert.equal(
    backupObjectKeyForPath("/tmp/head_in_clouds-20260526T050000Z.dump", { prefix: "/secure/backups/" }),
    "secure/backups/head_in_clouds-20260526T050000Z.dump"
  );
  assert.throws(
    () => backupObjectKeyForPath("/tmp/customer-export.txt"),
    /backup file name is invalid/
  );
  assert.throws(
    () => backupObjectKeyForPath("/tmp/head_in_clouds-20260526T050000Z.dump", { prefix: "../backup" }),
    /backup object prefix is invalid/
  );
});

test("backup upload fails closed when no files are provided", async () => {
  await assert.rejects(
    uploadBackupFiles({ files: [], storageProvider: { putObject: async () => ({}) } }),
    /backup files are required/
  );
});
