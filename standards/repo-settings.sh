#!/usr/bin/env bash
#
# Organization repository standard. Idempotent: re-running converges.
#
#   repo-settings.sh <owner/repo> [<owner/repo> ...]
#
# Applies plan-independent settings to every repo:
#   - squash-only merges; delete branch on merge; update-branch off
#   - issues on; projects, wiki, discussions off
#   - Actions enabled, all actions allowed, sha-pinning off
#   - default workflow token read-only; PR reviews cannot be approved
#   - Dependabot security updates disabled
#
# Public repos additionally get:
#   - secret scanning + push protection
#   - a "Default" branch ruleset: block deletion, block non-fast-forward,
#     require signed commits, require a pull request (dismiss stale reviews on
#     push). Required status checks are intentionally omitted: a required
#     context that no workflow emits would block every PR forever.
#
# Free-plan caveats (private repos):
#   - rulesets are rejected with HTTP 403
#   - allow_auto_merge is silently ignored
#   - secret scanning is unavailable
#
# Repos whose workflows push with the implicit GITHUB_TOKEN must declare
# `permissions: contents: write` before the read-only token default is safe.
# List them (space-separated) in SKIP_WORKFLOW_TOKEN.
set -uo pipefail

RULESET_JSON='{
  "name": "Default",
  "target": "branch",
  "enforcement": "active",
  "conditions": { "ref_name": { "include": ["~DEFAULT_BRANCH"], "exclude": [] } },
  "rules": [
    { "type": "deletion" },
    { "type": "non_fast_forward" },
    { "type": "required_signatures" },
    { "type": "pull_request", "parameters": {
        "required_approving_review_count": 1,
        "dismiss_stale_reviews_on_push": true,
        "require_code_owner_review": false,
        "require_last_push_approval": false,
        "required_review_thread_resolution": false,
        "require_extra_approval_for_unattributed_changes": true,
        "allowed_merge_methods": ["merge", "squash", "rebase"]
    } }
  ],
  "bypass_actors": []
}'

for r in "$@"; do
  echo "== $r"
  vis=$(gh api "repos/$r" --jq .visibility)

  gh api -X PATCH "repos/$r" \
    -F allow_merge_commit=false -F allow_squash_merge=true -F allow_rebase_merge=false \
    -F delete_branch_on_merge=true -F allow_auto_merge=true -F allow_update_branch=false \
    -F has_issues=true -F has_projects=false -F has_wiki=false -F has_discussions=false \
    >/dev/null && echo "   settings: applied"

  gh api -X PUT "repos/$r/actions/permissions" \
    -F enabled=true -F allowed_actions=all -F sha_pinning_required=false \
    >/dev/null && echo "   actions: enabled, all allowed"

  case " ${SKIP_WORKFLOW_TOKEN:-} " in
    *" $r "*)
      echo "   workflow-token: skipped (SKIP_WORKFLOW_TOKEN)" ;;
    *)
      gh api -X PUT "repos/$r/actions/permissions/workflow" \
        -F default_workflow_permissions=read -F can_approve_pull_request_reviews=false \
        >/dev/null && echo "   workflow-token: read-only" ;;
  esac

  if gh api -X DELETE "repos/$r/automated-security-fixes" >/dev/null 2>&1; then
    echo "   dependabot: security updates disabled"
  else
    echo "   dependabot: already disabled / n-a"
  fi

  if [ "$vis" = "public" ]; then
    gh api -X PATCH "repos/$r" --input - >/dev/null 2>&1 \
      <<<'{"security_and_analysis":{"secret_scanning":{"status":"enabled"},"secret_scanning_push_protection":{"status":"enabled"}}}' \
      && echo "   secret scanning + push protection: enabled"
    if [ -n "${SKIP_RULESET:-}" ]; then
      echo "   ruleset: skipped (SKIP_RULESET)"
    else
      id=$(gh api "repos/$r/rulesets" --jq '.[] | select(.name == "Default") | .id' 2>/dev/null)
      if [ -n "$id" ]; then
        gh api -X PUT "repos/$r/rulesets/$id" --input - >/dev/null 2>&1 <<<"$RULESET_JSON" \
          && echo "   ruleset Default: updated"
      else
        gh api -X POST "repos/$r/rulesets" --input - >/dev/null 2>&1 <<<"$RULESET_JSON" \
          && echo "   ruleset Default: created"
      fi
    fi
  else
    code=$(gh api "repos/$r/rulesets" -i 2>/dev/null | head -1 | grep -oE '[0-9]{3}' | head -1)
    echo "   ruleset: unavailable on private/free (HTTP ${code:-?})"
  fi
done
