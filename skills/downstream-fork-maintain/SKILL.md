---
name: downstream-fork-maintain
description: Maintain Git forks and prepare and continuously maintain PRs for upstream submission
---

# Downstream Fork Maintenance

## Overview

The purpose of maintaining a downstream fork is not to let it gradually drift away from upstream and become an independently evolving hard fork. It is to continuously maintain a set of patches that remain usable, buildable, and testable.

The downstream follows upstream while promptly providing users with code and artifacts containing these features and fixes when PRs have not yet been merged, upstream maintainers are busy, or a patch is niche but urgent. It is not a static patch archive, but a distribution channel where patches actually run and remain under validation.

A usable integrated result also lets more people freely test upstream PRs, downstream patches, and their own changes. As upstream moves forward, continuously building, testing, and reviewing the patches reduces the risk that PRs rot after falling behind upstream, exposes problems earlier, and helps changes eventually flow upstream.

## Core Goals

- Prevent the downstream fork from becoming a hard fork that remains separated from upstream.
- Continuously follow upstream rather than preserve only a static branch from one point in time.
- Keep every patch independently buildable, testable, reviewable, and suitable for submission or ongoing PR maintenance.
- Provide directly usable code and artifacts through the main or release branch.
- Let users test PRs, patches, and their own changes against a real integrated result.
- Detect conflicts between patches and upstream early, keep PRs mergeable, and help patches flow upstream.

## Branch Model

The repository determines the actual branch names. Do not assume a default branch, remote name, or hosting platform.

### Upstream Main Branch

The upstream main branch is the starting point for every rebuild. Fetch its latest state before syncing, and use a specific upstream commit as the baseline for the current build.

The downstream main or release branch must not become the new baseline for patches. A patch should always make clear what it changes relative to upstream.

### Patch Branches

Maintain each independent patch on its own branch and hold it to normal PR standards:

- Keep the scope focused and the commits and explanation clear.
- Include enough tests to demonstrate the behavior.
- Make it independently buildable and reviewable on the current upstream.
- Declare only necessary dependencies and avoid tying it to other downstream patches.
- Make it suitable for direct submission as an upstream PR or for continued maintenance of an existing PR.
- In general, a patch branch should not modify release files centrally maintained by upstream maintainers, such as `CHANGELOG`. Necessary documentation changes should be limited to code comments, API documentation, and implementation notes directly related to that patch. Maintain the downstream patch list and release notes centrally on the maintenance branch.

The patch branch is the long-term source of truth for that patch. An integration commit on the release branch is not the patch's only copy and must not carry temporary fixes that exist only in release history.

### Temporary Compatibility Patch Branches

When several patches apply independently but produce a build, test, or behavior conflict when combined that does not belong to any individual PR branch, maintain a compatibility patch on a `tmp/patch/<name>` branch.

Such a branch addresses only the downstream compatibility problem for a specific patch combination. Do not force the fix into one of the independent PR branches, and do not let it become a new long-term feature branch. It must state which patches it depends on, where it belongs in the order, which combined behavior it validates, and when it can be retired.

In the sync orchestration on the `ci` branch, add `tmp/patch/<name>` in order immediately after the patches it depends on. If an earlier Git merge has already produced unresolved textual conflicts, a later compatibility branch cannot cross that conflict. In that case, the `ci` orchestration must explicitly apply the corresponding compatibility handling at the step where the conflict occurs before continuing the rebuild; merely appending the branch to the end of the list is not enough.

When a patch cannot merge into the accumulated release candidate at all (not just a small textual conflict), the resolution mechanism is a position-dependent trade-off, not a blanket rule. Choose per patch, cheapest correct option first:

1. **Real merge or seam-diff against an actual ancestor** — preferred when the patch's neighbor in the integration order is a real git ancestor (e.g. patch B branched off patch A). Merge-base exists, so `git merge` or `git diff <seam> <tip> | git apply --3way` works with no extra infrastructure.

2. **Two-commit compatibility branch** — when the patch's real parent in the sequence is itself a squash-integrated commit on the rebuilt release branch. Squash integration records no ancestry, so merge-base falls back to upstream and every downstream-touched file reports add/add conflicts. Build a compat branch with exactly two commits: a *base* commit whose tree is the accumulated release candidate the patch expects to land on, and a *tip* commit with the patch's resolved content. The sync step then applies `git diff <tip>^ <tip> | git apply --3way`, which is ancestry-irrelevant — only trees matter. Keep the branch at exactly two commits (rebuild via `git commit-tree` rather than adding fixups): the step diffs `tip^..tip`, so any extra commit shrinks or shifts the applied delta.

   Cost warning: the base commit's tree is the accumulated result of *every* patch earlier in the integration order. For a patch late in the sequence, constructing that base means re-deriving the sync prefix itself (measured: ~20 merge/cherry-pick operations plus ~8 hand-resolved union conflicts for a position-19 patch), and it goes stale on every upstream advance. Each hand-resolved union must be compile-gated (`tsgo`/`biome` or the repo's checker) before pushing — diff-shape comparison against the release branch cannot catch a missing or extra brace in a different pre-image.

3. **Narrow resolver script on `ci`** — acceptable for late-sequence patches where a compat base would recreate most of the sync. Keep the script small and patch-specific; a resolver that grows to reimplement merge semantics is a sign the patch should be rebased or retired instead.

Whatever mechanism a sync step uses, any workflow-level assertion about that step must check content intrinsic to the patch itself, not patterns produced by the resolver's output. An assertion tied to resolver output breaks silently when the resolver is retired or replaced.

### The `ci` Maintenance Branch

When the fork needs to carry automation such as GitHub Actions, maintain a separate `ci` branch. If the repository already has an equivalent branch, retain its name. This branch is the downstream fork's release overlay and is responsible for:

- Downstream-specific CI/CD, packaging, releases, and repository configuration.
- Automatically fetching upstream, integrating patches in order, rebuilding the release branch, and pushing safely.
- Additional downstream single-patch tests and multi-patch integration tests.
- The downstream README, patch list, release notes, and any downstream-specific maintenance instructions.
- The fixed integration order of enabled regular patches and `tmp/patch/<name>` branches.
- Deterministic release-projection scripts when the distributed tree is a subset or rearrangement of upstream.

If the user or downstream fork has maintenance requirements beyond this general workflow, keep them in a downstream-owned `MAINTAIN.md` on the `ci` branch. It should state how this particular fork must be maintained and record any special rules that future maintainers and automation must follow. Treat it as repository-specific guidance: read it before changing patch branches, sync orchestration, or release history, and keep it current when those requirements change.

When the special maintenance rules might otherwise be missed, add a concise notice in the `ci` branch's `README.md` linking to `MAINTAIN.md`. Keep the detailed rules in `MAINTAIN.md` rather than duplicating them in the README.

The `ci` branch may centrally carry downstream release automation, but do not mix product behavior patches into it. Runtime changes should remain on branches suitable for independent building, testing, and upstream PR submission.

### Projected Release Trees

A downstream may distribute only one upstream package or use a different directory layout. Keep two products distinct:

- The **source candidate** preserves upstream's layout. Apply selected upstream PR heads, regular product patches, and compatibility patches here, using exact pinned commits, then run their source-tree tests.
- The **release projection** is a deterministic `ci`-owned script that reads that candidate and writes an empty output directory. It may use ordinary `cp`, `mv`, and `rm` operations inside the output, but must not mutate the source candidate, fetch network state, create commits, or push.
- **Release-layout overlays** run only after projection and contain packaging, metadata, CI, or downstream documentation that has no upstream-tree home. Product behavior stays in source-layout patch branches before projection.

The default order is:

```text
upstream commit → upstream PRs → product patches → source validation
→ release projection → release-layout overlays → projected validation
```

Apply an upstream PR before projection because its paths, tests, and cross-package dependencies target the upstream tree. Applying it after files have moved requires a translated downstream-only patch and loses direct upstream compatibility.

To retain countable release history, project the upstream baseline once, then re-run the same projection after each source patch and commit that patch's projected output difference separately. A patch that produces no projected difference is empty for that release and must be investigated rather than hidden with an empty commit. Record the exact upstream and patch commits in a generated provenance file.

Keep the projection script project-specific and small. [`ref/project-release.sh`](ref/project-release.sh) provides the source/output boundary and an output-only customization point; copy it to the target `ci` branch and adapt it rather than making the skill guess a repository layout.

This skill includes the GitHub Actions file used by the current practice: [`ref/upstream-sync.yml`](ref/upstream-sync.yml). When GitHub auto-sync is needed, copy it as a starting point for `.github/workflows/upstream-sync.yml`, then adapt the upstream address, default/release branch, `ci` and patch lists, `tmp/patch/<name>` order, sync schedule, downstream-owned files, secrets, and checks for the target repository. The file retains project-specific configuration from its original project and must not be enabled without review.

When configuring `schedule`, first ask the user during which hours each day the sync should run. GitHub cron uses UTC by default unless the workflow explicitly sets a supported `timezone`. Do not schedule jobs at minute 0 of the hour: [GitHub's official documentation](https://docs.github.com/actions/using-workflows/events-that-trigger-workflows#schedule) states that load is high at the start of every hour, so scheduled jobs may be delayed or even dropped under sufficiently high load. To further avoid common five-minute marks, do not use a multiple of 5, such as 10, 15, 20, 30, 40, or 45. Randomly choose a minute from 1–59 that is not a multiple of 5 and write it as a fixed value in the workflow, for example by running `python -c 'import secrets; print(secrets.choice([m for m in range(1, 60) if m % 5]))'`. Here, “random” applies only when generating the configuration; do not make the workflow wait for a dynamic random delay on every run.

### Main or Release Branch

The main or release branch starts from the latest upstream and integrates the maintenance branch and required patch branches in a fixed order. It provides the complete code, builds, tests, and release artifacts. A projected release branch instead contains the deterministic output described above; its source candidate still starts from upstream and carries the countable patch integrations.

This branch represents only the current downstream integrated result. It is not the long-term maintenance source for any patch. A problem may first be reproduced and analyzed here, but the fix must return to the owning patch or maintenance branch, after which the integrated result must be regenerated.

In release history, each patch should appear as one clear, countable integration commit, making both the number of downstream patches and the number of commits the fork lags behind upstream visible.

## Workflow

### 1. Inspect the Current State

Before starting, read the repository's own maintenance and contribution instructions, including the downstream `MAINTAIN.md` when present and any README notice that points to it. Inspect the worktree, remotes, current branch, upstream relationships, and existing sync and release process. Preserve or work around any uncommitted user work; do not clean it up or overwrite it without permission.

### 2. Check Upstream Issues and Pull Requests Before Coding

Before implementing any new request or writing code, search the upstream issue tracker and pull requests for related discussion or implementation. Check open and closed issues and open, draft, closed, and merged PRs; search not only the request's exact wording, but also relevant component names, error messages, and reasonable synonyms. Follow linked issues, reviews, commits, and replacement PRs far enough to establish the current status.

Use the result to choose the next action:

- If upstream already implements the requirement, verify the applicable version and behavior before deciding whether any downstream change is still needed.
- If an active issue or PR covers it, prefer contributing to, testing, updating, or temporarily carrying that work rather than creating an unaware duplicate.
- If an earlier approach was rejected, reverted, or superseded, understand the stated reason before proposing a new implementation.
- Record the relevant upstream links and the conclusion in the working plan, patch notes, or PR description so the decision remains reviewable.

When related upstream issues or PRs exist, do not proceed directly to implementation. First establish their actual status, scope, decisions, unresolved concerns, review feedback, implementation state, and relationship to the user's request. Then synthesize the relevant upstream information for the user instead of forwarding a raw list of links. Clearly explain what was learned, how it affects the current assumptions and plan, and which parts of the original request remain necessary.

If that investigation produces a new finding that could change the scope, approach, priority, ownership, compatibility strategy, or need for the work, explicitly ask the user whether the plan should be changed. Pause implementation until the user confirms whether to retain or revise the plan. Do not silently reinterpret the request based on upstream discussion.

Do not begin implementation merely because one exact-term search returned no result. Perform a reasonable search first; if no relevant discussion or implementation is found, state that result and continue.

### 3. Reproduce on the Complete Integrated Result

First reproduce the problem on the current main or release branch to confirm how it occurs in the patch combination users actually run.

During analysis, distinguish among:

- A problem in upstream itself.
- A problem in one independent patch.
- An integration problem between patches; if it belongs to no individual PR, place it in `tmp/patch/<name>`.
- A problem in CI, packaging, syncing, or downstream documentation.

### 4. Locate and Fix the Owning Branch

Find the patch branch responsible for the behavior and complete the fix and tests on that branch. If the problem concerns compatibility among multiple patches, create or update `tmp/patch/<name>`. If it concerns release automation or other downstream maintenance work, modify the `ci` branch.

Do not commit a conflict fix or product fix only to the main or release branch. It would be lost on the next rebuild from upstream and would prevent the patch from being reviewed independently.

### 5. Keep the Patch Independently Usable

Following repository conventions, update the patch onto the latest upstream, resolve conflicts on the patch branch, and run the builds and tests required by that patch.

Confirm that it does not rely on hidden changes in the release branch and can still be explained, reviewed, and submitted as a PR on its own. If an upstream PR already exists, update it as well and continue maintaining it in response to upstream feedback.

### 6. Rebuild the Main or Release Branch

Fetch the latest upstream again and create a clean source candidate from a specific upstream head. Integrate selected upstream PR commits first, followed by regular patches and required `tmp/patch/<name>` branches in the fixed order declared by `ci`.

For a same-layout release, integrate the release overlay as established by the repository. For a projected release, validate the source candidate, run the `ci` projection into an empty output tree, apply release-layout overlays, and validate the projected package or artifact before constructing the release history. The projection must be reproducible from the recorded refs without modifying any source branch.

Each regular patch and temporary compatibility patch should produce its own clear integration commit in release history. A repository may use squash merge or the equivalent method established by the project, but the result should be easy to review and count.

### 7. Validate the Usable Result

Run the repository's required checks against the complete candidate version, covering at least:

- Focused tests for each patch itself.
- Integrated behavior after combining multiple patches.
- Whether CI, packaging, projection tooling, and downstream documentation come from the correct branches.
- For a projected release, whether the output contains only the intended tree, records exact source provenance, and can be installed or packaged through the advertised distribution path.
- Whether the code or artifacts users actually obtain correspond to the validated commit.

Update the remote main or release branch only after both the candidate code and artifacts pass all required validation.

## Automatic Sync

The purpose of automatic sync is to periodically regenerate a usable downstream release result from a new upstream head, not to keep accumulating fixes on an old release branch.

The sync process should:

1. Use the repository's accepted concurrency controls to prevent two sync or release processes from updating the same branch at once.
2. Fetch the latest upstream, the `ci` branch, all enabled regular patches, and all `tmp/patch/<name>` branches.
3. Create a clean candidate branch from the explicitly selected upstream commit for that run.
4. Integrate selected upstream PR commits, regular patches, and temporary compatibility patches in the configured source-tree order.
5. For a same-layout release, integrate the release overlay. For a projected release, validate the source candidate, run the `ci` projection into an empty output tree, and apply release-layout overlays.
6. Give every patch one clear, countable integration commit; for projected releases, re-project after each source patch so its output difference remains separately countable.
7. Run the required source checks plus projected-package, build, and artifact checks.
8. Verify that no unknown update has appeared on the remote branch since it was fetched.
9. Update the release branch with a safe push method and ensure subsequent CI or releases run against the exact commit.

If a patch conflicts, stop the rebuild immediately. Return to the corresponding patch branch to resolve, test, and review it, then restart from a clean upstream baseline. Do not resolve the conflict directly on the release branch.

If a patch becomes empty, stop and confirm why. It may already have landed upstream, been superseded by another upstream change, or have been maintained incorrectly. Fix or retire it after confirmation; do not hide the state change with an empty commit.

When an update rewrites release history, use the repository's accepted lease protection, such as `--force-with-lease`. A lease failure means the remote has changed: fetch again, investigate, and rebuild. Do not overwrite unknown remote commits or use an unconditional force push.

## Patch Lifecycle

### Adding a Patch

1. Create an independent patch branch from an appropriate baseline on the latest upstream.
2. Limit its scope and add explanations and tests so that it meets PR standards.
3. Confirm that it can be built, tested, and reviewed independently.
4. Add it at an explicit position in the integration configuration.
5. Rebuild the release branch and validate the complete code and artifacts.
6. Submit an upstream PR when it is suitable to flow upstream.

### Maintaining a Patch

As upstream advances, update the patch branch promptly. Resolve conflicts, adjust the implementation, and run tests on that branch. Do not wait until the release branch can no longer build.

Continue following the review and CI of its upstream PR. If the patch depends on another patch, keep the dependency minimal and clear, and ensure the integration order matches the actual dependency.

### Maintaining a Temporary Compatibility Patch

When a problem caused by combining regular patches belongs to no individual PR branch:

1. Reproduce it in the complete release combination and confirm the dependencies.
2. Create `tmp/patch/<name>` containing only the changes and tests needed to solve that combination problem.
3. Place it after the related patches on the `ci` branch. If it addresses a textual merge conflict, apply the compatibility handling explicitly at the conflict step.
4. Rebuild and verify that the related patches work both independently and in combination.
5. Whenever the related patches, upstream implementation, or integration order changes, check first whether the compatibility patch can be retired.

### Retiring a Patch

When upstream merges the patch or provides equivalent behavior through another implementation, first confirm that the upstream version truly satisfies downstream needs and run the existing regression tests. Retire a temporary compatibility patch in the same order when its dependency combination no longer exists.

Then retire it in this order:

1. Remove the patch from the integration configuration and downstream README.
2. Regenerate the release branch from the latest upstream.
3. Verify that builds, tests, and artifacts no longer depend on the patch.
4. Confirm that the remote release result is correct.
5. Only then archive or delete the patch branch according to repository policy.

Do not first delete a patch branch that is still referenced by sync configuration, documentation, or the release process.

## Safety Rules

Before operating, inspect repository instructions, the worktree, remotes, and branch protections, and preserve uncommitted work. Use the repository's accepted concurrency controls and `--force-with-lease`. Do not bypass authentication, required checks, or branch protection, and do not overwrite remote changes you cannot explain.

Run projection scripts only with a disposable source worktree and a separate empty output directory. Permit destructive layout commands only inside that output boundary. A script that points `rm`, `mv`, or generated writes at the source checkout is unsafe and must stop before release construction.

A problem on the main or release branch must be fixed on the corresponding source branch. Stop on conflicts, empty patches, test failures, or differences of unknown origin; do not continue releasing from an uncertain state.

## Completion Checklist

- [ ] Before implementation began, related upstream open and closed issues and PRs were searched, and the relevant links and conclusion were recorded.
- [ ] When related upstream work existed, its actual status and implications were synthesized for the user; any plan-changing discovery was presented as an explicit choice and implementation waited for the user's decision.
- [ ] The rebuild started from the latest specific upstream commit.
- [ ] Selected upstream PRs were pinned and applied before any release projection.
- [ ] Every patch has its own branch and can be built, tested, and reviewed independently.
- [ ] Product patches are maintained separately from the CI/CD, packaging, syncing, and downstream documentation carried by the `ci` branch.
- [ ] When the fork has additional maintenance requirements, the `ci` branch carries an up-to-date `MAINTAIN.md`, the README points to it when necessary, and both files are preserved in the integrated result.
- [ ] Fixes were made on the corresponding regular patch, `tmp/patch/<name>`, or `ci` branch rather than existing only on the release branch.
- [ ] The `ci` branch declares a fixed order for regular and temporary compatibility patches, with one clear, countable integration commit per patch.
- [ ] Conflicts and empty patches were fixed on their source branches or retired through the defined process.
- [ ] The complete integrated result and its artifacts passed the required validation.
- [ ] When the release tree is projected, its script read a disposable source candidate, wrote an empty separate output tree, recorded exact provenance, and passed projected install/package checks.
- [ ] The push neither overwrote unknown remote changes nor bypassed authentication or branch protection.
- [ ] Patches merged upstream were removed from configuration and documentation and validated before their branches were deleted.
