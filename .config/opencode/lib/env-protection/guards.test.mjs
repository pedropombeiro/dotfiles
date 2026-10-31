// Run with: node --test (from this directory). Node's runner works on every machine,
// including the NAS, where Bun doesn't run. Uses made-up values in temporary directories only.
import assert from "node:assert/strict";
import { afterEach, beforeEach, test } from "node:test";
import { createHash } from "node:crypto";
import { mkdirSync, mkdtempSync, rmSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";
import {
  BYTE_DUMP_ERROR_MSG,
  ERROR_MSG,
  EXPOSURE_ERROR_MSG,
  buildIndex,
  createGuards,
  isHighEntropy,
  redactWithIndex,
} from "./guards.mjs";

// Fixtures are derived from fixed labels at runtime, so the source holds nothing that
// looks like a secret to scanners such as gitleaks.
const fake = (label, length, encoding = "base64url") =>
  createHash("sha256").update(`env-protection-test:${label}`).digest(encoding).replace(/[-_]/g, "x").slice(0, length);
const HEX_KEY = fake("hex-key", 64, "hex");
const PASSWORD = fake("password", 20);
const DB_PASSWORD = fake("db-password", 20);
const HEADER_VALUE = fake("header-value", 32);
const PGPASS_PASSWORD = fake("pgpass", 20);
const YAML_PASSWORD = fake("yaml", 20);
const OPS_TOKEN = `ops_${fake("ops-1", 43)}${fake("ops-2", 43)}`;

// A small subset of the Jest-style matchers, on top of node:assert.
const expect = (actual) => {
  const matchers = (negate) => ({
    toBe: (expected) => (negate ? assert.notStrictEqual : assert.strictEqual)(actual, expected),
    toContain: (expected) => assert.equal(actual.includes(expected), !negate, `${negate ? "unexpected" : "missing"}: ${expected}`),
    toThrow: (message) => {
      if (negate) return assert.doesNotThrow(actual);
      assert.throws(actual, message ? (error) => error.message === message : undefined);
    },
  });
  return { ...matchers(false), not: matchers(true) };
};

let root;
let clock;

const write = (path, content) => {
  mkdirSync(join(path, ".."), { recursive: true });
  writeFileSync(path, content);
};

beforeEach(() => {
  root = mkdtempSync(join(tmpdir(), "env-protection-"));
  clock = 0;
  write(join(root, "repo/secrets/readeck_secret_key"), HEX_KEY);
  write(join(root, "repo/secrets/grafana_db_password"), PASSWORD);
  write(join(root, "repo/secrets/grafana_security_admin_user"), "admin");
  write(join(root, "repo/secrets/postgres_exporter_data_source_user"), "postgres_exporter");
  write(join(root, "repo/secrets/atuin_db_uri"), `postgres://atuin:${DB_PASSWORD}@postgres.pombei.ro:5432/atuin`);
  write(
    join(root, "repo/compose/readeck/.env"),
    `TRAEFIK_SECRET_HEADER=X-Readeck-Gate\nTRAEFIK_SECRET_VALUE=${HEADER_VALUE}\nUPLOAD_LOCATION=/share/Multimedia/Readeck\nTZ=Europe/Lisbon\n`,
  );
  write(join(root, "repo/compose/readeck/.env.tpl"), "TRAEFIK_SECRET_VALUE={{ op://NAS/readeck-traefik-header/value }}\n");
  write(join(root, "repo/data/borg/borg/.pgpass"), `postgres:5432:hass_db:hass:${PGPASS_PASSWORD}\n`);
  write(
    join(root, "repo/config/home-assistant/secrets.yaml"),
    `db_url: postgresql://hass:${YAML_PASSWORD}@postgres/hass_db\nmqtt_user: homeassistant\n`,
  );
  write(join(root, "home/.config/op/nas-service-account.token"), OPS_TOKEN);
});

afterEach(() => rmSync(root, { recursive: true, force: true }));

const guards = (extra = {}) =>
  createGuards({
    directory: join(root, "repo"),
    worktree: join(root, "repo"),
    now: () => clock,
    config: {
      secretDirs: [join(root, "repo/secrets"), join(root, "home/.config/op")],
      secretFiles: [
        join(root, "repo/data/borg/borg/.pgpass"),
        join(root, "repo/config/home-assistant/secrets.yaml"),
        join(root, "repo/compose/*/.env"),
      ],
      ...extra,
    },
  });

const redacted = (text, g = guards()) => g.redactText(text).text;

// The leaks from this session ──────────────────────────────────────────────────

test("redacts a grouped xxd dump of a protected file", () => {
  const hex = Buffer.from(HEX_KEY.slice(48)).toString("hex");
  const line = `00000030: ${hex.match(/.{4}/g).join(" ")}  ${HEX_KEY.slice(48, 57)}`;
  const output = redacted(line);
  expect(output).toContain("[REDACTED:secret-fragment]");
  expect(output).not.toContain(hex.slice(0, 12));
});

test("redacts values printed by a script that never names the file", () => {
  const output = redacted(`walked secrets/: found ${PASSWORD} in one file`);
  expect(output).not.toContain(PASSWORD);
  expect(output).toContain("[REDACTED:secret]");
});

test("redacts base64, base64url, and hex encodings", () => {
  for (const form of [
    Buffer.from(PASSWORD).toString("base64"),
    Buffer.from(HEX_KEY).toString("base64url"),
    Buffer.from(PASSWORD).toString("hex").toUpperCase(),
  ]) {
    expect(redacted(`value: ${form}`)).not.toContain(form);
  }
});

test("redacts 12-character fragments of high-entropy secrets, but not shorter ones", () => {
  expect(redacted(`tail: ${HEX_KEY.slice(20, 32)}`)).toContain("[REDACTED:secret-fragment]");
  expect(redacted(`tail: ${HEX_KEY.slice(20, 31)}`)).toContain(HEX_KEY.slice(20, 31));
});

test("redacts the password inside a URI without redacting the host", () => {
  const output = redacted(`connecting to postgres.pombei.ro:5432 with ${DB_PASSWORD}`);
  expect(output).not.toContain(DB_PASSWORD);
  expect(output).toContain("postgres.pombei.ro:5432");
});

// False positives ──────────────────────────────────────────────────────────────

test("leaves user names, short values, and ordinary text alone", () => {
  const text =
    "role postgres_exporter, user admin, commit 6d73a1f63665f623541589bd0525a5c3c9bf0c52, path /share/Multimedia/Readeck";
  expect(redacted(text)).toBe(text);
});

test("only treats secret-looking .env keys as secrets", () => {
  const output = redacted(`gate X-Readeck-Gate=${HEADER_VALUE}; upload /share/Multimedia/Readeck in Europe/Lisbon`);
  expect(output).not.toContain(HEADER_VALUE);
  expect(output).toContain("X-Readeck-Gate");
  expect(output).toContain("/share/Multimedia/Readeck");
  expect(output).toContain("Europe/Lisbon");
});

test("isHighEntropy rejects words and identifiers", () => {
  expect(isHighEntropy(HEX_KEY)).toBe(true);
  expect(isHighEntropy(PASSWORD)).toBe(true);
  expect(isHighEntropy("postgres_exporter")).toBe(false);
  expect(isHighEntropy("gitlab_dashboard")).toBe(false);
});

// File formats ─────────────────────────────────────────────────────────────────

test("parses .pgpass and YAML secret files", () => {
  const output = redacted(`pgpass ${PGPASS_PASSWORD} yaml ${YAML_PASSWORD} mqtt homeassistant`);
  expect(output).not.toContain(PGPASS_PASSWORD);
  expect(output).not.toContain(YAML_PASSWORD);
  expect(output).toContain("homeassistant");
});

test("redacts service account tokens from protected files and by format", () => {
  expect(redacted(`token ${OPS_TOKEN}`)).not.toContain(OPS_TOKEN);
  const other = `ops_${fake("ops-other-1", 43)}${fake("ops-other-2", 43)}`;
  expect(redacted(`token ${other}`, guards({ secretDirs: [], secretFiles: [] }))).toContain(
    "[REDACTED:onepassword-service-account-token]",
  );
});

test("picks up secrets added after start, once the refresh interval passes", () => {
  const g = guards();
  const late = fake("late", 20);
  expect(redacted(late, g)).toBe(late);
  write(join(root, "repo/secrets/wakapi_password_salt"), late);
  clock += 5_000;
  expect(redacted(late, g)).toBe(late);
  clock += 10_000;
  expect(redacted(late, g)).not.toContain(late);
});

// Blocked tool calls ───────────────────────────────────────────────────────────

test("blocks byte-dump commands on protected paths, relative to the shell workdir", () => {
  const g = guards();
  const workdir = join(root, "repo");
  for (const command of [
    "xxd secrets/readeck_secret_key | tail -1",
    "tail -c1 secrets/grafana_db_password | od -c",
    "head -c 16 secrets/readeck_secret_key",
    "base64 secrets/grafana_db_password",
    "cut -c1-4 data/borg/borg/.pgpass",
    "strings ~/x config/home-assistant/secrets.yaml",
  ]) {
    expect(() => g.checkToolCall({ tool: "shell", args: { command, workdir } })).toThrow(BYTE_DUMP_ERROR_MSG);
  }
});

test("allows metadata commands on protected paths and dumps of other files", () => {
  const g = guards();
  const workdir = join(root, "repo");
  for (const command of [
    "ls -l secrets/",
    "stat -c %s secrets/readeck_secret_key",
    "test -r secrets/grafana_db_password",
    "xxd compose/readeck/.env.tpl",
    "mise run secrets:sync -- --check",
  ]) {
    expect(() => g.checkToolCall({ tool: "shell", args: { command, workdir } })).not.toThrow();
  }
});

test("blocks file tools on protected files but allows .env templates", () => {
  const g = guards();
  for (const filePath of [
    join(root, "repo/secrets/grafana_db_password"),
    join(root, "repo/data/borg/borg/.pgpass"),
    join(root, "repo/config/home-assistant/secrets.yaml"),
    join(root, "repo/compose/readeck/.env"),
    join(root, "home/.config/op/nas-service-account.token"),
  ]) {
    expect(() => g.checkToolCall({ tool: "read", filePath, args: {} })).toThrow(ERROR_MSG);
  }
  expect(() =>
    g.checkToolCall({ tool: "read", filePath: join(root, "repo/compose/readeck/.env.tpl"), args: {} }),
  ).not.toThrow();
});

test("refuses to write or send a protected value", () => {
  const g = guards();
  expect(() =>
    g.checkToolCall({ tool: "write", filePath: join(root, "repo/notes.md"), args: { content: `pw ${PASSWORD}` } }),
  ).toThrow(EXPOSURE_ERROR_MSG);
  expect(() =>
    g.checkToolCall({ tool: "shell", args: { command: `echo ${HEX_KEY.slice(0, 16)} > note` } }),
  ).toThrow(EXPOSURE_ERROR_MSG);
  expect(() =>
    g.checkToolCall({ tool: "write", filePath: join(root, "repo/notes.md"), args: { content: "no secrets" } }),
  ).not.toThrow();
});

// Index ────────────────────────────────────────────────────────────────────────

test("redactWithIndex merges overlapping fragments into one marker", () => {
  const index = buildIndex([HEX_KEY]);
  const { text, count } = redactWithIndex(`a ${HEX_KEY.slice(0, 40)} b`, index);
  expect(text).toBe("a [REDACTED:secret-fragment] b");
  expect(count).toBe(1);
});

// The plugin entry point ───────────────────────────────────────────────────────

test("the plugin loads and redacts tool output and replayed history", async () => {
  write(
    join(root, "xdg/opencode/env-protection.json"),
    JSON.stringify({ secretDirs: [join(root, "repo/secrets")] }),
  );
  const previous = process.env.XDG_CONFIG_HOME;
  process.env.XDG_CONFIG_HOME = join(root, "xdg");
  try {
    const { default: plugin } = await import("../../plugins/env-protection.js");
    const hooks = {};
    const hook = (scope) => async (name, fn) => {
      hooks[`${scope}.${name}`] = fn;
    };
    await plugin.setup({
      location: { directory: join(root, "repo"), project: { directory: join(root, "repo") } },
      shell: { hook: hook("shell") },
      tool: { hook: hook("tool") },
      session: { hook: hook("session") },
    });

    expect(() =>
      hooks["tool.execute.before"]({
        tool: "shell",
        input: { command: "xxd secrets/readeck_secret_key", workdir: join(root, "repo") },
      }),
    ).toThrow(BYTE_DUMP_ERROR_MSG);

    const event = {
      tool: "shell",
      status: "completed",
      input: { command: "python3 walk.py", workdir: join(root, "repo") },
      result: { content: [{ type: "text", text: `found ${PASSWORD}` }], output: `found ${PASSWORD}` },
    };
    hooks["tool.execute.after"](event);
    expect(event.result.content[0].text).toContain("WARNING: env-protection redacted");
    expect(event.result.content[0].text).not.toContain(PASSWORD);
    expect(event.result.output).not.toContain(PASSWORD);

    const request = { messages: [{ role: "tool", content: [{ type: "text", text: `old leak ${HEX_KEY}` }] }] };
    hooks["session.context"](request);
    expect(JSON.stringify(request.messages)).not.toContain(HEX_KEY);
  } finally {
    if (previous === undefined) delete process.env.XDG_CONFIG_HOME;
    else process.env.XDG_CONFIG_HOME = previous;
  }
});
