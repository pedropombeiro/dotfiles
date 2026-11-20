import type { Exec } from '../exec.ts';
import { formatCommentBody, formatIssueBody } from '../format.ts';
import { buildMatchQuery, findBestMatch } from '../match.ts';
import type { GitHubDestination } from '../options.ts';
import type { VentInput, VentMetadata, VentResult } from './types.ts';

interface GitHubIssue {
  number: number;
  title: string;
  body?: string | null;
  html_url: string;
  pull_request?: unknown;
}

interface GitHubComment {
  html_url?: string;
}

function mergeLabels(base: readonly string[], extra: readonly string[] | undefined): string[] {
  const seen = new Set<string>();
  const merged: string[] = [];
  for (const label of [...base, ...(extra ?? [])]) {
    const trimmed = label.trim();
    if (!trimmed || seen.has(trimmed)) continue;
    seen.add(trimmed);
    merged.push(trimmed);
  }
  return merged;
}

async function ghApi<T>(
  run: Exec,
  host: string,
  endpoint: string,
  options: {
    method?: 'GET' | 'POST';
    body?: Record<string, unknown>;
    cwd: string;
    signal?: AbortSignal;
  },
): Promise<T> {
  const args = ['api', '--hostname', host];
  if (options.method && options.method !== 'GET') {
    args.push('--method', options.method);
  }
  let stdin: string | undefined;
  if (options.body !== undefined) {
    args.push('--input', '-');
    stdin = JSON.stringify(options.body);
  }
  args.push(endpoint);

  const result = await run('gh', args, {
    cwd: options.cwd,
    stdin,
    signal: options.signal,
  });

  if (result.code !== 0) {
    const detail = (result.stderr || result.stdout).trim();
    throw new Error(`gh api ${options.method ?? 'GET'} ${endpoint} failed: ${detail}`);
  }

  const trimmed = result.stdout.trim();
  if (!trimmed) return {} as T;
  return JSON.parse(trimmed) as T;
}

export async function ventToGitHub(
  destinationName: string,
  destination: GitHubDestination,
  input: VentInput,
  metadata: VentMetadata,
  deps: { exec: Exec; threshold: number; signal?: AbortSignal },
): Promise<VentResult> {
  const labelFilter =
    destination.labels.length > 0
      ? `&labels=${encodeURIComponent(destination.labels.join(','))}`
      : '';
  const issues = await ghApi<GitHubIssue[]>(
    deps.exec,
    destination.host,
    `repos/${destination.repo}/issues?state=open&per_page=100${labelFilter}`,
    {
      cwd: metadata.directory,
      signal: deps.signal,
    },
  );

  const openCandidates = (Array.isArray(issues) ? issues : [])
    .filter((issue) => !issue.pull_request)
    .map((issue) => ({
      id: `#${issue.number}`,
      title: issue.title,
      body: issue.body ?? '',
      issue,
    }));

  const match = findBestMatch(buildMatchQuery(input), openCandidates, deps.threshold);

  if (match) {
    const matchedIssue = match.item.issue;
    const comment = await ghApi<GitHubComment>(
      deps.exec,
      destination.host,
      `repos/${destination.repo}/issues/${matchedIssue.number}/comments`,
      {
        method: 'POST',
        body: { body: formatCommentBody(input, metadata) },
        cwd: metadata.directory,
        signal: deps.signal,
      },
    );

    return {
      action: 'commented',
      destination: destinationName,
      destinationType: 'github',
      url: comment.html_url ?? matchedIssue.html_url,
      title: input.title,
      matchedTitle: matchedIssue.title,
      matchScore: Number(match.score.toFixed(2)),
    };
  }

  const labels = mergeLabels(destination.labels, input.labels);
  const created = await ghApi<GitHubIssue>(
    deps.exec,
    destination.host,
    `repos/${destination.repo}/issues`,
    {
      method: 'POST',
      body: {
        title: input.title.trim(),
        body: formatIssueBody(input, metadata),
        ...(labels.length > 0 ? { labels } : {}),
      },
      cwd: metadata.directory,
      signal: deps.signal,
    },
  );

  return {
    action: 'created',
    destination: destinationName,
    destinationType: 'github',
    url: created.html_url,
    title: input.title,
  };
}
