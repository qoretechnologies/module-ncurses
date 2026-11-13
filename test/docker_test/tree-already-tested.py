#!/usr/bin/env python3
# Copyright (C) 2026 Qore Technologies, s.r.o.
# SPDX-License-Identifier: MIT
"""Find successful CI for an identical develop tree; uncertainty runs the full pipeline.

Based on qore commit 22a9b5c721's tree-already-tested.sh. Python is available in
both module CI images and lets us validate API JSON and platform job evidence.

A candidate pipeline also needs the image fingerprint that each platform job
recorded in its ci-environment.txt artifact (see ci-environment.py). Both are
exported; each platform job skips only when its own image has the same fingerprint.
"""

import json
import os
import re
from http.client import HTTPException
from pathlib import Path
import subprocess
from urllib.error import URLError
from urllib.parse import urlencode
from urllib.request import Request, urlopen


REQUIRED_JOBS = frozenset(("test-ubuntu", "test-alpine"))
ENVIRONMENT_ARTIFACT = "ci-environment.txt"
FINGERPRINT = re.compile(r"[0-9a-f]{64}\n?")
# Upstream Qore pipelines trigger develop pipelines with the source "pipeline".
ELIGIBLE_SOURCES = frozenset(("push", "pipeline"))


class EvidenceUnavailable(Exception):
    """No trustworthy evidence is available; this is not a reason to skip tests."""


class GitLabApi:
    def __init__(self, env):
        self.base = env["CI_API_V4_URL"].rstrip("/")
        self.headers = [
            {header: env[token]}
            for header, token in (("JOB-TOKEN", "CI_JOB_TOKEN"),
                                  ("PRIVATE-TOKEN", "QORE_CI_READ_API_TOKEN"))
            if env.get(token)
        ]

    def fetch(self, path, parse):
        # Do not print exceptions, URLs with credentials, response bodies or tokens.
        for headers in self.headers:
            try:
                request = Request(self.base + path, headers=headers)
                with urlopen(request, timeout=15) as response:
                    return parse(response)
            except (OSError, URLError, HTTPException, ValueError):
                continue
        raise EvidenceUnavailable("cannot read valid pipeline evidence")

    def read(self, path):
        return self.fetch(path, json.load)

    def read_fingerprint(self, path):
        """Return a recorded image fingerprint; anything else is not evidence."""
        def parse(response):
            data = response.read(1024).decode("ascii")
            if not FINGERPRINT.fullmatch(data):
                raise ValueError("invalid fingerprint")
            return data.strip()
        return self.fetch(path, parse)


def git(*args):
    return subprocess.run(
        ["git", *args], check=True, capture_output=True, text=True, timeout=15
    ).stdout.strip()


def eligible(env):
    return (env.get("CI_COMMIT_BRANCH") == "develop"
            and env.get("CI_PIPELINE_SOURCE") in ELIGIBLE_SOURCES
            and env.get("QORE_CI_FORCE_FULL") != "1")


def positive_id(value):
    return type(value) is int and value > 0


def job_fingerprints(project, platform_jobs, api):
    """Return each platform job's recorded fingerprint, or None if any is unavailable.

    Older pipelines and expired artifacts have none. Such a pipeline is not evidence,
    but an older pipeline for the same tree may still be.
    """
    fingerprints = {}
    for job in platform_jobs:
        if not positive_id(job.get("id")):
            return None
        try:
            fingerprints[job["name"]] = api.read_fingerprint(
                f"/projects/{project}/jobs/{job['id']}/artifacts/{ENVIRONMENT_ARTIFACT}")
        except EvidenceUnavailable:
            return None
    return fingerprints


def find_evidence(env, api):
    project = int(env["CI_PROJECT_ID"])
    current_pipeline = int(env["CI_PIPELINE_ID"])
    if project <= 0 or current_pipeline <= 0:
        raise EvidenceUnavailable("invalid CI identity")
    head = git("rev-parse", "HEAD")
    if head != env["CI_COMMIT_SHA"]:
        raise EvidenceUnavailable("checkout does not match the pipeline commit")
    tree = git("rev-parse", "HEAD^{tree}")
    candidates = [head]
    # Missing shallow-history parents cannot establish an identical tree. No fetch
    # is necessary: retaining the full pipeline is the conservative outcome.
    for parent in git("rev-list", "--parents", "-n", "1", "HEAD").split()[1:]:
        try:
            if git("rev-parse", parent + "^{tree}") == tree:
                candidates.append(parent)
        except subprocess.CalledProcessError:
            continue

    for commit in candidates:
        query = urlencode({"sha": commit, "status": "success", "per_page": 20})
        pipelines = api.read(f"/projects/{project}/pipelines?{query}")
        if not isinstance(pipelines, list):
            raise EvidenceUnavailable("pipeline response is not a list")
        for pipeline in pipelines:
            if not isinstance(pipeline, dict):
                continue
            pipeline_id = pipeline.get("id")
            if (not positive_id(pipeline_id) or pipeline_id == current_pipeline
                    or pipeline.get("project_id") != project
                    or pipeline.get("sha") != commit
                    or pipeline.get("status") != "success"):
                continue
            jobs = api.read(f"/projects/{project}/pipelines/{pipeline_id}/jobs"
                            "?per_page=100&include_retried=false")
            if not isinstance(jobs, list):
                raise EvidenceUnavailable("job response is not a list")
            # A successful pipeline with only a lint/manual/subset job does not
            # establish that both platform suites passed. Retried jobs are omitted.
            platform_jobs = [job for job in jobs if isinstance(job, dict)
                             and isinstance(job.get("name"), str)
                             and job.get("name") in REQUIRED_JOBS]
            if (len(platform_jobs) == len(REQUIRED_JOBS)
                    and {job["name"] for job in platform_jobs} == REQUIRED_JOBS
                    and all(job.get("status") == "success" for job in platform_jobs)):
                fingerprints = job_fingerprints(project, platform_jobs, api)
                if fingerprints is not None:
                    return pipeline_id, commit, tree, fingerprints
    return None


def main():
    out = Path("tree-tested.env")
    # Always replace stale evidence, even when this invocation is ineligible.
    out.write_text("QORE_TREE_TESTED_CHECKED=1\n")
    env = os.environ
    if not eligible(env):
        print("ineligible pipeline or full verification requested: running the full pipeline")
        return
    try:
        evidence = find_evidence(env, GitLabApi(env))
    except (EvidenceUnavailable, KeyError, ValueError, OSError,
            subprocess.SubprocessError):
        print("cannot establish successful CI for this tree: running the full pipeline")
        return
    if evidence is None:
        print("no successful platform pipeline for this tree: running the full pipeline")
        return
    pipeline, commit, tree, fingerprints = evidence
    out.write_text("QORE_TREE_TESTED_CHECKED=1\n"
                   f"QORE_TREE_TESTED_IN={pipeline}\n"
                   f"QORE_TREE_TESTED_SHA={commit}\n"
                   f"QORE_TREE_TESTED_TREE={tree}\n"
                   + "".join(f"QORE_TREE_TESTED_ENV_{name.upper().replace('-', '_')}={value}\n"
                             for name, value in sorted(fingerprints.items())))
    print(f"tree {tree} passed both platform jobs in pipeline {pipeline} on {commit}")


if __name__ == "__main__":
    main()
