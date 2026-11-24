#!/usr/bin/env python3
"""Bounded GDK workload supervisor. Manifests and commands are operator-owned."""

import argparse
import contextlib
import fcntl
import hashlib
import json
import os
import re
import signal
import subprocess
import sys
from pathlib import Path


def require(condition, message):
    if not condition:
        raise ValueError(message)


def git(*args):
    return subprocess.check_output(["git", *args])


def text(*args):
    return git(*args).decode().strip()


def digest(path):
    with path.open("rb") as stream:
        return hashlib.file_digest(stream, "sha256").hexdigest()


def write(path, data):
    temp = path.with_suffix(path.suffix + ".next")
    with temp.open("wb") as stream:
        stream.write(data)
        stream.flush()
        os.fsync(stream.fileno())
    temp.replace(path)
    fd = os.open(path.parent, os.O_RDONLY)
    try:
        os.fsync(fd)
    finally:
        os.close(fd)


def command(step, out, env):
    name = step["name"]
    require(re.fullmatch(r"[a-z][a-z0-9_-]*", name), "Invalid step name")
    limit = step["seconds"]
    require(type(limit) is int and limit > 0, f"Invalid timeout: {name}")
    argv = step["argv"]
    require(
        isinstance(argv, list) and argv and all(isinstance(x, str) for x in argv),
        f"Expected argv list: {name}",
    )
    with (
        (out / f"{name}.stdout").open("wb") as stdout,
        (out / f"{name}.stderr").open("wb") as stderr,
        subprocess.Popen(
            argv,
            env=env,
            stdin=subprocess.DEVNULL,
            stdout=stdout,
            stderr=stderr,
            start_new_session=True,
        ) as child,
    ):
        try:
            rc = child.wait(timeout=limit)
        except subprocess.TimeoutExpired:
            with contextlib.suppress(ProcessLookupError):
                os.killpg(child.pid, signal.SIGKILL)
            child.wait()
            rc = 124
    write(out / f"{name}.exit", f"{rc}\n".encode())
    return rc


def image_check(image, out, env):
    require(
        re.fullmatch(r"[^\s@]+@sha256:[a-f0-9]{64}", image),
        "Image must be digest-pinned",
    )
    step = {
        "name": "image",
        "argv": ["crane", "config", "--platform", "linux/amd64", image],
        "seconds": 30,
    }
    require(
        command(step, out, env) == 0,
        f"Pinned image unavailable: {image} (linux/amd64); see image.stderr",
    )
    config = json.loads((out / "image.stdout").read_bytes())
    require(
        (config.get("os"), config.get("architecture")) == ("linux", "amd64"),
        f"Pinned image platform mismatch: {image}; expected linux/amd64",
    )


def restore(base, patch, sha, tree):
    require(
        re.fullmatch(r"[0-9a-f]{40}", base) and text("rev-parse", "HEAD") == base,
        "Wrong checkout base",
    )
    require(not git("status", "--porcelain", "-z"), "Checkout must start clean")
    require(digest(patch) == sha, "Patch digest mismatch")
    git("apply", "--check", "--index", "--whitespace=nowarn", str(patch))
    git("apply", "--index", "--whitespace=nowarn", str(patch))
    require(text("write-tree") == tree, "Restored tree mismatch")


def preflight(spec, out, env, clean_env):
    config = json.loads(env.get("OPENCODE_CONFIG_CONTENT", "{}"))
    require(
        not config.get("agents"), "Use a standalone job policy without agent overrides"
    )
    rules = config.get("permissions", [])
    require(
        rules and rules[0] == {"action": "*", "resource": "*", "effect": "deny"},
        "Expected a default-deny job policy in OPENCODE_CONFIG_CONTENT",
    )
    edits = [rule for rule in rules[1:] if rule["action"] in {"edit", "*"}]
    require(
        all(rule["action"] == "edit" and rule["effect"] == "allow" for rule in edits)
        and {rule["resource"] for rule in edits} == set(spec["edit_paths"])
        and all(not re.search(r"[*?]", rule["resource"]) for rule in edits),
        "OpenCode edit allowlist does not match the manifest",
    )
    for path in spec["required_files"]:
        require(
            Path(path).is_file(), f"Missing checkout instruction or dependency: {path}"
        )
    for step in spec.get("setup_checks", []):
        name = step["name"]
        require(command(step, out, clean_env) == 0, f"Setup check failed: {name}")
        if "output_equals" in step:
            require(
                (out / f"{name}.stdout").read_text().strip() == step["output_equals"],
                f"Unexpected setup output: {name}",
            )
    step = spec["probe"]
    require(command(step, out, env) == 0, "Agent preflight command failed")
    events = [
        json.loads(line)
        for line in (out / f"{step['name']}.stdout").read_text().splitlines()
        if line.strip()
    ]
    for probe in spec["required_tools"]:
        found = False
        for event in events:
            part = event.get("part", {})
            state = part.get("state", {})
            if (
                event.get("type") == "tool_use"
                and part.get("tool") == probe["tool"]
                and state.get("status") == "completed"
                and all(
                    state.get("input", {}).get(k) == v
                    for k, v in probe["input"].items()
                )
                and probe.get("output_contains", "") in str(state.get("output", ""))
            ):
                found = True
                break
        require(
            found,
            f"Missing successful preflight tool call: {probe['tool']} {probe['input']}",
        )


def verify(spec, out, env, tree, base):
    steps = spec["checks"]
    names = [step["name"] for step in steps]
    require(
        steps and len(names) == len(set(names)) and "whitespace" not in names,
        "Verification needs unique check names",
    )
    failures = []
    if command(
        {
            "name": "whitespace",
            "argv": ["git", "diff", "--cached", "--check", base],
            "seconds": 60,
        },
        out,
        env,
    ):
        failures.append("whitespace")
    for step in steps:
        try:
            require(command(step, out, env) == 0, "nonzero exit; see .exit and logs")
            if "rubocop_files" in step:
                report = json.loads((out / f"{step['name']}.stdout").read_bytes())
                summary = report["summary"]
                files = report["files"]
                require(
                    step["rubocop_files"] > 0
                    and step["rubocop_files"]
                    == summary["inspected_file_count"]
                    == summary["target_file_count"]
                    == len(files)
                    == len({f["path"] for f in files})
                    and summary["offense_count"] == 0
                    and all(not f["offenses"] for f in files),
                    "incomplete coverage or offenses remain",
                )
        except (ValueError, OSError, KeyError, TypeError) as error:
            failures.append(f"{step['name']}: {error}")
    require(
        text("rev-parse", "HEAD") == base
        and text("write-tree") == tree
        and not git("diff", "--name-only", "-z")
        and not git("ls-files", "--others", "--exclude-standard", "-z"),
        "Verification changed the checkout",
    )
    return failures


def run(args, spec, out):
    env = os.environ.copy()
    if args.phase == "image":
        image_check(spec["image"], out, env)
        return
    credentials = {
        "GITLAB_TOKEN",
        "GITLAB_GDKBOX_TOKEN",
        "ANTHROPIC_API_KEY",
        "OPENAI_API_KEY",
        *spec.get("credential_env", []),
    }
    clean_env = {key: value for key, value in env.items() if key not in credentials}
    for key in credentials:
        os.environ.pop(key, None)
    os.chdir(args.checkout.resolve(strict=True))
    require(
        Path(text("rev-parse", "--show-toplevel")) == Path.cwd(),
        "Use the isolated checkout root",
    )
    base = spec["base"]
    contract = verification_contract(spec)
    if args.phase == "verify-only":
        saved = args.checkpoint.resolve(strict=True)
        require((saved / "checkpoint.complete").is_file(), "Incomplete checkpoint")
        record = json.loads((saved / "checkpoint.json").read_bytes())
        require(
            record["job_id"] == spec["job_id"] and record["base"] == base,
            "Checkpoint identity mismatch",
        )
        require(
            record["verification_contract"] == contract, "Verification contract changed"
        )
        tree = record["tree"]
        require(
            record["repair_exit"] == 0 and record["input_tree"] == spec["input_tree"],
            "Checkpoint did not pass repair gates",
        )
        require(tree != spec["input_tree"], "Checkpoint is a no-op")
        restore(base, saved / "checkpoint.patch", record["sha256"], tree)
        require(
            set(record["repair_paths"]) <= set(spec["edit_paths"]),
            "Checkpoint repair scope mismatch",
        )
        failures = verify(spec, out, clean_env, tree, base)
        require(not failures, "; ".join(failures))
        write(out / "verified.json", json.dumps(record).encode())
        return

    initial = spec["input_tree"]
    restore(base, args.patch, spec["input_sha256"], initial)
    preflight(spec, out, env, clean_env)
    require(
        text("rev-parse", "HEAD") == base
        and text("write-tree") == initial
        and not git("diff", "--name-only", "-z")
        and not git("ls-files", "--others", "--exclude-standard", "-z"),
        "Preflight changed the checkout",
    )
    if args.phase == "preflight":
        return

    rc = command(spec["repair"], out, env)
    require(
        text("rev-parse", "HEAD") == base and text("write-tree") == initial,
        "Agent changed HEAD or the index",
    )
    changes = check_scope(git("diff", "--name-only", "--no-renames", "-z"), spec)
    require(
        not git("ls-files", "--others", "--exclude-standard", "-z"),
        "Agent created untracked files",
    )
    if changes:
        git("--literal-pathspecs", "add", "-u", "--", *sorted(changes))
    tree = text("write-tree")
    patch = out / "checkpoint.patch"
    write(patch, git("diff", "--cached", "--binary", base))
    record = {
        "job_id": spec["job_id"],
        "base": base,
        "input_tree": initial,
        "tree": tree,
        "sha256": digest(patch),
        "repair_exit": rc,
        "repair_paths": sorted(changes),
        "verification_contract": contract,
    }
    write(out / "checkpoint.json", json.dumps(record).encode())
    write(out / "checkpoint.complete", b"complete\n")
    failures = verify(spec, out, clean_env, tree, base)
    require(
        rc == 0 and tree != initial,
        "Agent failed or produced no repair"
        + (": " + "; ".join(failures) if failures else ""),
    )
    require(not failures, "; ".join(failures))
    write(out / "verified.json", json.dumps(record).encode())


def check_scope(paths, spec):
    changes = {os.fsdecode(path) for path in paths.split(b"\0") if path}
    require(
        changes <= set(spec["edit_paths"]),
        "Repair edited paths outside the manifest scope",
    )
    return changes


def verification_contract(spec):
    checks = [
        {k: v for k, v in step.items() if k != "seconds"} for step in spec["checks"]
    ]
    payload = {"checks": checks, "edit_paths": sorted(spec["edit_paths"])}
    return hashlib.sha256(json.dumps(payload, sort_keys=True).encode()).hexdigest()


def main():
    os.umask(0o077)
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "phase", choices=["image", "preflight", "repair", "verify-only"]
    )
    parser.add_argument("manifest", type=Path)
    parser.add_argument("output", type=Path)
    parser.add_argument("--checkout", type=Path)
    parser.add_argument("--patch", type=lambda p: Path(p).resolve())
    parser.add_argument("--checkpoint", type=lambda p: Path(p).resolve())
    args = parser.parse_args()
    if args.phase != "image" and not args.checkout:
        parser.error("--checkout is required")
    if args.phase in ("repair", "preflight") and not args.patch:
        parser.error("--patch is required")
    if args.phase == "verify-only" and not args.checkpoint:
        parser.error("--checkpoint is required")
    try:
        if args.checkout:
            root = args.checkout.resolve(strict=True)
            require(
                not args.output.resolve().is_relative_to(root),
                "Keep output outside the checkout",
            )
        spec = json.loads(args.manifest.read_bytes())
        if args.phase != "image":
            steps = list(spec["checks"])
            if args.phase != "verify-only":
                steps += [spec["probe"], spec["repair"], *spec.get("setup_checks", [])]
            names = [step["name"] for step in steps]
            require(
                len(names) == len(set(names)) and "whitespace" not in names,
                "Step names must be unique",
            )
        args.output.mkdir(mode=0o700)
        out = args.output.resolve()
        with contextlib.ExitStack() as stack:
            if args.phase != "image":
                root = args.checkout.resolve(strict=True)
                lock = stack.enter_context(
                    root.with_name(root.name + ".gdk-job.lock").open("a")
                )
                fcntl.flock(lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
            try:
                run(args, spec, out)
            except (
                ValueError,
                OSError,
                KeyError,
                TypeError,
                subprocess.SubprocessError,
            ) as error:
                write(out / "result", f"{args.phase}: {error}\n".encode())
                raise
            write(out / "result", f"{args.phase}: passed\n".encode())
    except (
        ValueError,
        OSError,
        KeyError,
        TypeError,
        subprocess.SubprocessError,
    ) as error:
        print(f"{args.phase}: {error}", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
