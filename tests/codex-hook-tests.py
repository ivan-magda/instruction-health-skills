#!/usr/bin/env python3
"""Run the shipped hook commands with realistic Claude and Codex events."""

import json
import os
import re
import shutil
import subprocess
import tempfile
import unittest
from pathlib import Path

REPOSITORY_ROOT = Path(__file__).resolve().parents[1]


class HookTests(unittest.TestCase):
    def setUp(self):
        temporary_directory = tempfile.TemporaryDirectory()
        self.addCleanup(temporary_directory.cleanup)
        self.root = Path(temporary_directory.name)

        self.codex_plugin_root = self.root / "plugin with spaces"
        self.claude_plugin_root = self.root / "claude-plugin"
        for plugin_root in (self.codex_plugin_root, self.claude_plugin_root):
            shutil.copytree(REPOSITORY_ROOT / "hooks", plugin_root / "hooks")

        self.project_directory = self.root / "project" / "nested session"
        self.project_directory.mkdir(parents=True)
        self.temporary_directory = self.root / "tmp"
        self.temporary_directory.mkdir()

        self.environment = {
            **os.environ,
            "PLUGIN_ROOT": str(self.codex_plugin_root),
            "CLAUDE_PLUGIN_ROOT": str(self.claude_plugin_root),
            "TMPDIR": str(self.temporary_directory),
        }
        self.environment.pop("CLAUDE_PROJECT_DIR", None)

    def cleanup_flag_path(self, directory=None, host="codex"):
        """Match the hook's host-specific, project-specific cleanup flag path."""
        if directory is None:
            directory = self.project_directory.resolve()
        checksum_output = subprocess.check_output(
            ["cksum"], input=str(directory).encode()
        )
        checksum = checksum_output.decode().split()[0]
        if host == "codex":
            prefix = "instruction-health-codex-cleanup-"
        else:
            prefix = "instruction-health-cleanup-"
        return self.temporary_directory / f"{prefix}{checksum}.flag"

    def run_event(self, host, event, payload):
        """Run matching hooks and return their decoded JSON responses."""
        filename = "codex-hooks.json" if host == "codex" else "hooks.json"
        config_path = self.codex_plugin_root / "hooks" / filename
        config = json.loads(config_path.read_text())
        payload = {
            **payload,
            "hook_event_name": event,
            "cwd": str(self.project_directory),
            "session_id": "test-session",
        }
        matcher_key = "source" if event == "SessionStart" else "tool_name"
        match_value = payload.get(matcher_key, "")
        outputs = []
        for group in config["hooks"][event]:
            if not re.search(group.get("matcher", ".*"), match_value):
                continue
            for hook in group["hooks"]:
                result = subprocess.run(
                    ["/bin/sh", "-c", hook["command"]],
                    input=json.dumps(payload),
                    text=True,
                    capture_output=True,
                    check=False,
                    cwd=self.project_directory,
                    env=self.environment,
                    timeout=10,
                )
                self.assertEqual(result.returncode, 0, result.stderr)
                self.assertEqual(result.stderr, "")
                if result.stdout:
                    outputs.append(json.loads(result.stdout))
        return outputs

    def assert_patch_reminder(self, patch_body, expect_reminder=True):
        """Submit a patch and check whether the guardian reminder is emitted."""
        payload = {
            "tool_name": "apply_patch",
            "tool_input": {
                "command": f"*** Begin Patch\n{patch_body}\n*** End Patch"
            },
        }
        outputs = self.run_event("codex", "PreToolUse", payload)
        if expect_reminder:
            self.assertEqual(len(outputs), 1)
            hook_output = outputs[0]["hookSpecificOutput"]
            self.assertEqual(hook_output["hookEventName"], "PreToolUse")
            self.assertIn("instruction-guardian", hook_output["additionalContext"])
            self.assertEqual(hook_output["permissionDecision"], "allow")
        else:
            self.assertEqual(outputs, [])

    def test_add_update_delete_and_rename(self):
        for patch_body in (
            "*** Add File: AGENTS.md\n+Keep instructions short.",
            "*** Update File: apps/mobile/CLAUDE.md\n@@\n-old\n+new",
            "*** Delete File: docs/MEMORY.md",
            "*** Update File: draft.md\n*** Move to: nested/AGENTS.md\n@@\n-a\n+b",
            "*** Update File: AGENTS.md\n*** Move to: archive.md\n@@\n-a\n+b",
            "*** Add File: .claude/rules/team.md\n+rule",
            "*** Add File: .claude/projects/demo/memory/topic.md\n+note",
            '*** Add File: /tmp/Проект "one"/AGENTS.md\n+rule',
        ):
            with self.subTest(patch_body=patch_body):
                self.assert_patch_reminder(patch_body)

    def test_multiple_files_emit_one_reminder(self):
        self.assert_patch_reminder(
            "*** Add File: src/app.py\n+pass\n"
            "*** Update File: docs/AGENTS.md\n@@\n-a\n+b\n"
            "*** Add File: MEMORY.md\n+note"
        )

    def test_content_and_near_misses_do_not_trigger(self):
        for patch_body in (
            '*** Add File: app.py\n+{"file_path":"AGENTS.md"}',
            "*** Add File: README.md\n+*** Update File: AGENTS.md",
            "*** Update File: README.md\n@@\n *** Delete File: AGENTS.md\n-x\n+y",
            "*** Add File: .claude/rules-backup/notes.md\n+rule",
            "*** Add File: docs/AGENTS.md.example\n+example",
        ):
            with self.subTest(patch_body=patch_body):
                self.assert_patch_reminder(patch_body, expect_reminder=False)

    def test_invalid_payloads_fail_open(self):
        payloads = ["", "invalid", '{"tool_name":', "null", "[]", "42"]
        for tool_input in (
            None,
            [],
            "patch",
            {},
            {"command": None},
            {"command": ["AGENTS.md"]},
            {"command": "AGENTS.md"},
            {"command": "*** Begin Patch\n*** Delete File: AGENTS.md"},
        ):
            payloads.append(
                json.dumps({"tool_name": "apply_patch", "tool_input": tool_input})
            )
        hook_path = self.codex_plugin_root / "hooks/codex-guardian-reminder.sh"
        for payload in payloads:
            with self.subTest(payload=payload):
                result = subprocess.run(
                    ["/bin/sh", str(hook_path)],
                    input=payload,
                    text=True,
                    capture_output=True,
                    check=False,
                    cwd=self.project_directory,
                    env=self.environment,
                    timeout=10,
                )
                self.assertEqual(result.returncode, 0, result.stderr)
                self.assertEqual(result.stdout, "")
                self.assertEqual(result.stderr, "")

    def test_shell_writes_are_outside_matcher(self):
        payload = {
            "tool_name": "Bash",
            "tool_input": {"command": "echo x >> AGENTS.md"},
        }
        self.assertEqual(self.run_event("codex", "PreToolUse", payload), [])

    def test_codex_flag_lifecycle_and_project_isolation(self):
        cleanup_flag = self.cleanup_flag_path()
        cleanup_flag.touch()
        other_project_flag = self.cleanup_flag_path(self.project_directory.parent)
        other_project_flag.touch()
        self.assert_patch_reminder(
            "*** Delete File: AGENTS.md", expect_reminder=False
        )
        self.run_event("codex", "SessionStart", {"source": "compact"})
        self.assertTrue(cleanup_flag.exists())
        for source in ("startup", "resume", "clear"):
            with self.subTest(source=source):
                cleanup_flag.touch()
                self.run_event("codex", "SessionStart", {"source": source})
                self.assertFalse(cleanup_flag.exists())
                self.assertTrue(other_project_flag.exists())
                self.run_event("codex", "SessionStart", {"source": source})
        self.assert_patch_reminder("*** Delete File: AGENTS.md")

    def test_claude_project_override_and_compaction_unchanged(self):
        self.environment["CLAUDE_PROJECT_DIR"] = str(self.project_directory.parent)
        cleanup_flag = self.cleanup_flag_path(
            self.project_directory.parent, host="claude"
        )
        payload = {"tool_name": "Edit", "tool_input": {"file_path": "AGENTS.md"}}
        self.assertEqual(len(self.run_event("claude", "PreToolUse", payload)), 1)
        cleanup_flag.touch()
        self.assertEqual(self.run_event("claude", "PreToolUse", payload), [])
        self.run_event("claude", "SessionStart", {"source": "compact"})
        self.assertFalse(cleanup_flag.exists())
        self.assertEqual(len(self.run_event("claude", "PreToolUse", payload)), 1)

    def test_hosts_do_not_suppress_or_clear_each_others_flags(self):
        project_directory = self.project_directory.resolve()
        self.environment["CLAUDE_PROJECT_DIR"] = str(project_directory)
        claude_flag = self.cleanup_flag_path(project_directory, host="claude")
        claude_flag.touch()
        self.assert_patch_reminder("*** Delete File: AGENTS.md")
        self.run_event("codex", "SessionStart", {"source": "startup"})
        self.assertTrue(claude_flag.exists())
        claude_flag.unlink()
        codex_flag = self.cleanup_flag_path()
        codex_flag.touch()
        payload = {"tool_name": "Edit", "tool_input": {"file_path": "AGENTS.md"}}
        self.assertEqual(len(self.run_event("claude", "PreToolUse", payload)), 1)
        self.run_event("claude", "SessionStart", {"source": "startup"})
        self.assertTrue(codex_flag.exists())

    def test_missing_python_preserves_claude_and_codex_fails_open(self):
        binary_directory = self.root / "bin"
        binary_directory.mkdir()
        for name in ("sh", "cat", "cksum", "awk", "sed", "head", "grep", "dirname"):
            executable_path = shutil.which(name)
            if executable_path is None:
                self.fail(f"Required test executable not found on PATH: {name}")
            (binary_directory / name).symlink_to(executable_path)
        self.environment["PATH"] = str(binary_directory)
        payload = {"tool_name": "Write", "tool_input": {"file_path": "AGENTS.md"}}
        self.assertEqual(len(self.run_event("claude", "PreToolUse", payload)), 1)
        self.assert_patch_reminder(
            "*** Delete File: AGENTS.md", expect_reminder=False
        )


if __name__ == "__main__":
    unittest.main(verbosity=2)
