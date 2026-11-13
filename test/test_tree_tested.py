#!/usr/bin/env python3
# Copyright (C) 2026 Qore Technologies, s.r.o.
# SPDX-License-Identifier: MIT
"""Exercise CI tree reuse with real Git histories, a local API and a fake status sink."""

import contextlib
import http.server
import json
import os
from pathlib import Path
import select
import socket
import subprocess
import sys
import tempfile
import threading
import unittest
from urllib.parse import parse_qs, urlsplit


ROOT = Path(__file__).resolve().parents[1]
CHECK = ROOT / "test/docker_test/tree-already-tested.py"
SKIP = ROOT / "test/docker_test/tree-tested-skip.sh"


@contextlib.contextmanager
def api_server(responder):
    requests = []
    errors = []

    class Handler(http.server.BaseHTTPRequestHandler):
        def do_GET(self):
            requests.append((self.path, dict(self.headers)))
            try:
                status, body = responder(self.path, self.headers)
            except Exception as error:
                errors.append(error)
                status, body = 500, {"message": "test responder failed"}
            data = body if isinstance(body, bytes) else json.dumps(body).encode()
            self.send_response(status)
            self.send_header("Content-Type", "application/json")
            self.send_header("Content-Length", str(len(data)))
            self.end_headers()
            self.wfile.write(data)

        def log_message(self, *args):
            pass

    server = http.server.HTTPServer(("127.0.0.1", 0), Handler)
    stop_read, stop_write = socket.socketpair()

    def serve():
        while True:
            readable = select.select([server, stop_read], [], [])[0]
            if stop_read in readable:
                return
            server.handle_request()

    thread = threading.Thread(target=serve)
    thread.start()
    try:
        yield f"http://127.0.0.1:{server.server_port}/api/v4", requests
    finally:
        stop_write.send(b"x")
        thread.join(timeout=5)
        server.server_close()
        stop_read.close()
        stop_write.close()
        if thread.is_alive():
            raise AssertionError("test API server did not exit")
        if errors:
            raise errors[0]


class TreeTestedTest(unittest.TestCase):
    def setUp(self):
        directory = tempfile.TemporaryDirectory(prefix="ncurses-ci-test-")
        self.addCleanup(directory.cleanup)
        self.directory = Path(directory.name)
        self.repo = self.directory / "repo"
        self.repo.mkdir()
        self.git("init", "-q", "-b", "develop")
        self.git("config", "user.name", "CI Test")
        self.git("config", "user.email", "ci-test@example.invalid")
        (self.repo / "source").write_text("base\n")
        self.git("add", "source")
        self.git("-c", "commit.gpgsign=false", "commit", "-qm", "base")
        self.head = self.git("rev-parse", "HEAD")
        self.tree = self.git("rev-parse", "HEAD^{tree}")
        self.env = dict(os.environ)
        self.env.pop("BASH_ENV", None)
        for key in list(self.env):
            if key.startswith(("CI_", "QORE_TREE_TESTED_", "QORE_CI_")):
                del self.env[key]
        self.env.update(CI_COMMIT_BRANCH="develop", CI_PIPELINE_SOURCE="push",
                        CI_COMMIT_SHA=self.head, CI_PROJECT_ID="83", CI_PIPELINE_ID="200",
                        CI_JOB_TOKEN="job-test-secret")
        self.responses = {}
        self.job_responses = {}
        # job ID -> (HTTP status, ci-environment.txt artifact body)
        self.artifacts = {}

    def git(self, *args):
        return subprocess.run(["git", *args], cwd=self.repo, check=True,
                              capture_output=True, text=True).stdout.strip()

    @staticmethod
    def fingerprint(name, pipeline_id=100):
        return f"{name}-{pipeline_id}".encode().hex().ljust(64, "0")[:64]

    def success(self, sha=None, pipeline_id=100, artifacts=True):
        sha = sha or self.head
        self.responses.setdefault(sha, []).append(dict(id=pipeline_id, project_id=83, sha=sha, status="success"))
        self.job_responses[pipeline_id] = []
        for offset, name in enumerate(("test-ubuntu", "test-alpine"), 1):
            job_id = pipeline_id * 10 + offset
            self.job_responses[pipeline_id].append(dict(id=job_id, name=name, status="success"))
            if artifacts:
                self.artifacts[job_id] = (200, (self.fingerprint(name, pipeline_id) + "\n").encode())

    def respond(self, path, headers):
        parsed = urlsplit(path)
        if parsed.path.endswith("/artifacts/ci-environment.txt"):
            parts = parsed.path.split("/")
            self.assertEqual(["", "api", "v4", "projects", "83", "jobs"], parts[:6])
            return self.artifacts.get(int(parts[6]), (404, {"message": "404 Not Found"}))
        if parsed.path.endswith("/jobs"):
            pipeline = int(parsed.path.split("/")[-2])
            return 200, self.job_responses.get(pipeline, [])
        self.assertEqual("/api/v4/projects/83/pipelines", parsed.path)
        query = parse_qs(parsed.query)
        self.assertEqual(["success"], query["status"])
        return 200, self.responses.get(query["sha"][0], [])

    def run_check(self, responder=None, **overrides):
        with api_server(responder or self.respond) as (url, requests):
            env = dict(self.env, CI_API_V4_URL=url, **overrides)
            result = subprocess.run([sys.executable, str(CHECK)], cwd=self.repo,
                                    env=env, capture_output=True, text=True, timeout=10)
        self.assertEqual(0, result.returncode, result.stdout + result.stderr)
        self.assertEqual("", result.stderr)
        self.assertNotIn("test-secret", result.stdout)
        report = dict(line.split("=", 1) for line in (self.repo / "tree-tested.env").read_text().splitlines())
        self.assertEqual("1", report["QORE_TREE_TESTED_CHECKED"])
        return report, requests

    def assert_full(self, report):
        self.assertEqual({"QORE_TREE_TESTED_CHECKED": "1"}, report)

    def merge(self, changed=False):
        self.git("checkout", "-qb", "feature")
        (self.repo / "source").write_text("feature\n")
        self.git("-c", "commit.gpgsign=false", "commit", "-qam", "feature")
        parent = self.git("rev-parse", "HEAD")
        self.git("checkout", "-q", "develop")
        if changed:
            (self.repo / "another-source").write_text("develop\n")
            self.git("add", "another-source")
            self.git("-c", "commit.gpgsign=false", "commit", "-qm", "develop")
        self.git("-c", "commit.gpgsign=false", "merge", "--no-ff", "--no-edit", "feature")
        self.head = self.git("rev-parse", "HEAD")
        self.tree = self.git("rev-parse", "HEAD^{tree}")
        self.env["CI_COMMIT_SHA"] = self.head
        return parent

    def test_same_commit_success(self):
        self.success()
        report, requests = self.run_check()
        self.assertEqual("100", report["QORE_TREE_TESTED_IN"])
        self.assertEqual(self.head, report["QORE_TREE_TESTED_SHA"])
        self.assertEqual(self.tree, report["QORE_TREE_TESTED_TREE"])
        self.assertEqual(self.fingerprint("test-ubuntu"), report["QORE_TREE_TESTED_ENV_TEST_UBUNTU"])
        self.assertEqual(self.fingerprint("test-alpine"), report["QORE_TREE_TESTED_ENV_TEST_ALPINE"])
        self.assertEqual(6, len(report))
        self.assertEqual(4, len(requests))
        self.assertEqual(["false"], parse_qs(urlsplit(requests[1][0]).query)["include_retried"])
        self.assertEqual(["/api/v4/projects/83/jobs/1001/artifacts/ci-environment.txt",
                          "/api/v4/projects/83/jobs/1002/artifacts/ci-environment.txt"],
                         [path for path, _ in requests[2:]])

    def test_triggered_pipeline_is_eligible(self):
        self.success()
        report, requests = self.run_check(CI_PIPELINE_SOURCE="pipeline")
        self.assertEqual("100", report["QORE_TREE_TESTED_IN"])
        self.assertEqual(self.fingerprint("test-alpine"), report["QORE_TREE_TESTED_ENV_TEST_ALPINE"])
        self.assertEqual(4, len(requests))

    def test_missing_or_invalid_fingerprints_run_full(self):
        good = (200, (self.fingerprint("x") + "\n").encode())
        for job_id, artifact in ((1001, None), (1002, None), (1002, (404, {"message": "404"})),
                                 (1001, (500, b"error")), (1001, (200, b"")),
                                 (1001, (200, b"A" * 64)), (1001, (200, b"a" * 63)),
                                 (1001, (200, b"a" * 65)), (1001, (200, b"a" * 64 + b"\n\n")),
                                 (1001, (200, b"a" * 64 + b"\ninjected=1\n")),
                                 (1001, (200, b"\xff" * 64)), (1001, (200, b"a" * 4096))):
            with self.subTest(job_id=job_id, artifact=artifact):
                self.success()
                self.artifacts[1001 if job_id == 1002 else 1002] = good
                if artifact is None:
                    self.artifacts.pop(job_id, None)
                else:
                    self.artifacts[job_id] = artifact
                report, _ = self.run_check()
                self.assert_full(report)
                self.responses.clear()

    def test_invalid_job_ids_run_full(self):
        self.success()
        for job_id in (None, 0, -1, "1001", True):
            with self.subTest(job_id=job_id):
                jobs = [dict(job) for job in self.job_responses[100]]
                if job_id is None:
                    del jobs[0]["id"]
                else:
                    jobs[0]["id"] = job_id
                self.job_responses[100] = jobs
                report, _ = self.run_check()
                self.assert_full(report)

    def test_older_pipeline_with_fingerprints_is_used(self):
        # A newer success predating fingerprint recording is not evidence; an older one is.
        self.success(pipeline_id=150, artifacts=False)
        self.success(pipeline_id=100)
        report, requests = self.run_check()
        self.assertEqual("100", report["QORE_TREE_TESTED_IN"])
        self.assertEqual(self.fingerprint("test-ubuntu"), report["QORE_TREE_TESTED_ENV_TEST_UBUNTU"])
        # pipelines, jobs 150, missing ubuntu artifact (alpine is not read), jobs 100, both artifacts
        self.assertEqual(6, len(requests))

    def test_merge_reuses_identical_parent(self):
        parent = self.merge()
        self.success(parent)
        report, requests = self.run_check()
        self.assertEqual(parent, report["QORE_TREE_TESTED_SHA"])
        self.assertEqual(self.tree, report["QORE_TREE_TESTED_TREE"])
        self.assertEqual(5, len(requests))

    def test_changed_merge_tree_runs_full(self):
        parent = self.merge(changed=True)
        self.success(parent)
        report, requests = self.run_check()
        self.assert_full(report)
        self.assertEqual(1, len(requests))

    def test_no_prior_success(self):
        report, _ = self.run_check()
        self.assert_full(report)

    def test_current_pipeline_is_excluded(self):
        self.success(pipeline_id=200)
        report, requests = self.run_check()
        self.assert_full(report)
        self.assertEqual(1, len(requests))

    def test_older_success_after_current_pipeline(self):
        self.success()
        self.responses[self.head].insert(0, dict(id=200, project_id=83, sha=self.head, status="success"))
        report, _ = self.run_check()
        self.assertEqual("100", report["QORE_TREE_TESTED_IN"])

    def test_ineligible_pipelines_and_force_override(self):
        self.success()
        for overrides in ({"CI_COMMIT_BRANCH": "feature"}, {"CI_COMMIT_BRANCH": ""},
                          {"CI_PIPELINE_SOURCE": "web"}, {"CI_PIPELINE_SOURCE": "schedule"},
                          {"CI_PIPELINE_SOURCE": "merge_request_event"}, {"QORE_CI_FORCE_FULL": "1"}):
            with self.subTest(overrides=overrides):
                report, requests = self.run_check(**overrides)
                self.assert_full(report)
                self.assertEqual([], requests)

    def test_checkout_mismatch(self):
        self.success()
        report, requests = self.run_check(CI_COMMIT_SHA="a" * 40)
        self.assert_full(report)
        self.assertEqual([], requests)

    def test_invalid_pipeline_identity(self):
        for overrides in ({"CI_PROJECT_ID": "bad"}, {"CI_PROJECT_ID": "0"},
                          {"CI_PIPELINE_ID": "-1"}, {"CI_PIPELINE_ID": ""}):
            with self.subTest(overrides=overrides):
                report, requests = self.run_check(**overrides)
                self.assert_full(report)
                self.assertEqual([], requests)

    def test_missing_credentials(self):
        self.success()
        report, requests = self.run_check(CI_JOB_TOKEN="")
        self.assert_full(report)
        self.assertEqual([], requests)

    def test_read_api_token_fallback(self):
        self.success()
        def respond(path, headers):
            if headers.get("JOB-TOKEN"):
                return 403, {"message": "denied"}
            self.assertEqual("read-test-secret", headers.get("PRIVATE-TOKEN"))
            return self.respond(path, headers)
        report, requests = self.run_check(respond, QORE_CI_READ_API_TOKEN="read-test-secret")
        self.assertEqual("100", report["QORE_TREE_TESTED_IN"])
        self.assertEqual(self.fingerprint("test-ubuntu"), report["QORE_TREE_TESTED_ENV_TEST_UBUNTU"])
        self.assertEqual(8, len(requests))

    def test_read_api_token_without_job_token(self):
        self.success()
        report, requests = self.run_check(CI_JOB_TOKEN="", QORE_CI_READ_API_TOKEN="read-test-secret")
        self.assertEqual("100", report["QORE_TREE_TESTED_IN"])
        self.assertTrue(all(headers.get("Private-Token") == "read-test-secret" for _, headers in requests))

    def test_api_errors_and_malformed_json_run_full(self):
        for response in ((403, {"message": "denied"}), (500, b"internal error"),
                         (200, b"truncated ["), (200, {"id": 100}), (200, None)):
            with self.subTest(response=response):
                report, _ = self.run_check(lambda path, headers: response)
                self.assert_full(report)

    def test_untrusted_pipeline_items_are_ignored(self):
        self.success()
        original = self.responses[self.head][0]
        for patch in ({"id": True}, {"id": "100"}, {"id": 0}, {"id": -1},
                      {"project_id": 84}, {"sha": "a" * 40}, {"status": "failed"},
                      {"status": "running"}, {"status": "canceled"}):
            with self.subTest(patch=patch):
                self.responses[self.head] = [dict(original, **patch), None, "bad"]
                report, requests = self.run_check()
                self.assert_full(report)
                self.assertEqual(1, len(requests))

    def test_incomplete_or_nonpassing_platform_jobs(self):
        self.success()
        for jobs in ([], [{"name": "test-ubuntu", "status": "success"}],
                     [{"name": ["test-ubuntu"], "status": "success"}],
                     [{"name": "lint", "status": "success"}],
                     [{"name": "test-ubuntu", "status": "success"}] * 2,
                     [{"name": "test-ubuntu", "status": "success"},
                      {"name": "test-alpine", "status": "skipped"}],
                     [{"name": "test-ubuntu", "status": "failed"},
                      {"name": "test-alpine", "status": "success"}],
                     {"name": "test-ubuntu", "status": "success"}):
            with self.subTest(jobs=jobs):
                self.job_responses[100] = jobs
                report, _ = self.run_check()
                self.assert_full(report)

    def test_job_api_failure_runs_full(self):
        self.success()
        def respond(path, headers):
            return (500, {}) if urlsplit(path).path.endswith("/jobs") else self.respond(path, headers)
        report, _ = self.run_check(respond)
        self.assert_full(report)

    def test_stale_artifact_is_replaced(self):
        (self.repo / "tree-tested.env").write_text("QORE_TREE_TESTED_IN=100\n")
        report, _ = self.run_check()
        self.assert_full(report)

    def test_shallow_checkout_does_not_guess_missing_parents(self):
        parent = self.merge()
        self.success(parent)
        clone = self.directory / "shallow"
        subprocess.run(["git", "clone", "-q", "--depth=1", self.repo.as_uri(), str(clone)], check=True)
        self.repo = clone
        self.assertEqual("true", self.git("rev-parse", "--is-shallow-repository"))
        report, requests = self.run_check()
        self.assert_full(report)
        self.assertEqual(1, len(requests))

    def skip_env(self):
        fake_bin = self.directory / "bin"
        fake_bin.mkdir(exist_ok=True)
        curl = fake_bin / "curl"
        curl.write_text(f"#!{sys.executable}\n"
                        "import json, os, pathlib, sys\n"
                        "pathlib.Path(os.environ['STATUS_CAPTURE']).write_text(json.dumps(sys.argv[1:]))\n"
                        "sys.exit(int(os.environ.get('STATUS_EXIT', '0')))\n")
        curl.chmod(0o755)
        # The real fingerprint tool has its own tests (test_ci_environment.py); this
        # one prints FAKE_FINGERPRINT or fails with FAKE_FINGERPRINT_EXIT.
        tools = self.directory / "tools"
        tools.mkdir(exist_ok=True)
        (tools / "ci-environment.py").write_text(
            "import os, sys\n"
            "code = int(os.environ.get('FAKE_FINGERPRINT_EXIT', '0'))\n"
            "if code:\n"
            "    print('partial output')\n"
            "    sys.exit(code)\n"
            "print(os.environ['FAKE_FINGERPRINT'])\n")
        self.ubuntu_fingerprint = "a1" * 32
        return dict(self.env, PATH=str(fake_bin) + os.pathsep + self.env["PATH"],
                    QORE_TREE_TESTED_CHECKED="1", QORE_TREE_TESTED_IN="100",
                    QORE_TREE_TESTED_SHA=self.head, QORE_TREE_TESTED_TREE=self.tree,
                    QORE_TREE_TESTED_ENV_TEST_UBUNTU=self.ubuntu_fingerprint,
                    QORE_TREE_TESTED_ENV_TEST_ALPINE="b2" * 32,
                    CI_JOB_NAME="test-ubuntu", FAKE_FINGERPRINT=self.ubuntu_fingerprint,
                    QORE_CI_TOOLS_DIR=str(tools),
                    QORE_CI_ENV_FILE=str(self.directory / "missing-env.sh"),
                    GITHUB_ACCESS_TOKEN="github-test-secret", REPO_NAME="module-ncurses",
                    CI_PROJECT_URL="https://git.example.invalid/mirror/module-ncurses",
                    STATUS_CAPTURE=str(self.directory / "status.json"))

    def run_skip(self, env, shell="sh", after='echo FULL_JOB'):
        capture = self.directory / "status.json"
        if capture.exists():
            capture.unlink()
        # The sentinel is reached only if sourcing the helper did not exit.
        result = subprocess.run([shell, "-euxc", '. "$1"; ' + after, "ci-job", str(SKIP)],
                                cwd=self.repo, env=env, text=True, capture_output=True, timeout=10)
        self.assertEqual(0, result.returncode, result.stdout + result.stderr)
        self.assertNotIn("github-test-secret", result.stdout + result.stderr)
        self.assertFalse((self.repo / "ci-environment.txt.tmp").exists())
        args = json.loads(capture.read_text()) if capture.exists() else None
        return result.stdout, args

    def recorded_fingerprint(self):
        path = self.repo / "ci-environment.txt"
        return path.read_text() if path.exists() else None

    def test_skip_records_fingerprint_in_every_job(self):
        # Full jobs record it too, so that later pipelines can compare their images.
        for patch in ({}, {"CI_COMMIT_BRANCH": "feature"}, {"CI_PIPELINE_SOURCE": "web"},
                      {"QORE_CI_FORCE_FULL": "1"}, {"QORE_TREE_TESTED_CHECKED": ""},
                      {"FAKE_FINGERPRINT": "c3" * 32}):
            with self.subTest(patch=patch):
                env = dict(self.skip_env(), **patch)
                self.run_skip(env)
                self.assertEqual(env["FAKE_FINGERPRINT"] + "\n", self.recorded_fingerprint())

    def test_skip_for_each_platform_and_triggered_pipelines(self):
        for patch in ({}, {"CI_PIPELINE_SOURCE": "pipeline"},
                      {"CI_JOB_NAME": "test-alpine", "FAKE_FINGERPRINT": "b2" * 32}):
            with self.subTest(patch=patch):
                output, args = self.run_skip(dict(self.skip_env(), **patch))
                self.assertNotIn("FULL_JOB", output)
                self.assertEqual("success", json.loads(args[args.index("-d") + 1])["state"])

    def test_changed_image_runs_full(self):
        for patch in ({"FAKE_FINGERPRINT": "c3" * 32},
                      {"CI_JOB_NAME": "test-alpine"},
                      {"QORE_TREE_TESTED_ENV_TEST_UBUNTU": ""},
                      {"QORE_TREE_TESTED_ENV_TEST_UBUNTU": "A1" * 32, "FAKE_FINGERPRINT": "A1" * 32},
                      {"QORE_TREE_TESTED_ENV_TEST_UBUNTU": "a1" * 31, "FAKE_FINGERPRINT": "a1" * 31},
                      {"QORE_TREE_TESTED_ENV_TEST_UBUNTU": "a1" * 33, "FAKE_FINGERPRINT": "a1" * 33},
                      {"QORE_TREE_TESTED_ENV_TEST_UBUNTU": "a1" * 32 + "\nx"},
                      {"CI_JOB_NAME": ""}, {"CI_JOB_NAME": "tree-already-tested"}):
            with self.subTest(patch=patch):
                env = self.skip_env()
                if "QORE_TREE_TESTED_ENV_TEST_UBUNTU" in patch and not patch["QORE_TREE_TESTED_ENV_TEST_UBUNTU"]:
                    del env["QORE_TREE_TESTED_ENV_TEST_UBUNTU"]
                    patch = {}
                output, args = self.run_skip(dict(env, **patch))
                self.assertIn("FULL_JOB", output)
                self.assertIsNone(args)

    def test_fingerprint_failure_runs_full_without_recording(self):
        (self.repo / "ci-environment.txt").write_text("a1" * 32 + "\n")
        for patch in ({"FAKE_FINGERPRINT_EXIT": "1"},
                      {"QORE_CI_TOOLS_DIR": str(self.directory / "no-tools")}):
            with self.subTest(patch=patch):
                output, args = self.run_skip(dict(self.skip_env(), **patch))
                self.assertIn("FULL_JOB", output)
                self.assertIn("fingerprint is unavailable", output)
                self.assertIsNone(args)
                # A stale fingerprint from an earlier run must not be uploaded.
                self.assertIsNone(self.recorded_fingerprint())

    def test_image_environment_file_is_sourced_in_a_subshell(self):
        env = self.skip_env()
        del env["FAKE_FINGERPRINT"]
        env_file = self.directory / "env.sh"
        env_file.write_text(f"export FAKE_FINGERPRINT={self.ubuntu_fingerprint}\n")
        env["QORE_CI_ENV_FILE"] = str(env_file)
        output, args = self.run_skip(env)
        self.assertNotIn("FULL_JOB", output)
        self.assertIsNotNone(args)
        # Without a skip, the variables set by the environment file stay in the subshell.
        output, _ = self.run_skip(dict(env, QORE_CI_FORCE_FULL="1"),
                                  after='echo "FULL_JOB leaked=${FAKE_FINGERPRINT:-}"')
        self.assertIn("FULL_JOB leaked=\n", output)
        self.assertEqual(self.ubuntu_fingerprint + "\n", self.recorded_fingerprint())

    def test_skip_publishes_success_and_exits_before_work(self):
        for shell in ("sh", "bash"):
            with self.subTest(shell=shell):
                output, args = self.run_skip(self.skip_env(), shell)
                self.assertNotIn("FULL_JOB", output)
                self.assertIn(f"https://api.github.com/repos/qoretechnologies/module-ncurses/statuses/{self.head}", args)
                body = json.loads(args[args.index("-d") + 1])
                self.assertEqual("success", body["state"])
                self.assertEqual("module-ncurses", body["context"])
                self.assertEqual("https://git.example.invalid/mirror/module-ncurses/-/pipelines/100", body["target_url"])

    def test_skip_requires_valid_matching_evidence(self):
        for patch in ({"QORE_TREE_TESTED_CHECKED": ""}, {"QORE_TREE_TESTED_IN": ""},
                      {"QORE_TREE_TESTED_IN": "0"}, {"QORE_TREE_TESTED_IN": "100\ninjected"},
                      {"QORE_TREE_TESTED_IN": "200"}, {"QORE_TREE_TESTED_SHA": "abc"},
                      {"QORE_TREE_TESTED_SHA": "g" * 40}, {"QORE_TREE_TESTED_TREE": ""},
                      {"QORE_TREE_TESTED_TREE": "a" * 40}, {"GITHUB_ACCESS_TOKEN": ""},
                      {"CI_COMMIT_BRANCH": "feature"}, {"CI_PIPELINE_SOURCE": "web"},
                      {"CI_PIPELINE_SOURCE": "schedule"}, {"QORE_CI_FORCE_FULL": "1"}):
            with self.subTest(patch=patch):
                output, args = self.run_skip(dict(self.skip_env(), **patch))
                self.assertIn("FULL_JOB", output)
                self.assertIsNone(args)

    def test_skip_without_checkout_runs_full(self):
        env = self.skip_env()
        self.repo = self.directory
        output, args = self.run_skip(env)
        self.assertIn("FULL_JOB", output)
        self.assertIsNone(args)

    def test_status_failure_runs_full(self):
        output, args = self.run_skip(dict(self.skip_env(), STATUS_EXIT="22"))
        self.assertIn("FULL_JOB", output)
        self.assertIsNotNone(args)


if __name__ == "__main__":
    unittest.main()
