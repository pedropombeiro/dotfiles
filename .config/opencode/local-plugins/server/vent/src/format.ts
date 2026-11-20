import type { VentInput, VentMetadata } from './destinations/types.ts';

function formatMetadataBlock(metadata: VentMetadata): string {
  const rows: string[] = [
    `- **Recorded**: ${metadata.timestamp}`,
    ...(metadata.category ? [`- **Category**: \`${metadata.category}\``] : []),
    `- **Directory**: \`${metadata.directory}\``,
    ...(metadata.remote ? [`- **Repository**: \`${metadata.remote}\``] : []),
    ...(metadata.branch ? [`- **Branch**: \`${metadata.branch}\``] : []),
    `- **Session**: \`${metadata.sessionID}\``,
  ];

  return ['<details>', '<summary>Session metadata</summary>', '', ...rows, '', '</details>'].join(
    '\n',
  );
}

export function formatIssueBody(input: VentInput, metadata: VentMetadata): string {
  const sections: string[] = [
    '## Friction',
    '',
    input.friction.trim(),
    '',
    '## Context',
    '',
    input.context.trim(),
  ];

  if (input.evidence?.trim()) {
    sections.push('', '## Evidence / Reproduction', '', input.evidence.trim());
  }

  if (input.suggestion?.trim()) {
    sections.push('', '## Suggested Improvement', '', input.suggestion.trim());
  }

  sections.push('', formatMetadataBlock(metadata));
  return sections.join('\n');
}

export function formatCommentBody(input: VentInput, metadata: VentMetadata): string {
  const sections: string[] = [
    `Additional occurrence reported on ${metadata.date}.`,
    '',
    '### Friction',
    '',
    input.friction.trim(),
    '',
    '### Context',
    '',
    input.context.trim(),
  ];

  if (input.evidence?.trim()) {
    sections.push('', '### Evidence / Reproduction', '', input.evidence.trim());
  }

  if (input.suggestion?.trim()) {
    sections.push('', '### Suggested Improvement', '', input.suggestion.trim());
  }

  sections.push('', formatMetadataBlock(metadata));
  return sections.join('\n');
}

export function formatFileSection(input: VentInput, metadata: VentMetadata): string {
  const sections: string[] = [
    `## ${input.title.trim()}`,
    '',
    '### Friction',
    '',
    input.friction.trim(),
    '',
    '### Context',
    '',
    input.context.trim(),
  ];

  if (input.evidence?.trim()) {
    sections.push('', '### Evidence / Reproduction', '', input.evidence.trim());
  }

  if (input.suggestion?.trim()) {
    sections.push('', '### Suggested Improvement', '', input.suggestion.trim());
  }

  sections.push('', formatMetadataBlock(metadata));
  return sections.join('\n');
}

export function formatFileOccurrence(input: VentInput, metadata: VentMetadata): string {
  const sections: string[] = [
    `### Occurrence (${metadata.date})`,
    '',
    input.friction.trim(),
    '',
    `**Context**: ${input.context.trim()}`,
  ];

  if (input.evidence?.trim()) {
    sections.push('', `**Evidence**: ${input.evidence.trim()}`);
  }

  if (input.suggestion?.trim()) {
    sections.push('', `**Suggested improvement**: ${input.suggestion.trim()}`);
  }

  sections.push('', formatMetadataBlock(metadata));
  return sections.join('\n');
}
