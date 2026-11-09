#!/usr/bin/env python3
"""Regression checks for safe inclusion of the final navigation timeout."""
import hashlib
import json
from pathlib import Path
import subprocess
import tempfile
import unittest

SCRIPT = Path(__file__).with_name("project-crow-replay.swift")


class ProjectionTerminalTests(unittest.TestCase):
    def project(self, mutate=lambda frames: None, include_timeout=False):
        frames = [
            {"step": 1, "done": False, "timeout": False,
             "outcomes": {"navigation_waypoints_reached": 0}},
            {"step": 2, "done": False, "timeout": False,
             "outcomes": {"navigation_waypoints_reached": 5}},
            {"step": 3, "done": True, "timeout": True,
             "outcomes": {"navigation_waypoints_reached": 5,
                          "navigation_completion": 1}},
        ]
        mutate(frames)
        with tempfile.TemporaryDirectory() as temporary:
            source = Path(temporary) / "source.json"
            result = Path(temporary) / "result.json"
            source.write_text(json.dumps({"schema": "numi.crow-replay.v1", "payload": {"frames": frames}}))
            digest = hashlib.sha256(source.read_bytes()).hexdigest()
            args = ["swift", str(SCRIPT), str(source), str(result),
                    "--stride", "1", "--stop-index", "2", "--source-sha256", digest]
            if include_timeout:
                args.append("--include-final-timeout")
            run = subprocess.run(args, capture_output=True, text=True, check=False)
            payload = json.loads(result.read_text())["payload"] if result.exists() else None
            return run.returncode, payload

    def test_source_digest_mismatch_is_rejected(self):
        with tempfile.TemporaryDirectory() as temporary:
            source = Path(temporary) / "source.json"
            result = Path(temporary) / "result.json"
            source.write_text('{"payload":{"frames":[]}}')
            run = subprocess.run(["swift", str(SCRIPT), str(source), str(result),
                "--stride", "1", "--stop-index", "2", "--source-sha256", "0" * 64],
                capture_output=True, text=True, check=False)
            self.assertNotEqual(run.returncode, 0)
            self.assertFalse(result.exists())

    def test_final_timeout_requires_explicit_opt_in(self):
        self.assertNotEqual(self.project()[0], 0)

    def test_completed_final_timeout_is_preserved(self):
        status, payload = self.project(include_timeout=True)
        self.assertEqual(status, 0)
        self.assertEqual([f["step"] for f in payload["frames"]], [1, 2, 3])
        self.assertTrue(payload["frames"][-1]["timeout"])
        self.assertFalse(payload["presentation_projection"]["terminal_frame_excluded"])

    def test_intermediate_termination_is_rejected(self):
        def terminate_early(frames):
            frames[1].update(done=True, timeout=True)
        self.assertNotEqual(self.project(terminate_early, True)[0], 0)

    def test_terminal_failure_is_rejected(self):
        def fail(frames):
            frames[-1]["timeout"] = False
        self.assertNotEqual(self.project(fail, True)[0], 0)

    def test_incomplete_navigation_is_rejected(self):
        def incomplete(frames):
            frames[-1]["outcomes"]["navigation_completion"] = 0
        self.assertNotEqual(self.project(incomplete, True)[0], 0)


if __name__ == "__main__":
    unittest.main()
