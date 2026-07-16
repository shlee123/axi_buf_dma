# AXI DMA Agent Policy

This repository supports an opt-in, GitHub-native development loop.

## Trust boundary

The privileged auto-merge workflow does not check out or execute pull-request code. It only queries GitHub metadata and merges an eligible same-repository pull request.

## Merge gate

A pull request may be merged automatically only when all conditions are true:

1. The pull request targets `main`.
2. The head branch belongs to this repository and starts with `agent/`.
3. The pull request has the `agent-automerge` label.
4. The pull request is not a draft.
5. GitHub reports it as mergeable.
6. The latest `RTL Regression` workflow for the pull-request head commit completed successfully.
7. The latest `Synthesis Check` workflow for the pull-request head commit completed successfully.
8. No review has requested changes.

The merge method is squash.

## RTL quality policy

Changes under `rtl/` must satisfy all of the following:

- no simulation-only constructs such as delays, `initial`, system tasks, classes, mailboxes, queues, DPI, `force`, or `release`;
- no register or memory object may have multiple procedural write owners unless the target technology and implementation intent are explicitly documented and validated;
- counters and storage widths should be derived from parameters rather than unconstrained integers when practical;
- parameterized interfaces must either support the advertised range or contain an explicit elaboration-time restriction;
- both simulation regression and synthesis-oriented checks must pass.

Open-source checks are the mandatory CI baseline. Vivado `synth_design` or Synopsys Design Compiler is the sign-off synthesis stage when an appropriately licensed runner is available.

## Failure behavior

A failed, missing, pending, or cancelled check blocks merge. The agent must diagnose logs, update the same branch, and wait for a new successful run. The workflow never bypasses branch protection and never force-pushes `main`.

## Human decision points

Automation must stop for specification ambiguity, interface compatibility changes, security-sensitive workflow changes, technology-specific memory inference decisions, or modifications that require external credentials. Such work requires explicit approval in the pull request or issue.

## External coding agent interface

A self-hosted or hosted coding agent may consume `.agent/roadmap.yml`, create an `agent/<task>` branch, update RTL/tests/docs, and open a pull request. External credentials must be stored as GitHub Actions secrets and must not be committed to this repository.
