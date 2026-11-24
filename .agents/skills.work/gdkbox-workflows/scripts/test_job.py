"""Run with python3 -m unittest discover -s scripts -v from the skill directory."""

import hashlib
import json
import os
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

RUNNER = Path(__file__).with_name("job.py").resolve()


def step(name, code, seconds=10, **options):
    return dict(
        name=name, argv=[sys.executable, "-c", code], seconds=seconds, **options
    )


class JobTest(unittest.TestCase):
    def setUp(self):
        tmp = tempfile.TemporaryDirectory()
        self.addCleanup(tmp.cleanup)
        self.root = Path(tmp.name)
        self.repo = self.root / "checkout"
        self.repo.mkdir()
        self.git("init", "-q")
        self.git("config", "user.name", "Fixture")
        self.git("config", "user.email", "fixture@example.com")
        (self.repo / "example.rb").write_text("original\n")
        self.git("add", "example.rb")
        self.git("commit", "-qm", "Fixture base")
        base = self.git("rev-parse", "HEAD").decode().strip()
        (self.repo / "example.rb").write_text("staged input\n")
        self.git("add", "example.rb")
        self.patch = self.root / "input.patch"
        self.patch.write_bytes(self.git("diff", "--cached", "--binary"))
        tree = self.git("write-tree").decode().strip()
        self.git("restore", "--source=HEAD", "--staged", "--worktree", "example.rb")
        call = {
            "tool": "shell",
            "input": {"command": "git rev-parse HEAD"},
            "output_contains": base,
        }
        event = {
            "type": "tool_use",
            "part": {
                "tool": "shell",
                "state": {
                    "status": "completed",
                    "input": call["input"],
                    "output": base,
                },
            },
        }
        self.spec = {
            "job_id": "fixture",
            "base": base,
            "input_tree": tree,
            "input_sha256": hashlib.sha256(self.patch.read_bytes()).hexdigest(),
            "edit_paths": ["example.rb"],
            "required_files": ["example.rb"],
            "required_tools": [call],
            "probe": step("probe", f"print({json.dumps(event)!r})"),
            "repair": step(
                "agent",
                "from pathlib import Path; Path('example.rb').write_text('repaired\\n')",
            ),
            "checks": [
                step("check", "import os; assert 'GITLAB_TOKEN' not in os.environ")
            ],
        }
        self.policy = [
            {"action": "*", "resource": "*", "effect": "deny"},
            {"action": "edit", "resource": "example.rb", "effect": "allow"},
        ]

    def git(self, *args, cwd=None):
        return subprocess.check_output(["git", *args], cwd=cwd or self.repo)

    def run_job(self, phase="repair", checkout=None, **options):
        out = self.root / phase
        manifest = self.root / "job.json"
        manifest.write_text(json.dumps(self.spec))
        env = dict(
            os.environ,
            GITLAB_TOKEN="fixture-only",
            OPENCODE_CONFIG_CONTENT=json.dumps({"permissions": self.policy}),
        )
        args = [sys.executable, str(RUNNER), phase, str(manifest), str(out)]
        if phase != "image":
            args += ["--checkout", str(checkout or self.repo)]
        if phase in {"repair", "preflight"}:
            args += ["--patch", str(self.patch)]
        if phase == "verify-only":
            args += ["--checkpoint", str(self.root / "repair")]
        return subprocess.run(
            args,
            env=env | options,
            capture_output=True,
            text=True,
            check=False,
            timeout=30,
        ), out

    def test_timeout_preserves_checkpoint_and_resume_without_agent(self):
        self.spec["checks"].insert(
            0,
            step(
                "scan",
                "import os,time; time.sleep(3 if 'FAST' not in os.environ else 0)",
                1,
            ),
        )
        run, out = self.run_job()
        self.assertEqual(run.returncode, 1, run.stderr)
        self.assertEqual((out / "scan.exit").read_text().strip(), "124")
        self.assertEqual((out / "check.exit").read_text().strip(), "0")
        self.assertTrue((out / "checkpoint.complete").is_file())
        self.assertFalse((out / "verified.json").exists())
        checkout = self.root / "resumed"
        self.git("clone", "-q", str(self.repo), str(checkout))
        self.spec["repair"] = step("agent", "raise RuntimeError('must not run')")
        run, resumed = self.run_job("verify-only", checkout, FAST="1")
        self.assertEqual(run.returncode, 0, run.stderr)
        self.assertEqual(
            (resumed / "verified.json").read_bytes(),
            (out / "checkpoint.json").read_bytes(),
        )
        self.assertEqual((checkout / "example.rb").read_text(), "repaired\n")
        self.assertFalse((resumed / "agent.exit").exists())

    def test_missing_tool_aborts_before_repair(self):
        self.spec["required_tools"].append(
            {"tool": "skill", "input": {"id": "required-skill"}}
        )
        run, out = self.run_job()
        self.assertIn("required-skill", run.stderr)
        self.assertFalse((out / "agent.exit").exists())

    def test_different_shell_command_does_not_satisfy_probe(self):
        self.spec["required_tools"][0]["input"]["command"] = "git status --short"
        run, out = self.run_job()
        self.assertNotEqual(run.returncode, 0)
        self.assertIn("git status --short", run.stderr)
        self.assertFalse((out / "agent.exit").exists())

    def test_resume_rejects_tampered_patch(self):
        run, out = self.run_job()
        self.assertEqual(run.returncode, 0, run.stderr)
        with (out / "checkpoint.patch").open("ab") as patch:
            patch.write(b"unexpected\n")
        checkout = self.root / "resumed"
        self.git("clone", "-q", str(self.repo), str(checkout))
        run, resumed = self.run_job("verify-only", checkout)
        self.assertIn("Patch digest mismatch", run.stderr)
        self.assertFalse((resumed / "check.exit").exists())

    def test_resume_rejects_changed_verification_contract(self):
        run, _ = self.run_job()
        self.assertEqual(run.returncode, 0, run.stderr)
        checkout = self.root / "resumed"
        self.git("clone", "-q", str(self.repo), str(checkout))
        self.spec["checks"] = [step("check", "pass")]
        run, resumed = self.run_job("verify-only", checkout)
        self.assertIn("Verification contract changed", run.stderr)
        self.assertFalse((resumed / "check.exit").exists())

    def test_mismatched_edit_policy_aborts(self):
        self.policy[1]["resource"] = "*.rb"
        run, out = self.run_job()
        self.assertIn("edit allowlist", run.stderr)
        self.assertFalse((out / "probe.exit").exists())

    def test_zero_exit_no_op_is_rejected(self):
        self.spec["repair"] = step("agent", "pass")
        run, out = self.run_job()
        self.assertIn("no repair", run.stderr)
        self.assertFalse((out / "verified.json").exists())

    def test_out_of_scope_tracked_edit_is_not_exported(self):
        self.policy.pop()
        self.spec["edit_paths"] = []
        run, out = self.run_job()
        self.assertIn("outside the manifest scope", run.stderr)
        self.assertFalse((out / "checkpoint.patch").exists())

    def test_whitespace_failure_still_collects_check_results(self):
        self.spec["repair"] = step(
            "agent",
            "from pathlib import Path; Path('example.rb').write_text('repair \\n')",
        )
        run, out = self.run_job()
        self.assertNotEqual(run.returncode, 0)
        self.assertIn("whitespace", run.stderr)
        self.assertEqual((out / "check.exit").read_text().strip(), "0")
        self.assertTrue((out / "checkpoint.complete").exists())
        self.assertFalse((out / "verified.json").exists())

    def test_zero_offenses_in_partial_report_is_rejected(self):
        report = {
            "summary": {
                "offense_count": 0,
                "inspected_file_count": 1,
                "target_file_count": 2,
            },
            "files": [{"path": "example.rb", "offenses": []}],
        }
        self.spec["checks"].insert(
            0, step("scan", f"print({json.dumps(report)!r})", rubocop_files=2)
        )
        run, out = self.run_job()
        self.assertIn("incomplete coverage", run.stderr)
        self.assertEqual((out / "check.exit").read_text().strip(), "0")
        self.assertFalse((out / "verified.json").exists())

    def test_image_rejects_wrong_platform(self):
        bin_dir = self.root / "bin"
        bin_dir.mkdir()
        crane = bin_dir / "crane"
        crane.write_text(
            '#!/bin/sh\nprintf \'{"os":"linux","architecture":"arm64"}\\n\'\n'
        )
        crane.chmod(0o700)
        self.spec["image"] = "example.invalid/gdk@sha256:" + "1" * 64
        run, _ = self.run_job("image", PATH=f"{bin_dir}:{os.environ['PATH']}")
        self.assertIn("platform mismatch", run.stderr)

    def test_image_registry_failure_keeps_diagnostics(self):
        bin_dir = self.root / "bin"
        bin_dir.mkdir()
        crane = bin_dir / "crane"
        crane.write_text("#!/bin/sh\necho 'manifest unknown' >&2\nexit 1\n")
        crane.chmod(0o700)
        self.spec["image"] = "example.invalid/gdk@sha256:" + "1" * 64
        run, out = self.run_job("image", PATH=f"{bin_dir}:{os.environ['PATH']}")
        self.assertNotEqual(run.returncode, 0)
        self.assertIn("Pinned image unavailable", run.stderr)
        self.assertIn("manifest unknown", (out / "image.stderr").read_text())
