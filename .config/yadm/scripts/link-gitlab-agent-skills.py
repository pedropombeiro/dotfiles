#!/usr/bin/env python3
"""Link public skills without copying checkout content back into their source."""

import argparse
import os
from pathlib import Path
import subprocess


HOME = Path.home()
SOURCE = HOME / "Developer/gitlab.com/pedropombeiro/gitlab-agent-skills"
PRIVATE = HOME / ".config/dotfiles/gitlab/.opencode/skills"
SKILLS = ("issue-state", "mr-pipeline", "second-brain-context")


def link_skill(worktree, name):
    source = SOURCE / "skills" / name
    target = worktree / ".opencode/skills" / name
    if not source.is_dir():
        raise RuntimeError(f"Missing skill source: {source}")
    if target.is_symlink():
        if target.resolve() == source.resolve():
            return
        if target.resolve() != (PRIVATE / name).resolve():
            raise RuntimeError(f"Unexpected symlink: {target}")
        target.unlink()
    elif target.exists():
        # Only migrate the known per-file links installed by the private sync.
        entries = list(target.rglob("*"))
        for entry in entries:
            if entry.is_symlink():
                expected = PRIVATE / name / entry.relative_to(target)
                if entry.resolve() != expected.resolve():
                    raise RuntimeError(f"Unexpected symlink: {entry}")
            elif not entry.is_dir():
                raise RuntimeError(f"Preserving unexpected local file: {entry}")
        for entry in sorted(entries, key=lambda path: len(path.parts), reverse=True):
            if entry.is_symlink():
                entry.unlink()
            else:
                entry.rmdir()
        target.rmdir()
    target.parent.mkdir(parents=True, exist_ok=True)
    target.symlink_to(source, target_is_directory=True)


def link_worktree(worktree):
    exclude = subprocess.check_output(
        ["git", "rev-parse", "--path-format=absolute", "--git-path", "info/exclude"],
        cwd=worktree, text=True,
    ).strip()
    exclude = Path(exclude)
    exclude.parent.mkdir(parents=True, exist_ok=True)
    existing = exclude.read_text() if exclude.exists() else ""
    for name in SKILLS:
        link_skill(worktree, name)
        rule = f"/.opencode/skills/{name}"
        if rule not in existing.splitlines():
            existing = existing.rstrip("\n") + "\n" + rule + "\n"
    exclude.write_text(existing)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--worktree", type=Path)
    args = parser.parse_args()
    if args.worktree:
        link_worktree(args.worktree.resolve())
        return
    if not SOURCE.is_dir():
        print(f"Public skills checkout missing; skipping: {SOURCE}")
        return
    root = Path(os.environ.get("GDK_ROOT", str(HOME / "gitlab-development-kit")))
    main_checkout = root / "gitlab"
    if (main_checkout / ".git").exists():
        output = subprocess.check_output(
            ["git", "worktree", "list", "--porcelain"], cwd=main_checkout, text=True,
        )
        for line in output.splitlines():
            if line.startswith("worktree "):
                link_worktree(Path(line.removeprefix("worktree ")))
    for name in ("wait_for_mr_merge", "run_mr_pipeline"):
        target = HOME / ".local/bin" / name
        source = SOURCE / "skills/mr-pipeline/scripts" / name
        legacy = HOME / ".local/bin" / f"{name}##class.Work"
        if target.is_symlink() and target.resolve() in (source.resolve(), legacy.resolve()):
            target.unlink()
        elif target.exists() or target.is_symlink():
            raise RuntimeError(f"Preserving unexpected command: {target}")
        target.parent.mkdir(parents=True, exist_ok=True)
        target.symlink_to(source)


if __name__ == "__main__":
    main()
