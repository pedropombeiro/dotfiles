import { homedir } from "node:os";
import { resolve } from "node:path";

export interface GitLabDestination {
  type: "gitlab";
  project: string;
  epic?: string;
  host: string;
  confidential: boolean;
  labels: string[];
}

export interface GitHubDestination {
  type: "github";
  repo: string;
  host: string;
  labels: string[];
}

export interface FileDestination {
  type: "file";
  path: string;
}

export type DestinationConfig =
  GitLabDestination | GitHubDestination | FileDestination;

export interface DestinationRoute {
  directoryPrefix?: string;
  remoteContains?: string;
  remoteRepository?: string;
  destination: string;
  enforced?: boolean;
}

export interface ResolvedVentOptions {
  defaultDestination?: string;
  destinations: Record<string, DestinationConfig>;
  routes: DestinationRoute[];
  similarityThreshold: number;
}

export interface ResolvedDestination {
  name: string;
  config: DestinationConfig;
}

export const DEFAULT_SIMILARITY_THRESHOLD = 0.45;

export function expandHome(
  inputPath: string,
  home: string = homedir(),
): string {
  if (inputPath === "~") return home;
  if (inputPath.startsWith("~/")) return resolve(home, inputPath.slice(2));
  return inputPath;
}

function stringValue(value: unknown): string | undefined {
  if (typeof value !== "string") return undefined;
  const trimmed = value.trim();
  return trimmed ? trimmed : undefined;
}

function stringArray(value: unknown): string[] {
  if (!Array.isArray(value)) return [];
  return value
    .map((item) => stringValue(item))
    .filter((item): item is string => item !== undefined);
}

function parseDestination(raw: unknown): DestinationConfig | undefined {
  if (!raw || typeof raw !== "object") return undefined;
  const record = raw as Record<string, unknown>;
  const type = stringValue(record.type);

  if (type === "gitlab") {
    const project = stringValue(record.project);
    if (!project) return undefined;
    const epic = stringValue(record.epic);
    return {
      type: "gitlab",
      project,
      ...(epic ? { epic } : {}),
      host: stringValue(record.host) ?? "gitlab.com",
      confidential:
        typeof record.confidential === "boolean" ? record.confidential : true,
      labels: stringArray(record.labels),
    };
  }

  if (type === "github") {
    const repo = stringValue(record.repo);
    if (!repo) return undefined;
    return {
      type: "github",
      repo,
      host: stringValue(record.host) ?? "github.com",
      labels: stringArray(record.labels),
    };
  }

  if (type === "file") {
    const filePath = stringValue(record.path);
    if (!filePath) return undefined;
    return {
      type: "file",
      path: filePath,
    };
  }

  return undefined;
}

function parseRoute(raw: unknown): DestinationRoute | undefined {
  if (!raw || typeof raw !== "object") return undefined;
  const record = raw as Record<string, unknown>;
  const destination = stringValue(record.destination);
  if (!destination) return undefined;
  const directoryPrefix = stringValue(record.directoryPrefix);
  const remoteContains = stringValue(record.remoteContains);
  const remoteRepository = stringValue(record.remoteRepository);
  if (!directoryPrefix && !remoteContains && !remoteRepository)
    return undefined;
  return {
    ...(directoryPrefix ? { directoryPrefix } : {}),
    ...(remoteContains ? { remoteContains } : {}),
    ...(remoteRepository ? { remoteRepository } : {}),
    destination,
    ...(record.enforced === true ? { enforced: true } : {}),
  };
}

export function resolveOptions(raw: unknown): ResolvedVentOptions {
  if (!raw || typeof raw !== "object") {
    return {
      destinations: {},
      routes: [],
      similarityThreshold: DEFAULT_SIMILARITY_THRESHOLD,
    };
  }

  const record = raw as Record<string, unknown>;
  const destinations: Record<string, DestinationConfig> = {};

  if (record.destinations && typeof record.destinations === "object") {
    for (const [name, value] of Object.entries(
      record.destinations as Record<string, unknown>,
    )) {
      const trimmedName = name.trim();
      if (!trimmedName) continue;
      const parsed = parseDestination(value);
      if (parsed) destinations[trimmedName] = parsed;
    }
  }

  const routes: DestinationRoute[] = Array.isArray(record.routes)
    ? record.routes
        .map((entry) => parseRoute(entry))
        .filter((entry): entry is DestinationRoute => entry !== undefined)
    : [];

  const defaultDestination = stringValue(record.defaultDestination);
  const threshold =
    typeof record.similarityThreshold === "number" &&
    Number.isFinite(record.similarityThreshold) &&
    record.similarityThreshold > 0 &&
    record.similarityThreshold <= 1
      ? record.similarityThreshold
      : DEFAULT_SIMILARITY_THRESHOLD;

  return {
    ...(defaultDestination ? { defaultDestination } : {}),
    destinations,
    routes,
    similarityThreshold: threshold,
  };
}

function normalizeRemote(remote: string): string {
  const sshScp = remote.match(/^[^@]+@([^:/]+):(.+)$/);
  if (sshScp) return `${sshScp[1]}/${sshScp[2]}`;
  return remote;
}

function matchesRemote(remote: string, pattern: string): boolean {
  const needle = pattern.toLowerCase();
  return (
    remote.toLowerCase().includes(needle) ||
    normalizeRemote(remote).toLowerCase().includes(needle)
  );
}

function repositoryIdentity(remote: string): string {
  const url =
    remote.includes("://") && URL.canParse(remote)
      ? new URL(remote)
      : undefined;
  return (url ? `${url.hostname}${url.pathname}` : normalizeRemote(remote))
    .replace(/\/+$/, "")
    .replace(/\.git$/i, "")
    .toLowerCase();
}

function matchesPrefix(
  directory: string,
  prefix: string,
  home: string,
): boolean {
  const normalizedDir = resolve(expandHome(directory, home));
  const normalizedPrefix = resolve(expandHome(prefix, home));
  return (
    normalizedDir === normalizedPrefix ||
    normalizedDir.startsWith(`${normalizedPrefix}/`)
  );
}

export function selectDestination(
  options: ResolvedVentOptions,
  context: {
    requested?: string;
    directory?: string;
    remote?: string;
    fetchRemotes?: readonly string[];
    localReason?: string;
    home?: string;
  },
): ResolvedDestination {
  const names = Object.keys(options.destinations);
  if (names.length === 0) {
    throw new Error(
      "No vent destinations are configured. Add a `destinations` entry to the `vent` plugin options.",
    );
  }

  const home = context.home ?? homedir();
  const fetchRemotes =
    context.fetchRemotes ?? (context.remote ? [context.remote] : []);
  const matchingRoutes = options.routes.filter((route) => {
    const directoryMatches =
      !route.directoryPrefix ||
      (context.directory !== undefined &&
        matchesPrefix(context.directory, route.directoryPrefix, home));
    if (!directoryMatches) return false;
    if (!route.remoteContains && !route.remoteRepository) return true;
    return fetchRemotes.some(
      (remote) =>
        (!route.remoteContains ||
          matchesRemote(remote, route.remoteContains)) &&
        (!route.remoteRepository ||
          repositoryIdentity(remote) ===
            repositoryIdentity(route.remoteRepository)),
    );
  });

  const enforced = matchingRoutes.find((route) => route.enforced);
  const requested = context.requested
    ? options.destinations[context.requested]
    : undefined;
  if (context.requested && !requested) {
    throw new Error(
      `Unknown vent destination "${context.requested}". Configured destinations: ${names.join(", ")}.`,
    );
  }
  if (context.localReason && requested?.type !== "file") {
    throw new Error("`localReason` requires an explicit file destination.");
  }
  if (enforced) {
    const config = options.destinations[enforced.destination];
    if (!config || config.type === "file") {
      throw new Error(
        `Enforced vent route requires a configured issue destination: "${enforced.destination}".`,
      );
    }
    if (requested && context.requested !== enforced.destination) {
      if (requested.type === "file" && context.localReason?.trim()) {
        return { name: context.requested!, config: requested };
      }
      throw new Error(
        `This checkout routes vents to "${enforced.destination}". Omit destination, or provide a localReason with a file destination only for unrelated personal friction.`,
      );
    }
    return { name: enforced.destination, config };
  }
  if (requested) return { name: context.requested!, config: requested };

  const route = matchingRoutes.find(
    (entry) => options.destinations[entry.destination],
  );
  if (route)
    return {
      name: route.destination,
      config: options.destinations[route.destination]!,
    };

  if (options.defaultDestination) {
    const config = options.destinations[options.defaultDestination];
    if (!config) {
      throw new Error(
        `Configured defaultDestination "${options.defaultDestination}" was not found in destinations (${names.join(", ")}).`,
      );
    }
    return { name: options.defaultDestination, config };
  }

  if (names.length === 1) {
    const only = names[0]!;
    return { name: only, config: options.destinations[only]! };
  }

  throw new Error(
    `Multiple vent destinations are configured (${names.join(", ")}), but no route matched and no defaultDestination is set.`,
  );
}
