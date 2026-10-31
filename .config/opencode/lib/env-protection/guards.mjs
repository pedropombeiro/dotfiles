// Guard logic for plugins/env-protection.js. It lives outside plugins/ so that OpenCode
// doesn't load it as a plugin and so that guards.test.mjs can exercise it directly.
import { existsSync, readdirSync, readFileSync, realpathSync, statSync } from "node:fs";
import { basename, join, resolve, sep } from "node:path";

export const SECRET_RULES = [
  ["gitlab-token", /\b(?:glpat|glptt|gldt|glrt|glcbt|glffct|gloas|glsoat|glagent|glptr)-[0-9A-Za-z_-]{20,}\b/g],
  ["gitlab-runner-token", /\bGR1348941[0-9A-Za-z_-]{20,}\b/g],
  ["github-token", /\b(?:ghp|gho|ghu|ghs|ghr)_[0-9A-Za-z]{36,}\b/g],
  ["github-pat", /\bgithub_pat_[0-9A-Za-z_]{22,}\b/g],
  ["onepassword-service-account-token", /\bops_[0-9A-Za-z_-]{50,}={0,2}/g],
  ["aws-access-key-id", /\b(?:AKIA|ASIA|AGPA|AIDA|AROA|AIPA|ANPA|ANVA)[0-9A-Z]{16}\b/g],
  ["slack-token", /\bxox[baprs]-[0-9A-Za-z-]{10,}\b/g],
  ["stripe-key", /\b(?:sk|rk)_live_[0-9A-Za-z]{20,}\b/g],
  ["google-key", /\bAIza[0-9A-Za-z_-]{35}\b/g],
  ["anthropic-key", /\bsk-ant-[0-9A-Za-z_-]{20,}\b/g],
  ["openai-key", /\bsk-(?:proj-)?[0-9A-Za-z_-]{20,}\b/g],
  ["jwt", /\beyJ[0-9A-Za-z_-]{8,}\.eyJ[0-9A-Za-z_-]{8,}\.[0-9A-Za-z_-]{8,}\b/g],
  ["private-key", /-----BEGIN (?:RSA |EC |DSA |OPENSSH |PGP |ENCRYPTED )?PRIVATE KEY-----[\s\S]*?-----END (?:RSA |EC |DSA |OPENSSH |PGP |ENCRYPTED )?PRIVATE KEY-----/g],
];

const KEYWORD_SECRET_PATTERN =
  /\b((?:[A-Za-z][A-Za-z0-9]*[_-]){0,5}(?:password|passwd|pwd|secret|api[_-]?key|access[_-]?key|client[_-]?secret|auth[_-]?token|access[_-]?token|token))\s*[:=]\s*["']?([^\s"'$<>{}]{6,})["']?/gi;

// Tools whose input stays on this machine and is never persisted. Every other
// tool's input is scanned for literal secrets before it runs, because it is
// written to a file or sent elsewhere: MCP calls (which reach this hook as
// `lazy-mcp_invoke_command`, including from Code Mode), web search and fetch,
// and subagent prompts. `shell` is handled separately below.
export const LOCAL_ONLY_TOOLS = new Set(["read", "grep", "glob"]);

export const ERROR_MSG = "Access to protected credential files is not allowed";
export const EXPOSURE_ERROR_MSG =
  "Refusing to persist or expose a literal secret; use an environment variable or file reference";
export const BYTE_DUMP_ERROR_MSG =
  "Refusing to dump or encode a protected credential file; check its length, type, or permissions instead";
const SHELL_EXPOSURE_PATTERN = /\b(?:echo|printf|print|tee)\b|\bcat\s*<</;

// Commands that print a file's bytes in another form, which exact-value redaction can't
// recognize. They're refused when the command also names a protected path.
const BYTE_DUMP_PATTERN =
  /\b(?:xxd|od|hexdump|hd|strings|base64|base32|basenc|uuencode|rev|tac)\b|\bopenssl\s+(?:enc|base64)\b|\b(?:head|tail)\s+(?:-[a-zA-Z]*c|--bytes)|\bdd\b|\bcut\s+(?:-[a-zA-Z]*[bc]|--bytes|--characters)/;

// Values shorter than this are never redacted: they are usually user names or words.
const MIN_VALUE_LENGTH = 8;
// A run of this many characters from a high-entropy secret counts as a leak.
const MIN_FRAGMENT_LENGTH = 12;
const MAX_FILE_SIZE = 256 * 1024;
const REFRESH_INTERVAL_MS = 10_000;
// Files and keys whose name ends like this hold an identifier, not a secret.
const NON_SECRET_NAME = /(?:^|[_.-])(?:user|username|login)$/i;
// .env keys whose values are secret. Other keys hold paths, host names, and settings.
// Header names, such as TRAEFIK_SECRET_HEADER, are documented in READMEs: only the value is secret.
const SECRET_ENV_KEY = /pass|pwd|secret|token|key|dsn|credential|auth|cookie|salt|value/i;
const NON_SECRET_ENV_KEY = /header$/i;
const PLACEHOLDER_VALUES = new Set(["changeme", "dummy", "example", "placeholder", "todo", "xxx"]);

export const warningFor = (count) =>
  `WARNING: env-protection redacted ${count} secret value(s). ` +
  "Reference them via the file path or an environment variable, never the literal value.\n";

export const redactStructuredSecrets = (text) => {
  if (typeof text !== "string") return { text, hits: [] };
  const hits = [];
  let result = text;
  for (const [name, pattern] of SECRET_RULES) {
    let count = 0;
    result = result.replace(new RegExp(pattern.source, pattern.flags), () => {
      count += 1;
      return `[REDACTED:${name}]`;
    });
    if (count > 0) hits.push({ name, count });
  }
  let keywordCount = 0;
  result = result.replace(
    new RegExp(KEYWORD_SECRET_PATTERN.source, KEYWORD_SECRET_PATTERN.flags),
    (match, _key, value) => {
      if (
        /^\$\{?\w+\}?$/.test(value) ||
        /^\[REDACTED/.test(value) ||
        /^(?:x{3,}|\*{3,}|<[^>]+>|changeme|example|placeholder|dummy|fake|test|none|null)$/i.test(value) ||
        /[A-Za-z_][\w.]*\s*\(/.test(value) ||
        /^[A-Za-z_]\w*(?:\.[A-Za-z_]\w*)+$/.test(value)
      ) {
        return match;
      }
      keywordCount += 1;
      return match.replace(value, "[REDACTED:keyword-secret]");
    },
  );
  if (keywordCount > 0) hits.push({ name: "keyword-secret", count: keywordCount });
  return { text: result, hits };
};

const containsStructuredSecret = (value) => {
  if (typeof value === "string") {
    return SECRET_RULES.some(([, pattern]) => new RegExp(pattern.source, pattern.flags).test(value));
  }
  if (Array.isArray(value)) return value.some(containsStructuredSecret);
  return Boolean(value && typeof value === "object" && Object.values(value).some(containsStructuredSecret));
};

export const redactStructuredSecretsDeep = (value) => {
  if (typeof value === "string") return redactStructuredSecrets(value).text;
  if (Array.isArray(value)) {
    for (let i = 0; i < value.length; i += 1) value[i] = redactStructuredSecretsDeep(value[i]);
  } else if (value && typeof value === "object") {
    for (const key of Object.keys(value)) value[key] = redactStructuredSecretsDeep(value[key]);
  }
  return value;
};

// Secret material ────────────────────────────────────────────────────────────

/** Estimates randomness, so that fragments of words and identifiers aren't treated as leaks. */
export const isHighEntropy = (value) => {
  if (value.length < MIN_FRAGMENT_LENGTH) return false;
  if (!/[0-9]/.test(value) || !/[A-Za-z]/.test(value)) return false;
  const counts = new Map();
  for (const char of value) counts.set(char, (counts.get(char) ?? 0) + 1);
  let entropy = 0;
  for (const count of counts.values()) {
    const p = count / value.length;
    entropy -= p * Math.log2(p);
  }
  return entropy >= 3;
};

const isRedactableValue = (value) =>
  value.length >= MIN_VALUE_LENGTH &&
  !PLACEHOLDER_VALUES.has(value.toLowerCase()) &&
  !/^\$\{?[A-Za-z_][A-Za-z0-9_]*\}?$/.test(value) &&
  !/^(?:~\/|\.\/|\/)/.test(value);

const SEPARATORS = /[\s:@/=&?,;'"]+/;

/** Splits a composite value, such as a URI, DSN, or header line, into its secret-looking parts. */
const secretTokens = (value) => value.split(SEPARATORS).filter((token) => token !== value && isHighEntropy(token));

// Fragments of a composite value would include its host names and paths, so only
// single-token values, and the tokens of composite ones, are matched by fragment.
const isFragmentable = (value) => isHighEntropy(value) && !SEPARATORS.test(value);

const fileFormat = (filePath) => {
  const name = basename(filePath);
  if (name === ".pgpass") return "pgpass";
  if (/^\.env(\.|$)/.test(name) || /\.env$/.test(name)) return "env";
  if (/\.ya?ml$/.test(name)) return "yaml";
  return "whole";
};

const unquote = (value) => value.trim().replace(/^(["'])(.*)\1$/, "$2");

/** The secret values a file holds, by format. Never throws. */
export const fileSecretValues = (filePath, { whole = false } = {}) => {
  try {
    if (statSync(filePath).size > MAX_FILE_SIZE) return [];
    const text = readFileSync(filePath, "utf8");
    const format = whole ? "whole" : fileFormat(filePath);
    if (format === "whole") {
      if (NON_SECRET_NAME.test(basename(filePath))) return [];
      const value = text.trim();
      return value ? [value] : [];
    }
    const values = [];
    for (const line of text.split(/\r?\n/)) {
      if (format === "pgpass") {
        const fields = line.split(":");
        if (fields.length >= 5 && !line.startsWith("#")) values.push(fields.slice(4).join(":"));
      } else if (format === "env") {
        const match = line.match(/^\s*(?:export\s+)?([A-Za-z_][A-Za-z0-9_]*)\s*=\s*(.*)\s*$/);
        if (match && SECRET_ENV_KEY.test(match[1]) && !NON_SECRET_ENV_KEY.test(match[1])) {
          values.push(unquote(match[2]));
        }
      } else {
        const match = line.match(/^\s*([A-Za-z_][\w.-]*)\s*:\s*(\S.*?)\s*$/);
        if (match && !NON_SECRET_NAME.test(match[1])) values.push(unquote(match[2]));
      }
    }
    return values.filter(Boolean);
  } catch {
    return [];
  }
};

const encodings = (value) => {
  const bytes = Buffer.from(value, "utf8");
  const hex = bytes.toString("hex");
  const base64 = bytes.toString("base64");
  const forms = [value, hex, hex.toUpperCase(), base64, base64.replace(/=+$/, ""), bytes.toString("base64url")];
  const uri = encodeURIComponent(value);
  if (uri !== value) forms.push(uri);
  return forms;
};

const stripWhitespace = (text) => text.replace(/\s+/g, "");

/**
 * An index of secret values. Exact matches cover every redactable value and its
 * encodings. Fragment matches cover runs of MIN_FRAGMENT_LENGTH characters from
 * high-entropy values and their hex form, ignoring whitespace, so a partial copy or
 * a grouped hex dump is still caught.
 */
export const buildIndex = (rawValues) => {
  const exact = new Set();
  const fragments = new Set();
  for (const raw of rawValues) {
    const candidates = [raw, ...secretTokens(raw)].filter(isRedactableValue);
    for (const value of candidates) {
      for (const form of encodings(value)) if (form.length >= MIN_VALUE_LENGTH) exact.add(form);
      if (!isFragmentable(value)) continue;
      const hex = Buffer.from(value, "utf8").toString("hex");
      for (const form of [value, hex, hex.toUpperCase()]) {
        const compact = stripWhitespace(form);
        for (let i = 0; i + MIN_FRAGMENT_LENGTH <= compact.length; i += 1) {
          fragments.add(compact.slice(i, i + MIN_FRAGMENT_LENGTH));
        }
      }
    }
  }
  // Longest first, so a value is replaced before any shorter value inside it.
  return { exact: [...exact].sort((a, b) => b.length - a.length), fragments };
};

export const EMPTY_INDEX = buildIndex([]);

/** Replaces indexed secrets in text. Returns the text and the number of replacements. */
export const redactWithIndex = (text, index, label = "secret") => {
  if (typeof text !== "string" || !text || (!index.exact.length && !index.fragments.size)) {
    return { text, count: 0 };
  }
  let result = text;
  let count = 0;
  for (const value of index.exact) {
    if (!result.includes(value)) continue;
    const parts = result.split(value);
    count += parts.length - 1;
    result = parts.join(`[REDACTED:${label}]`);
  }
  if (!index.fragments.size) return { text: result, count };

  // Match fragments on a whitespace-free view of the text, then map back to it.
  const positions = [];
  let compact = "";
  for (let i = 0; i < result.length; i += 1) {
    if (!/\s/.test(result[i])) {
      positions.push(i);
      compact += result[i];
    }
  }
  const covered = new Uint8Array(compact.length);
  let found = false;
  for (let i = 0; i + MIN_FRAGMENT_LENGTH <= compact.length; i += 1) {
    if (index.fragments.has(compact.slice(i, i + MIN_FRAGMENT_LENGTH))) {
      covered.fill(1, i, i + MIN_FRAGMENT_LENGTH);
      found = true;
    }
  }
  if (!found) return { text: result, count };

  const ranges = [];
  for (let i = 0; i < covered.length; i += 1) {
    if (!covered[i]) continue;
    let end = i;
    while (end + 1 < covered.length && covered[end + 1]) end += 1;
    ranges.push([positions[i], positions[end] + 1]);
    i = end;
  }
  let output = "";
  let last = 0;
  for (const [start, end] of ranges) {
    output += result.slice(last, start) + `[REDACTED:${label}-fragment]`;
    last = end;
  }
  return { text: output + result.slice(last), count: count + ranges.length };
};

const redactDeepWithIndex = (value, index, label) => {
  if (typeof value === "string") {
    const result = redactWithIndex(value, index, label);
    return { value: result.text, count: result.count };
  }
  let count = 0;
  if (Array.isArray(value)) {
    for (let i = 0; i < value.length; i += 1) {
      const result = redactDeepWithIndex(value[i], index, label);
      value[i] = result.value;
      count += result.count;
    }
  } else if (value && typeof value === "object") {
    for (const key of Object.keys(value)) {
      const result = redactDeepWithIndex(value[key], index, label);
      value[key] = result.value;
      count += result.count;
    }
  }
  return { value, count };
};

const indexMatches = (value, index) => {
  if (typeof value === "string") return redactWithIndex(value, index).count > 0;
  if (Array.isArray(value)) return value.some((item) => indexMatches(item, index));
  return Boolean(value && typeof value === "object" && Object.values(value).some((item) => indexMatches(item, index)));
};

// Configuration ──────────────────────────────────────────────────────────────

const expandHome = (path) => (path.startsWith("~/") ? join(process.env.HOME || "~", path.slice(2)) : path);

/** Expands `*` path segments. Other glob syntax is not supported. */
const expandGlob = (pattern) => {
  const parts = expandHome(pattern).split("/");
  let paths = [parts[0] === "" ? "/" : parts[0]];
  for (const part of parts.slice(1)) {
    if (!part) continue;
    if (!part.includes("*")) {
      paths = paths.map((path) => join(path, part));
      continue;
    }
    const matcher = new RegExp(`^${part.replace(/[.+^${}()|[\]\\]/g, "\\$&").replace(/\*/g, "[^/]*")}$`);
    paths = paths.flatMap((path) => {
      try {
        return readdirSync(path)
          .filter((name) => matcher.test(name))
          .map((name) => join(path, name));
      } catch {
        return [];
      }
    });
  }
  return paths;
};

const realpaths = (entries) =>
  (Array.isArray(entries) ? entries : [])
    .filter((entry) => typeof entry === "string")
    .flatMap(expandGlob)
    .flatMap((path) => {
      try {
        return [realpathSync(path)];
      } catch {
        return [];
      }
    });

export const loadConfig = (configPath) => {
  const path =
    configPath ??
    resolve(process.env.XDG_CONFIG_HOME || resolve(process.env.HOME || "~", ".config"), "opencode", "env-protection.json");
  try {
    const config = JSON.parse(readFileSync(path, "utf8"));
    return { secretDirs: config.secretDirs ?? [], secretFiles: config.secretFiles ?? [] };
  } catch {
    return { secretDirs: [], secretFiles: [] };
  }
};

const statSafe = (path) => {
  try {
    return statSync(path);
  } catch {
    return null;
  }
};

const walk = (dir) => {
  try {
    return readdirSync(dir, { withFileTypes: true }).flatMap((entry) => {
      const path = join(dir, entry.name);
      if (entry.isDirectory()) return walk(path);
      return entry.isFile() ? [path] : [];
    });
  } catch {
    return [];
  }
};

// Guards ─────────────────────────────────────────────────────────────────────

export const createGuards = ({ directory, worktree, config = loadConfig(), now = () => Date.now() }) => {
  /**
   * Matches .env files and all variants:
   * .env, .env.local, .env.production, .env.development, .env.test, etc.
   * Handles paths like /foo/.env, /foo/.env.local, .env, ../.env.production
   *
   * Allows safe template files: .env.example, .env.sample, .env.template, .env.tpl
   */
  const SAFE_SUFFIXES = /\.(?:example|sample|template|tpl)$/i;
  const ENV_FILE_PATTERN = /(^|[/\\])\.env(\.[a-zA-Z0-9_.]+)?$/;
  const ENV_FILE_TOKEN_PATTERN = /(?:^|[/\\])[^/\\]*\.env(?:\.[a-zA-Z0-9_.]+)?$/i;

  const secretDirs = realpaths(config.secretDirs);
  const secretFilePatterns = config.secretFiles ?? [];
  // Re-resolved on refresh, so a protected file that appears later is covered.
  let secretFiles = realpaths(secretFilePatterns);

  const resolveAgainst = (filePath, base) => {
    try {
      return realpathSync(resolve(base, filePath));
    } catch {
      // Also protect a path before it exists (for example, an edit creating one).
      return resolve(base, filePath);
    }
  };

  const inProtectedDir = (resolved) => secretDirs.some((dir) => resolved === dir || resolved.startsWith(dir + sep));
  const isProtectedPath = (resolved) => inProtectedDir(resolved) || secretFiles.includes(resolved);

  const inSecretDir = (filePath, bases = [directory, worktree]) => {
    if (!filePath) return false;
    const path = expandHome(filePath);
    if (path.startsWith("/")) return isProtectedPath(resolveAgainst(path, "/"));
    return bases.filter(Boolean).some((base) => isProtectedPath(resolveAgainst(path, base)));
  };

  /** Checks if a string contains a reference to a .env file */
  const containsEnvRef = (str) => {
    if (!str) return false;
    const matches = str.match(/\.env(\.[a-zA-Z0-9_.]+)?/gi);
    if (!matches) return false;
    return matches.some((m) => !SAFE_SUFFIXES.test(m));
  };

  /** Checks if a file path points to a .env variant */
  const isEnvFile = (filePath) => {
    if (!filePath) return false;
    if (SAFE_SUFFIXES.test(filePath)) return false;
    return ENV_FILE_PATTERN.test(filePath);
  };

  const isProtectedFile = (filePath) => isEnvFile(filePath) || inSecretDir(filePath);

  const commandBases = (workdir) => [workdir, directory, worktree].filter(Boolean);

  const protectedPathsInCommand = (command, workdir) => {
    if (!command) return [];
    const paths = new Set();
    for (const raw of command.split(/[\s|&;<>()[\]{}`=]+/)) {
      const token = raw.replace(/^["']+|["']+$/g, "");
      if (!token || SAFE_SUFFIXES.test(token)) continue;
      if (ENV_FILE_TOKEN_PATTERN.test(token) || inSecretDir(token, commandBases(workdir))) paths.add(token);
    }
    return [...paths];
  };

  const resolveExisting = (filePath, workdir) => {
    const path = expandHome(filePath);
    const candidates = path.startsWith("/") ? [path] : commandBases(workdir).map((base) => resolve(base, path));
    return candidates.find((candidate) => existsSync(candidate));
  };

  // Every protected value, refreshed when protected files change ────────────

  let index = EMPTY_INDEX;
  let signature = null;
  let checkedAt = -Infinity;

  const protectedFiles = () => [
    ...secretDirs.flatMap((dir) => (statSafe(dir)?.isDirectory() ? walk(dir) : [dir])),
    ...secretFiles,
  ];

  const refresh = () => {
    if (now() - checkedAt < REFRESH_INTERVAL_MS) return;
    checkedAt = now();
    secretFiles = realpaths(secretFilePatterns);
    const files = protectedFiles();
    const nextSignature = files
      .map((file) => {
        const info = statSafe(file);
        return `${file}:${info?.mtimeMs ?? 0}:${info?.size ?? 0}`;
      })
      .sort()
      .join("|");
    if (nextSignature === signature) return;
    signature = nextSignature;
    // Every file in a configured directory is one secret; listed files are parsed by format.
    index = buildIndex(files.flatMap((file) => fileSecretValues(file, { whole: inProtectedDir(file) })));
  };

  const currentIndex = () => {
    refresh();
    return index;
  };

  // Values of .env files a command names, which may sit outside the configured paths.
  const commandIndex = (command, workdir) => {
    const files = protectedPathsInCommand(command, workdir)
      .map((path) => resolveExisting(path, workdir))
      .filter(Boolean)
      .filter((path) => !isProtectedPath(resolveAgainst(path, "/")));
    return files.length ? buildIndex(files.flatMap((path) => fileSecretValues(path))) : EMPTY_INDEX;
  };

  // Throws when a tool call would read a protected file or expose a literal secret.
  // `filePath` is the tool's file argument (`path` on the OpenCode 2 file tools).
  const checkToolCall = ({ tool, filePath, args }) => {
    if (["read", "edit", "write", "patch", "apply_patch"].includes(tool)) {
      if (isProtectedFile(filePath)) throw new Error(ERROR_MSG);
    }

    if (tool === "patch" || tool === "apply_patch") {
      const patch = args.patchText ?? args.patch ?? "";
      for (const match of patch.matchAll(/^\*\*\* (?:Add File|Update File|Delete File|Move to): (.+)\r?$/gm)) {
        if (isProtectedFile(resolve(directory, match[1].trim()))) throw new Error(ERROR_MSG);
      }
    }

    if (tool === "grep") {
      if (isProtectedFile(args.path) || containsEnvRef(args.include) || containsEnvRef(args.glob)) {
        throw new Error(ERROR_MSG);
      }
    }

    if (tool === "glob") {
      if (containsEnvRef(args.pattern) || isProtectedFile(args.path)) throw new Error(ERROR_MSG);
    }

    if (tool === "shell") {
      const command = args.command || "";
      if (BYTE_DUMP_PATTERN.test(command) && protectedPathsInCommand(command, args.workdir).length) {
        throw new Error(BYTE_DUMP_ERROR_MSG);
      }
    }

    // Shell commands may legitimately pass a token (`curl -H ...`), so only
    // commands that print or write text are checked.
    const exposes =
      tool === "shell" ? SHELL_EXPOSURE_PATTERN.test(args.command || "") : !LOCAL_ONLY_TOOLS.has(tool);
    if (exposes && (containsStructuredSecret(args) || indexMatches(args, currentIndex()))) {
      throw new Error(EXPOSURE_ERROR_MSG);
    }
  };

  // Redacts protected values and structured secrets from a string.
  const redactText = (text, extra = EMPTY_INDEX) => {
    const fromCommand = redactWithIndex(text, extra, "file");
    const fromFiles = redactWithIndex(fromCommand.text, currentIndex());
    const structured = redactStructuredSecrets(fromFiles.text);
    return {
      text: structured.text,
      count: fromCommand.count + fromFiles.count + structured.hits.reduce((total, hit) => total + hit.count, 0),
    };
  };

  // Redacts in place inside objects; returns the redacted value and the hit count.
  const redactValue = (value, extra = EMPTY_INDEX) => {
    const fromCommand = redactDeepWithIndex(value, extra, "file");
    const fromFiles = redactDeepWithIndex(fromCommand.value, currentIndex(), "secret");
    return { value: redactStructuredSecretsDeep(fromFiles.value), count: fromCommand.count + fromFiles.count };
  };

  return { checkToolCall, commandIndex, redactText, redactValue, isProtectedFile, protectedPathsInCommand };
};

export const textParts = (result) =>
  Array.isArray(result?.content) ? result.content.filter((part) => part?.type === "text") : [];
