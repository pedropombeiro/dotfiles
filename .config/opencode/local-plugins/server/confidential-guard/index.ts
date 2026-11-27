import type { Plugin } from "@opencode/plugin";
import {
  analyzeGitConfig,
  checkToolCallBefore,
  confidentialReasonForDirectory,
  defaultModelForAgent,
  detectConfidentialOutput,
  duoModelForAgent,
  execGit,
  execGlab,
  extractBranchIssueIid,
  extractGitLabRefs,
  extractMessageText,
  extractResultText,
  extractSetSessionTargetUrls,
  extractTargetsFromInstructions,
  extractToolInputRefs,
  forkSource,
  formatRedactionNotice,
  GitLabConfidentialityChecker,
  isDuoModel,
  isGitLabOutputTool,
  linkedOwner,
  parseModelRef,
  parseRecentContextEntries,
  redactToolResult,
  resolveDefaultModels,
  resolveDuoModels,
  splitCompactionCheckpoint,
  type CliRunner,
  type DefaultModels,
  type DirectorySessionLike,
  type DuoModels,
  type GitRepoAnalysis,
  type GitLabRef,
  type GitRunner,
  type ModelRef,
} from "./src/guard.ts";
import { ConfidentialGuardRpc } from "./rpc.ts";
import {
  canRecheck,
  findingKey,
  parseStoredFindings,
  type Finding,
  type Observation,
  type StatusFinding,
  type StoredFindings,
} from "./src/findings.ts";

export {
  analyzeGitConfig,
  checkToolCallBefore,
  confidentialReasonForDirectory,
  defaultModelForAgent,
  detectConfidentialOutput,
  DUO_MODELS,
  DUO_PROVIDER_ID,
  duoModelForAgent,
  extractBranchIssueIid,
  extractGitLabRefs,
  extractSetSessionTargetUrls,
  extractTargetsFromInstructions,
  extractToolInputRefs,
  forkSource,
  formatRedactionNotice,
  GitLabConfidentialityChecker,
  isConfidentialProjectPath,
  isDuoModel,
  isGitLabOutputTool,
  linkedOwner,
  normalizeGitLabProject,
  parseGitLabRemote,
  parseModelRef,
  parseRecentContextEntries,
  redactToolResult,
  resolveDefaultModels,
  resolveDuoModels,
  splitCompactionCheckpoint,
  type ConfidentialityAssessment,
  type ConfidentialityStatus,
  type DefaultModels,
} from "./src/guard.ts";

const STORAGE_PREFIX = "confidential-guard/sessions/";
const REPO_CACHE_TTL_MS = 10_000;
const MAX_CHAIN_DEPTH = 10;

export interface CreatePluginOptions {
  readonly glab?: CliRunner;
  readonly git?: GitRunner;
  readonly now?: () => number;
  readonly env?: Record<string, string | undefined>;
}

interface SessionChain {
  readonly session?: DirectorySessionLike;
  readonly ancestors: readonly DirectorySessionLike[];
  readonly forkAncestors: readonly string[];
  readonly ownerAncestors: readonly string[];
  readonly rootSessionID: string;
  readonly ownerSessionID?: string;
  readonly inheritedDuoModel?: ModelRef;
}

interface RepoCacheEntry {
  readonly analysis: GitRepoAnalysis;
  readonly branch?: string;
  readonly expiresAt: number;
}

interface LockSwitchResult {
  readonly targetModel: ModelRef;
  readonly switched: boolean;
}

const storageKey = (sessionID: string) => `${STORAGE_PREFIX}${sessionID}`;

export function createPlugin(options: CreatePluginOptions = {}) {
  const now = options.now ?? (() => Date.now());
  const git = options.git ?? execGit;
  const checker = new GitLabConfidentialityChecker(
    options.glab ?? execGlab,
    now,
  );
  // Location instances can update the same parent. Serialize ledger writes.
  let writes: Promise<unknown> = Promise.resolve();
  function updateLedger<T>(update: () => Promise<T>): Promise<T> {
    const result = writes.then(update);
    writes = result.catch(() => undefined);
    return result;
  }
  const failedWrites = new Map<string, Finding[]>();

  return {
    id: "confidential-guard",
    async setup(ctx) {
      const env = options.env ?? process.env;
      const duoModels: DuoModels = resolveDuoModels(ctx.options, env);
      const defaultModels: DefaultModels = resolveDefaultModels(
        ctx.options,
        env,
      );
      const repoCache = new Map<string, RepoCacheEntry>();
      const activeTurnModel = new Map<string, ModelRef>();
      const inflightCompaction = new Map<string, Promise<void>>();

      function isSessionTurnOnDuo(
        sessionID: string,
        chain: SessionChain,
      ): boolean {
        return isDuoModel(
          activeTurnModel.get(sessionID) ?? chain.session?.model,
        );
      }

      function ownsSession(session?: DirectorySessionLike): boolean {
        if (!ctx.location?.directory || !session?.location?.directory)
          return true;
        return session.location.directory === ctx.location.directory;
      }

      async function getSessionSafe(
        sessionID: string,
      ): Promise<DirectorySessionLike | undefined> {
        try {
          return (await ctx.session.get({ sessionID })) as DirectorySessionLike;
        } catch {
          return undefined;
        }
      }

      async function resolveChain(sessionID: string): Promise<SessionChain> {
        const session = await getSessionSafe(sessionID);
        if (!session) {
          return {
            ancestors: [],
            forkAncestors: [],
            ownerAncestors: [],
            rootSessionID: sessionID,
          };
        }

        const ancestors: DirectorySessionLike[] = [];
        const forkAncestors: string[] = [];
        const ownerAncestors: string[] = [];
        const seen = new Set<string>([session.id]);
        let ownerSessionID: string | undefined = linkedOwner(session);
        let inheritedDuoModel: ModelRef | undefined;
        let current: DirectorySessionLike | undefined = session;

        const collectForks = async (start?: DirectorySessionLike) => {
          let forkID = start ? forkSource(start) : undefined;
          while (
            forkID &&
            !seen.has(forkID) &&
            forkAncestors.length < MAX_CHAIN_DEPTH
          ) {
            seen.add(forkID);
            forkAncestors.push(forkID);
            const forkedSession = await getSessionSafe(forkID);
            if (!forkedSession) break;
            if (!inheritedDuoModel && isDuoModel(forkedSession.model)) {
              inheritedDuoModel = forkedSession.model;
            }
            if (!ownerSessionID) {
              ownerSessionID = linkedOwner(forkedSession);
            }
            forkID = forkSource(forkedSession) ?? forkedSession.parentID;
          }
        };

        for (let depth = 0; depth < MAX_CHAIN_DEPTH && current; depth += 1) {
          await collectForks(current);

          const nextID = current.parentID;
          if (!nextID || seen.has(nextID)) break;
          seen.add(nextID);

          const parent = await getSessionSafe(nextID);
          if (!parent) {
            ancestors.push({ id: nextID });
            break;
          }
          ancestors.push(parent);
          if (!inheritedDuoModel && isDuoModel(parent.model)) {
            inheritedDuoModel = parent.model;
          }
          if (!ownerSessionID) {
            ownerSessionID = linkedOwner(parent);
          }
          current = parent;
        }

        let ownerCursor = ownerSessionID;
        for (
          let depth = 0;
          depth < MAX_CHAIN_DEPTH && ownerCursor && !seen.has(ownerCursor);
          depth += 1
        ) {
          seen.add(ownerCursor);
          ownerAncestors.push(ownerCursor);
          const ownerSession = await getSessionSafe(ownerCursor);
          if (!ownerSession) break;
          if (!inheritedDuoModel && isDuoModel(ownerSession.model)) {
            inheritedDuoModel = ownerSession.model;
          }
          await collectForks(ownerSession);
          ownerCursor = ownerSession.parentID ?? linkedOwner(ownerSession);
        }

        const rootSessionID =
          ancestors.length > 0
            ? ancestors[ancestors.length - 1].id
            : session.id;

        return {
          session,
          ancestors,
          forkAncestors,
          ownerAncestors,
          rootSessionID,
          ownerSessionID,
          inheritedDuoModel,
        };
      }

      function relatedLockIDs(chain: SessionChain, sessionID: string) {
        const ids = new Set<string>([sessionID, chain.rootSessionID]);
        if (chain.ownerSessionID) ids.add(chain.ownerSessionID);
        for (const ancestor of chain.ancestors) ids.add(ancestor.id);
        for (const forkID of chain.forkAncestors) ids.add(forkID);
        for (const ownerID of chain.ownerAncestors) ids.add(ownerID);

        return ids;
      }

      async function readStoredFindings(id: string): Promise<StoredFindings> {
        const stored = parseStoredFindings(
          await ctx.storage.get(storageKey(id)),
          id,
        );
        return {
          compactionID: stored.compactionID,
          findings: [...stored.findings, ...(failedWrites.get(id) ?? [])],
        };
      }

      async function readFindings(id: string): Promise<Finding[]> {
        return (await readStoredFindings(id)).findings;
      }

      async function collectFindings(chain: SessionChain, sessionID: string) {
        await writes;
        const findings = new Map<string, Finding>();
        for (const id of relatedLockIDs(chain, sessionID)) {
          try {
            for (const finding of await readFindings(id)) {
              findings.set(
                JSON.stringify([finding.origin, finding.id]),
                finding,
              );
            }
          } catch {
            findings.set(`storage:${id}`, {
              id: `storage:${id}`,
              origin: id,
              source: "storage",
              reason: "session lock storage could not be read",
              markedAt: now(),
            });
          }
        }
        return [...findings.values()];
      }

      async function writeFindings(
        id: string,
        findings: Finding[],
        compactionID?: string,
      ) {
        const fallbackLock =
          findings.find((finding) => finding.dismissedAt === undefined) ??
          findings[0];
        await ctx.storage.set(storageKey(id), {
          version: 1,
          findings,
          ...(compactionID && { compactionID }),
          // Older versions must stay locked because they do not understand dismissals.
          ...(fallbackLock && {
            confidential: true,
            reason: fallbackLock.reason,
            markedAt: fallbackLock.markedAt,
          }),
        });
        failedWrites.delete(id);
      }

      function persistFindings(
        chain: SessionChain,
        sessionID: string,
        observations: Observation[],
      ) {
        if (observations.length === 0) return;
        const incoming = observations.map((observation) => ({
          ...observation,
          id: crypto.randomUUID(),
          origin: sessionID,
          markedAt: now(),
        }));
        return updateLedger(async () => {
          const ids = new Set([
            sessionID,
            chain.rootSessionID,
            ...chain.ancestors.map(({ id }) => id),
          ]);
          // Mark every affected session before attempting storage so a partial write stays guarded.
          for (const id of ids) {
            failedWrites.set(id, [
              ...(failedWrites.get(id) ?? []),
              ...incoming,
            ]);
          }
          for (const id of ids) {
            const stored = await readStoredFindings(id);
            const seen = new Set<string>();
            await writeFindings(
              id,
              stored.findings.filter((finding) => {
                if (finding.dismissedAt !== undefined) return true;
                const key = JSON.stringify([
                  finding.origin,
                  findingKey(finding),
                ]);
                if (seen.has(key)) return false;
                seen.add(key);
                return true;
              }),
              stored.compactionID,
            );
          }
        });
      }

      async function switchToModel(
        sessionID: string,
        model: ModelRef,
      ): Promise<boolean> {
        try {
          await ctx.session.switchModel({ sessionID, model });
          return true;
        } catch {
          return false;
        }
      }

      async function resolveDefaultModelForSession(
        session?: DirectorySessionLike,
        currentAgent?: string,
      ): Promise<ModelRef | undefined> {
        const agent = currentAgent ?? session?.agent ?? "plan";
        if (ctx.agent?.get) {
          try {
            const info = await ctx.agent.get({ agentID: agent });
            const rawModel =
              (info as { data?: { model?: unknown }; model?: unknown })?.data
                ?.model ?? (info as { model?: unknown })?.model;
            const parsed = parseModelRef(rawModel);
            if (parsed && !isDuoModel(parsed)) return parsed;
          } catch {
            // Fall through to configured/env defaults.
          }
        }
        const fromEnv = defaultModelForAgent(agent, defaultModels);
        if (fromEnv && !isDuoModel(fromEnv)) return fromEnv;
        if (ctx.model?.default) {
          try {
            const info = await ctx.model.default();
            const rawModel = (info as { data?: unknown })?.data ?? info;
            const parsed = parseModelRef(rawModel);
            if (parsed && !isDuoModel(parsed)) return parsed;
          } catch {
            // Fall through.
          }
        }
        return fromEnv;
      }

      async function unlockAndSwitchBack(
        chain: SessionChain,
        sessionID: string,
        preserveActiveTurn = false,
      ): Promise<void> {
        if (!preserveActiveTurn) {
          activeTurnModel.delete(sessionID);
        }
        const currentSession =
          (await getSessionSafe(sessionID)) ?? chain.session;
        if (!isDuoModel(currentSession?.model)) return;
        const targetModel = await resolveDefaultModelForSession(currentSession);
        if (
          targetModel &&
          (currentSession?.model?.providerID !== targetModel.providerID ||
            currentSession?.model?.id !== targetModel.id)
        ) {
          await switchToModel(sessionID, targetModel);
        }
      }

      async function lockAndSwitch(
        chain: SessionChain,
        sessionID: string,
        currentAgent?: string,
        currentModel?: ModelRef,
      ): Promise<LockSwitchResult> {
        const targetModel = duoModelForAgent(
          currentAgent ?? chain.session?.agent,
          chain.inheritedDuoModel,
          duoModels,
        );

        const activeModel = currentModel ?? chain.session?.model;
        const switched = isDuoModel(activeModel)
          ? true
          : await switchToModel(sessionID, targetModel);

        // Propagate Duo switch to parent/root sessions in the same parentID
        // tree (subagents return their output directly to their parent).
        // Forgekeeper linked sessions run in isolated session transcripts and
        // must not lock or switch their owning session.
        const relatedIDs = new Set<string>();
        for (const ancestor of chain.ancestors) {
          if (ancestor.id !== sessionID) relatedIDs.add(ancestor.id);
        }
        if (chain.rootSessionID !== sessionID) {
          relatedIDs.add(chain.rootSessionID);
        }

        for (const relatedID of relatedIDs) {
          const relatedSession =
            chain.ancestors.find((item) => item.id === relatedID) ??
            (await getSessionSafe(relatedID));
          if (!isDuoModel(relatedSession?.model)) {
            await switchToModel(
              relatedID,
              duoModelForAgent(relatedSession?.agent, undefined, duoModels),
            );
          }
        }

        return { targetModel, switched };
      }

      async function statusChain(sessionID: string) {
        const chain = await resolveChain(sessionID);
        if (!chain.session || !ownsSession(chain.session)) {
          throw new Error("Session is not available in this location");
        }
        return chain;
      }

      function canDismiss(
        chain: SessionChain,
        sessionID: string,
        finding: Finding,
      ) {
        return (
          finding.origin === sessionID &&
          finding.dismissedAt === undefined &&
          relatedLockIDs(chain, sessionID).size === 1 &&
          (finding.source === "legacy" ||
            (finding.source === "prompt" &&
              !!finding.ref &&
              finding.ref.kind !== "overflow"))
        );
      }

      async function status(chain: SessionChain, sessionID: string) {
        await reconcileCompactionIfNeeded(chain, sessionID);
        const findings: StatusFinding[] = (
          await collectFindings(chain, sessionID)
        ).map((finding) => ({
          id: finding.id,
          source: finding.source,
          reason: finding.reason,
          markedAt: finding.markedAt,
          inherited: finding.origin !== sessionID,
          dismissed:
            finding.origin === sessionID && finding.dismissedAt !== undefined,
          canDismiss: canDismiss(chain, sessionID, finding),
          canRecheck: canRecheck(finding),
        }));
        return { findings };
      }

      await ctx.rpc.register(ConfidentialGuardRpc, {
        status: async (input) => {
          const { sessionID } = input as { sessionID: string };
          return status(await statusChain(sessionID), sessionID);
        },
        recheck: async (input, context) => {
          const { sessionID, findingID } = input as {
            sessionID: string;
            findingID: string;
          };
          const chain = await statusChain(sessionID);
          const finding = (await collectFindings(chain, sessionID)).find(
            ({ id }) => id === findingID,
          );
          if (!finding?.ref || !canRecheck(finding))
            throw new Error("No GitLab item to recheck");
          return checker.recheck(finding.ref, context.signal);
        },
        dismissPromptFinding: async (input, context) => {
          const { sessionID, findingID } = input as {
            sessionID: string;
            findingID: string;
          };
          const chain = await statusChain(sessionID);
          const finding = (await collectFindings(chain, sessionID)).find(
            ({ id }) => id === findingID,
          );
          if (!finding || !canDismiss(chain, sessionID, finding))
            throw new Error("This finding cannot be dismissed");
          if (
            finding.ref &&
            canRecheck(finding) &&
            (await checker.recheck(finding.ref, context.signal)).status !==
              "public"
          ) {
            throw new Error(
              "GitLab must verify this item is public before the finding can be dismissed",
            );
          }
          await updateLedger(async () => {
            const current = await readStoredFindings(sessionID);
            const selected = current.findings.find(
              ({ id }) => id === findingID,
            );
            if (
              !selected ||
              !canDismiss(await statusChain(sessionID), sessionID, selected)
            ) {
              throw new Error("This finding can no longer be dismissed");
            }
            await writeFindings(
              sessionID,
              current.findings.map((entry) =>
                entry.id === findingID
                  ? { ...entry, dismissedAt: now() }
                  : entry,
              ),
              current.compactionID,
            );
          });
          return status(chain, sessionID);
        },
      });

      async function currentBranch(
        session?: DirectorySessionLike,
      ): Promise<string | undefined> {
        const directory =
          session?.location?.directory ?? ctx.location?.directory;
        if (session?.location && ctx.vcs?.get) {
          try {
            const vcs = await ctx.vcs.get({
              location: session.location as never,
            });
            const branch = (vcs as { data?: { branch?: { current?: string } } })
              ?.data?.branch?.current;
            if (branch) return branch;
          } catch {
            // Fall through to git CLI.
          }
        }
        if (!directory) return undefined;
        try {
          const out = (
            await git(["rev-parse", "--abbrev-ref", "HEAD"], directory)
          ).trim();
          return out && out !== "HEAD" ? out : undefined;
        } catch {
          return undefined;
        }
      }

      async function inspectRepo(session?: DirectorySessionLike): Promise<{
        readonly analysis: GitRepoAnalysis;
        readonly branch?: string;
      }> {
        const directory =
          session?.location?.directory ?? ctx.location?.directory;
        if (!directory) return { analysis: {} };

        const dirReason = confidentialReasonForDirectory(directory);
        if (dirReason) {
          return { analysis: { confidentialReason: dirReason } };
        }

        const branch = await currentBranch(session);
        const cached = repoCache.get(directory);
        if (cached && cached.expiresAt > now() && cached.branch === branch) {
          return { analysis: cached.analysis, branch: cached.branch };
        }

        let configOutput = "";
        try {
          configOutput = await git(
            [
              "config",
              "--get-regexp",
              "^(remote\\.[^.]+\\.url|branch\\..*\\.(remote|pushremote))$",
            ],
            directory,
          );
        } catch {
          configOutput = "";
        }

        const analysis = analyzeGitConfig(configOutput, branch);
        repoCache.set(directory, {
          analysis,
          branch,
          expiresAt: now() + REPO_CACHE_TTL_MS,
        });
        return { analysis, branch };
      }

      async function inspectTargetInstructions(
        sessionID: string,
        defaultProject?: string,
        fresh: boolean | GitLabConfidentialityChecker = false,
      ): Promise<Observation[]> {
        if (!ctx.session.instructions?.entry?.list) return [];
        try {
          const entries = await ctx.session.instructions.entry.list({
            sessionID,
          });
          const targetText = extractTargetsFromInstructions(entries);
          if (!targetText) return [];
          return assessRefs(
            "target",
            extractGitLabRefs(targetText, defaultProject),
            fresh,
          );
        } catch {
          return [
            {
              source: "target",
              reason: "session target instructions could not be read",
            },
          ];
        }
      }

      async function assessRefs(
        source: Observation["source"],
        refs: GitLabRef[],
        fresh: boolean | GitLabConfidentialityChecker = false,
      ) {
        const observations: Observation[] = [];
        for (const { kind, path, iid } of refs) {
          const ref = { kind, path, ...(iid && { iid }) };
          const reason =
            fresh instanceof GitLabConfidentialityChecker
              ? await fresh.checkRefs([ref])
              : fresh
                ? await checker.checkRefsFresh([ref])
                : await checker.checkRefs([ref]);
          if (reason) observations.push({ source, reason, ref });
        }
        return observations;
      }

      async function inspectRepoAndTargetObservations(
        chain: SessionChain,
        sessionID: string,
        fresh: boolean | GitLabConfidentialityChecker = false,
      ): Promise<{
        readonly observations: Observation[];
        readonly defaultProject?: string;
      }> {
        if (fresh) {
          const directory =
            chain.session?.location?.directory ?? ctx.location?.directory;
          if (directory) repoCache.delete(directory);
        }
        const observations: Observation[] = [];
        const { analysis, branch } = await inspectRepo(chain.session);
        if (analysis.confidentialReason) {
          observations.push({
            source: "checkout",
            reason: analysis.confidentialReason,
          });
        }

        observations.push(
          ...(await inspectTargetInstructions(
            sessionID,
            analysis.defaultProject,
            fresh,
          )),
        );

        if (chain.ownerSessionID) {
          observations.push(
            ...(await inspectTargetInstructions(
              chain.ownerSessionID,
              analysis.defaultProject,
              fresh,
            )),
          );
        }

        if (analysis.defaultProject && branch) {
          if (/^(?:.*\/)?security-/i.test(branch)) {
            observations.push({
              source: "branch",
              reason: `security branch "${branch}"`,
            });
          }
          const branchIid = extractBranchIssueIid(branch);
          if (branchIid) {
            const branchFindings = await assessRefs(
              "branch",
              [
                {
                  kind: "issue",
                  path: analysis.defaultProject,
                  iid: branchIid,
                },
              ],
              fresh,
            );
            observations.push(
              ...branchFindings.map((finding) => ({
                ...finding,
                reason: `branch "${branch}" (${finding.reason})`,
              })),
            );
          }
        }

        return { observations, defaultProject: analysis.defaultProject };
      }

      async function inspectToolCallAndResult(
        tool: string,
        input: unknown,
        completedText: string | undefined,
        defaultProject?: string,
        fresh: boolean | GitLabConfidentialityChecker = true,
      ): Promise<Observation[]> {
        const observations: Observation[] = [];
        const direct = checkToolCallBefore(tool, input);
        if (direct) {
          observations.push({ source: "tool input", reason: direct.reason });
        } else {
          const inputRefs = extractToolInputRefs(tool, input, defaultProject);
          if (inputRefs.length > 0) {
            observations.push(
              ...(await assessRefs(
                tool === "set_session_target" ? "target" : "tool input",
                inputRefs,
                fresh,
              )),
            );
          }
        }
        if (completedText && isGitLabOutputTool(tool, input)) {
          const outputReason = detectConfidentialOutput(completedText);
          if (outputReason) {
            observations.push({ source: "tool output", reason: outputReason });
          }
        }
        return observations;
      }

      async function inspectCheckpointText(
        rawSummary: string,
        rawRecent?: string,
        defaultProject?: string,
        fresh: boolean | GitLabConfidentialityChecker = true,
      ): Promise<Observation[]> {
        const observations: Observation[] = [];
        const { summaryText, recentText } = splitCompactionCheckpoint(
          rawSummary,
          rawRecent,
        );
        if (summaryText) {
          observations.push(
            ...(await assessRefs(
              "prompt",
              extractGitLabRefs(summaryText, defaultProject),
              fresh,
            )),
          );
        }
        for (const entry of parseRecentContextEntries(recentText)) {
          if (entry.kind === "user" || entry.kind === "assistant") {
            observations.push(
              ...(await assessRefs(
                "prompt",
                extractGitLabRefs(entry.text, defaultProject),
                fresh,
              )),
            );
          } else if (entry.kind === "tool_call") {
            observations.push(
              ...(await inspectToolCallAndResult(
                entry.tool,
                entry.input,
                undefined,
                defaultProject,
                fresh,
              )),
            );
          } else if (entry.kind === "tool_result") {
            if (isGitLabOutputTool(entry.tool, entry.input)) {
              const outputReason = detectConfidentialOutput(entry.text);
              if (outputReason) {
                observations.push({
                  source: "tool output",
                  reason: outputReason,
                });
              }
            }
          } else if (entry.kind === "tool_error") {
            if (entry.tool && isGitLabOutputTool(entry.tool, entry.input)) {
              const outputReason = detectConfidentialOutput(entry.text);
              if (outputReason) {
                observations.push({
                  source: "tool output",
                  reason: outputReason,
                });
              }
            }
            observations.push(
              ...(await assessRefs(
                "prompt",
                extractGitLabRefs(entry.text, defaultProject),
                fresh,
              )),
            );
          } else if (entry.kind === "shell") {
            observations.push(
              ...(await inspectToolCallAndResult(
                "shell",
                { command: entry.command },
                entry.output,
                defaultProject,
                fresh,
              )),
            );
          }
        }
        return observations;
      }

      function deriveCompactionID(
        msg: Record<string, unknown> | undefined,
        fallbackID?: string,
      ): string | undefined {
        if (typeof msg?.id === "string" && msg.id) return msg.id;
        if (fallbackID) return fallbackID;
        if (!msg) return undefined;
        const summary =
          typeof msg.summary === "string"
            ? msg.summary
            : typeof msg.text === "string"
              ? msg.text
              : extractMessageText(msg.content);
        const recent =
          msg.metadata &&
          typeof msg.metadata === "object" &&
          typeof (msg.metadata as { recent?: unknown }).recent === "string"
            ? (msg.metadata as { recent: string }).recent
            : "";
        const combined = `${summary}\n${recent}`.trim();
        if (!combined) return undefined;
        let hash = 2166136261;
        for (let i = 0; i < combined.length; i += 1) {
          hash ^= combined.charCodeAt(i);
          hash = Math.imul(hash, 16777619);
        }
        return `checkpoint:${(hash >>> 0).toString(16)}:${combined.length}`;
      }

      function findLatestCompactionIndex(
        messages: readonly Record<string, unknown>[],
      ): number {
        for (let i = messages.length - 1; i >= 0; i -= 1) {
          const msg = messages[i];
          if (!msg || typeof msg !== "object") continue;
          if (
            msg.type === "compaction" &&
            (msg.status === "completed" || msg.status === undefined)
          ) {
            return i;
          }
          if (
            msg.role === "user" &&
            extractMessageText(msg.content).includes(
              "<conversation-checkpoint>",
            )
          ) {
            return i;
          }
        }
        return -1;
      }

      async function inspectCompactedMessages(
        messages: readonly Record<string, unknown>[],
        defaultProject?: string,
        fresh: boolean | GitLabConfidentialityChecker = true,
      ): Promise<Observation[]> {
        const observations: Observation[] = [];
        const toolCallsByID = new Map<
          string,
          { tool: string; input: unknown }
        >();

        for (const msg of messages) {
          if (!msg || typeof msg !== "object") continue;

          if (msg.type === "compaction") {
            if (msg.status && msg.status !== "completed") continue;
            const summary = typeof msg.summary === "string" ? msg.summary : "";
            const recent =
              msg.metadata &&
              typeof msg.metadata === "object" &&
              typeof (msg.metadata as { recent?: unknown }).recent === "string"
                ? (msg.metadata as { recent: string }).recent
                : undefined;
            observations.push(
              ...(await inspectCheckpointText(
                summary,
                recent,
                defaultProject,
                fresh,
              )),
            );
            continue;
          }

          if (
            msg.type === "user" ||
            msg.type === "synthetic" ||
            msg.role === "user"
          ) {
            const text =
              typeof msg.text === "string"
                ? msg.text
                : extractMessageText(msg.content);
            if (!text) continue;
            if (text.includes("<conversation-checkpoint>")) {
              observations.push(
                ...(await inspectCheckpointText(
                  text,
                  undefined,
                  defaultProject,
                  fresh,
                )),
              );
            } else {
              observations.push(
                ...(await assessRefs(
                  "prompt",
                  extractGitLabRefs(text, defaultProject),
                  fresh,
                )),
              );
            }
            continue;
          }

          if (msg.type === "shell") {
            const command = typeof msg.command === "string" ? msg.command : "";
            const output =
              msg.output &&
              typeof msg.output === "object" &&
              typeof (msg.output as { output?: unknown }).output === "string"
                ? (msg.output as { output: string }).output
                : "";
            observations.push(
              ...(await inspectToolCallAndResult(
                "shell",
                { command },
                output,
                defaultProject,
                fresh,
              )),
            );
            continue;
          }

          if (msg.role === "tool" && Array.isArray(msg.content)) {
            for (const part of msg.content) {
              if (!part || typeof part !== "object") continue;
              const record = part as Record<string, unknown>;
              const callID =
                typeof record.toolCallId === "string"
                  ? record.toolCallId
                  : undefined;
              const prior = callID ? toolCallsByID.get(callID) : undefined;
              const toolName =
                typeof record.toolName === "string"
                  ? record.toolName
                  : prior?.tool;
              const toolInput = "input" in record ? record.input : prior?.input;
              const resultRaw =
                "output" in record
                  ? record.output
                  : "result" in record
                    ? record.result
                    : record.content;
              const resultText =
                typeof resultRaw === "string"
                  ? resultRaw
                  : extractResultText({ content: resultRaw }) ||
                    JSON.stringify(resultRaw ?? "");
              if (toolName && isGitLabOutputTool(toolName, toolInput)) {
                const outputReason = detectConfidentialOutput(resultText);
                if (outputReason) {
                  observations.push({
                    source: "tool output",
                    reason: outputReason,
                  });
                }
              }
            }
            continue;
          }

          if (msg.type === "assistant" || msg.role === "assistant") {
            if (typeof msg.content === "string" && msg.content) {
              observations.push(
                ...(await assessRefs(
                  "prompt",
                  extractGitLabRefs(msg.content, defaultProject),
                  fresh,
                )),
              );
              continue;
            }
            if (!Array.isArray(msg.content)) continue;
            for (const part of msg.content) {
              if (!part || typeof part !== "object") continue;
              const record = part as Record<string, unknown>;
              if (record.type === "text" && typeof record.text === "string") {
                observations.push(
                  ...(await assessRefs(
                    "prompt",
                    extractGitLabRefs(record.text, defaultProject),
                    fresh,
                  )),
                );
                continue;
              }
              if (
                record.type === "tool-call" &&
                typeof record.toolName === "string"
              ) {
                const input =
                  "input" in record
                    ? record.input
                    : "args" in record
                      ? record.args
                      : undefined;
                if (typeof record.toolCallId === "string") {
                  toolCallsByID.set(record.toolCallId, {
                    tool: record.toolName,
                    input,
                  });
                }
                observations.push(
                  ...(await inspectToolCallAndResult(
                    record.toolName,
                    input,
                    undefined,
                    defaultProject,
                    fresh,
                  )),
                );
                continue;
              }
              if (record.type !== "tool" || typeof record.name !== "string") {
                continue;
              }
              const state =
                record.state && typeof record.state === "object"
                  ? (record.state as Record<string, unknown>)
                  : undefined;
              const input =
                state && "input" in state ? state.input : record.input;
              const completedText =
                state?.status === "completed"
                  ? extractResultText({ content: state.content })
                  : undefined;
              observations.push(
                ...(await inspectToolCallAndResult(
                  record.name,
                  input,
                  completedText,
                  defaultProject,
                  fresh,
                )),
              );
            }
          }
        }

        return observations;
      }

      async function reevaluateAfterCompaction(
        sessionID: string,
        opts: {
          chain?: SessionChain;
          contextMessages?: readonly Record<string, unknown>[];
          compactionID?: string;
          compactedAt?: number;
          preserveActiveTurn?: boolean;
        } = {},
      ): Promise<void> {
        const existingRun = inflightCompaction.get(sessionID);
        if (existingRun) {
          await existingRun;
          return;
        }

        const run = (async () => {
          const chain = opts.chain ?? (await resolveChain(sessionID));
          if (!ownsSession(chain.session)) return;

          let contextMessages = opts.contextMessages;
          if (!contextMessages && typeof ctx.session.context === "function") {
            try {
              contextMessages = (await ctx.session.context({
                sessionID,
              })) as unknown as readonly Record<string, unknown>[];
            } catch {
              // Fail closed if active context cannot be read.
              return;
            }
          }

          const idx = contextMessages
            ? findLatestCompactionIndex(contextMessages)
            : -1;
          // Fail closed: require the full compaction checkpoint in contextMessages
          // so `<recent-context>` and kept post-compaction messages are always scanned.
          if (idx === -1) {
            return;
          }

          const compactionMsg = contextMessages![idx];
          const msgCreated =
            compactionMsg?.time &&
            typeof compactionMsg.time === "object" &&
            typeof (compactionMsg.time as { created?: unknown }).created ===
              "number"
              ? (compactionMsg.time as { created: number }).created
              : undefined;
          const compactedAt = msgCreated ?? opts.compactedAt ?? now();
          const compactionID =
            deriveCompactionID(compactionMsg, opts.compactionID) ??
            `compaction:${compactedAt}`;

          const storedBefore = await readStoredFindings(sessionID);
          if (storedBefore.compactionID === compactionID) {
            return;
          }

          const activeMessages = contextMessages!.slice(idx);

          const beforeFindings = await collectFindings(chain, sessionID);
          const hadActiveLock = beforeFindings.some(
            (finding) =>
              finding.dismissedAt === undefined || finding.origin !== sessionID,
          );

          const freshChecker = checker.createFreshChecker();
          const { observations: repoAndTarget, defaultProject } =
            await inspectRepoAndTargetObservations(
              chain,
              sessionID,
              freshChecker,
            );
          const contextObservations = await inspectCompactedMessages(
            activeMessages,
            defaultProject,
            freshChecker,
          );
          checker.mergeCacheFrom(freshChecker);
          const allObservations = [...repoAndTarget, ...contextObservations];

          await updateLedger(async () => {
            const current = await readStoredFindings(sessionID);
            const dismissedByKey = new Map<string, Finding>();
            const dismissedLegacyByReason = new Map<string, Finding>();
            for (const finding of current.findings) {
              if (finding.dismissedAt === undefined) continue;
              dismissedByKey.set(findingKey(finding), finding);
              if (finding.source === "legacy") {
                dismissedLegacyByReason.set(finding.reason, finding);
              }
            }

            const postCompactionConcurrent = current.findings.filter(
              (finding) =>
                finding.dismissedAt === undefined &&
                finding.markedAt > compactedAt,
            );

            const seen = new Set<string>();
            const nextFindings: Finding[] = [];
            for (const obs of allObservations) {
              const key = findingKey(obs);
              if (seen.has(key)) continue;
              seen.add(key);

              // Only carry forward dismissals for static/non-recheckable prompt
              // references (such as incidental security-project URLs). If a
              // recheckable GitLab issue/MR is returned in allObservations, the
              // fresh check found it confidential or unknown, so it must re-lock.
              const isRecheckableRef =
                !!obs.ref &&
                obs.ref.kind !== "project" &&
                obs.ref.kind !== "overflow";
              const prevDismissed =
                obs.source === "prompt" && !isRecheckableRef
                  ? (dismissedByKey.get(key) ??
                    dismissedLegacyByReason.get(obs.reason))
                  : undefined;
              if (prevDismissed) {
                nextFindings.push({
                  ...obs,
                  id: prevDismissed.id,
                  origin: sessionID,
                  markedAt: prevDismissed.markedAt,
                  dismissedAt: prevDismissed.dismissedAt,
                });
              } else {
                nextFindings.push({
                  ...obs,
                  id: crypto.randomUUID(),
                  origin: sessionID,
                  markedAt: compactedAt,
                });
              }
            }

            for (const concurrent of postCompactionConcurrent) {
              const key = findingKey(concurrent);
              if (seen.has(key)) continue;
              seen.add(key);
              nextFindings.push(concurrent);
            }

            await writeFindings(sessionID, nextFindings, compactionID);
          });

          const afterFindings = await collectFindings(chain, sessionID);
          const stillLocked = afterFindings.some(
            (finding) =>
              finding.dismissedAt === undefined || finding.origin !== sessionID,
          );

          if (stillLocked) {
            await lockAndSwitch(chain, sessionID);
          } else if (hadActiveLock) {
            await unlockAndSwitchBack(
              chain,
              sessionID,
              opts.preserveActiveTurn,
            );
          }
        })();

        inflightCompaction.set(sessionID, run);
        try {
          await run;
        } finally {
          inflightCompaction.delete(sessionID);
        }
      }

      async function reconcileCompactionIfNeeded(
        chain: SessionChain,
        sessionID: string,
        hookMessages?: readonly Record<string, unknown>[],
        preserveActiveTurn = false,
      ): Promise<void> {
        await writes;
        let stored: StoredFindings;
        try {
          stored = await readStoredFindings(sessionID);
        } catch {
          return;
        }
        if (stored.findings.length === 0) return;

        if (typeof ctx.session.context === "function") {
          let contextMessages: readonly Record<string, unknown>[] | undefined;
          try {
            contextMessages = (await ctx.session.context({
              sessionID,
            })) as unknown as readonly Record<string, unknown>[];
          } catch {
            contextMessages = undefined;
          }
          if (contextMessages) {
            const idx = findLatestCompactionIndex(contextMessages);
            if (idx !== -1) {
              const compactionMsg = contextMessages[idx];
              const compactionID = deriveCompactionID(compactionMsg);
              if (compactionID && compactionID !== stored.compactionID) {
                await reevaluateAfterCompaction(sessionID, {
                  chain,
                  contextMessages,
                  compactionID,
                  preserveActiveTurn,
                });
              }
              return;
            }
          }
        }

        if (hookMessages && hookMessages.length > 0) {
          const idx = findLatestCompactionIndex(hookMessages);
          if (idx === -1) return;
          const msg = hookMessages[idx];
          const compactionID = deriveCompactionID(msg);
          if (!compactionID || compactionID === stored.compactionID) return;
          await reevaluateAfterCompaction(sessionID, {
            chain,
            contextMessages: hookMessages,
            compactionID,
            preserveActiveTurn,
          });
        }
      }

      async function detectConfidentialForSession(
        chain: SessionChain,
        sessionID: string,
        extraText?: string,
        historicalText = false,
        hookMessages?: readonly Record<string, unknown>[],
        reconcileCompaction = true,
      ): Promise<string | undefined> {
        if (reconcileCompaction) {
          await reconcileCompactionIfNeeded(chain, sessionID, hookMessages);
        }
        const stored = await collectFindings(chain, sessionID);
        const { observations, defaultProject } =
          await inspectRepoAndTargetObservations(chain, sessionID, false);

        if (extraText) {
          const promptRefs = extractGitLabRefs(extraText, defaultProject);
          const dismissed = new Set(
            stored
              .filter(
                (finding) =>
                  finding.origin === sessionID &&
                  finding.dismissedAt !== undefined,
              )
              .map(findingKey),
          );
          observations.push(
            ...(await assessRefs("prompt", promptRefs)).filter(
              (finding) =>
                !historicalText || !dismissed.has(findingKey(finding)),
            ),
          );
        }

        const alreadyActive = new Set(
          stored
            .filter(
              (finding) =>
                finding.origin === sessionID &&
                finding.dismissedAt === undefined,
            )
            .map(findingKey),
        );
        const active = stored.find(
          (finding) =>
            finding.dismissedAt === undefined || finding.origin !== sessionID,
        );
        await persistFindings(
          chain,
          sessionID,
          observations.filter(
            (finding) => !alreadyActive.has(findingKey(finding)),
          ),
        );
        return active?.reason ?? observations[0]?.reason;
      }

      // 1. Prompt admission: switch to Duo before the turn resolves its model
      // (covers user prompts, subagents, and Forgekeeper queued/linked turns).
      // Do not update activeTurnModel here: a queued prompt can be admitted
      // while an earlier upstream turn still has tool calls in flight.
      await ctx.session.hook("prompt", async (event) => {
        const chain = await resolveChain(event.sessionID);
        if (!ownsSession(chain.session)) return;

        const promptText =
          typeof event.prompt?.text === "string" ? event.prompt.text : "";
        const reason = await detectConfidentialForSession(
          chain,
          event.sessionID,
          promptText,
        );
        if (reason) {
          const { targetModel, switched } = await lockAndSwitch(
            chain,
            event.sessionID,
          );
          if (!switched) {
            throw new Error(
              `Confidential session (${reason}) could not be switched to ${targetModel.providerID}/${targetModel.id}.`,
            );
          }
        }
      });

      // 2. Pre-execution tool guard: classify confidential inputs on all providers
      // so Duo reads still lock the session, and block on upstream models.
      await ctx.tool.hook("execute.before", async (event) => {
        const chain = await resolveChain(event.sessionID);
        if (!ownsSession(chain.session)) return;

        const alreadyOnDuo = isSessionTurnOnDuo(event.sessionID, chain);
        const direct = checkToolCallBefore(event.tool, event.input);
        const observations: Observation[] = direct
          ? [{ source: "tool input", reason: direct.reason }]
          : [];

        if (!direct) {
          const { analysis } = await inspectRepo(chain.session);
          const inputRefs = extractToolInputRefs(
            event.tool,
            event.input,
            analysis.defaultProject,
          );
          if (inputRefs.length > 0) {
            observations.push(...(await assessRefs("tool input", inputRefs)));
          }
        }

        if (observations.length === 0) return;
        await persistFindings(chain, event.sessionID, observations);
        const reason = observations[0].reason;

        const { targetModel, switched } = await lockAndSwitch(
          chain,
          event.sessionID,
          event.agent,
          chain.session?.model,
        );

        if (!alreadyOnDuo) {
          const switchMsg = switched
            ? `Session model switched to ${targetModel.providerID}/${targetModel.id}; retry on the next turn.`
            : `Automatic switch to ${targetModel.providerID}/${targetModel.id} failed; switch the session model manually before retrying.`;
          throw new Error(
            `Confidential/RED tool call blocked on upstream model (${reason}). ${switchMsg}`,
          );
        }
      });

      // 3. Post-execution guard: redact confidential GitLab responses on upstream
      // models and switch the session to Duo (including via set_session_target).
      await ctx.tool.hook("execute.after", async (event) => {
        if (event.status !== "completed" || !event.result) return;

        if (event.tool === "set_session_target") {
          const urls = extractSetSessionTargetUrls(event.input);
          if (urls.length === 0) return;

          const chain = await resolveChain(event.sessionID);
          if (!ownsSession(chain.session)) return;

          const { analysis } = await inspectRepo(chain.session);
          const refs = extractGitLabRefs(
            urls.join("\n"),
            analysis.defaultProject,
          );
          const observations = await assessRefs("target", refs);
          if (observations.length === 0) return;
          await persistFindings(chain, event.sessionID, observations);
          const reason = observations[0].reason;

          const alreadyOnDuo = isSessionTurnOnDuo(event.sessionID, chain);
          const { targetModel, switched } = await lockAndSwitch(
            chain,
            event.sessionID,
            event.agent,
            chain.session?.model,
          );

          if (!alreadyOnDuo) {
            const statusText = switched
              ? `Session model switched to ${targetModel.providerID}/${targetModel.id}.`
              : `Automatic model switch to ${targetModel.providerID}/${targetModel.id} failed; switch the session model manually.`;
            const notice = `\n[Confidential target detected (${reason}). ${statusText}]`;
            const current = event.result as Record<string, unknown>;
            if (typeof current.content === "string") {
              event.result = {
                ...current,
                content: current.content + notice,
              } as typeof event.result;
            } else if (Array.isArray(current.content)) {
              event.result = {
                ...current,
                content: [
                  ...current.content,
                  { type: "text", text: notice.trimStart() },
                ],
              } as typeof event.result;
            }
          }
          return;
        }

        if (!isGitLabOutputTool(event.tool, event.input)) return;

        const text = extractResultText(event.result);
        const reason = detectConfidentialOutput(text);
        if (!reason) return;

        const chain = await resolveChain(event.sessionID);
        if (!ownsSession(chain.session)) return;

        const alreadyOnDuo = isSessionTurnOnDuo(event.sessionID, chain);
        const plannedModel = duoModelForAgent(
          event.agent ?? chain.session?.agent,
          chain.inheritedDuoModel,
          duoModels,
        );
        if (!alreadyOnDuo) {
          // Redact before awaiting lock persistence so a storage error cannot
          // leave confidential tool output exposed to the active upstream turn.
          const prelimNotice = formatRedactionNotice(
            reason,
            plannedModel,
            false,
          );
          event.result = redactToolResult(
            event.result as Record<string, unknown>,
            prelimNotice,
          ) as typeof event.result;
        }

        await persistFindings(chain, event.sessionID, [
          { source: "tool output", reason },
        ]);
        const { targetModel, switched } = await lockAndSwitch(
          chain,
          event.sessionID,
          event.agent,
          chain.session?.model,
        );

        if (!alreadyOnDuo) {
          const notice = formatRedactionNotice(reason, targetModel, switched);
          event.result = redactToolResult(
            event.result as Record<string, unknown>,
            notice,
          ) as typeof event.result;
        }
      });

      // 4. Request backstops: refuse any upstream LLM call once confidential.
      // Only primary turn requests (context and non-transient generate) establish
      // activeTurnModel, so interleaved Duo auxiliary calls cannot unmask an
      // in-flight upstream tool call.
      const guardRequest = async (
        event: {
          readonly sessionID: string;
          readonly agent?: string;
          readonly model: ModelRef;
          readonly transient?: boolean;
          readonly messages?: readonly Record<string, unknown>[];
        },
        isPrimaryTurn: boolean,
        allowCompactionReconcile = true,
      ) => {
        if (isDuoModel(event.model)) {
          if (isPrimaryTurn && !event.transient) {
            activeTurnModel.set(event.sessionID, event.model);
          }
          if (allowCompactionReconcile) {
            const chain = await resolveChain(event.sessionID);
            if (ownsSession(chain.session)) {
              await reconcileCompactionIfNeeded(
                chain,
                event.sessionID,
                event.messages,
                true,
              );
            }
          }
          return;
        }

        const chain = await resolveChain(event.sessionID);
        if (!ownsSession(chain.session)) return;

        const reason = await detectConfidentialForSession(
          chain,
          event.sessionID,
          undefined,
          false,
          event.messages,
          allowCompactionReconcile,
        );
        if (!reason) {
          if (isPrimaryTurn && !event.transient) {
            activeTurnModel.set(event.sessionID, event.model);
          }
          return;
        }

        const { targetModel, switched } = await lockAndSwitch(
          chain,
          event.sessionID,
          event.agent,
          event.model,
        );
        const switchMsg = switched
          ? `Session model switched to ${targetModel.providerID}/${targetModel.id}; retry the turn.`
          : `Automatic switch to ${targetModel.providerID}/${targetModel.id} failed; switch the session model manually.`;

        throw new Error(
          `Blocked upstream model ${event.model.providerID}/${event.model.id} for confidential session (${reason}). ${switchMsg}`,
        );
      };

      await ctx.session.hook("context", (event) =>
        guardRequest(
          event as typeof event & {
            readonly messages?: readonly Record<string, unknown>[];
          },
          true,
          true,
        ),
      );
      await ctx.session.hook("generate", (event) =>
        guardRequest(
          event as typeof event & {
            readonly messages?: readonly Record<string, unknown>[];
          },
          !(event as { readonly transient?: boolean }).transient,
          true,
        ),
      );
      await ctx.session.hook("compaction", (event) =>
        guardRequest(event, false, false),
      );

      // 5. Title hook: prevent confidential prompts from hitting upstream title models.
      await ctx.session.hook("title", async (event) => {
        if (isDuoModel(event.model)) return;

        const chain = await resolveChain(event.sessionID);
        if (!ownsSession(chain.session)) return;

        const userText = event.messages
          .filter((msg) => msg.role === "user")
          .map((msg) => extractMessageText(msg.content))
          .join("\n");

        const reason = await detectConfidentialForSession(
          chain,
          event.sessionID,
          userText,
          true,
          event.messages as unknown as readonly Record<string, unknown>[],
        );
        if (!reason) return;

        if (event.result !== undefined) return;

        const systemText = Array.isArray(event.system)
          ? event.system
              .map((part) =>
                part &&
                typeof part === "object" &&
                typeof (part as { text?: unknown }).text === "string"
                  ? (part as { text: string }).text
                  : "",
              )
              .filter(Boolean)
              .join("\n")
          : "";

        if (ctx.experimental?.generate?.text && userText.trim()) {
          try {
            const promptParts = [
              "Write a concise, single-line session title (max 60 characters, no quotes or markdown) summarizing this request.",
              ...(systemText ? [systemText] : []),
              userText.slice(0, 1500),
            ];
            const generated = await ctx.experimental.generate.text({
              model: duoModels.title,
              prompt: promptParts.join("\n\n"),
            });
            const raw =
              typeof generated === "string"
                ? generated
                : ((generated as { data?: { text?: unknown }; text?: unknown })
                    ?.data?.text ?? (generated as { text?: unknown })?.text);
            if (typeof raw === "string") {
              const cleaned = raw.replace(/\s+/g, " ").trim().slice(0, 100);
              if (cleaned) {
                event.result = cleaned;
                return;
              }
            }
          } catch {
            // Fall through and block the upstream title request.
          }
        }

        throw new Error(
          `Blocked upstream title model ${event.model.providerID}/${event.model.id} for confidential session (${reason}).`,
        );
      });

      // 6. Post-compaction re-evaluation: rescan the compacted context, repo,
      // branch, and session target when compaction completes, unlocking and
      // switching back to the configured default model when clean.
      const eventController = new AbortController();
      if (ctx.event?.subscribe) {
        void (async () => {
          try {
            for await (const rawEvent of ctx.event.subscribe({
              types: ["session.compaction.ended"],
              signal: eventController.signal,
            })) {
              const event = rawEvent as {
                readonly id?: unknown;
                readonly created?: unknown;
                readonly type?: unknown;
                readonly data?: {
                  readonly sessionID?: unknown;
                  readonly inputID?: unknown;
                  readonly text?: unknown;
                };
              };
              if (event.type !== "session.compaction.ended") continue;
              const sessionID =
                typeof event.data?.sessionID === "string"
                  ? event.data.sessionID
                  : undefined;
              if (!sessionID) continue;
              const compactionID =
                typeof event.data?.inputID === "string" && event.data.inputID
                  ? event.data.inputID
                  : typeof event.id === "string" && event.id
                    ? event.id
                    : undefined;
              const compactedAt =
                typeof event.created === "number" ? event.created : undefined;
              await reevaluateAfterCompaction(sessionID, {
                compactionID,
                compactedAt,
              });
            }
          } catch {
            // Ignore stream termination on plugin unload.
          }
        })();
      }

      return () => {
        eventController.abort();
      };
    },
  } satisfies Plugin.Plugin;
}

export default createPlugin();
