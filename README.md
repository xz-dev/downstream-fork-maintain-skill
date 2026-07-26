# Downstream Fork Maintain Skill

An Agent Skill for maintaining downstream Git forks as continuously validated, upstream-tracking patch sets.

The goal is to avoid turning a downstream repository into a permanently divergent hard fork. Instead, each change remains a living, PR-quality patch that follows upstream, can be reviewed and tested independently, and can eventually flow upstream. A generated main or release branch provides usable integrated code and artifacts, while continuous rebuilding detects conflicts early and prevents patches and upstream PRs from rotting.

## Branch Model

Actual branch and remote names remain project-specific.

- **`ci`** — Downstream release overlay containing synchronization automation, CI/CD, packaging, release configuration, downstream documentation, and the ordered patch list. Product behavior changes do not belong here.
- **Ordinary patch branches** — One focused feature or fix per branch. Each patch remains independently buildable, testable, reviewable, and suitable for upstream submission or continued PR maintenance.
- **`tmp/patch/<name>`** — Temporary compatibility patches for integration problems caused by combining otherwise independent patches. These branches declare their dependencies, integration position, validation scope, and retirement condition.
- **Generated main or release branch** — Rebuilt from a specific current upstream commit by applying `ci`, ordinary patches, and compatibility patches in a fixed order. It is the usable integrated result, not the source of truth for patches.

Fixes discovered in the integrated branch must be returned to the owning patch, compatibility, or `ci` branch. The main or release branch is then regenerated.

## Installation

### Pi

Clone the repository into Pi's skill directory:

```sh
mkdir -p ~/.pi/agent/skills
git clone https://github.com/xz-dev/downstream-fork-maintain-skill.git \
  ~/.pi/agent/skills/downstream-fork-maintain
```

Restart Pi or begin a new session if the skill is not detected immediately.

### Other Agent Skills implementations

The repository follows the `SKILL.md`-based Agent Skills format. Clone or copy it into the skills directory recognized by your compatible agent, preserving `SKILL.md` and `ref/` together.

Discovery paths and invocation syntax depend on the agent implementation.

## Usage

Invoke the skill through a natural-language request, for example:

```text
Maintain this downstream fork against its upstream repository, keep each patch
independently reviewable, and rebuild the integrated release branch.
```

In Pi, it can also be selected explicitly:

```text
/skill:downstream-fork-maintain
```

The skill first inspects repository instructions, remotes, branches, protections, uncommitted work, and the existing release process before proposing or performing maintenance.

## Repository Layout

```text
.
├── README.md
├── SKILL.md
├── LICENSE
└── ref/
    └── upstream-sync.yml
```

- **`SKILL.md`** — Maintenance model, workflow, patch lifecycle, safety rules, and completion checklist.
- **`ref/upstream-sync.yml`** — Example GitHub Actions synchronization workflow.
- **`LICENSE`** — CC BY-NC-SA 4.0 legal terms.

## Workflow Reference

`ref/upstream-sync.yml` is a project-specific, copy-and-customize reference. It is not a universal ready-to-run workflow.

Before enabling it, review and adapt at least:

- Upstream repository, remote, and baseline branch.
- Downstream main or release branch.
- `ci`, ordinary patch, and `tmp/patch/<name>` branch names and order.
- Conflict handling and downstream-owned files.
- Build, test, packaging, and artifact validation.
- Authentication secrets, permissions, concurrency, and branch protection.
- Safe push and lease checks.
- Synchronization schedule and timezone.

The included branch names, repository URL, patch list, secrets, and conflict assumptions originate from a specific project and must not be reused without review.

## License

This work is licensed under CC BY-NC-SA 4.0.
For commercial use, please contact the author for a separate license.

See the full [Creative Commons Attribution-NonCommercial-ShareAlike 4.0 International License](LICENSE).

If you share the material, you must provide attribution. If you share adapted material, the ShareAlike terms apply. Commercial use requires separate permission from the author.
