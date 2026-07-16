# GitHub-native Agent Framework

## Purpose

The framework converts the repository workflow into a controlled closed loop:

1. Read `.agent/roadmap.yml`.
2. Select the first incomplete stage.
3. Create an `agent/<task>` branch from `main`.
4. Modify RTL, testbench, CI, and documentation as required.
5. Run local regression when a runner is available.
6. Open a pull request and apply the `agent-automerge` label.
7. GitHub Actions runs `RTL Regression`.
8. A successful, mergeable, same-repository PR is squash-merged automatically.
9. The next agent invocation continues from the updated roadmap.

## What runs entirely in GitHub

- RTL regression
- merge gating
- squash merge and branch deletion
- roadmap and policy storage

## What requires an external coding agent

GitHub Actions alone cannot safely invent and validate arbitrary RTL fixes. A coding agent requires a hosted service or self-hosted runner with an LLM API. The external agent should receive only the minimum required repository permissions and create pull requests rather than writing directly to `main`.

Required capabilities:

- clone and edit the repository
- run Icarus Verilog regression
- inspect GitHub Actions logs
- push to `agent/*` branches
- open/update pull requests

Optional secret names for a future runner:

- `AGENT_LLM_API_KEY`
- `AGENT_GITHUB_TOKEN` when the default token is insufficient

Secrets must be configured in GitHub settings and never committed.

## Enabling automatic merge

Add the `agent-automerge` label only to PRs that are within the approved roadmap. The privileged workflow checks repository ownership, branch prefix, draft state, mergeability, CI success, and requested-change reviews before merging.

## Recommended repository protection

Protect `main`, require the `RTL Regression` check, disallow force pushes, and require pull requests. The auto-merge workflow should be allowed to merge but not bypass required checks.
