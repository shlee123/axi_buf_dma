# AXI Buffer DMA Agent Policy

## Trust boundary

Privileged workflows must not check out or execute pull-request code. Agent changes use same-repository `agent/*` branches.

## Merge gate

An agent pull request may be squash-merged only when it targets `main`, is non-draft and mergeable, has no requested changes, and its latest head commit passes both `RTL Regression` and `Synthesis Check`.

## RTL quality gate

RTL must contain no simulation-only constructs, unresolved references, inferred latches, or multiple procedural drivers. Parameter-dependent widths must be explicit. The synchronous SRAM wrapper remains the technology-replacement boundary.

## Failure behavior

Failed, missing, skipped, cancelled, or pending checks block merge. Fixes must be pushed to the same task branch and revalidated.

## Human decision points

Stop for specification ambiguity, interface compatibility changes, security-sensitive workflow changes, technology-specific SRAM decisions, or external credential requirements.
