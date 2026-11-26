export const VENT_CATEGORIES = [
  "tooling",
  "documentation",
  "skill",
  "permissions",
  "environment",
  "workflow",
  "other",
] as const;

export type VentCategory = (typeof VENT_CATEGORIES)[number];

export interface VentInput {
  title: string;
  friction: string;
  context: string;
  evidence?: string;
  suggestion?: string;
  category?: VentCategory;
  labels?: string[];
  destination?: string;
  unrelatedReason?: string;
  /**
   * How to proceed after a result reported a similar closed item: `reopen` reopens it and
   * adds this occurrence, `create` files a new item that links it.
   */
  onClosedMatch?: "reopen" | "create";
}

export interface VentMetadata {
  date: string;
  timestamp: string;
  directory: string;
  remote?: string;
  branch?: string;
  sessionID: string;
  category?: VentCategory;
}

export interface VentResult {
  action: "created" | "commented" | "reopened" | "closed-match";
  destination: string;
  destinationType: "gitlab" | "github" | "file";
  url?: string;
  path?: string;
  title: string;
  matchedTitle?: string;
  matchScore?: number;
  /** Labels of the closed item that matched, when `action` is `closed-match`. */
  closedLabels?: string[];
  note?: string;
}
