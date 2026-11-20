import { mkdir, readFile, writeFile } from 'node:fs/promises';
import { dirname } from 'node:path';
import { formatFileOccurrence, formatFileSection } from '../format.ts';
import { buildMatchQuery, findBestMatch } from '../match.ts';
import { expandHome, type FileDestination } from '../options.ts';
import type { VentInput, VentMetadata, VentResult } from './types.ts';

export interface MarkdownSection {
  id: string;
  title: string;
  body: string;
  startLine: number;
  endLine: number;
}

const DEFAULT_HEADER = '# Agent vents\n';

const fileLocks = new Map<string, Promise<unknown>>();

function withFileLock<T>(filePath: string, task: () => Promise<T>): Promise<T> {
  const previous = fileLocks.get(filePath) ?? Promise.resolve();
  const next = previous.then(task, task);
  const cleanup = next.then(
    () => {
      if (fileLocks.get(filePath) === cleanup) fileLocks.delete(filePath);
    },
    () => {
      if (fileLocks.get(filePath) === cleanup) fileLocks.delete(filePath);
    },
  );
  fileLocks.set(filePath, cleanup);
  return next;
}

export function parseMarkdownSections(content: string): MarkdownSection[] {
  const lines = content.replace(/\r\n/g, '\n').split('\n');
  const sections: MarkdownSection[] = [];
  let fenceChar: string | undefined;

  let currentStart = -1;
  let currentTitle = '';

  const closeCurrent = (endLine: number) => {
    if (currentStart < 0) return;
    sections.push({
      id: `line:${currentStart + 1}`,
      title: currentTitle,
      body: lines
        .slice(currentStart + 1, endLine)
        .join('\n')
        .trim(),
      startLine: currentStart,
      endLine,
    });
    currentStart = -1;
    currentTitle = '';
  };

  for (let i = 0; i < lines.length; i += 1) {
    const line = lines[i]!;
    const trimmed = line.trimStart();

    if (fenceChar) {
      if (trimmed.startsWith(fenceChar.repeat(3))) {
        fenceChar = undefined;
      }
      continue;
    }

    if (trimmed.startsWith('```')) {
      fenceChar = '`';
      continue;
    }
    if (trimmed.startsWith('~~~')) {
      fenceChar = '~';
      continue;
    }

    const headingMatch = line.match(/^##\s+(.+?)\s*$/);
    if (headingMatch) {
      closeCurrent(i);
      currentStart = i;
      currentTitle = headingMatch[1]!;
    }
  }

  closeCurrent(lines.length);
  return sections;
}

export function ventToFile(
  destinationName: string,
  destination: FileDestination,
  input: VentInput,
  metadata: VentMetadata,
  deps: { threshold: number; home?: string },
): Promise<VentResult> {
  const resolvedPath = expandHome(destination.path, deps.home);

  return withFileLock(resolvedPath, async () => {
    let existing: string;
    try {
      existing = (await readFile(resolvedPath, 'utf8')).replace(/\r\n/g, '\n');
    } catch (error) {
      const code = (error as NodeJS.ErrnoException).code;
      if (code !== 'ENOENT') throw error;
      existing = DEFAULT_HEADER;
    }

    const sections = parseMarkdownSections(existing);
    const match = findBestMatch(buildMatchQuery(input), sections, deps.threshold);

    let updated: string;
    if (match) {
      const section = match.item;
      const lines = existing.split('\n');
      let insertAt = section.endLine;
      while (insertAt > section.startLine + 1 && lines[insertAt - 1]?.trim() === '') {
        insertAt -= 1;
      }

      const occurrenceLines = ['', ...formatFileOccurrence(input, metadata).split('\n')];
      const hasFollowingSection = section.endLine < lines.length;
      if (hasFollowingSection) {
        occurrenceLines.push('');
      }

      const nextLines = [
        ...lines.slice(0, insertAt),
        ...occurrenceLines,
        ...lines.slice(section.endLine),
      ];
      updated = `${nextLines.join('\n').replace(/\n+$/, '')}\n`;

      await mkdir(dirname(resolvedPath), { recursive: true });
      await writeFile(resolvedPath, updated, 'utf8');

      return {
        action: 'commented',
        destination: destinationName,
        destinationType: 'file',
        path: resolvedPath,
        title: input.title,
        matchedTitle: section.title,
        matchScore: Number(match.score.toFixed(2)),
      };
    }

    const base = existing.trimEnd();
    const prefix = base ? `${base}\n\n` : `${DEFAULT_HEADER}\n`;
    updated = `${prefix}${formatFileSection(input, metadata)}\n`;

    await mkdir(dirname(resolvedPath), { recursive: true });
    await writeFile(resolvedPath, updated, 'utf8');

    return {
      action: 'created',
      destination: destinationName,
      destinationType: 'file',
      path: resolvedPath,
      title: input.title,
    };
  });
}
