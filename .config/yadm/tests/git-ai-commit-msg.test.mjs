import assert from "node:assert/strict";
import { execFileSync, spawnSync } from "node:child_process";
import { chmodSync, mkdtempSync, rmSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import path from "node:path";
import test from "node:test";

const repoRoot = path.resolve(import.meta.dirname, "../../..");
const scriptPath = path.join(repoRoot, ".local/bin/git-ai-commit-msg");

function setupTestEnv(t, opts = {}) {
  const dir = mkdtempSync(path.join(tmpdir(), "git-ai-commit-msg-test-"));
  t.after(() => {
    rmSync(dir, { recursive: true, force: true });
  });

  const binDir = path.join(dir, "bin");
  const repoDir = path.join(dir, "repo");
  const captureFile = path.join(dir, "captured-request.json");
  execFileSync("mkdir", ["-p", binDir, repoDir]);

  // Stub opencode CLI to record the JSON payload passed to `--data`.
  const opencodeStub = path.join(binDir, "opencode");
  writeFileSync(
    opencodeStub,
    `#!/usr/bin/env sh
while [ $# -gt 0 ]; do
  if [ "$1" = "--data" ]; then
    printf '%s' "$2" > "${captureFile}"
    break
  fi
  shift
done
printf '%s\\n' '{"data":{"text":"feat(scope): test commit message"}}'
`,
  );
  chmodSync(opencodeStub, 0o755);

  // Stub ping for deterministic online/offline simulation.
  const pingStub = path.join(binDir, "ping");
  writeFileSync(
    pingStub,
    `#!/usr/bin/env sh
exit ${opts.offline ? 1 : 0}
`,
  );
  chmodSync(pingStub, 0o755);

  // Stub glab for deterministic issue lookups.
  const glabStub = path.join(binDir, "glab");
  writeFileSync(
    glabStub,
    `#!/usr/bin/env sh
if [ "${opts.glabMode ?? "public"}" = "fail" ]; then
  exit 1
fi
if [ "${opts.glabMode ?? "public"}" = "confidential" ]; then
  printf '%s\\n' '{"iid":555,"confidential":true,"labels":[]}'
  exit 0
fi
if [ "${opts.glabMode ?? "public"}" = "partial" ]; then
  printf '%s\\n' '{"iid":111}'
  exit 0
fi
printf '%s\\n' '{"iid":111,"confidential":false,"labels":[]}'
`,
  );
  chmodSync(glabStub, 0o755);

  execFileSync("git", ["init", "-q"], { cwd: repoDir });
  execFileSync(
    "git",
    [
      "remote",
      "add",
      "origin",
      opts.originUrl ?? "git@gitlab.com:gitlab-org/gitlab.git",
    ],
    { cwd: repoDir },
  );
  if (opts.branch) {
    execFileSync("git", ["checkout", "-q", "-b", opts.branch], {
      cwd: repoDir,
    });
  }

  return { dir, binDir, repoDir, captureFile };
}

function runCommitMsg({ binDir, repoDir }, diffText, extraEnv = {}) {
  const env = {
    ...process.env,
    PATH: `${binDir}:${process.env.PATH}`,
    OPENCODE_FAST_MODEL: "google-vertex/gemini-4-hydrogen",
    OPENCODE_DUO_FAST_MODEL: "gitlab/duo-chat-gpt-6-luna",
    OPENCODE_OFFLINE_MODEL: "",
    ...extraEnv,
  };
  if (!("OPENCODE_COMMIT_MODEL" in extraEnv)) {
    delete env.OPENCODE_COMMIT_MODEL;
  }
  return spawnSync("sh", [scriptPath, "--no-commit"], {
    cwd: repoDir,
    input: diffText,
    env,
    encoding: "utf8",
  });
}

const SAMPLE_DIFF = `diff --git a/app/models/user.rb b/app/models/user.rb
index 1111111..2222222 100644
--- a/app/models/user.rb
+++ b/app/models/user.rb
@@ -1,2 +1,3 @@
 class User
+  # change
 end
`;

test("routes public branch with verified public issue to OPENCODE_FAST_MODEL", async (t) => {
  const ctx = setupTestEnv(t, {
    branch: "pedropombeiro/111/public-cleanup",
    glabMode: "public",
  });
  const res = runCommitMsg(ctx, SAMPLE_DIFF);
  assert.equal(res.status, 0, res.stderr);
  const captured = JSON.parse(
    execFileSync("cat", [ctx.captureFile], { encoding: "utf8" }),
  );
  assert.deepEqual(captured.model, {
    providerID: "google-vertex",
    id: "gemini-4-hydrogen",
  });
});

test("routes confidential issue branch and failed glab lookups to OPENCODE_DUO_FAST_MODEL", async (t) => {
  const confCtx = setupTestEnv(t, {
    branch: "pedropombeiro/555/secret-fix",
    glabMode: "confidential",
  });
  const confRes = runCommitMsg(confCtx, SAMPLE_DIFF);
  assert.equal(confRes.status, 0, confRes.stderr);
  const confCaptured = JSON.parse(
    execFileSync("cat", [confCtx.captureFile], { encoding: "utf8" }),
  );
  assert.deepEqual(confCaptured.model, {
    providerID: "gitlab",
    id: "duo-chat-gpt-6-luna",
  });

  // Failed glab lookup on <user>/<iid>/... branch must fail closed to Duo.
  const failCtx = setupTestEnv(t, {
    branch: "pedropombeiro/888/unknown-issue",
    glabMode: "fail",
  });
  const failRes = runCommitMsg(failCtx, SAMPLE_DIFF);
  assert.equal(failRes.status, 0, failRes.stderr);
  const failCaptured = JSON.parse(
    execFileSync("cat", [failCtx.captureFile], { encoding: "utf8" }),
  );
  assert.deepEqual(failCaptured.model, {
    providerID: "gitlab",
    id: "duo-chat-gpt-6-luna",
  });

  // Incomplete issue payload (missing boolean confidential / array labels) must fail closed to Duo.
  const partialCtx = setupTestEnv(t, {
    branch: "pedropombeiro/111/partial-issue",
    glabMode: "partial",
  });
  const partialRes = runCommitMsg(partialCtx, SAMPLE_DIFF);
  assert.equal(partialRes.status, 0, partialRes.stderr);
  const partialCaptured = JSON.parse(
    execFileSync("cat", [partialCtx.captureFile], { encoding: "utf8" }),
  );
  assert.deepEqual(partialCaptured.model, {
    providerID: "gitlab",
    id: "duo-chat-gpt-6-luna",
  });
});

test("rejects non-gitlab OPENCODE_COMMIT_MODEL in confidential checkouts and allows gitlab/* override", async (t) => {
  const ctx = setupTestEnv(t, {
    originUrl: "git@gitlab.com:gitlab-org/security/gitlab.git",
    branch: "master",
  });

  const rejected = runCommitMsg(ctx, SAMPLE_DIFF, {
    OPENCODE_COMMIT_MODEL: "google-vertex/gemini-4-hydrogen",
  });
  assert.notEqual(rejected.status, 0);
  assert.match(rejected.stderr, /must use the gitlab\/ provider/);

  const allowed = runCommitMsg(ctx, SAMPLE_DIFF, {
    OPENCODE_COMMIT_MODEL: "gitlab/duo-chat-sonnet-5-5",
  });
  assert.equal(allowed.status, 0, allowed.stderr);
  const captured = JSON.parse(
    execFileSync("cat", [ctx.captureFile], { encoding: "utf8" }),
  );
  assert.deepEqual(captured.model, {
    providerID: "gitlab",
    id: "duo-chat-sonnet-5-5",
  });
});

test("handles offline mode across public, Work (disabled offline provider), confidential, and explicit override", async (t) => {
  // 1. Personal/non-Work with OPENCODE_OFFLINE_MODEL configured falls back to ollama.
  const personalCtx = setupTestEnv(t, {
    branch: "main",
    offline: true,
  });
  const personalRes = runCommitMsg(personalCtx, SAMPLE_DIFF, {
    OPENCODE_OFFLINE_MODEL: "ollama/gemma4:e2b",
  });
  assert.equal(personalRes.status, 0, personalRes.stderr);
  const personalCaptured = JSON.parse(
    execFileSync("cat", [personalCtx.captureFile], { encoding: "utf8" }),
  );
  assert.deepEqual(personalCaptured.model, {
    providerID: "ollama",
    id: "gemma4:e2b",
  });

  // 2. Work machine (OPENCODE_OFFLINE_MODEL="") returns explicit offline error.
  const workRes = runCommitMsg(personalCtx, SAMPLE_DIFF, {
    OPENCODE_OFFLINE_MODEL: "",
  });
  assert.notEqual(workRes.status, 0);
  assert.match(workRes.stderr, /offline commit generation is unavailable/);

  // 3. Explicit OPENCODE_COMMIT_MODEL on public checkout is not replaced by offline fallback.
  const overrideRes = runCommitMsg(personalCtx, SAMPLE_DIFF, {
    OPENCODE_COMMIT_MODEL: "gitlab/duo-chat-gpt-6-luna",
    OPENCODE_OFFLINE_MODEL: "ollama/gemma4:e2b",
  });
  assert.equal(overrideRes.status, 0, overrideRes.stderr);
  const overrideCaptured = JSON.parse(
    execFileSync("cat", [personalCtx.captureFile], { encoding: "utf8" }),
  );
  assert.deepEqual(overrideCaptured.model, {
    providerID: "gitlab",
    id: "duo-chat-gpt-6-luna",
  });

  // 4. Confidential checkout refuses offline fallback.
  const confOfflineCtx = setupTestEnv(t, {
    originUrl: "git@gitlab.com:gitlab-org/security/gitlab.git",
    branch: "master",
    offline: true,
  });
  const confOfflineRes = runCommitMsg(confOfflineCtx, SAMPLE_DIFF, {
    OPENCODE_OFFLINE_MODEL: "ollama/gemma4:e2b",
  });
  assert.notEqual(confOfflineRes.status, 0);
  assert.match(
    confOfflineRes.stderr,
    /offline commit generation is unavailable for confidential checkouts/,
  );
});

test("omits minified bundle bodies while keeping headers", async (t) => {
  const ctx = setupTestEnv(t, { branch: "main" });
  const minDiff = `diff --git a/dist/app.min.js b/dist/app.min.js
index 1111111..2222222 100644
--- a/dist/app.min.js
+++ b/dist/app.min.js
@@ -1 +1 @@
-console.log("old minified payload");
+console.log("new minified payload");
`;
  const res = runCommitMsg(ctx, minDiff);
  assert.equal(res.status, 0, res.stderr);
  const captured = JSON.parse(
    execFileSync("cat", [ctx.captureFile], { encoding: "utf8" }),
  );
  assert.match(captured.prompt, /\[generated file: diff content omitted\]/);
  assert.doesNotMatch(captured.prompt, /new minified payload/);
});
