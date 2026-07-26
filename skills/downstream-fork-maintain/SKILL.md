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

### The `ci` Maintenance Branch

When the fork needs to carry automation such as GitHub Actions, maintain a separate `ci` branch. If the repository already has an equivalent branch, retain its name. This branch is the downstream fork's release overlay and is responsible for:

- Downstream-specific CI/CD, packaging, releases, and repository configuration.
- Automatically fetching upstream, integrating patches in order, rebuilding the release branch, and pushing safely.
- Additional downstream single-patch tests and multi-patch integration tests.
- The downstream README, patch list, release notes, and any downstream-specific maintenance instructions.
- The fixed integration order of enabled regular patches and `tmp/patch/<name>` branches.

If the user or downstream fork has maintenance requirements beyond this general workflow, keep them in a downstream-owned `MAINTAIN.md` on the `ci` branch. It should state how this particular fork must be maintained and record any special rules that future maintainers and automation must follow. Treat it as repository-specific guidance: read it before changing patch branches, sync orchestration, or release history, and keep it current when those requirements change.

When the special maintenance rules might otherwise be missed, add a concise notice in the `ci` branch's `README.md` linking to `MAINTAIN.md`. Keep the detailed rules in `MAINTAIN.md` rather than duplicating them in the README.

The `ci` branch may centrally carry downstream release automation, but do not mix product behavior patches into it. Runtime changes should remain on branches suitable for independent building, testing, and upstream PR submission.

This skill includes the GitHub Actions file used by the current practice: [`ref/upstream-sync.yml`](ref/upstream-sync.yml). When GitHub auto-sync is needed, copy it as a starting point for `.github/workflows/upstream-sync.yml`, then adapt the upstream address, default/release branch, `ci` and patch lists, `tmp/patch/<name>` order, sync schedule, downstream-owned files, secrets, and checks for the target repository. The file retains project-specific configuration from its original project and must not be enabled without review.

When configuring `schedule`, first ask the user during which hours each day the sync should run. GitHub cron uses UTC by default unless the workflow explicitly sets a supported `timezone`. Do not schedule jobs at minute 0 of the hour: [GitHub's official documentation](https://docs.github.com/actions/using-workflows/events-that-trigger-workflows#schedule) states that load is high at the start of every hour, so scheduled jobs may be delayed or even dropped under sufficiently high load. To further avoid common five-minute marks, do not use a multiple of 5, such as 10, 15, 20, 30, 40, or 45. Randomly choose a minute from 1–59 that is not a multiple of 5 and write it as a fixed value in the workflow, for example by running `python -c 'import secrets; print(secrets.choice([m for m in range(1, 60) if m % 5]))'`. Here, “random” applies only when generating the configuration; do not make the workflow wait for a dynamic random delay on every run.

### Main or Release Branch

The main or release branch starts from the latest upstream and integrates the maintenance branch and required patch branches in a fixed order. It provides the complete code, builds, tests, and release artifacts.

This branch represents only the current downstream integrated result. It is not the long-term maintenance source for any patch. A problem may first be reproduced and analyzed here, but the fix must return to the owning patch or maintenance branch, after which the integrated result must be regenerated.

In release history, each patch should appear as one clear, countable integration commit, making both the number of downstream patches and the number of commits the fork lags behind upstream visible.

## Workflow

### 1. Inspect the Current State

Before starting, read the repository's own maintenance and contribution instructions, including the downstream `MAINTAIN.md` when present and any README notice that points to it. Inspect the worktree, remotes, current branch, upstream relationships, and existing sync and release process. Preserve or work around any uncommitted user work; do not clean it up or overwrite it without permission.

### 2. Reproduce on the Complete Integrated Result

First reproduce the problem on the current main or release branch to confirm how it occurs in the patch combination users actually run.

During analysis, distinguish among:

- A problem in upstream itself.
- A problem in one independent patch.
- An integration problem between patches; if it belongs to no individual PR, place it in `tmp/patch/<name>`.
- A problem in CI, packaging, syncing, or downstream documentation.

### 3. Locate and Fix the Owning Branch

Find the patch branch responsible for the behavior and complete the fix and tests on that branch. If the problem concerns compatibility among multiple patches, create or update `tmp/patch/<name>`. If it concerns release automation or other downstream maintenance work, modify the `ci` branch.

Do not commit a conflict fix or product fix only to the main or release branch. It would be lost on the next rebuild from upstream and would prevent the patch from being reviewed independently.

### 4. Keep the Patch Independently Usable

Following repository conventions, update the patch onto the latest upstream, resolve conflicts on the patch branch, and run the builds and tests required by that patch.

Confirm that it does not rely on hidden changes in the release branch and can still be explained, reviewed, and submitted as a PR on its own. If an upstream PR already exists, update it as well and continue maintaining it in response to upstream feedback.

### 5. Rebuild the Main or Release Branch

Fetch the latest upstream again, create a clean candidate branch from a specific upstream head, and then integrate the release overlay, regular patches, and required `tmp/patch/<name>` branches in the fixed order declared by the `ci` branch.

Each regular patch and temporary compatibility patch should produce its own clear integration commit in release history. A repository may use squash merge or the equivalent method established by the project, but the result should be easy to review and count.

### 6. Validate the Usable Result

Run the repository's required checks against the complete candidate version, covering at least:

- Focused tests for each patch itself.
- Integrated behavior after combining multiple patches.
- Whether CI, packaging, and downstream documentation come from the correct branches.
- Whether the code or artifacts users actually obtain correspond to the validated commit.

Update the remote main or release branch only after both the candidate code and artifacts pass all required validation.

## Automatic Sync

The purpose of automatic sync is to periodically regenerate a usable downstream release result from a new upstream head, not to keep accumulating fixes on an old release branch.

The sync process should:

1. Use the repository's accepted concurrency controls to prevent two sync or release processes from updating the same branch at once.
2. Fetch the latest upstream, the `ci` branch, all enabled regular patches, and all `tmp/patch/<name>` branches.
3. Create a clean candidate branch from the explicitly selected upstream commit for that run.
4. Integrate the downstream release overlay, regular patches, and temporary compatibility patches in the fixed order configured by `ci`.
5. Give every patch one clear, countable integration commit.
6. Run the required tests, builds, and packaging against the complete candidate commit.
7. Verify that no unknown update has appeared on the remote branch since it was fetched.
8. Update the release branch with a safe push method and ensure subsequent CI or releases run against the exact commit.

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

A problem on the main or release branch must be fixed on the corresponding source branch. Stop on conflicts, empty patches, test failures, or differences of unknown origin; do not continue releasing from an uncertain state.

## Completion Checklist

- [ ] The rebuild started from the latest specific upstream commit.
- [ ] Every patch has its own branch and can be built, tested, and reviewed independently.
- [ ] Product patches are maintained separately from the CI/CD, packaging, syncing, and downstream documentation carried by the `ci` branch.
- [ ] When the fork has additional maintenance requirements, the `ci` branch carries an up-to-date `MAINTAIN.md`, the README points to it when necessary, and both files are preserved in the integrated result.
- [ ] Fixes were made on the corresponding regular patch, `tmp/patch/<name>`, or `ci` branch rather than existing only on the release branch.
- [ ] The `ci` branch declares a fixed order for regular and temporary compatibility patches, with one clear, countable integration commit per patch.
- [ ] Conflicts and empty patches were fixed on their source branches or retired through the defined process.
- [ ] The complete integrated result and its artifacts passed the required validation.
- [ ] The push neither overwrote unknown remote changes nor bypassed authentication or branch protection.
- [ ] Patches merged upstream were removed from configuration and documentation and validated before their branches were deleted.
