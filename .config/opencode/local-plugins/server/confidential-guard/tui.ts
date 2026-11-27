import { Plugin } from "@opencode/plugin/tui";
import { ConfidentialGuardRpc } from "./rpc.ts";
import type { StatusFinding } from "./src/findings.ts";
import type { ConfidentialityAssessment } from "./src/guard.ts";

const title = "Confidentiality status";

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
                  for (;;) {
                    const { findings } = (await rpc.status(
                      { sessionID },
                      { location },
                    )) as { findings: StatusFinding[] };
                    const locked = findings.some(({ dismissed }) => !dismissed);
                    if (findings.length === 0) {
                      await context.ui.dialog.alert({
                        title,
                        message:
                          "No recorded lock. The guard still checks the next request.",
                      });
                      return;
                    }
                    const selected = await context.ui.dialog.select({
                      title: locked
                        ? "GitLab Duo required"
                        : "No active lock. Use /models to change models.",
                      options: findings.map((finding) => ({
                        title: `${finding.source}${finding.inherited ? " (inherited)" : ""}${finding.dismissed ? " (dismissed)" : ""}: ${finding.reason}`,
                        description:
                          finding.source === "legacy"
                            ? "History incomplete. Review the whole session before clearing this lock."
                            : undefined,
                        value: finding.id,
                      })),
                    });
                    if (!selected) return;
                    const finding = findings.find(({ id }) => id === selected);
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
                    if (actions.length === 0) continue;
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
