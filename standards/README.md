# Repository standard

The standard configuration for repositories in this organization, derived from
`TroyAlford/basis`.

## Settings (every repo)

| Setting | Value |
| --- | --- |
| Merge methods | squash only (merge-commit and rebase off) |
| Delete branch on merge | on |
| Update branch | off |
| Issues | on |
| Projects | off |
| Wiki | off |
| Discussions | off |
| Actions | enabled, all actions allowed, sha-pinning off |
| Default workflow token | read-only, cannot approve PR reviews |
| Dependabot security updates | off |

## Public repos additionally

- Secret scanning + push protection enabled.
- A `Default` branch ruleset: block deletion, block non-fast-forward, require
  signed commits, and require a pull request with **at least one approving
  review from someone other than the author** (stale reviews dismissed on push).
  Required status checks are intentionally **omitted** until a repo defines the
  required CI job; adding a required check that no workflow emits blocks every
  PR forever. Note that GitHub will not let a user approve their own pull
  request, so a repo with a single member needs a second collaborator (or the
  `*-AI` machine account) to satisfy the approval requirement.

## GitHub Free caveats

On the Free plan, **private** repositories:

- reject rulesets with HTTP `403`,
- silently ignore `allow_auto_merge`,
- cannot enable secret scanning or push protection.

Everything else above still applies. The script prints these cases as it runs.

Repositories whose workflows push with the implicit `GITHUB_TOKEN` must declare
`permissions: contents: write` before the read-only default is safe. List them
in `SKIP_WORKFLOW_TOKEN` when running the script.

## Usage

```sh
standards/repo-settings.sh <owner/repo> [<owner/repo> ...]
SKIP_WORKFLOW_TOKEN="owner/repo another/repo" standards/repo-settings.sh ...
```
