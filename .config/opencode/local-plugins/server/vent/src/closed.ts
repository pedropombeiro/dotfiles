/**
 * Handling for a vent that matches an item that was already closed. The tool never writes
 * to a closed item on its own. It reports the match, and the agent asks the user and calls
 * `vent` again with `onClosedMatch`.
 */

/** Labels that don't describe how the item was resolved, so they stay when it reopens. */
export function withoutResolutionLabels(
  labels: readonly string[],
  prefix: string | undefined,
): string[] {
  return prefix ? labels.filter((label) => !label.startsWith(prefix)) : [...labels];
}

/** The advice returned with a closed match, based on how the item was resolved. */
export function describeClosedMatch(
  labels: readonly string[],
  reopenLabels: readonly string[] | undefined,
): string {
  const labelText = labels.length > 0 ? ` Labels: ${labels.join(", ")}.` : "";
  const intro = `No issue or comment was created.${labelText}`;
  const ask = "Ask the user before calling `vent` again";

  if (!reopenLabels || reopenLabels.length === 0) {
    return (
      `${intro} ${ask} with \`onClosedMatch: "reopen"\` (reopen it and add this occurrence) ` +
      `or \`"create"\` (file a new item that links the closed one).`
    );
  }
  if (labels.some((label) => reopenLabels.includes(label))) {
    return (
      `${intro} It was closed without a confirmed fix, so this occurrence is new evidence. ` +
      `${ask} with \`onClosedMatch: "reopen"\`.`
    );
  }
  return (
    `${intro} It was closed with a resolution, so a recurrence is likely a regression. ` +
    `${ask} with \`onClosedMatch: "create"\` to file a new item that links it.`
  );
}

export function relatedToClosed(url: string): string {
  return `Related to the closed issue ${url}.`;
}
