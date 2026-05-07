# shellcheck shell=bash
# op-run/projects.bash -- per-project credential registry
#
# Sourced by scripts/op-run. Associative arrays keyed by project name.
# ProjectPath is matched against `realpath $(git rev-parse --show-toplevel)`
# at the call site to identify which project the launcher is running for.
#
# Naming Policy: standalone-script style, no namespace prefix on globals.
#
# Per-project env spec is a newline-separated string of KEY=value lines.
# Values starting with op:// are resolved by `op run` at exec time;
# all others pass through literally.

declare -Ag ProjectPath=(
  [urma]=/home/ted/projects/urma
)

declare -Ag ProjectAccount=(
  [urma]=work
)

declare -Ag ProjectVault=(
  [urma]=urma-atlassian
)

# urma: matches the env vars the existing .envrc was exporting -- Bitbucket
# Server (stash.digi.com) and Confluence Cloud (onedigi.atlassian.net),
# both via _PERSONAL_TOKEN. JIRA_* deliberately omitted (was not in the
# original .envrc). Add later if/when Jira becomes a consumer.
#
# 1Password item/field names assumed:
#   urma-atlassian/bitbucket   field: credential
#   urma-atlassian/confluence  field: credential
# Adjust the op:// references if the vault uses different names.

declare -Ag ProjectEnvSpec=(
  [urma]="BITBUCKET_URL=https://stash.digi.com
BITBUCKET_USERNAME=tlilley
BITBUCKET_PERSONAL_TOKEN=op://urma-atlassian/bitbucket/credential
CONFLUENCE_URL=https://onedigi.atlassian.net/wiki
CONFLUENCE_USERNAME=tlilley@digi.com
CONFLUENCE_PERSONAL_TOKEN=op://urma-atlassian/confluence/credential"
)
