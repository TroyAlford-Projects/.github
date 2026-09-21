# .github

Organization-wide defaults and the repository standard for this organization.

GitHub automatically applies the files here to any repository in the
organization that does not define its own:

- `CONTRIBUTING.md`
- `SECURITY.md`
- `SUPPORT.md`
- `PULL_REQUEST_TEMPLATE.md`
- `.github/ISSUE_TEMPLATE/*`

The `standards/` directory holds the canonical repository configuration and is
applied by `standards/repo-settings.sh`.

> This repository must stay **public** for GitHub to use it as the source of
> default community health files. Do not make it private.
