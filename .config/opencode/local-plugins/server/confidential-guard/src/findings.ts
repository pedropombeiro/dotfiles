import type { GitLabRef } from "./guard.ts";

export type FindingSource =
  | "prompt"
  | "checkout"
  | "branch"
  | "target"
  | "tool input"
  | "tool output"
  | "legacy"
  | "storage";

export interface Observation {
  source: FindingSource;
  reason: string;
  ref?: GitLabRef;
}

export interface Finding extends Observation {
  id: string;
  origin: string;
  markedAt: number;
  dismissedAt?: number;
}

export interface StatusFinding {
  id: string;
  source: FindingSource;
  reason: string;
  markedAt: number;
  inherited: boolean;
  dismissed: boolean;
  canDismiss: boolean;
  canRecheck: boolean;
}

export function findingKey({ source, reason, ref }: Observation): string {
  return JSON.stringify(
    ref
      ? [source, ref.kind, ref.path.toLowerCase(), ref.iid]
      : [source, reason],
  );
}

export const canRecheck = (finding: Finding) =>
  !!finding.ref &&
  finding.ref.kind !== "project" &&
  finding.ref.kind !== "overflow";

export interface StoredFindings {
  findings: Finding[];
  compactionID?: string;
}

export function parseStoredFindings(
  raw: unknown,
  sessionID: string,
): StoredFindings {
  if (raw === undefined) return { findings: [] };
  if (raw && typeof raw === "object") {
    const record = raw as {
      version?: unknown;
      findings?: unknown;
      compactionID?: unknown;
      confidential?: unknown;
      reason?: unknown;
      markedAt?: unknown;
    };
    if (record.version === 1 && Array.isArray(record.findings)) {
      if (
        record.findings.every(
          (f) =>
            f &&
            typeof f.id === "string" &&
            typeof f.origin === "string" &&
            typeof f.reason === "string" &&
            typeof f.source === "string" &&
            typeof f.markedAt === "number",
        )
      ) {
        return {
          findings: record.findings,
          ...(typeof record.compactionID === "string" &&
            record.compactionID && { compactionID: record.compactionID }),
        };
      }
    }
    if (record.confidential === true && typeof record.reason === "string") {
      return {
        findings: [
          {
            id: `legacy:${sessionID}`,
            origin: sessionID,
            source: "legacy",
            reason: record.reason,
            markedAt: typeof record.markedAt === "number" ? record.markedAt : 0,
          },
        ],
      };
    }
  }
  throw new Error("Unexpected confidentiality lock record");
}
