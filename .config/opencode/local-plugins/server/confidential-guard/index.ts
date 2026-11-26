import type { Plugin } from "@opencode/plugin";
import {
  analyzeGitConfig,
  checkToolCallBefore,
  confidentialReasonForDirectory,
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
  redactToolResult,
  resolveDuoModels,
  type CliRunner,
  type ConfidentialityAssessment,
  type ConfidentialityStatus,
  type ConfidentialLock,
  type DirectorySessionLike,
  type DuoModels,
  type GitRepoAnalysis,
  type GitRunner,
  type ModelRef,
} from "./src/guard.ts";

export {
  analyzeGitConfig,
  checkToolCallBefore,
  confidentialReasonForDirectory,
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
  redactToolResult,
  resolveDuoModels,
  type ConfidentialityAssessment,
  type ConfidentialityStatus,
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

function parseStoredLock(value: unknown): ConfidentialLock | undefined {
  if (!value || typeof value !== "object") return undefined;
  const record = value as Partial<ConfidentialLock>;
  if (record.confidential !== true || typeof record.reason !== "string") {
    return undefined;
  }
  return {
    confidential: true,
    reason: record.reason,
    markedAt: typeof record.markedAt === "number" ? record.markedAt : 0,
  };
}

export function createPlugin(options: CreatePluginOptions = {}) {
  const now = options.now ?? (() => Date.now());
  const git = options.git ?? execGit;
  const checker = new GitLabConfidentialityChecker(
    options.glab ?? execGlab,
    now,
  );

  return {
    id: "confidential-guard",
    async setup(ctx) {
      const duoModels: DuoModels = resolveDuoModels(
        ctx.options,
        options.env ?? process.env,
      );
      const repoCache = new Map<string, RepoCacheEntry>();
      const activeTurnModel = new Map<string, ModelRef>();
      const memoryLocks = new Map<string, ConfidentialLock>();

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

      async function getStoredLock(
        chain: SessionChain,
        sessionID: string,
      ): Promise<ConfidentialLock | undefined> {
        const ids = new Set<string>([sessionID, chain.rootSessionID]);
        if (chain.ownerSessionID) ids.add(chain.ownerSessionID);
        for (const ancestor of chain.ancestors) ids.add(ancestor.id);
        for (const forkID of chain.forkAncestors) ids.add(forkID);
        for (const ownerID of chain.ownerAncestors) ids.add(ownerID);

        for (const id of ids) {
          const inMemory = memoryLocks.get(id);
          if (inMemory) return inMemory;
        }

        let storageReadFailed = false;
        for (const id of ids) {
          try {
            const raw = await ctx.storage.get(storageKey(id));
            const lock = parseStoredLock(raw);
            if (lock) {
              memoryLocks.set(id, lock);
              memoryLocks.set(sessionID, lock);
              return lock;
            }
          } catch {
            storageReadFailed = true;
          }
        }

        if (storageReadFailed) {
          return {
            confidential: true,
            reason: "session lock storage could not be read",
            markedAt: now(),
          };
        }
        return undefined;
      }

      async function persistLock(
        chain: SessionChain,
        sessionID: string,
        reason: string,
      ): Promise<ConfidentialLock> {
        const lock: ConfidentialLock = {
          confidential: true,
          reason,
          markedAt: now(),
        };
        const ids = new Set<string>([sessionID, chain.rootSessionID]);
        for (const ancestor of chain.ancestors) ids.add(ancestor.id);

        for (const id of ids) {
          memoryLocks.set(id, lock);
        }

        await Promise.all(
          [...ids].map((id) => ctx.storage.set(storageKey(id), lock)),
        );
        return lock;
      }

      async function switchToDuo(
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

      async function lockAndSwitch(
        chain: SessionChain,
        sessionID: string,
        reason: string,
        currentAgent?: string,
        currentModel?: ModelRef,
      ): Promise<LockSwitchResult> {
        await persistLock(chain, sessionID, reason);

        const targetModel = duoModelForAgent(
          currentAgent ?? chain.session?.agent,
          chain.inheritedDuoModel,
          duoModels,
        );

        const activeModel = currentModel ?? chain.session?.model;
        const switched = isDuoModel(activeModel)
          ? true
          : await switchToDuo(sessionID, targetModel);

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
            await switchToDuo(
              relatedID,
              duoModelForAgent(relatedSession?.agent, undefined, duoModels),
            );
          }
        }

        return { targetModel, switched };
      }

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
      ): Promise<string | undefined> {
        if (!ctx.session.instructions?.entry?.list) return undefined;
        try {
          const entries = await ctx.session.instructions.entry.list({
            sessionID,
          });
          const targetText = extractTargetsFromInstructions(entries);
          if (!targetText) return undefined;
          const refs = extractGitLabRefs(targetText, defaultProject);
          return checker.checkRefs(refs);
        } catch {
          return "session target instructions could not be read";
        }
      }

      async function detectConfidentialForSession(
        chain: SessionChain,
        sessionID: string,
        extraText?: string,
      ): Promise<string | undefined> {
        const stored = await getStoredLock(chain, sessionID);
        if (stored) return stored.reason;

        const { analysis, branch } = await inspectRepo(chain.session);
        if (analysis.confidentialReason) return analysis.confidentialReason;

        if (extraText) {
          const promptRefs = extractGitLabRefs(
            extraText,
            analysis.defaultProject,
          );
          const promptReason = await checker.checkRefs(promptRefs);
          if (promptReason) return promptReason;
        }

        const targetReason = await inspectTargetInstructions(
          sessionID,
          analysis.defaultProject,
        );
        if (targetReason) return targetReason;

        if (chain.ownerSessionID) {
          const ownerTargetReason = await inspectTargetInstructions(
            chain.ownerSessionID,
            analysis.defaultProject,
          );
          if (ownerTargetReason) return ownerTargetReason;
        }

        if (analysis.defaultProject && branch) {
          if (/^(?:.*\/)?security-/i.test(branch)) {
            return `security branch "${branch}"`;
          }
          const branchIid = extractBranchIssueIid(branch);
          if (branchIid) {
            const branchReason = await checker.checkRefs([
              { kind: "issue", path: analysis.defaultProject, iid: branchIid },
            ]);
            if (branchReason) return `branch "${branch}" (${branchReason})`;
          }
        }

        return undefined;
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
            reason,
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
        let reason = checkToolCallBefore(event.tool, event.input)?.reason;

        if (!reason) {
          const { analysis } = await inspectRepo(chain.session);
          const inputRefs = extractToolInputRefs(
            event.tool,
            event.input,
            analysis.defaultProject,
          );
          if (inputRefs.length > 0) {
            reason = await checker.checkRefs(inputRefs);
          }
        }

        if (!reason) return;

        const { targetModel, switched } = await lockAndSwitch(
          chain,
          event.sessionID,
          reason,
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
          const reason = await checker.checkRefs(refs);
          if (!reason) return;

          const alreadyOnDuo = isSessionTurnOnDuo(event.sessionID, chain);
          const { targetModel, switched } = await lockAndSwitch(
            chain,
            event.sessionID,
            reason,
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

        const { targetModel, switched } = await lockAndSwitch(
          chain,
          event.sessionID,
          reason,
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
        },
        isPrimaryTurn: boolean,
      ) => {
        if (isDuoModel(event.model)) {
          if (isPrimaryTurn && !event.transient) {
            activeTurnModel.set(event.sessionID, event.model);
          }
          return;
        }

        const chain = await resolveChain(event.sessionID);
        if (!ownsSession(chain.session)) return;

        const reason = await detectConfidentialForSession(
          chain,
          event.sessionID,
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
          reason,
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

      await ctx.session.hook("context", (event) => guardRequest(event, true));
      await ctx.session.hook("generate", (event) =>
        guardRequest(event, !event.transient),
      );
      await ctx.session.hook("compaction", (event) =>
        guardRequest(event, false),
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
        );
        if (!reason) return;

        await persistLock(chain, event.sessionID, reason);
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
    },
  } satisfies Plugin.Plugin;
}

export default createPlugin();
