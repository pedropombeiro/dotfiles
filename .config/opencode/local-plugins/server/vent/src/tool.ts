import { ventToFile } from "./destinations/file.ts";
import { ventToGitHub } from "./destinations/github.ts";
import { ventToGitLab } from "./destinations/gitlab.ts";
import {
  VENT_CATEGORIES,
  type VentCategory,
  type VentInput,
  type VentMetadata,
  type VentResult,
} from "./destinations/types.ts";
import type { Exec } from "./exec.ts";
import { selectDestination, type ResolvedVentOptions } from "./options.ts";

export const VENT_TOOL_NAME = "vent";

export const VENT_DESCRIPTION = [
  "Record a tooling, documentation, skill, permission, or workflow friction encountered during work.",
  "Routes to a configured destination (such as a GitLab issue under an epic, a GitHub issue, or a",
  "local Markdown log). Automatically checks open items at the destination and appends a comment or",
  "occurrence entry when a matching friction already exists instead of creating a duplicate.",
  "",
  "Include concrete details: what failed or slowed you down, what you were doing, evidence (commands,",
  "paths, error text), and a suggested improvement when clear. Never include secret values, tokens,",
  "or sensitive production data.",
].join("\n");

export const VENT_GUIDANCE = [
  "When you encounter genuine, actionable friction in tools, skills, documentation, permissions, or",
  "repository workflows (such as misleading docs, broken helper scripts, missing read-only permission",
  "rules, or repeated workarounds), call the `vent` tool to record it.",
  "Do not call `vent` for normal bugs in the feature or fix you are actively implementing, or for",
  "transient user typos. Never include secrets, credentials, or sensitive production data in vents.",
  "Omit destination for project friction. Use a file destination with localReason only for personal",
  "friction unrelated to the project, never when issue filing fails.",
].join(" ");

export const ventInputSchema = {
  type: "object",
  properties: {
    title: {
      type: "string",
      minLength: 3,
      description:
        "Concise summary of the friction, used as the issue title or section heading.",
    },
    friction: {
      type: "string",
      minLength: 10,
      description:
        "Clear description of what failed, was slow, was undocumented, or caused wasted effort.",
    },
    context: {
      type: "string",
      minLength: 5,
      description:
        "What task or investigation you were performing when the friction occurred.",
    },
    evidence: {
      type: "string",
      description:
        "Relevant error messages, command invocations, file paths, or reproduction details.",
    },
    suggestion: {
      type: "string",
      description:
        "Concrete proposal to fix or improve the tool, documentation, skill, or workflow.",
    },
    category: {
      type: "string",
      enum: [...VENT_CATEGORIES],
      description: "Broad area where the friction occurred.",
    },
    labels: {
      type: "array",
      items: { type: "string", minLength: 1 },
      description:
        "Optional extra labels to apply when creating an issue on GitLab or GitHub.",
    },
    destination: {
      type: "string",
      minLength: 1,
      description:
        "Optional configured destination name. An enforced route restricts overrides.",
    },
    localReason: {
      type: "string",
      minLength: 1,
      description:
        "With a file destination, explain why this is unrelated personal friction. Never use this to bypass failed issue filing.",
    },
  },
  required: ["title", "friction", "context"],
  additionalProperties: false,
} as const;

function requiredString(value: unknown, field: string): string {
  if (typeof value !== "string" || !value.trim()) {
    throw new Error(`\`${field}\` must be a non-empty string.`);
  }
  return value.trim();
}

function optionalString(value: unknown): string | undefined {
  if (typeof value !== "string") return undefined;
  const trimmed = value.trim();
  return trimmed ? trimmed : undefined;
}

function optionalCategory(value: unknown): VentCategory | undefined {
  if (value === undefined) return undefined;
  if (
    typeof value === "string" &&
    (VENT_CATEGORIES as readonly string[]).includes(value)
  ) {
    return value as VentCategory;
  }
  throw new Error(
    `Invalid \`category\`. Expected one of: ${VENT_CATEGORIES.join(", ")}.`,
  );
}

function optionalStringArray(value: unknown): string[] | undefined {
  if (value === undefined) return undefined;
  if (!Array.isArray(value))
    throw new Error("`labels` must be an array of strings.");
  const items = value
    .map((item) => optionalString(item))
    .filter((item): item is string => item !== undefined);
  return items.length > 0 ? items : undefined;
}

export function parseVentInput(raw: unknown): VentInput {
  if (!raw || typeof raw !== "object") {
    throw new Error("Vent input must be an object.");
  }
  const record = raw as Record<string, unknown>;
  const evidence = optionalString(record.evidence);
  const suggestion = optionalString(record.suggestion);
  const category = optionalCategory(record.category);
  const labels = optionalStringArray(record.labels);
  const destination = optionalString(record.destination);
  const localReason = optionalString(record.localReason);

  return {
    title: requiredString(record.title, "title"),
    friction: requiredString(record.friction, "friction"),
    context: requiredString(record.context, "context"),
    ...(evidence ? { evidence } : {}),
    ...(suggestion ? { suggestion } : {}),
    ...(category ? { category } : {}),
    ...(labels ? { labels } : {}),
    ...(destination ? { destination } : {}),
    ...(localReason ? { localReason } : {}),
  };
}

export async function collectGitContext(
  run: Exec,
  directory: string,
  signal?: AbortSignal,
): Promise<{ remote?: string; fetchRemotes: string[]; branch?: string }> {
  const [remoteResult, branchResult] = await Promise.all([
    run("git", ["remote", "-v"], { cwd: directory, timeout: 5_000, signal }),
    run("git", ["rev-parse", "--abbrev-ref", "HEAD"], {
      cwd: directory,
      timeout: 5_000,
      signal,
    }),
  ]);

  const fetchEntries =
    remoteResult.code === 0
      ? [...remoteResult.stdout.matchAll(/^(\S+)\s+(.+) \(fetch\)$/gm)]
      : [];
  const remote = fetchEntries.find((entry) => entry[1] === "origin")?.[2];
  const rawBranch =
    branchResult.code === 0 ? optionalString(branchResult.stdout) : undefined;
  const branch = rawBranch && rawBranch !== "HEAD" ? rawBranch : undefined;

  return {
    ...(remote ? { remote } : {}),
    fetchRemotes: fetchEntries.map((entry) => entry[2]!),
    ...(branch ? { branch } : {}),
  };
}

export function formatVentResult(result: VentResult): string {
  const target = result.url ?? result.path ?? result.destination;
  const lines: string[] = [];

  if (result.action === "commented") {
    const score =
      result.matchScore !== undefined
        ? ` (similarity ${result.matchScore})`
        : "";
    lines.push(
      `Recorded new occurrence on existing ${result.destinationType} entry "${result.matchedTitle ?? result.title}"${score}: ${target}`,
    );
  } else {
    lines.push(
      `Created new ${result.destinationType} vent "${result.title}" in destination "${result.destination}": ${target}`,
    );
  }

  if (result.note) {
    lines.push(`Note: ${result.note}`);
  }

  return lines.join("\n");
}

export async function executeVent(
  rawInput: unknown,
  options: ResolvedVentOptions,
  runtime: {
    sessionID: string;
    directory: string;
    branch?: string;
    remote?: string;
    exec: Exec;
    now?: () => Date;
    home?: string;
    signal?: AbortSignal;
  },
): Promise<VentResult> {
  const input = parseVentInput(rawInput);
  const git =
    runtime.remote === undefined || runtime.branch === undefined
      ? await collectGitContext(runtime.exec, runtime.directory, runtime.signal)
      : {};

  const remote = runtime.remote ?? git.remote;
  const branch = runtime.branch ?? git.branch;

  const selected = selectDestination(options, {
    requested: input.destination,
    directory: runtime.directory,
    fetchRemotes: [
      ...(runtime.remote ? [runtime.remote] : []),
      ...(git.fetchRemotes ?? []),
    ],
    localReason: input.localReason,
    home: runtime.home,
  });

  const now = (runtime.now ?? (() => new Date()))();
  const timestamp = now.toISOString();
  const date = timestamp.slice(0, 10);

  const metadata: VentMetadata = {
    date,
    timestamp,
    directory: runtime.directory,
    ...(remote ? { remote } : {}),
    ...(branch ? { branch } : {}),
    sessionID: runtime.sessionID,
    ...(input.category ? { category: input.category } : {}),
  };

  const deps = {
    exec: runtime.exec,
    threshold: options.similarityThreshold,
    signal: runtime.signal,
    home: runtime.home,
  };

  if (selected.config.type === "gitlab") {
    return ventToGitLab(selected.name, selected.config, input, metadata, deps);
  }
  if (selected.config.type === "github") {
    return ventToGitHub(selected.name, selected.config, input, metadata, deps);
  }
  return ventToFile(selected.name, selected.config, input, metadata, deps);
}
