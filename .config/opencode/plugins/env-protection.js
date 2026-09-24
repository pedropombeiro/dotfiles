import { existsSync, readFileSync, realpathSync, statSync } from "node:fs";
import { basename, resolve, sep } from "node:path";

const SECRET_RULES = [
  ["gitlab-token", /\b(?:glpat|glptt|gldt|glrt|glcbt|glffct|gloas|glsoat|glagent|glptr)-[0-9A-Za-z_-]{20,}\b/g],
  ["gitlab-runner-token", /\bGR1348941[0-9A-Za-z_-]{20,}\b/g],
  ["github-token", /\b(?:ghp|gho|ghu|ghs|ghr)_[0-9A-Za-z]{36,}\b/g],
  ["github-pat", /\bgithub_pat_[0-9A-Za-z_]{22,}\b/g],
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

const EXPOSURE_TOOLS = new Set([
  "write",
  "edit",
  "apply_patch",
  "gitlab_create_note",
  "gitlab_create_discussion",
  "gitlab_create_issue",
  "gitlab_create_merge_request",
  "gitlab_update_merge_request",
  "gitlab_create_epic",
  "gitlab_update_epic",
  "gitlab_create_work_item",
  "gitlab_create_work_item_note",
]);

const redactStructuredSecrets = (text) => {
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

const containsHighConfidenceSecret = (value) => {
  if (typeof value === "string") {
    return SECRET_RULES.some(([, pattern]) => new RegExp(pattern.source, pattern.flags).test(value));
  }
  if (Array.isArray(value)) return value.some(containsHighConfidenceSecret);
  return Boolean(value && typeof value === "object" && Object.values(value).some(containsHighConfidenceSecret));
};

const redactStructuredSecretsDeep = (value) => {
  if (typeof value === "string") return redactStructuredSecrets(value).text;
  if (Array.isArray(value)) {
    for (let i = 0; i < value.length; i += 1) value[i] = redactStructuredSecretsDeep(value[i]);
  } else if (value && typeof value === "object") {
    for (const key of Object.keys(value)) value[key] = redactStructuredSecretsDeep(value[key]);
  }
  return value;
};

const SHELL_ENV_OVERRIDES = {
  MANPAGER: undefined,
  VIMPAGER_VIM: undefined,
  EDITOR: "cat",
  VISUAL: "cat",
  GIT_EDITOR: "cat",
};

const applyProcessEnvOverrides = () => {
  for (const [key, value] of Object.entries(SHELL_ENV_OVERRIDES)) {
    if (value === undefined) delete process.env[key];
    else process.env[key] = value;
  }
};

const ERROR_MSG = "Access to protected credential files is not allowed";
const EXPOSURE_ERROR_MSG =
  "Refusing to persist or expose a literal secret; use an environment variable or file reference";
const SHELL_EXPOSURE_PATTERN = /\b(?:echo|printf|print|tee)\b|\bcat\s*<</;

const warningFor = (count) =>
  `WARNING: env-protection redacted ${count} secret value(s). ` +
  "Reference them via the file path or an environment variable, never the literal value.\n";

const createGuards = ({ directory, worktree }) => {
  /**
   * Matches .env files and all variants:
   * .env, .env.local, .env.production, .env.development, .env.test, etc.
   * Handles paths like /foo/.env, /foo/.env.local, .env, ../.env.production
   *
   * Allows safe template files: .env.example, .env.sample, .env.template
   */
  const SAFE_SUFFIXES = /\.(?:example|sample|template)$/i;
  const ENV_FILE_PATTERN = /(^|[/\\])\.env(\.[a-zA-Z0-9_.]+)?$/;
  const ENV_FILE_TOKEN_PATTERN = /(?:^|[/\\])[^/\\]*\.env(?:\.[a-zA-Z0-9_.]+)?$/i;
  const MAX_ENV_FILE_SIZE = 256 * 1024;
  const PLACEHOLDER_VALUES = new Set([
    "changeme",
    "dummy",
    "example",
    "placeholder",
    "todo",
    "xxx",
  ]);

  const loadSecretDirs = () => {
    const configPath = resolve(
      process.env.XDG_CONFIG_HOME || resolve(process.env.HOME || "~", ".config"),
      "opencode",
      "env-protection.json",
    );
    try {
      const { secretDirs = [] } = JSON.parse(readFileSync(configPath, "utf8"));
      if (!Array.isArray(secretDirs)) return [];
      return secretDirs
        .filter((dir) => typeof dir === "string")
        .flatMap((dir) => {
          try {
            return [realpathSync(dir)];
          } catch {
            return [];
          }
        });
    } catch {
      return [];
    }
  };

  const secretDirs = loadSecretDirs();

  const inSecretDir = (filePath) => {
    if (!filePath) return false;
    try {
      const resolved = realpathSync(filePath);
      return secretDirs.some((dir) => resolved === dir || resolved.startsWith(dir + sep));
    } catch {
      // Also protect a path before it exists (for example, an edit creating one).
      const resolved = resolve(filePath);
      return secretDirs.some((dir) => resolved === dir || resolved.startsWith(dir + sep));
    }
  };

  /** Checks if a string contains a reference to a .env file */
  const containsEnvRef = (str) => {
    if (!str) return false;
    // Match .env variants as standalone path segments (word boundary or path separator)
    const matches = str.match(
      /\.env(\.[a-zA-Z0-9_.]+)?/gi,
    );
    if (!matches) return false;
    // Only flag if at least one match is NOT a safe template suffix
    return matches.some((m) => !SAFE_SUFFIXES.test(m));
  };

  /** Checks if a file path points to a .env variant */
  const isEnvFile = (filePath) => {
    if (!filePath) return false;
    if (SAFE_SUFFIXES.test(filePath)) return false;
    return ENV_FILE_PATTERN.test(filePath);
  };

  const isProtectedFile = (filePath) => isEnvFile(filePath) || inSecretDir(filePath);

  const envPathsInCommand = (command) => {
    if (!command) return [];
    const paths = new Set();
    for (const token of command.split(/[\s|&;<>()[\]{}'"`=]+/)) {
      if (!token || SAFE_SUFFIXES.test(token)) {
        continue;
      }
      if (ENV_FILE_TOKEN_PATTERN.test(token) || inSecretDir(token)) paths.add(token);
    }
    return [...paths];
  };

  const resolveEnvPath = (filePath) => {
    const candidates = filePath.startsWith("/")
      ? [filePath]
      : [resolve(directory, filePath), resolve(worktree, filePath)];
    return candidates.find((candidate) => existsSync(candidate));
  };

  const protectedPathsInCommand = (command) => {
    const paths = new Set(envPathsInCommand(command));
    if (!command) return [...paths];
    for (const token of command.split(/\s+/)) {
      const path = token.replace(/^["']|["']$/g, "");
      if (inSecretDir(path)) paths.add(path);
    }
    return [...paths];
  };

  const isSecretValue = (value) => {
    if (value.length < 8 || PLACEHOLDER_VALUES.has(value.toLowerCase())) return false;
    if (/^\$\{?[A-Za-z_][A-Za-z0-9_]*\}?$/.test(value)) return false;
    return !/^(?:~\/|\.\/|\/)/.test(value);
  };

  const protectedFileValues = (filePath) => {
    try {
      if (statSync(filePath).size > MAX_ENV_FILE_SIZE) return [];
      if (inSecretDir(filePath)) {
        const value = readFileSync(filePath, "utf8").trim();
        // Every non-empty file in a configured directory is secret material.
        return value
          ? [{ key: basename(filePath), value, protectedFile: true }]
          : [];
      }
      return readFileSync(filePath, "utf8")
        .split(/\r?\n/)
        .flatMap((line) => {
          const match = line.match(
            /^\s*(?:export\s+)?([A-Za-z_][A-Za-z0-9_]*)\s*=\s*(.*)\s*$/,
          );
          if (!match) return [];
          const [, key, rawValue] = match;
          const value = rawValue.replace(/^(["'])(.*)\1$/, "$2");
          return isSecretValue(value) ? [{ key, value }] : [];
        });
    } catch {
      return [];
    }
  };

  const redact = (text, values) => {
    if (typeof text !== "string") return { text, count: 0 };
    let result = text;
    let count = 0;
    for (const { key, value, source } of values) {
      if (!result.includes(value)) continue;
      count += result.split(value).length - 1;
      result = result.split(value).join(`[REDACTED:${source}:${key}]`);
    }
    return { text: result, count };
  };

  const redactDeep = (value, values) => {
    if (typeof value === "string") {
      const result = redact(value, values);
      return { value: result.text, count: result.count };
    }
    if (Array.isArray(value)) {
      const count = value.reduce((total, item, index) => {
        const result = redactDeep(item, values);
        value[index] = result.value;
        return total + result.count;
      }, 0);
      return { value, count };
    }
    if (value && typeof value === "object") {
      const count = Object.keys(value).reduce((total, key) => {
        const result = redactDeep(value[key], values);
        value[key] = result.value;
        return total + result.count;
      }, 0);
      return { value, count };
    }
    return { value, count: 0 };
  };

  // Throws when a tool call would read a protected file or expose a literal secret.
  // `filePath` is the tool's file argument (`path` on the OpenCode 2 file tools).
  const checkToolCall = ({ tool, filePath, args }) => {
    if (["read", "edit", "write", "patch", "apply_patch"].includes(tool)) {
      if (isProtectedFile(filePath)) {
        throw new Error(ERROR_MSG);
      }
    }

    if (tool === "grep") {
      if (isProtectedFile(args.path) || containsEnvRef(args.include) || containsEnvRef(args.glob)) {
        throw new Error(ERROR_MSG);
      }
    }

    if (tool === "glob") {
      if (containsEnvRef(args.pattern) || isProtectedFile(args.path)) {
        throw new Error(ERROR_MSG);
      }
    }

    const shellExposure = tool === "shell" && SHELL_EXPOSURE_PATTERN.test(args.command || "");
    if ((EXPOSURE_TOOLS.has(tool) || shellExposure) && containsHighConfidenceSecret(args)) {
      throw new Error(EXPOSURE_ERROR_MSG);
    }
  };

  // Secret values from protected files a shell command referenced, longest first.
  const commandSecretValues = (command) =>
    protectedPathsInCommand(command)
      .map(resolveEnvPath)
      .filter(Boolean)
      .flatMap((filePath) =>
        protectedFileValues(filePath).map((value) => ({
          ...value,
          source: basename(filePath),
        })),
      )
      .filter(({ value, protectedFile }) => protectedFile || isSecretValue(value))
      .sort((a, b) => b.value.length - a.value.length);

  // Redacts file values and structured secrets from a string; returns the text and hit count.
  const redactText = (text, values) => {
    const redacted = redact(text, values);
    const structured = redactStructuredSecrets(redacted.text);
    return {
      text: structured.text,
      count: redacted.count + structured.hits.reduce((total, hit) => total + hit.count, 0),
    };
  };

  // Redacts in place inside objects; returns the redacted value.
  const redactValue = (value, values) => redactStructuredSecretsDeep(redactDeep(value, values).value);

  return { checkToolCall, commandSecretValues, redactText, redactValue };
};

const textParts = (result) =>
  Array.isArray(result?.content) ? result.content.filter((part) => part?.type === "text") : [];

export default {
  id: "env-protection",
  async setup(ctx) {
    applyProcessEnvOverrides();
    const guards = createGuards({
      directory: ctx.location.directory,
      worktree: ctx.location.project.directory,
    });

    await ctx.shell.hook("create.before", (event) => {
      Object.assign(event.env, SHELL_ENV_OVERRIDES);
    });

    await ctx.tool.hook("execute.before", (event) => {
      const args = event.input || {};
      guards.checkToolCall({
        tool: event.tool,
        filePath: args.path ?? args.filePath,
        args,
      });
    });

    await ctx.tool.hook("execute.after", (event) => {
      if (event.status !== "completed" || !event.result) return;
      try {
        const values = event.tool === "shell" ? guards.commandSecretValues(event.input?.command) : [];
        const result = event.result;
        let count = 0;

        for (const part of textParts(result)) {
          const redacted = guards.redactText(part.text, values);
          part.text = redacted.text;
          count += redacted.count;
        }

        for (const key of ["output", "metadata"]) {
          if (result[key] !== undefined) result[key] = guards.redactValue(result[key], values);
        }

        if (count > 0) {
          const [first] = textParts(result);
          if (first) first.text = warningFor(count) + first.text;
          else result.content = [{ type: "text", text: warningFor(count) }, ...(result.content ?? [])];
        }
        event.result = result;
      } catch {
        // A redaction failure must never prevent the command from completing.
      }
    });

    const redactRequest = (event) => {
      if (Array.isArray(event.messages)) redactStructuredSecretsDeep(event.messages);
    };
    for (const name of ["context", "compaction", "generate", "title"]) {
      await ctx.session.hook(name, redactRequest);
    }
  },
};
