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
- Treat the fork as a product first: a code change counts as delivered only when the corresponding release is updated and users can obtain the usable result, not when the code is merged.
- Let users test PRs, patches, and their own changes against a real integrated result.
- Detect conflicts between patches and upstream early, keep PRs mergeable, and help patches flow upstream.
- Carry downstream-only overrides and ecosystem capabilities without letting them turn the fork into a hard fork.

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

1. **Real merge or seam-diff against an actual ancestor** — preferred when the patches have the relevant ancestry (e.g. patch B branched off patch A). Try `git merge` or `git diff <seam> <tip> | git apply --3way` before adding compatibility infrastructure. Ancestry does not guarantee a clean merge or correct combined behavior.

2. **Compatibility branch** — use when combining patches needs a reviewed resolution. A squash merge does not record the source branch as an ancestor, so later merges may use an older merge-base. Depending on the changes, this can cause content conflicts or add/add conflicts; shared file edits do not guarantee either. Record a *base* commit representing the required input state and a *tip* containing the resolved result. The base may include only relevant prerequisite patches if dependency analysis and full-candidate tests establish that the omitted patches do not interfere. Apply `git diff <base> <tip> | git apply --3way`, using an explicit `base..tip` range rather than `tip^..tip` so later fixups do not shrink the delta. Record the exact upstream, dependency and source-patch SHAs alongside the base and tip in durable commit metadata or the integration input record.

   Cost depends on the prerequisite patches and their interactions; a late position often makes constructing and maintaining the base more expensive. Use position as a cost heuristic, not a correctness argument. Revalidate when upstream, dependencies or integration order change, and update the compat when textual or behavioral changes require it. An upstream advance alone does not require rebuilding the base, and a clean apply alone does not establish that the old resolution remains valid.

   A compat source commit is ordinary reviewable history: it is diffed, read, and tested like any patch, and it may implement real cross-patch semantics — resolving a genuine combination problem is its purpose. What it must not silently absorb is a standalone upstream-API adaptation belonging to one patch (an upstream API the patch calls was renamed or removed); that change stays attributed and testable on the owning patch branch, and the compat then applies the already-adapted patch. This boundary describes attribution, not a reason to reject an approved compat route or to force a rebase.

   A clean `--3way` or merge result proves only that the text applied. Semantic validity still has to be demonstrated: hand-resolved unions must be compile-gated (`tsgo`/`biome` or the repo's checker) before pushing — diff-shape comparison against the release branch cannot catch a missing or extra brace in a different pre-image — and the combined result still needs the behavioral tests that cover the interaction.

3. **Narrow resolver script on `ci`** — acceptable for a known, exact conflict shape that is mechanical-only (import reordering, adjacent field insertion) and produces no new runtime semantics. Match the expected shape precisely and fail closed on anything else; position in the sequence is a cost consideration, never permission to union unknown blocks, dedup by guesswork, or rewrite runtime logic in CI strings. A resolver that rewrites function signatures, splits control flow, or drops/merges whole blocks is not narrow — that logic belongs on the patch or compat branch where it can be tested. Line count is not the test; semantic weight is.

Validate each patch when it is introduced and the combined result after integration. Workflow guards should check declared contracts rather than incidental variable names produced by a particular resolver. Keep behavioral tests for cross-patch interactions even when every per-step check passed.

### Downstream Override Branches

A downstream sometimes must override or switch off a specific upstream feature: the feature conflicts with downstream packaging, policy, or integration needs, and the change is not intended to flow upstream. Maintain each such override on its own `chore/<name>` branch.

An override is intentional divergence, which is in tension with the goal of staying mergeable with upstream. Govern it strictly:

- Before creating the branch, search upstream issues, PRs, documentation, and configuration for an official way to disable or configure the feature. Only when no supported mechanism exists should the fork carry an override.
- Each `chore/<name>` branch must declare which upstream feature it covers or disables, why the downstream needs it, the relevant upstream discussion links, and a retirement condition — for example upstream ships an official toggle, removes or replaces the feature, or downstream decides to restore it.
- Record every enabled override in an intentional-divergence ledger on the `ci` branch (the downstream patch list may serve as one). Review the ledger at every sync: confirm the override still applies cleanly, still matches the upstream feature's current shape, and its retirement condition has not been met.
- Prefer the smallest effective change — flipping a default, disabling an entry point, stubbing a call site — over deleting or rewriting large parts of upstream code. Smaller overrides conflict less and retire cheaply. When upstream changes the same area, update the override branch first, like any patch.
- Keep the override buildable and testable on the current upstream, with a check that fails if the disabled behavior reappears in the integrated result.

An override is not held to the upstream-PR goal, but it is held to the same hygiene: focused scope, clear commits, tests, and independent reviewability.

Integrate `chore/<name>` branches after the product and compatibility patches they may override and before the release overlay and any projection, so the override takes effect in the source candidate and is validated there. Each override appears as one clear, countable integration commit, like any other patch.

When a sync makes an override empty or conflicting, treat it as a state change, not a mechanical event: upstream may have removed the feature, added an official toggle, or changed the feature's implementation. Stop, confirm which case occurred, and update or retire the override per its declaration instead of forcing it through.

### The `ci` Maintenance Branch

When the fork needs to carry automation such as GitHub Actions, maintain a separate `ci` branch. If the repository already has an equivalent branch, retain its name. This branch is the downstream fork's release overlay and is responsible for:

- Downstream-specific CI/CD, packaging, releases, and repository configuration.
- Automatically fetching upstream, integrating patches in order, rebuilding the release branch, and pushing safely.
- Additional downstream single-patch tests and multi-patch integration tests.
- The downstream README, patch list, release notes, and any downstream-specific maintenance instructions.
- The fixed integration order of enabled regular patches, `tmp/patch/<name>` branches, `chore/<name>` overrides, and ecosystem branches.
- The intentional-divergence ledger recording every enabled `chore/<name>` override: the upstream feature it covers, why, upstream links, and its retirement condition.
- Deterministic release-projection scripts when the distributed tree is a subset or rearrangement of upstream.

If the user or downstream fork has maintenance requirements beyond this general workflow, keep them in a downstream-owned `MAINTAIN.md` on the `ci` branch. It should state how this particular fork must be maintained and record any special rules that future maintainers and automation must follow. Treat it as repository-specific guidance: read it before changing patch branches, sync orchestration, or release history, and keep it current when those requirements change.

When the special maintenance rules might otherwise be missed, add a concise notice in the `ci` branch's `README.md` linking to `MAINTAIN.md`. Keep the detailed rules in `MAINTAIN.md` rather than duplicating them in the README.

The `ci` branch may centrally carry downstream release automation, but do not mix product behavior patches into it. Runtime changes should remain on branches suitable for independent building, testing, and upstream PR submission.

### Downstream Ecosystem Branches

A fork that serves a downstream community grows capabilities upstream does not want and the release overlay should not absorb: extra integration harnesses, bot and community tooling, downstream package automation, or additional developer workflows. Maintain each such capability on its own ecosystem branch.

Git ref namespaces forbid a bare `ci` branch from coexisting with `ci/<name>` refs — a ref name cannot be both a file and a directory, and the files, packed-refs, and reftable backends all reject it. Since the maintenance trunk keeps the name `ci`, ecosystem branches use a separate prefix: `ecosystem/<name>` or `downstream/<name>`. Pick one prefix per fork and stay consistent; do not rename them into `ci/<name>`.

Ecosystem branches follow the maintenance discipline of `ci`:

- One capability per branch, independently testable, with a clear commit history.
- No product behavior for upstream packages — runtime changes belong on patch branches, and overrides of upstream features belong on `chore/<name>`.
- Declared in the `ci` orchestration next to the overlay integration, each producing its own clear, countable integration commit.
- Fixes return to the owning ecosystem branch; the release branch is only regenerated.

For a same-layout release, integrate ecosystem branches together with the `ci` overlay in the declared order. For a projected release, they integrate with the release-layout overlays after projection.

### Projected Release Trees

A downstream may distribute only one upstream package or use a different directory layout. Keep two products distinct:

- The **source candidate** preserves upstream's layout. Apply selected upstream PR heads, regular product patches, and compatibility patches here, using exact pinned commits, then run their source-tree tests.
- The **release projection** is a deterministic `ci`-owned script that reads that candidate and writes an empty output directory. It may use ordinary `cp`, `mv`, and `rm` operations inside the output, but must not mutate the source candidate, fetch network state, create commits, or push.
- **Release-layout overlays** run only after projection and contain packaging, metadata, CI, or downstream documentation that has no upstream-tree home. Product behavior stays in source-layout patch branches before projection.

The default order is:

```text
upstream commit → upstream PRs → product patches → tmp/patch/<name> → chore/<name> overrides
→ source validation → release projection → release-layout overlays + ecosystem branches → projected validation
```

Apply an upstream PR before projection because its paths, tests, and cross-package dependencies target the upstream tree. Applying it after files have moved requires a translated downstream-only patch and loses direct upstream compatibility. `chore/<name>` overrides also run in the source tree, before validation and projection, so the disabled or replaced behavior is absent from the validated source candidate and from every projected artifact.

To retain countable release history, project the upstream baseline once, then re-run the same projection after each source patch and commit that patch's projected output difference separately. A patch that produces no projected difference is empty for that release and must be investigated rather than hidden with an empty commit. Record the exact upstream and patch commits in a generated provenance file.

Keep the projection script project-specific and small. [`ref/project-release.sh`](ref/project-release.sh) provides the source/output boundary and an output-only customization point; copy it to the target `ci` branch and adapt it rather than making the skill guess a repository layout.

This skill includes the GitHub Actions file used by the current practice: [`ref/upstream-sync.yml`](ref/upstream-sync.yml). When GitHub auto-sync is needed, copy it as a starting point for `.github/workflows/upstream-sync.yml`, then adapt the upstream address, default/release branch, `ci`, patch, `chore/<name>`, and ecosystem branch lists, `tmp/patch/<name>` order, sync schedule, downstream-owned files, secrets, and checks for the target repository. The file retains project-specific configuration from its original project and must not be enabled without review.

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
- A problem in a `chore/<name>` override of an upstream feature.
- An integration problem between patches; if it belongs to no individual PR, place it in `tmp/patch/<name>`.
- A problem in CI, packaging, syncing, downstream documentation, or downstream ecosystem tooling.

### 4. Locate and Fix the Owning Branch

Find the patch branch responsible for the behavior and complete the fix and tests on that branch. If the problem concerns compatibility among multiple patches, create or update `tmp/patch/<name>`. If it concerns an overridden or disabled upstream feature, fix the owning `chore/<name>` branch. If it concerns release automation, ecosystem tooling, or other downstream maintenance work, modify the `ci` branch or the owning ecosystem branch.

Do not commit a conflict fix or product fix only to the main or release branch. It would be lost on the next rebuild from upstream and would prevent the patch from being reviewed independently.

### 5. Keep the Patch Independently Usable

Following repository conventions, update the patch onto the latest upstream, resolve conflicts on the patch branch, and run the builds and tests required by that patch.

Confirm that it does not rely on hidden changes in the release branch and can still be explained, reviewed, and submitted as a PR on its own. If an upstream PR already exists, update it as well and continue maintaining it in response to upstream feedback.

### 6. Rebuild the Main or Release Branch

Fetch the latest upstream again and create a clean source candidate from a specific upstream head. Integrate selected upstream PR commits first, followed by regular patches, required `tmp/patch/<name>` branches, and `chore/<name>` overrides in the fixed order declared by `ci`.

For a same-layout release, integrate the `ci` overlay and ecosystem branches as established by the repository. For a projected release, validate the source candidate, run the `ci` projection into an empty output tree, apply release-layout overlays together with ecosystem branches, and validate the projected package or artifact before constructing the release history. The projection must be reproducible from the recorded refs without modifying any source branch.

Each regular patch and temporary compatibility patch should produce its own clear integration commit in release history. A repository may use squash merge or the equivalent method established by the project, but the result should be easy to review and count.

### 7. Validate the Usable Result

Run the repository's required checks against the complete candidate version, covering at least:

- Focused tests for each patch itself.
- Integrated behavior after combining multiple patches.
- Whether CI, packaging, projection tooling, and downstream documentation come from the correct branches.
- For a projected release, whether the output contains only the intended tree, records exact source provenance, and can be installed or packaged through the advertised distribution path.
- Whether the code or artifacts users actually obtain correspond to the validated commit.

Update the remote main or release branch only after both the candidate code and artifacts pass all required validation.

### 8. Publish the Usable Update

If the fork runs its own release system — version numbers, tags, changelogs, packaged artifacts, or distribution channels — updating code is not the end of the work. After the rebuilt branch passes validation, update the release according to the fork's established convention, or by that system's default: bump the version, regenerate and verify the artifacts, and publish them where users obtain updates.

A change that lives only on patch or integration branches is undelivered work. Users of a downstream fork receive versions and artifacts, not branches. Do not stop after pushing code; stop after users can obtain the update. When the fork's convention leaves the choice open, publish by default rather than accumulating unreleased changes.

## Automatic Sync

The purpose of automatic sync is to periodically regenerate a usable downstream release result from a new upstream head, not to keep accumulating fixes on an old release branch.

The sync process should:

1. Use the repository's accepted concurrency controls to prevent two sync or release processes from updating the same branch at once.
2. Fetch the latest upstream, the `ci` branch, all enabled regular patches, all `tmp/patch/<name>` branches, all enabled `chore/<name>` overrides, and all ecosystem branches.
3. Create a clean candidate branch from the explicitly selected upstream commit for that run.
4. Integrate selected upstream PR commits, regular patches, temporary compatibility patches, and `chore/<name>` overrides in the configured source-tree order.
5. Review the intentional-divergence ledger against the fetched upstream state: confirm every `chore/<name>` override still targets the feature it declares, and retire overrides whose retirement condition is met rather than re-applying them.
6. For a same-layout release, integrate the `ci` overlay and ecosystem branches. For a projected release, validate the source candidate, run the `ci` projection into an empty output tree, and apply release-layout overlays together with ecosystem branches.
7. Give every patch one clear, countable integration commit; for projected releases, re-project after each source patch so its output difference remains separately countable.
8. Run the required source checks plus projected-package, build, and artifact checks.
9. Verify that no unknown update has appeared on the remote branch since it was fetched.
10. Update the release branch with a safe push method and ensure subsequent CI or releases run against the exact commit.

If a patch conflicts, stop the rebuild immediately. Return to the corresponding patch branch to resolve, test, and review it, then restart from a clean upstream baseline. Do not resolve the conflict directly on the release branch.

If a patch becomes empty, stop and confirm why. It may already have landed upstream, been superseded by another upstream change, or have been maintained incorrectly. For a `chore/<name>` override, the covered upstream feature may also have been removed, replaced, or given an official switch, meeting the override's declared retirement condition. Fix or retire it after confirmation; do not hide the state change with an empty commit.

When an update rewrites release history, use the repository's accepted lease protection, such as `--force-with-lease`. A lease failure means the remote has changed: fetch again, investigate, and rebuild. Do not overwrite unknown remote commits or use an unconditional force push.

## Patch Lifecycle

### Adding a Patch

1. Create an independent patch branch from an appropriate baseline on the latest upstream.
2. Limit its scope and add explanations and tests so that it meets PR standards.
3. Confirm that it can be built, tested, and reviewed independently.
4. Add it at an explicit position in the integration configuration.
5. Rebuild the release branch, validate the complete code and artifacts, and publish through the fork's release system.
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

When upstream merges the patch or provides equivalent behavior through another implementation, first confirm that the upstream version truly satisfies downstream needs and run the existing regression tests. Retire a temporary compatibility patch in the same order when its dependency combination no longer exists. Retire a `chore/<name>` override through the same order when its declared retirement condition is met, removing its divergence-ledger entry together with the integration configuration.

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
- [ ] The `ci` branch declares a fixed order for regular, temporary compatibility, `chore/<name>` override, and ecosystem branches, with one clear, countable integration commit per branch.
- [ ] Every `chore/<name>` override was checked against upstream for an official switch first, declares the covered feature, reason, and retirement condition, and is recorded in the divergence ledger on `ci`.
- [ ] Ecosystem branches carry no product behavior and integrate alongside the `ci` overlay.
- [ ] Conflicts and empty patches were fixed on their source branches or retired through the defined process.
- [ ] The complete integrated result and its artifacts passed the required validation.
- [ ] When the release tree is projected, its script read a disposable source candidate, wrote an empty separate output tree, recorded exact provenance, and passed projected install/package checks.
- [ ] The push neither overwrote unknown remote changes nor bypassed authentication or branch protection.
- [ ] Patches merged upstream were removed from configuration and documentation and validated before their branches were deleted.
- [ ] If the fork has its own release system, the release was updated per its convention or by default — version, artifacts, and channels — so users can obtain the change, not only updated code branches.
