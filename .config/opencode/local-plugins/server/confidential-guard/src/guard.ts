import { execFile } from "node:child_process";
import { promisify } from "node:util";

export const DUO_PROVIDER_ID = "gitlab";

export interface ModelRef {
  readonly providerID: string;
  readonly id: string;
  readonly variant?: string;
}

export interface DuoModels {
  readonly plan: ModelRef;
  readonly build: ModelRef;
  readonly explore: ModelRef;
  readonly title: ModelRef;
}

export const DUO_MODELS: DuoModels = {
  plan: { providerID: DUO_PROVIDER_ID, id: "duo-chat-gpt-6-2-astra" },
  build: { providerID: DUO_PROVIDER_ID, id: "duo-chat-gpt-6-2-sol" },
  explore: { providerID: DUO_PROVIDER_ID, id: "duo-chat-gpt-6-luna" },
  title: { providerID: DUO_PROVIDER_ID, id: "duo-chat-gpt-6-luna" },
};

export function parseModelRef(raw: unknown): ModelRef | undefined {
  if (!raw) return undefined;
  if (typeof raw === "string") {
    const trimmed = raw.trim();
    const slash = trimmed.indexOf("/");
    if (slash <= 0 || slash === trimmed.length - 1) return undefined;
    const providerID = trimmed.slice(0, slash);
    const rest = trimmed.slice(slash + 1);
    const hash = rest.indexOf("#");
    if (hash === -1) return { providerID, id: rest };
    const id = rest.slice(0, hash);
    const variant = rest.slice(hash + 1);
    if (!id) return undefined;
    return variant ? { providerID, id, variant } : { providerID, id };
  }
  if (typeof raw === "object") {
    const record = raw as {
      providerID?: unknown;
      id?: unknown;
      variant?: unknown;
    };
    if (
      typeof record.providerID === "string" &&
      record.providerID.trim() &&
      typeof record.id === "string" &&
      record.id.trim()
    ) {
      return typeof record.variant === "string" && record.variant.trim()
        ? {
            providerID: record.providerID.trim(),
            id: record.id.trim(),
            variant: record.variant.trim(),
          }
        : { providerID: record.providerID.trim(), id: record.id.trim() };
    }
  }
  return undefined;
}

function parseDuoModelRef(raw: unknown): ModelRef | undefined {
  const ref = parseModelRef(raw);
  return ref && isDuoModel(ref) ? ref : undefined;
}

export function resolveDuoModels(
  options?: unknown,
  env: Record<string, string | undefined> = process.env,
): DuoModels {
  const rawModels =
    options &&
    typeof options === "object" &&
    "models" in options &&
    options.models &&
    typeof options.models === "object"
      ? (options.models as Record<string, unknown>)
      : {};

  return {
    plan:
      parseDuoModelRef(rawModels.plan) ??
      parseDuoModelRef(env.OPENCODE_DUO_PLAN_MODEL) ??
      DUO_MODELS.plan,
    build:
      parseDuoModelRef(rawModels.build) ??
      parseDuoModelRef(env.OPENCODE_DUO_BUILD_MODEL) ??
      DUO_MODELS.build,
    explore:
      parseDuoModelRef(rawModels.explore) ??
      parseDuoModelRef(env.OPENCODE_DUO_FAST_MODEL) ??
      DUO_MODELS.explore,
    title:
      parseDuoModelRef(rawModels.title) ??
      parseDuoModelRef(env.OPENCODE_DUO_FAST_MODEL) ??
      DUO_MODELS.title,
  };
}

export interface DefaultModels {
  readonly plan?: ModelRef;
  readonly build?: ModelRef;
  readonly explore?: ModelRef;
  readonly title?: ModelRef;
}

export function resolveDefaultModels(
  options?: unknown,
  env: Record<string, string | undefined> = process.env,
): DefaultModels {
  const rawModels =
    options &&
    typeof options === "object" &&
    "defaultModels" in options &&
    options.defaultModels &&
    typeof options.defaultModels === "object"
      ? (options.defaultModels as Record<string, unknown>)
      : {};

  const plan =
    parseModelRef(rawModels.plan) ?? parseModelRef(env.OPENCODE_PLAN_MODEL);
  const build =
    parseModelRef(rawModels.build) ?? parseModelRef(env.OPENCODE_BUILD_MODEL);
  const fast = parseModelRef(env.OPENCODE_FAST_MODEL);
  const explore = parseModelRef(rawModels.explore) ?? fast;
  const title = parseModelRef(rawModels.title) ?? fast;

  return {
    ...(plan && { plan }),
    ...(build && { build }),
    ...(explore && { explore }),
    ...(title && { title }),
  };
}

export function defaultModelForAgent(
  agent?: string,
  models?: DefaultModels,
): ModelRef | undefined {
  if (agent === "build") return models?.build ?? models?.plan;
  if (agent === "explore") return models?.explore ?? models?.plan;
  if (agent === "title")
    return models?.title ?? models?.explore ?? models?.plan;
  return models?.plan;
}

export interface ConfidentialLock {
  readonly confidential: true;
  readonly reason: string;
  readonly markedAt: number;
}

export type GitLabRefKind =
  "issue" | "merge_request" | "group_work_item" | "project" | "overflow";

export interface GitLabRef {
  readonly kind: GitLabRefKind;
  readonly path: string;
  readonly iid?: string;
  readonly url?: string;
}

export interface DirectorySessionLike {
  readonly id: string;
  readonly parentID?: string;
  readonly fork?: unknown;
  readonly agent?: string;
  readonly model?: ModelRef;
  readonly metadata?: Record<string, unknown>;
  readonly location?: { readonly directory?: string };
}

export type CliRunner = (
  args: string[],
  signal?: AbortSignal,
) => Promise<string>;
export type GitRunner = (
  args: string[],
  cwd: string,
  signal?: AbortSignal,
) => Promise<string>;

const execFileAsync = promisify(execFile);

export const execGlab: CliRunner = async (args, signal) => {
  const { stdout } = await execFileAsync(
    "glab",
    ["api", "--hostname", "gitlab.com", ...args],
    { timeout: 5000, signal },
  );
  return stdout;
};

export const execGit: GitRunner = async (args, cwd, signal) => {
  const { stdout } = await execFileAsync("git", args, {
    cwd,
    timeout: 3000,
    signal,
  });
  return stdout;
};

const CONFIDENTIAL_PROJECT_PATTERNS = [
  /^gitlab-org\/security(?:\/|$)/i,
  /^gitlab-com\/gl-security(?:\/|$)/i,
  /^pedropombeiro\/work-friction(?:\/|$)/i,
];

const CONFIDENTIAL_DIR_PATTERNS = [
  /(?:^|\/)gitlab-org\/security(?:\/|$)/i,
  /(?:^|\/)gitlab-com\/gl-security(?:\/|$)/i,
  /(?:^|\/)pedropombeiro\/work-friction(?:\/|$)/i,
];

const RED_MCP_SERVER_PATTERN = /^(?:esquery(?:-staging)?|incident(?:_io)?)$/i;
const RED_DIRECT_TOOL_PATTERN =
  /^(?:(?:esquery(?:-staging)?|incident(?:_io)?)[_/:.-]|gitlab_.*(?:vulnerabilit|audit_event))/i;
// Matches the start of a shell subcommand after optional inline env assignments,
// command wrappers (mise, uv, env, run-in-tmux-pane, subshells, bundle exec),
// and a directory path prefix.
const COMMAND_BOUNDARY = String.raw`(?:^|[;&|(\n` + "`" + String.raw`])\s*`;
const ENV_ASSIGNMENTS = String.raw`(?:[A-Za-z_]\w*=\S*\s+)*`;
const COMMAND_WRAPPERS = [
  String.raw`mise\s+(?:x|exec)\s+[^;&|\n]*?--\s+`,
  String.raw`uv\s+run\s+(?:(?:--with|--python|-p)\s+\S+\s+|-[^\s]+\s+)*`,
  String.raw`env\s+(?:-[^\s]+\s+)*(?:[A-Za-z_]\w*=\S*\s+)*`,
  String.raw`run-in-tmux-pane\s+(?:-[^\s]+\s+)*["']?`,
  String.raw`(?:sh|zsh|bash)\s+(?:-[a-zA-Z]+\s+)*["']?`,
  String.raw`bundle\s+exec\s+`,
].join("|");
const OPTIONAL_PATH_PREFIX = String.raw`["']?(?:[^\s;&|\n"'()]*\/)?`;
const COMMAND_PREFIX = `${COMMAND_BOUNDARY}(?:${ENV_ASSIGNMENTS}(?:(?:${COMMAND_WRAPPERS})\\s*)*)${OPTIONAL_PATH_PREFIX}`;
const COMMAND_SUFFIX = String.raw`["']?(?=$|[\s;&|)\n` + "`" + String.raw`"'])`;
const RED_SHELL_TOOLS = ["esquery", "postgresai", "pgai", "dblab", "orbit-chq"];
const RED_SHELL_CMD_PATTERN = new RegExp(
  `${COMMAND_PREFIX}(${RED_SHELL_TOOLS.join("|")})${COMMAND_SUFFIX}`,
  "i",
);
const GLAB_SHELL_CMD_PATTERN = new RegExp(
  `${COMMAND_PREFIX}glab${COMMAND_SUFFIX}`,
  "i",
);

const CONFIDENTIAL_TEXT_URL_PATTERN =
  /(?:gitlab\.com\/|gitlab\.com:)(gitlab-org\/security(?:\/[\w.-]+)*|gitlab-com\/gl-security(?:\/[\w.-]+)*|pedropombeiro\/work-friction)(?=$|[/#?'"\s)\]}.,;:])/i;
const CONFIDENTIAL_ENCODED_PATTERN =
  /\b(gitlab-org%2Fsecurity(?:%2F[\w.-]+)*|gitlab-com%2Fgl-security(?:%2F[\w.-]+)*|pedropombeiro%2Fwork-friction)\b/i;

const WORK_ITEM_CONFIDENTIAL_QUERY =
  "query($fullPath: ID!, $iid: String!) { namespace(fullPath: $fullPath) { workItem(iid: $iid) { confidential } } }";

const MAX_REFS_PER_TEXT = 16;
const NON_CONFIDENTIAL_CACHE_TTL_MS = 5 * 60 * 1000;

export function isDuoModel(model?: { readonly providerID?: string }): boolean {
  return model?.providerID === DUO_PROVIDER_ID;
}

export function duoModelForAgent(
  agent?: string,
  inheritedDuoModel?: ModelRef,
  models: DuoModels = DUO_MODELS,
): ModelRef {
  if (agent === "build") return models.build;
  if (agent === "explore") return models.explore;
  if (agent === "title") return models.title;
  if (agent === "general" && isDuoModel(inheritedDuoModel)) {
    return inheritedDuoModel!;
  }
  return models.plan;
}

export function safeDecodeURIComponent(value: string): string {
  try {
    return decodeURIComponent(value);
  } catch {
    return value;
  }
}

export function normalizeGitLabProject(raw: string): string {
  let cleaned = safeDecodeURIComponent(raw.trim());
  cleaned = cleaned
    .replace(/^https?:\/\/gitlab\.com\//i, "")
    .replace(/^ssh:\/\/git@gitlab\.com\//i, "")
    .replace(/^git@gitlab\.com:/i, "")
    .replace(/^\/+/, "")
    .replace(/\/-\/.*$/, "")
    .replace(/\.git$/i, "")
    .replace(/[./]+$/, "");
  if (cleaned.toLowerCase().startsWith("groups/")) {
    cleaned = cleaned.slice("groups/".length);
  }
  return cleaned;
}

export function isConfidentialProjectPath(raw?: string): boolean {
  if (!raw || typeof raw !== "string") return false;
  const normalized = normalizeGitLabProject(raw);
  return CONFIDENTIAL_PROJECT_PATTERNS.some((pattern) =>
    pattern.test(normalized),
  );
}

export function confidentialReasonForDirectory(
  directory?: string,
): string | undefined {
  if (!directory) return undefined;
  const normalized = directory.replace(/\\/g, "/");
  for (const pattern of CONFIDENTIAL_DIR_PATTERNS) {
    const match = pattern.exec(normalized);
    if (match) {
      return `confidential repository directory (${match[0].replace(/^\/|\/$/g, "")})`;
    }
  }
  return undefined;
}

export function parseGitLabRemote(url: string): string | undefined {
  const trimmed = url.trim();
  const match =
    /^(?:https?:\/\/|ssh:\/\/git@|git@)gitlab\.com[:/]((?:[\w.-]+\/)+[\w.-]+?)(?:\.git)?\/?$/i.exec(
      trimmed,
    );
  return match?.[1];
}

export interface GitRepoAnalysis {
  readonly confidentialReason?: string;
  readonly defaultProject?: string;
}

// Inspects origin and the current branch's tracking remotes rather than every
// configured remote, because shared checkouts such as $GDK_ROOT/gitlab carry
// an idle `security` remote even while working on public branches.
export function analyzeGitConfig(
  configOutput: string,
  branch?: string,
): GitRepoAnalysis {
  const remotes = new Map<string, string>();
  const branchRemotes = new Set<string>();

  for (const rawLine of configOutput.split(/\r?\n/)) {
    const line = rawLine.trim();
    if (!line) continue;
    const spaceIdx = line.indexOf(" ");
    if (spaceIdx === -1) continue;
    const key = line.slice(0, spaceIdx);
    const value = line.slice(spaceIdx + 1).trim();

    const remoteMatch = /^remote\.(.+)\.url$/i.exec(key);
    if (remoteMatch) {
      remotes.set(remoteMatch[1], value);
      continue;
    }

    if (branch) {
      const branchPrefix = `branch.${branch}.`;
      if (
        key === `${branchPrefix}remote` ||
        key === `${branchPrefix}pushremote`
      ) {
        if (value) branchRemotes.add(value);
      }
    }
  }

  const originUrl = remotes.get("origin");
  const originProject = originUrl ? parseGitLabRemote(originUrl) : undefined;
  if (originProject && isConfidentialProjectPath(originProject)) {
    return {
      confidentialReason: `confidential origin remote (${originProject})`,
      defaultProject: originProject,
    };
  }

  for (const remoteName of branchRemotes) {
    const remoteUrl = remotes.get(remoteName);
    const project = remoteUrl ? parseGitLabRemote(remoteUrl) : undefined;
    if (project && isConfidentialProjectPath(project)) {
      return {
        confidentialReason: `branch "${branch}" tracks confidential remote "${remoteName}" (${project})`,
        defaultProject: project,
      };
    }
  }

  let defaultProject = originProject;
  if (!defaultProject) {
    const upstreamUrl = remotes.get("upstream");
    defaultProject = upstreamUrl ? parseGitLabRemote(upstreamUrl) : undefined;
  }
  if (!defaultProject) {
    for (const [name, url] of remotes) {
      const project = parseGitLabRemote(url);
      if (
        project &&
        name !== "security" &&
        !isConfidentialProjectPath(project)
      ) {
        defaultProject = project;
        break;
      }
    }
  }

  return { defaultProject };
}

export function extractBranchIssueIid(branch?: string): string | undefined {
  if (!branch) return undefined;
  const match = /^[a-zA-Z0-9._-]+\/([1-9]\d*)(?:\/|$)/.exec(branch.trim());
  return match?.[1];
}

export function linkedOwner(session: DirectorySessionLike): string | undefined {
  const value = session.metadata?.forgekeeper;
  const linked =
    value && typeof value === "object"
      ? (value as { linked?: { owner?: unknown; session?: unknown } }).linked
      : undefined;
  if (!linked || typeof linked.owner !== "string") return undefined;
  if (
    typeof linked.session === "string"
      ? linked.session !== session.id
      : !!session.fork
  ) {
    return undefined;
  }
  return linked.owner;
}

export function forkSource(session: DirectorySessionLike): string | undefined {
  const fork = session.fork;
  if (!fork || typeof fork !== "object") return undefined;
  const sessionID = (fork as { sessionID?: unknown }).sessionID;
  return typeof sessionID === "string" && sessionID ? sessionID : undefined;
}

export function extractTargetsFromInstructions(
  entries: ReadonlyArray<{ readonly key: string; readonly value: string }>,
): string | undefined {
  const entry = entries.find(
    (item) => item.key === "forgekeeper-session-target",
  );
  if (!entry) return undefined;
  const text = entry.value.trim();
  if (!text || /Current session target:\s*none\.?$/i.test(text))
    return undefined;
  return text;
}

export function extractGitLabRefs(
  text: string,
  defaultProject?: string,
): GitLabRef[] {
  if (!text) return [];
  const results: GitLabRef[] = [];
  const seen = new Set<string>();
  let networkCount = 0;

  const add = (ref: GitLabRef) => {
    const isOfflineConfidential =
      ref.kind === "project" || isConfidentialProjectPath(ref.path);
    const key = `${ref.kind}:${ref.path.toLowerCase()}:${ref.iid ?? ""}`;
    if (seen.has(key)) return;
    if (!isOfflineConfidential && networkCount >= MAX_REFS_PER_TEXT) {
      if (!seen.has("overflow")) {
        seen.add("overflow");
        results.push({
          kind: "overflow",
          path: ref.path,
          iid: ref.iid,
        });
      }
      return;
    }
    seen.add(key);
    if (!isOfflineConfidential) networkCount += 1;
    results.push(ref);
  };

  // 0. Catch any confidential project URL or encoded path first without cap.
  const confidentialProjectUrl = new RegExp(
    CONFIDENTIAL_TEXT_URL_PATTERN.source,
    "gi",
  );
  for (const match of text.matchAll(confidentialProjectUrl)) {
    add({
      kind: "project",
      path: normalizeGitLabProject(match[1]),
      url: match[0],
    });
  }
  const confidentialEncoded = new RegExp(
    CONFIDENTIAL_ENCODED_PATTERN.source,
    "gi",
  );
  for (const match of text.matchAll(confidentialEncoded)) {
    add({
      kind: "project",
      path: normalizeGitLabProject(match[1]),
      url: match[0],
    });
  }

  // 1. Full GitLab URLs
  const groupWorkItemUrl =
    /\bhttps:\/\/gitlab\.com\/groups\/((?:[\w.-]+\/)*[\w.-]+)\/-\/(?:epics|work_items)\/([1-9]\d*)(?![\w-])/gi;
  for (const match of text.matchAll(groupWorkItemUrl)) {
    add({
      kind: "group_work_item",
      path: match[1],
      iid: match[2],
      url: match[0],
    });
  }

  const issueUrl =
    /\bhttps:\/\/gitlab\.com\/((?:[\w.-]+\/)+[\w.-]+)\/-\/(?:issues|work_items)\/([1-9]\d*)(?![\w-])/gi;
  for (const match of text.matchAll(issueUrl)) {
    if (match[1].toLowerCase().startsWith("groups/")) continue;
    add({
      kind: "issue",
      path: match[1],
      iid: match[2],
      url: match[0],
    });
  }

  const mrUrl =
    /\bhttps:\/\/gitlab\.com\/((?:[\w.-]+\/)+[\w.-]+)\/-\/merge_requests\/([1-9]\d*)(?![\w-])/gi;
  for (const match of text.matchAll(mrUrl)) {
    add({
      kind: "merge_request",
      path: match[1],
      iid: match[2],
      url: match[0],
    });
  }

  // 2. Qualified shorthands (group/project#123, group/project!123, group&123)
  const projectIssueRef =
    /(?<![\w/.:=?&-])((?:[\w.-]+\/)+[\w.-]+)#([1-9]\d*)(?![\w-])/gi;
  for (const match of text.matchAll(projectIssueRef)) {
    add({ kind: "issue", path: match[1], iid: match[2] });
  }

  const projectMrRef =
    /(?<![\w/.:=?&-])((?:[\w.-]+\/)+[\w.-]+)!([1-9]\d*)(?![\w-])/gi;
  for (const match of text.matchAll(projectMrRef)) {
    add({ kind: "merge_request", path: match[1], iid: match[2] });
  }

  const epicRef =
    /(?<![\w/.:=?&-])([a-zA-Z][\w.-]*(?:\/[\w.-]+)*)&([1-9]\d*)(?![\w-])/gi;
  for (const match of text.matchAll(epicRef)) {
    const groupPath = match[1];
    if (groupPath.includes("/") || /^gitlab-(?:org|com)$/i.test(groupPath)) {
      add({ kind: "group_work_item", path: groupPath, iid: match[2] });
    }
  }

  // 3. Bare shorthands (#123, !123) when defaultProject is known
  if (defaultProject) {
    const bareIssueRef = /(?<![\w/.:=?&-])#([1-9]\d*)(?![\w-])/g;
    for (const match of text.matchAll(bareIssueRef)) {
      add({ kind: "issue", path: defaultProject, iid: match[1] });
    }

    const bareMrRef = /(?<![\w/.:=?&-])!([1-9]\d*)(?![\w-])/g;
    for (const match of text.matchAll(bareMrRef)) {
      add({ kind: "merge_request", path: defaultProject, iid: match[1] });
    }
  }

  return results;
}

function hasConfidentialSecurityLabels(labels: unknown): boolean {
  if (!Array.isArray(labels)) return false;
  const normalized = labels
    .map((item) => {
      if (typeof item === "string") return item.toLowerCase();
      if (
        item &&
        typeof item === "object" &&
        typeof (item as { name?: unknown }).name === "string"
      ) {
        return (item as { name: string }).name.toLowerCase();
      }
      return "";
    })
    .filter(Boolean);
  return (
    normalized.includes("security") &&
    !normalized.includes("security-fix-in-public")
  );
}

function collectStrings(
  value: unknown,
  maxDepth = 4,
  out: string[] = [],
): string[] {
  if (maxDepth < 0 || value == null) return out;
  if (typeof value === "string") {
    out.push(value);
    return out;
  }
  if (Array.isArray(value)) {
    for (const item of value) collectStrings(item, maxDepth - 1, out);
    return out;
  }
  if (typeof value === "object") {
    for (const val of Object.values(value as Record<string, unknown>)) {
      collectStrings(val, maxDepth - 1, out);
    }
  }
  return out;
}

const PROJECT_PARAM_KEYS = new Set([
  "project_id",
  "group_id",
  "full_path",
  "fullPath",
  "project",
  "repo",
  "repository",
  "url",
  "target",
  "targets",
  "issue_url",
]);

function confidentialProjectInObject(
  value: unknown,
  depth = 3,
): string | undefined {
  if (depth < 0 || value == null) return undefined;
  if (typeof value === "string") {
    const urlMatch = CONFIDENTIAL_TEXT_URL_PATTERN.exec(value);
    if (urlMatch) return urlMatch[1];
    const encodedMatch = CONFIDENTIAL_ENCODED_PATTERN.exec(value);
    if (encodedMatch) return safeDecodeURIComponent(encodedMatch[1]);
    return undefined;
  }
  if (Array.isArray(value)) {
    for (const item of value) {
      const hit = confidentialProjectInObject(item, depth - 1);
      if (hit) return hit;
    }
    return undefined;
  }
  if (typeof value === "object") {
    for (const [key, val] of Object.entries(value as Record<string, unknown>)) {
      if (PROJECT_PARAM_KEYS.has(key)) {
        for (const str of collectStrings(val, 2)) {
          if (isConfidentialProjectPath(str))
            return normalizeGitLabProject(str);
        }
      }
      const nested = confidentialProjectInObject(val, depth - 1);
      if (nested) return nested;
    }
  }
  return undefined;
}

export function checkToolCallBefore(
  tool: string,
  input: unknown,
): { readonly reason: string } | undefined {
  const args =
    input && typeof input === "object"
      ? (input as Record<string, unknown>)
      : {};

  if (RED_DIRECT_TOOL_PATTERN.test(tool)) {
    return { reason: `RED tool "${tool}" requires GitLab Duo` };
  }

  for (const pathKey of ["path", "filePath", "workdir", "directory"]) {
    const rawPath = args[pathKey];
    if (typeof rawPath === "string") {
      const dirReason = confidentialReasonForDirectory(rawPath);
      if (dirReason) {
        return { reason: `tool "${tool}" accesses ${dirReason}` };
      }
    }
  }

  if (tool === "lazy-mcp_invoke_command") {
    const server = typeof args.server === "string" ? args.server.trim() : "";
    if (RED_MCP_SERVER_PATTERN.test(server)) {
      return { reason: `RED MCP server "${server}" requires GitLab Duo` };
    }
    if (server.toLowerCase() === "gitlab") {
      const commandName =
        typeof args.command_name === "string"
          ? args.command_name.trim()
          : typeof args.command === "string"
            ? args.command.trim()
            : "";
      if (/vulnerabilit|audit_event/i.test(commandName)) {
        return {
          reason: `GitLab MCP command "${commandName}" requires GitLab Duo`,
        };
      }
      const params = args.parameters ?? args.arguments ?? args.args ?? args;
      const hit = confidentialProjectInObject(params);
      if (hit) {
        return {
          reason: `GitLab MCP call targets confidential project (${hit})`,
        };
      }
    }
    return undefined;
  }

  if (tool.startsWith("gitlab_") || tool === "gitlab") {
    const hit = confidentialProjectInObject(args);
    if (hit) {
      return {
        reason: `GitLab tool "${tool}" targets confidential project (${hit})`,
      };
    }
    return undefined;
  }

  if (tool === "shell") {
    const command = typeof args.command === "string" ? args.command : "";
    if (!command) return undefined;

    const redMatch = RED_SHELL_CMD_PATTERN.exec(command);
    if (redMatch) {
      return { reason: `RED shell tool "${redMatch[1]}" requires GitLab Duo` };
    }

    if (GLAB_SHELL_CMD_PATTERN.test(command)) {
      const urlHit = CONFIDENTIAL_TEXT_URL_PATTERN.exec(command);
      if (urlHit) {
        return {
          reason: `glab command targets confidential project (${urlHit[1]})`,
        };
      }
      const encodedHit = CONFIDENTIAL_ENCODED_PATTERN.exec(command);
      if (encodedHit) {
        return {
          reason: `glab command targets confidential project (${safeDecodeURIComponent(encodedHit[1])})`,
        };
      }
      const bareConfidential =
        /(?:^|[\s"'=:/])(gitlab-org\/security(?:\/[\w.-]+)*|gitlab-com\/gl-security(?:\/[\w.-]+)*|pedropombeiro\/work-friction)(?=$|[\s"'/;,)])/i.exec(
          command,
        );
      if (bareConfidential) {
        return {
          reason: `glab command targets confidential project (${bareConfidential[1]})`,
        };
      }
    }

    const dirReason = confidentialReasonForDirectory(command);
    if (dirReason) {
      const urlHit = CONFIDENTIAL_TEXT_URL_PATTERN.exec(command);
      // Strip URLs only for the diagnostic; the original match still locks the session.
      const gitLabUrls =
        /\b(?:https?:\/\/|ssh:\/\/git@|git@)gitlab\.com[/:][^\s"'`<>;&|()]+/gi;
      if (
        urlHit &&
        !confidentialReasonForDirectory(command.replace(gitLabUrls, " "))
      ) {
        return {
          reason: `shell command contains a confidential GitLab reference (${urlHit[1]})`,
        };
      }
      return { reason: `shell command text matches a ${dirReason} pattern` };
    }
  }

  return undefined;
}

function scalarId(value: unknown): string | undefined {
  if (typeof value === "number" && Number.isInteger(value) && value > 0) {
    return String(value);
  }
  if (typeof value === "string" && /^[1-9]\d*$/.test(value.trim())) {
    return value.trim();
  }
  return undefined;
}

function extractStructuredGitLabRefs(
  tool: string,
  params: Record<string, unknown>,
  defaultProject?: string,
): GitLabRef[] {
  const refs: GitLabRef[] = [];
  const rawProject =
    params.project_id ??
    params.fullPath ??
    params.full_path ??
    params.project ??
    params.group_id;
  const project =
    typeof rawProject === "string" && rawProject.trim()
      ? normalizeGitLabProject(rawProject)
      : defaultProject;

  if (typeof rawProject === "string" && isConfidentialProjectPath(rawProject)) {
    refs.push({
      kind: "project",
      path: normalizeGitLabProject(rawProject),
    });
  }

  if (project) {
    const issueIid = scalarId(
      params.issue_iid ?? params.work_item_iid ?? params.work_item_id,
    );
    if (issueIid) {
      refs.push({ kind: "issue", path: project, iid: issueIid });
    }

    const mrIid = scalarId(params.mr_iid ?? params.merge_request_iid);
    if (mrIid) {
      refs.push({ kind: "merge_request", path: project, iid: mrIid });
    }

    const epicIid = scalarId(params.epic_iid);
    if (epicIid) {
      refs.push({ kind: "group_work_item", path: project, iid: epicIid });
    }

    const resourceIid = scalarId(params.resource_iid ?? params.iid);
    const resourceType =
      typeof params.resource_type === "string"
        ? params.resource_type.toLowerCase()
        : "";
    if (resourceIid && resourceType) {
      if (resourceType === "merge_request") {
        refs.push({ kind: "merge_request", path: project, iid: resourceIid });
      } else if (resourceType === "issue" || resourceType === "work_item") {
        refs.push({ kind: "issue", path: project, iid: resourceIid });
      } else if (resourceType === "epic") {
        refs.push({ kind: "group_work_item", path: project, iid: resourceIid });
      }
    }

    const genericIid = scalarId(params.iid);
    if (
      genericIid &&
      !resourceType &&
      !issueIid &&
      !mrIid &&
      !epicIid &&
      !scalarId(params.resource_iid)
    ) {
      if (/merge_request|_mr(?:_|$)/i.test(tool)) {
        refs.push({ kind: "merge_request", path: project, iid: genericIid });
      } else if (/epic/i.test(tool)) {
        refs.push({ kind: "group_work_item", path: project, iid: genericIid });
      } else {
        refs.push({ kind: "issue", path: project, iid: genericIid });
      }
    }
  }

  for (const str of collectStrings(params, 3)) {
    for (const ref of extractGitLabRefs(str, project)) {
      refs.push(ref);
    }
  }

  return refs;
}

function extractGlabCommandRefs(
  command: string,
  defaultProject?: string,
): GitLabRef[] {
  const refs = extractGitLabRefs(command, defaultProject);

  // `glab api projects/<project>/(issues|merge_requests)/<iid>...`
  const apiMatch =
    /\bprojects\/([^\s/"']+)\/(issues|merge_requests)\/([1-9]\d*)\b/gi;
  for (const match of command.matchAll(apiMatch)) {
    const project = normalizeGitLabProject(match[1]);
    const kind =
      match[2].toLowerCase() === "merge_requests" ? "merge_request" : "issue";
    refs.push({ kind, path: project, iid: match[3] });
  }

  // `glab (issue|mr) (view|note|discussion|...) <iid> [-R <project>]`
  const repoFlag =
    /(?:^|\s)(?:-R|--repo)(?:=|\s+)["']?((?:gitlab\.com\/)?(?:[\w.-]+\/)+[\w.-]+)["']?/i.exec(
      command,
    );
  const project = repoFlag
    ? normalizeGitLabProject(repoFlag[1])
    : defaultProject;
  if (project) {
    const subcommandMatch =
      /\bglab\s+(issue|mr)\s+(?:view|note|comment|diff|checkout|show|list)\s+(?:-[^\s]+\s+)*([1-9]\d*)\b/i.exec(
        command,
      );
    if (subcommandMatch) {
      const kind =
        subcommandMatch[1].toLowerCase() === "mr" ? "merge_request" : "issue";
      refs.push({ kind, path: project, iid: subcommandMatch[2] });
    }
  }

  return refs;
}

export function extractToolInputRefs(
  tool: string,
  input: unknown,
  defaultProject?: string,
): GitLabRef[] {
  const args =
    input && typeof input === "object"
      ? (input as Record<string, unknown>)
      : {};

  if (tool === "set_session_target") {
    const urls = extractSetSessionTargetUrls(input);
    return extractGitLabRefs(urls.join("\n"), defaultProject);
  }

  if (tool === "rename_issue_session" || tool === "rename_mr_review_session") {
    const url = typeof args.url === "string" ? args.url : "";
    return extractGitLabRefs(url, defaultProject);
  }

  if (tool.startsWith("gitlab_") || tool === "gitlab") {
    return extractStructuredGitLabRefs(tool, args, defaultProject);
  }

  if (tool === "lazy-mcp_invoke_command") {
    const server =
      typeof args.server === "string" ? args.server.trim().toLowerCase() : "";
    if (server === "gitlab") {
      const commandName =
        typeof args.command_name === "string"
          ? args.command_name
          : typeof args.command === "string"
            ? args.command
            : "gitlab";
      const params =
        args.parameters && typeof args.parameters === "object"
          ? (args.parameters as Record<string, unknown>)
          : args.arguments && typeof args.arguments === "object"
            ? (args.arguments as Record<string, unknown>)
            : args;
      return extractStructuredGitLabRefs(commandName, params, defaultProject);
    }
    return [];
  }

  if (tool === "shell") {
    const command = typeof args.command === "string" ? args.command : "";
    if (GLAB_SHELL_CMD_PATTERN.test(command)) {
      return extractGlabCommandRefs(command, defaultProject);
    }
  }

  return [];
}

export function isGitLabOutputTool(tool: string, input: unknown): boolean {
  if (
    tool.startsWith("gitlab_") ||
    tool === "gitlab" ||
    tool === "vent" ||
    tool === "rename_issue_session" ||
    tool === "rename_mr_review_session"
  ) {
    return true;
  }
  const args =
    input && typeof input === "object"
      ? (input as Record<string, unknown>)
      : {};
  if (tool === "lazy-mcp_invoke_command") {
    const server =
      typeof args.server === "string" ? args.server.trim().toLowerCase() : "";
    return server === "gitlab";
  }
  if (tool === "shell") {
    const command = typeof args.command === "string" ? args.command : "";
    return GLAB_SHELL_CMD_PATTERN.test(command);
  }
  return false;
}

export function extractResultText(result: unknown): string {
  if (typeof result === "string") return result;
  if (!result || typeof result !== "object") return "";
  const record = result as Record<string, unknown>;
  const chunks: string[] = [];

  if (typeof record.content === "string") {
    chunks.push(record.content);
  } else if (Array.isArray(record.content)) {
    for (const part of record.content) {
      if (typeof part === "string") chunks.push(part);
      else if (
        part &&
        typeof part === "object" &&
        typeof (part as { text?: unknown }).text === "string"
      ) {
        chunks.push((part as { text: string }).text);
      }
    }
  }

  if (typeof record.output === "string") {
    chunks.push(record.output);
  } else if (record.output !== undefined) {
    try {
      chunks.push(JSON.stringify(record.output));
    } catch {
      // ignore unserializable output
    }
  }

  return chunks.join("\n");
}

function detectConfidentialObject(
  value: unknown,
  depth = 5,
): string | undefined {
  if (depth < 0 || !value || typeof value !== "object") return undefined;
  if (Array.isArray(value)) {
    for (const item of value) {
      const hit = detectConfidentialObject(item, depth - 1);
      if (hit) return hit;
    }
    return undefined;
  }
  const record = value as Record<string, unknown>;
  if (record.confidential === true) {
    return "confidential GitLab item in tool output";
  }
  if (hasConfidentialSecurityLabels(record.labels)) {
    return "security-labeled GitLab item in tool output";
  }
  if (
    typeof record.source_branch === "string" &&
    /(?:^|\/)security-/i.test(record.source_branch)
  ) {
    return `security-branch GitLab item in tool output (${record.source_branch})`;
  }
  for (const nested of Object.values(record)) {
    if (nested && typeof nested === "object") {
      const hit = detectConfidentialObject(nested, depth - 1);
      if (hit) return hit;
    }
  }
  return undefined;
}

export function detectConfidentialOutput(text: string): string | undefined {
  if (!text) return undefined;
  if (/"confidential"\s*:\s*true\b/i.test(text)) {
    return "confidential GitLab item in tool output";
  }
  if (/(?:^|[\r\n])\s*confidential\s*[:\t]\s*(?:true|yes)\b/i.test(text)) {
    return "confidential GitLab item in tool output";
  }
  const urlMatch = CONFIDENTIAL_TEXT_URL_PATTERN.exec(text);
  if (urlMatch) {
    return `confidential GitLab project in tool output (${urlMatch[1]})`;
  }
  const encodedMatch = CONFIDENTIAL_ENCODED_PATTERN.exec(text);
  if (encodedMatch) {
    return `confidential GitLab project in tool output (${safeDecodeURIComponent(encodedMatch[1])})`;
  }
  if (
    (text.includes("{") || text.includes("[")) &&
    (/labels|source_branch|confidential/i.test(text) ||
      text.trimStart().startsWith("{") ||
      text.trimStart().startsWith("["))
  ) {
    const trimmed = text.trim();
    const candidates = [trimmed];
    const firstObj = trimmed.search(/[{[]/);
    if (firstObj > 0) {
      candidates.push(trimmed.slice(firstObj));
    }
    for (const candidate of candidates) {
      try {
        const parsed = JSON.parse(candidate);
        const hit = detectConfidentialObject(parsed);
        if (hit) return hit;
        break;
      } catch {
        // Not valid standalone JSON; continue.
      }
    }
  }
  return undefined;
}

export function formatRedactionNotice(
  reason: string,
  targetModel: ModelRef,
  switched = true,
): string {
  const status = switched
    ? `Session model switched to ${targetModel.providerID}/${targetModel.id}; re-run the tool on the next turn.`
    : `Automatic model switch to ${targetModel.providerID}/${targetModel.id} failed; switch the session model manually before continuing.`;
  return `[Confidential GitLab content withheld from upstream model (${reason}). ${status}]`;
}

export function redactToolResult<T extends Record<string, unknown>>(
  result: T,
  notice: string,
): T {
  const next: Record<string, unknown> = { ...result };
  if (typeof result.content === "string") {
    next.content = notice;
  } else {
    next.content = [{ type: "text", text: notice }];
  }
  if ("output" in next) {
    next.output = notice;
  }
  if ("metadata" in next && next.metadata !== undefined) {
    next.metadata = { confidentialRedacted: true };
  }
  return next as T;
}

export function extractSetSessionTargetUrls(input: unknown): string[] {
  if (!input || typeof input !== "object") return [];
  const args = input as Record<string, unknown>;
  const urls: string[] = [];
  if (typeof args.target === "string" && args.target !== "none") {
    urls.push(args.target);
  }
  if (Array.isArray(args.targets)) {
    for (const item of args.targets) {
      if (typeof item === "string") urls.push(item);
    }
  }
  if (typeof args.issue_url === "string") {
    urls.push(args.issue_url);
  }
  return urls;
}

export function extractMessageText(content: unknown): string {
  if (typeof content === "string") return content;
  if (Array.isArray(content)) {
    return content
      .flatMap((part) => {
        if (typeof part === "string") return [part];
        if (
          part &&
          typeof part === "object" &&
          typeof (part as { text?: unknown }).text === "string"
        ) {
          return [(part as { text: string }).text];
        }
        return [];
      })
      .join("\n");
  }
  return "";
}

export type RecentContextEntry =
  | { readonly kind: "user"; readonly text: string }
  | { readonly kind: "assistant"; readonly text: string }
  | {
      readonly kind: "tool_call";
      readonly tool: string;
      readonly input: unknown;
    }
  | {
      readonly kind: "tool_result";
      readonly tool: string;
      readonly input: unknown;
      readonly text: string;
    }
  | {
      readonly kind: "tool_error";
      readonly tool?: string;
      readonly input?: unknown;
      readonly text: string;
    }
  | {
      readonly kind: "shell";
      readonly command: string;
      readonly output: string;
    };

export function splitCompactionCheckpoint(
  text: string,
  recentMetadata?: string,
): { readonly summaryText: string; readonly recentText: string } {
  const summaryMatch = /<summary>\r?\n?([\s\S]*?)\r?\n?<\/summary>/i.exec(text);
  const recentMatch =
    /<recent-context>\r?\n?([\s\S]*?)\r?\n?<\/recent-context>/i.exec(text);
  const summaryText = summaryMatch
    ? summaryMatch[1].trim()
    : recentMatch
      ? text.replace(recentMatch[0], "").trim()
      : text.trim();
  const fromTag = recentMatch ? recentMatch[1].trim() : "";
  const fromMeta =
    typeof recentMetadata === "string" ? recentMetadata.trim() : "";
  const recentText =
    fromTag && fromMeta && fromTag !== fromMeta
      ? `${fromTag}\n\n${fromMeta}`
      : fromTag || fromMeta;
  return { summaryText, recentText };
}

const RECENT_MARKER_SPLIT =
  /^(?=\[(?:User|Synthetic context|Skill activated: [^\]]+|Assistant|Assistant tool call|Tool result|Tool error|Shell)\]:?\s)/m;

export function parseRecentContextEntries(
  recentText: string,
): RecentContextEntry[] {
  if (!recentText) return [];
  const entries: RecentContextEntry[] = [];
  let lastTool: { tool: string; input: unknown } | undefined;

  for (const rawChunk of recentText.split(RECENT_MARKER_SPLIT)) {
    const chunk = rawChunk.trim();
    if (!chunk) continue;

    const userMatch = /^\[(?:User|Synthetic context)\]:?\s*([\s\S]*)$/.exec(
      chunk,
    );
    if (userMatch) {
      lastTool = undefined;
      entries.push({ kind: "user", text: userMatch[1].trim() });
      continue;
    }

    const toolCallMatch = /^\[Assistant tool call\]:?\s*([\s\S]*)$/.exec(chunk);
    if (toolCallMatch) {
      const body = toolCallMatch[1].trim();
      const callMatch = /^([A-Za-z0-9_.:/-]+)\(([\s\S]*?)\)?$/.exec(body);
      if (callMatch) {
        const tool = callMatch[1];
        const rawInput = callMatch[2].trim();
        let input: unknown = rawInput;
        try {
          input = JSON.parse(rawInput);
        } catch {
          // Keep raw string when JSON is truncated or non-JSON.
        }
        lastTool = { tool, input };
        entries.push({ kind: "tool_call", tool, input });
      } else {
        lastTool = undefined;
        entries.push({ kind: "assistant", text: body });
      }
      continue;
    }

    const assistantMatch = /^\[Assistant\]:?\s*([\s\S]*)$/.exec(chunk);
    if (assistantMatch) {
      lastTool = undefined;
      entries.push({ kind: "assistant", text: assistantMatch[1].trim() });
      continue;
    }

    const toolResultMatch = /^\[Tool result\]:?\s*([\s\S]*)$/.exec(chunk);
    if (toolResultMatch) {
      const text = toolResultMatch[1].trim();
      if (lastTool) {
        entries.push({
          kind: "tool_result",
          tool: lastTool.tool,
          input: lastTool.input,
          text,
        });
      } else {
        entries.push({ kind: "assistant", text });
      }
      lastTool = undefined;
      continue;
    }

    const toolErrorMatch = /^\[Tool error\]:?\s*([\s\S]*)$/.exec(chunk);
    if (toolErrorMatch) {
      entries.push({
        kind: "tool_error",
        ...(lastTool && { tool: lastTool.tool, input: lastTool.input }),
        text: toolErrorMatch[1].trim(),
      });
      lastTool = undefined;
      continue;
    }

    const shellMatch = /^\[Shell\]:?\s*([\s\S]*)$/.exec(chunk);
    if (shellMatch) {
      lastTool = undefined;
      const body = shellMatch[1];
      const newline = body.indexOf("\n");
      const command = (newline === -1 ? body : body.slice(0, newline)).trim();
      const output = newline === -1 ? "" : body.slice(newline + 1).trim();
      entries.push({ kind: "shell", command, output });
      continue;
    }

    lastTool = undefined;
  }

  return entries;
}

export type ConfidentialityStatus = "public" | "confidential" | "unknown";

export interface ConfidentialityAssessment {
  readonly status: ConfidentialityStatus;
  readonly reason?: string;
}

interface CacheEntry {
  readonly status: "public" | "confidential";
  readonly reason?: string;
  readonly expiresAt: number;
}

export class GitLabConfidentialityChecker {
  private readonly cache = new Map<string, CacheEntry>();

  constructor(
    private readonly glab: CliRunner = execGlab,
    private readonly now: () => number = () => Date.now(),
  ) {}

  async checkRefs(
    refs: readonly GitLabRef[],
    signal?: AbortSignal,
  ): Promise<string | undefined> {
    const assessment = await this.checkRefsAssessment(refs, signal);
    return assessment.status === "public" ? undefined : assessment.reason;
  }

  createFreshChecker(): GitLabConfidentialityChecker {
    return new GitLabConfidentialityChecker(this.glab, this.now);
  }

  mergeCacheFrom(other: GitLabConfidentialityChecker): void {
    for (const [key, entry] of other.cache) {
      this.cache.set(key, entry);
    }
  }

  async checkRefsFresh(
    refs: readonly GitLabRef[],
    signal?: AbortSignal,
  ): Promise<string | undefined> {
    const fresh = this.createFreshChecker();
    const assessment = await fresh.checkRefsAssessment(refs, signal);
    for (const ref of refs) {
      if (ref.iid) {
        this.cache.delete(`${ref.kind}:${ref.path.toLowerCase()}:${ref.iid}`);
      }
    }
    this.mergeCacheFrom(fresh);
    return assessment.status === "public" ? undefined : assessment.reason;
  }

  recheck(
    ref: GitLabRef,
    signal?: AbortSignal,
  ): Promise<ConfidentialityAssessment> {
    // Include linked issues in the fresh assessment without evicting live cache entries.
    return new GitLabConfidentialityChecker(
      this.glab,
      this.now,
    ).checkRefsAssessment([ref], signal);
  }

  async checkRefsAssessment(
    refs: readonly GitLabRef[],
    signal?: AbortSignal,
    depth = 0,
  ): Promise<ConfidentialityAssessment> {
    // Check offline confidential project paths first before any network call.
    for (const ref of refs) {
      if (isConfidentialProjectPath(ref.path)) {
        return {
          status: "confidential",
          reason: `confidential project (${normalizeGitLabProject(ref.path)})`,
        };
      }
    }

    let firstUnknown: ConfidentialityAssessment | undefined;
    for (const ref of refs) {
      if (ref.kind === "project") continue;
      if (ref.kind === "overflow") {
        firstUnknown ??= {
          status: "unknown",
          reason: `unverified GitLab references beyond lookup limit (${MAX_REFS_PER_TEXT})`,
        };
        continue;
      }
      const outcome = await this.checkRefAssessment(ref, depth, signal);
      if (outcome.status === "confidential") return outcome;
      if (outcome.status === "unknown" && !firstUnknown) {
        firstUnknown = outcome;
      }
    }
    return firstUnknown ?? { status: "public" };
  }

  private async checkRefAssessment(
    ref: GitLabRef,
    depth: number,
    signal?: AbortSignal,
  ): Promise<ConfidentialityAssessment> {
    if (isConfidentialProjectPath(ref.path)) {
      return {
        status: "confidential",
        reason: `confidential project (${normalizeGitLabProject(ref.path)})`,
      };
    }
    if (!ref.iid) return { status: "public" };

    const cacheKey = `${ref.kind}:${ref.path.toLowerCase()}:${ref.iid}`;
    const cached = this.cache.get(cacheKey);
    if (cached && cached.expiresAt > this.now()) {
      return { status: cached.status, reason: cached.reason };
    }

    let outcome: ConfidentialityAssessment = {
      status: "unknown",
      reason: `unverified GitLab ${ref.kind} ${ref.path}#${ref.iid}`,
    };
    if (ref.kind === "issue") {
      outcome = await this.lookupIssue(ref.path, ref.iid, signal);
    } else if (ref.kind === "group_work_item") {
      outcome = await this.lookupWorkItem(ref.path, ref.iid, signal);
    } else if (ref.kind === "merge_request") {
      outcome = await this.lookupMergeRequest(ref.path, ref.iid, depth, signal);
    }

    if (outcome.status === "confidential" || outcome.status === "public") {
      this.cache.set(cacheKey, {
        status: outcome.status,
        reason: outcome.reason,
        expiresAt:
          outcome.status === "confidential"
            ? Number.POSITIVE_INFINITY
            : this.now() + NON_CONFIDENTIAL_CACHE_TTL_MS,
      });
    }
    return outcome;
  }

  private async lookupIssue(
    project: string,
    iid: string,
    signal?: AbortSignal,
  ): Promise<ConfidentialityAssessment> {
    try {
      const endpoint = `projects/${encodeURIComponent(project)}/issues/${iid}`;
      const data = JSON.parse(await this.glab([endpoint], signal)) as {
        id?: unknown;
        iid?: unknown;
        confidential?: unknown;
        labels?: unknown;
      };
      if (!data || typeof data !== "object") {
        return this.lookupWorkItem(project, iid, signal);
      }
      if (data.confidential === true) {
        return {
          status: "confidential",
          reason: `confidential issue ${project}#${iid}`,
        };
      }
      if (hasConfidentialSecurityLabels(data.labels)) {
        return {
          status: "confidential",
          reason: `security issue ${project}#${iid}`,
        };
      }
      if (
        typeof data.confidential === "boolean" &&
        Array.isArray(data.labels)
      ) {
        return { status: "public" };
      }
      return this.lookupWorkItem(project, iid, signal);
    } catch {
      return this.lookupWorkItem(project, iid, signal);
    }
  }

  private async lookupWorkItem(
    fullPath: string,
    iid: string,
    signal?: AbortSignal,
  ): Promise<ConfidentialityAssessment> {
    try {
      const stdout = await this.glab(
        [
          "graphql",
          "-f",
          `query=${WORK_ITEM_CONFIDENTIAL_QUERY}`,
          "-f",
          `fullPath=${fullPath}`,
          "-f",
          `iid=${iid}`,
        ],
        signal,
      );
      const data = JSON.parse(stdout) as {
        data?: {
          namespace?: { workItem?: { confidential?: unknown } | null } | null;
        };
      };
      const workItem = data?.data?.namespace?.workItem;
      if (
        !workItem ||
        typeof workItem !== "object" ||
        typeof workItem.confidential !== "boolean"
      ) {
        return {
          status: "unknown",
          reason: `unverified GitLab item ${fullPath}#${iid} (lookup failed)`,
        };
      }
      if (workItem.confidential === true) {
        return {
          status: "confidential",
          reason: `confidential work item ${fullPath}#${iid}`,
        };
      }
      return { status: "public" };
    } catch {
      return {
        status: "unknown",
        reason: `unverified GitLab item ${fullPath}#${iid} (lookup failed)`,
      };
    }
  }

  private async lookupMergeRequest(
    project: string,
    iid: string,
    depth: number,
    signal?: AbortSignal,
  ): Promise<ConfidentialityAssessment> {
    try {
      const endpoint = `projects/${encodeURIComponent(project)}/merge_requests/${iid}`;
      const data = JSON.parse(await this.glab([endpoint], signal)) as {
        id?: unknown;
        iid?: unknown;
        labels?: unknown;
        source_branch?: unknown;
        description?: unknown;
      };

      if (
        !data ||
        typeof data !== "object" ||
        (typeof data.iid !== "number" &&
          typeof data.id !== "number" &&
          !("source_branch" in data) &&
          !("labels" in data) &&
          !("description" in data))
      ) {
        return {
          status: "unknown",
          reason: `unverified GitLab merge request ${project}!${iid} (lookup failed)`,
        };
      }

      if (hasConfidentialSecurityLabels(data.labels)) {
        return {
          status: "confidential",
          reason: `security merge request ${project}!${iid}`,
        };
      }

      if (
        typeof data.source_branch === "string" &&
        /(?:^|\/)security-/i.test(data.source_branch)
      ) {
        return {
          status: "confidential",
          reason: `security-branch merge request ${project}!${iid} (${data.source_branch})`,
        };
      }

      if (depth >= 1) return { status: "public" };

      let unknownReason: string | undefined;

      // Check issue IID encoded in the MR's source branch (<username>/<iid>/...).
      const branchIid =
        typeof data.source_branch === "string"
          ? extractBranchIssueIid(data.source_branch)
          : undefined;
      if (branchIid) {
        const branchOutcome = await this.checkRefAssessment(
          { kind: "issue", path: project, iid: branchIid },
          depth + 1,
          signal,
        );
        if (branchOutcome.status === "confidential") {
          return {
            status: "confidential",
            reason: `merge request ${project}!${iid} linked to ${branchOutcome.reason}`,
          };
        }
        if (branchOutcome.status === "unknown") {
          unknownReason ??= `merge request ${project}!${iid} has unverified branch issue (${branchOutcome.reason})`;
        }
      }

      // Check closing issues reported by GitLab.
      try {
        const closesRaw = await this.glab(
          [
            `projects/${encodeURIComponent(project)}/merge_requests/${iid}/closes_issues`,
          ],
          signal,
        );
        const closes = JSON.parse(closesRaw);
        if (!Array.isArray(closes)) {
          unknownReason ??= `merge request ${project}!${iid} has unverified closing issues`;
        } else {
          for (const issue of closes) {
            if (
              issue?.confidential === true ||
              hasConfidentialSecurityLabels(issue?.labels)
            ) {
              const issueIid = issue?.iid ? `#${issue.iid}` : "";
              return {
                status: "confidential",
                reason: `merge request ${project}!${iid} closes confidential issue ${project}${issueIid}`,
              };
            }
          }
        }
      } catch {
        unknownReason ??= `merge request ${project}!${iid} has unverified closing issues (closes_issues lookup failed)`;
      }

      // Check issues/epics referenced in the MR description.
      if (typeof data.description === "string" && data.description.trim()) {
        const linkedRefs = extractGitLabRefs(data.description, project).filter(
          (item) => item.kind !== "merge_request",
        );
        const linkedOutcome = await this.checkRefsAssessment(
          linkedRefs,
          signal,
          depth + 1,
        );
        if (linkedOutcome.status === "confidential") {
          return {
            status: "confidential",
            reason: `merge request ${project}!${iid} references ${linkedOutcome.reason}`,
          };
        }
        if (linkedOutcome.status === "unknown") {
          unknownReason ??= `merge request ${project}!${iid} references ${linkedOutcome.reason}`;
        }
      }

      if (unknownReason) {
        return { status: "unknown", reason: unknownReason };
      }
      return { status: "public" };
    } catch {
      return {
        status: "unknown",
        reason: `unverified GitLab merge request ${project}!${iid} (lookup failed)`,
      };
    }
  }
}
