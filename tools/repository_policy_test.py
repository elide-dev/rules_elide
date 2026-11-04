# Copyright 2026 rules_elide contributors
# SPDX-License-Identifier: Apache-2.0
"""Regression checks for workflow privilege, pinning, and scanner boundaries."""
from pathlib import Path
import re

import pytest
import yaml

ROOT = Path(__file__).resolve().parents[1]
# Exact exceptions, not a wildcard for all bazel-contrib actions or versions.
BCR_TAG_EXCEPTIONS = {
    "bazel-contrib/.github/.github/workflows/release_ruleset.yaml@v7.7.0",
    "bazel-contrib/publish-to-bcr/.github/workflows/publish.yaml@v1.6.0",
}


def read_yaml(path):
    # BaseLoader preserves 'on' as a string and does not construct Python objects.
    return yaml.load(path.read_text(), Loader=yaml.BaseLoader)


def workflow_errors(workflow, filename):
    errors = []
    if "permissions" not in workflow:
        errors.append("explicit workflow permissions are required")
    permissions = workflow.get("permissions", {})
    if not isinstance(permissions, dict) or any(v != "read" for v in permissions.values()):
        errors.append("workflow permissions must be read-only")
    if "pull_request_target" in workflow.get("on", {}):
        errors.append("privileged pull_request_target trigger")
    for job in workflow.get("jobs", {}).values():
        if job.get("secrets") == "inherit":
            errors.append("unscoped reusable workflow secrets")
        for entry in [job, *job.get("steps", [])]:
            action = entry.get("uses", "")
            if not action:
                continue
            if action.startswith("github/codeql-action/"):
                errors.append("CodeQL action is not permitted")
            pinned = re.fullmatch(r"[^@]+@[0-9a-f]{40}", action)
            exception = filename == "release.yml" and action in BCR_TAG_EXCEPTIONS
            if not action.startswith("./") and not pinned and not exception:
                errors.append("remote action must be SHA-pinned")
            if action.startswith("actions/checkout@"):
                if entry.get("with", {}).get("persist-credentials") != "false":
                    errors.append("checkout must not persist credentials")
    return errors


def test_repository_workflows_obey_security_boundaries():
    for path in (ROOT / ".github/workflows").glob("*.yml"):
        assert not workflow_errors(read_yaml(path), path.name), path.name


@pytest.mark.parametrize("change,expected", [
    ({"permissions": "write-all"}, "read-only"),
    ({"on": {"pull_request_target": {}}}, "pull_request_target"),
    ({"jobs": {"scan": {"steps": [{"uses": "github/codeql-action/init@" + "a" * 40}]}}}, "CodeQL"),
    ({"jobs": {"scan": {"steps": [{"uses": "actions/checkout@v7"}]}}}, "SHA-pinned"),
    ({"jobs": {"scan": {"steps": [{"uses": "actions/checkout@" + "a" * 40}]}}}, "persist credentials"),
    ({"jobs": {"publish": {"secrets": "inherit"}}}, "unscoped"),
])
def test_policy_rejects_privilege_and_pinning_regressions(change, expected):
    workflow = {"permissions": {"contents": "read"}, **change}
    assert any(expected in error for error in workflow_errors(workflow, "test.yml"))


def test_bcr_exception_is_limited_to_release_and_exact_version():
    action = next(iter(BCR_TAG_EXCEPTIONS))
    workflow = {"permissions": {"contents": "read"}, "jobs": {"release": {"uses": action}}}
    assert not workflow_errors(workflow, "release.yml")
    assert workflow_errors(workflow, "ci.yml")
    workflow["jobs"]["release"]["uses"] = action.rsplit("@", 1)[0] + "@main"
    assert workflow_errors(workflow, "release.yml")


def test_dependency_automation_covers_repository_tools():
    updates = read_yaml(ROOT / ".github/dependabot.yml")["updates"]
    targets = {(item["package-ecosystem"], item["directory"]) for item in updates}
    assert {("github-actions", "/"), ("pip", "/"), ("pip", "/benchmarks/codspeed")} <= targets


def test_security_workflow_runs_on_contributions_and_schedule():
    workflow = read_yaml(ROOT / ".github/workflows/security.yml")
    assert {"push", "pull_request", "schedule"} <= workflow["on"].keys()
    commands = "\n".join(step.get("run", "") for job in workflow["jobs"].values() for step in job.get("steps", []))
    assert "zizmor --offline" in commands
    assert "repository_policy_test.py" in commands


def test_scorecard_inspects_git_tree_including_export_ignored_workflows():
    workflow = read_yaml(ROOT / ".github/workflows/scorecards.yml")
    steps = workflow["jobs"]["analysis"]["steps"]
    scanner = next(step for step in steps if step.get("uses", "").startswith("ossf/scorecard-action@"))
    assert scanner["with"]["file_mode"] == "git"
    assert scanner["with"]["results_format"] == "json"


def test_workflow_cannot_inherit_implicit_token_permissions():
    assert workflow_errors({"jobs": {}}, "test.yml")
