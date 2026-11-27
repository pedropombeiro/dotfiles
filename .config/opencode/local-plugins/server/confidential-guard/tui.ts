import { Plugin } from "@opencode/plugin/tui";
import { ConfidentialGuardRpc } from "./rpc.ts";
import type { StatusFinding } from "./src/findings.ts";
import type { ConfidentialityAssessment } from "./src/guard.ts";

const title = "Confidentiality status";

function findingOrigin(finding: StatusFinding) {
  return `${finding.inherited ? "Inherited" : "This session"} · ${finding.source}`;
}

export default Plugin.define({
  id: "confidential-guard-cli",
  setup(context) {
    return context.ui.slot({
      append: "app",
      render: () => {
        context.keymap.layer(() => ({
          mode: "global",
          commands: [
            {
              id: "confidential-guard.status",
              title,
              palette: true,
              slash: { name: "confidential-status" },
              async run() {
                const route = context.ui.router.current();
                if (route.type !== "session") {
                  context.ui.toast.show({ message: "Open a session first." });
                  return;
                }
                const sessionID = route.sessionID;
                const location =
                  context.location ?? context.data.location.default();
                const rpc = context.client.rpc(ConfidentialGuardRpc);
                try {
                  const { findings } = (await rpc.status(
                    { sessionID },
                    { location },
                  )) as { findings: StatusFinding[] };
                  const groups = new Map<string, StatusFinding[]>();
                  const dismissed = findings.filter(
                    (finding) => finding.dismissed,
                  );
                  for (const finding of findings) {
                    if (finding.dismissed) continue;
                    const group = groups.get(finding.reason);
                    if (group) group.push(finding);
                    else groups.set(finding.reason, [finding]);
                  }
                  if (findings.length === 0) {
                    await context.ui.dialog.alert({
                      title,
                      message:
                        "No recorded lock. The guard still checks the next request.",
                    });
                    return;
                  }
                  const reasonGroups = [...groups.entries()];
                  const selected = await context.ui.dialog.select({
                    title:
                      groups.size > 0
                        ? `GitLab Duo required · ${groups.size} active ${groups.size === 1 ? "reason" : "reasons"}`
                        : "No active confidentiality lock",
                    options: [
                      ...reasonGroups.map(([reason, records], index) => ({
                        title: reason,
                        description: `${records.length} ${records.length === 1 ? "finding" : "findings"} · ${[...new Set(records.map(findingOrigin))].join(", ")}`,
                        value: String(index),
                      })),
                      ...(dismissed.length > 0
                        ? [
                            {
                              title: `Dismissed findings (${dismissed.length})`,
                              description:
                                "These findings do not require GitLab Duo.",
                              value: "dismissed",
                            },
                          ]
                        : []),
                    ],
                  });
                  if (selected === undefined) return;
                  const records =
                    selected === "dismissed"
                      ? dismissed
                      : reasonGroups[Number(selected)]?.[1];
                  if (!records?.length) return;
                  const groupTitle =
                    selected === "dismissed"
                      ? "Dismissed findings"
                      : records[0].reason;
                  const findingOption = (finding: StatusFinding) => ({
                    title: finding.dismissed
                      ? finding.reason
                      : findingOrigin(finding),
                    description: [
                      finding.canDismiss
                        ? "Can request dismissal"
                        : finding.canRecheck
                          ? "Recheck only"
                          : "Read-only",
                      finding.markedAt > 0
                        ? new Date(finding.markedAt).toLocaleString()
                        : "Time not recorded",
                    ].join(" · "),
                    value: finding.id,
                  });
                  const dismissible = records.filter(
                    ({ canDismiss }) => canDismiss,
                  );
                  const recheckOnly = records.filter(
                    ({ canDismiss, canRecheck }) => !canDismiss && canRecheck,
                  );
                  const readOnly =
                    records.length - dismissible.length - recheckOnly.length;
                  const summary = `${dismissible.length} can request dismissal · ${recheckOnly.length} recheck only · ${readOnly} read-only`;
                  const bulkCandidates = dismissible.filter(
                    ({ source, canRecheck }) =>
                      source === "prompt" && canRecheck,
                  );
                  const dismissGroup = "dismiss-group";
                  const showAll = "show-all-findings";
                  let findingID =
                    records.length === 1
                      ? records[0].id
                      : await context.ui.dialog.select({
                          title: groupTitle,
                          options: [
                            ...(bulkCandidates.length > 1
                              ? [
                                  {
                                    title: `Review ${bulkCandidates.length} prompt findings for dismissal`,
                                    description:
                                      "Confirm once. GitLab must verify each item is public.",
                                    value: dismissGroup,
                                  },
                                ]
                              : []),
                            ...dismissible.map(findingOption),
                            {
                              title: `View all ${records.length} findings`,
                              description: summary,
                              value: showAll,
                            },
                          ],
                        });
                  if (findingID === dismissGroup) {
                    const confirmed = await context.ui.dialog.confirm({
                      title: `Request dismissal of ${bulkCandidates.length} prompt findings?`,
                      message: `${groupTitle}\n\nOnly continue if you reviewed this group and the references were incidental. The conversation, including tool results, must be safe to send to another provider.`,
                      label: {
                        confirm: "Request dismissal",
                        cancel: "Keep findings",
                      },
                    });
                    if (!confirmed) return;

                    let dismissedCount = 0;
                    const errors = new Set<string>();
                    for (const { id } of bulkCandidates) {
                      try {
                        await rpc.dismissPromptFinding(
                          { sessionID, findingID: id },
                          { location },
                        );
                        dismissedCount++;
                      } catch (error) {
                        errors.add(
                          error instanceof Error
                            ? error.message
                            : "Dismissal failed.",
                        );
                      }
                    }
                    await context.ui.dialog.alert({
                      title: "Group dismissal result",
                      message: [
                        `Dismissed ${dismissedCount} of ${bulkCandidates.length} selected findings.`,
                        ...errors,
                      ].join("\n\n"),
                    });
                    return;
                  }
                  if (findingID === showAll) {
                    findingID = await context.ui.dialog.select({
                      title: groupTitle,
                      options: records.map(findingOption),
                    });
                  }
                  const finding = records.find(({ id }) => id === findingID);
                  if (!finding) return;
                  const request = { sessionID, findingID: finding.id };
                  const actions = [
                    ...(finding.canRecheck
                      ? [{ title: "Recheck GitLab", value: "recheck" }]
                      : []),
                    ...(finding.canDismiss
                      ? [
                          {
                            title:
                              finding.source === "legacy"
                                ? "Clear legacy lock after reviewing session"
                                : "Mark as false positive",
                            value: "dismiss",
                          },
                        ]
                      : []),
                  ];
                  if (actions.length === 0) {
                    await context.ui.dialog.alert({
                      title: finding.dismissed
                        ? "Dismissed finding"
                        : "Active confidentiality finding",
                      message: `${finding.reason}\n\n${findingOrigin(finding)}. ${finding.dismissed ? "This finding no longer contributes to the lock." : "This finding contributes to the lock and cannot be changed here."}`,
                    });
                    return;
                  }
                  const action = await context.ui.dialog.select({
                    title: finding.reason,
                    options: actions,
                  });
                  if (action === "recheck") {
                    const result = (await rpc.recheck(request, {
                      location,
                    })) as ConfidentialityAssessment;
                    await context.ui.dialog.alert({
                      title,
                      message:
                        `GitLab assessment: ${result.status}. ${result.reason ?? ""}`.trim(),
                    });
                  } else if (
                    action === "dismiss" &&
                    (await context.ui.dialog.confirm({
                      title:
                        finding.source === "legacy"
                          ? "Clear this legacy lock?"
                          : "Mark this finding as a false positive?",
                      message:
                        finding.source === "legacy"
                          ? "The old guard only saved one reason. Confirm that you reviewed the entire session, including tool results, and it is safe to share with another provider."
                          : "Only continue if this reference was incidental and the conversation does not contain confidential material about it. Existing history can be sent to the next model.",
                      label: {
                        confirm: "Dismiss finding",
                        cancel: "Keep lock",
                      },
                    }))
                  ) {
                    await rpc.dismissPromptFinding(request, { location });
                  }
                } catch (error) {
                  await context.ui.dialog.alert({
                    title,
                    message:
                      error instanceof Error
                        ? error.message
                        : "Could not read confidentiality status.",
                  });
                }
              },
            },
          ],
        }));
        return null;
      },
    });
  },
});
