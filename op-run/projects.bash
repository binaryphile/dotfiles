# shellcheck shell=bash
# op-run/projects.bash -- per-project credential registry
#
# Sourced by scripts/op-run. Associative arrays keyed by project name.
# ProjectPath is matched against `realpath $(git rev-parse --show-toplevel)`
# at the call site to identify which project the launcher is running for.
#
# Naming Policy: standalone-script style, no namespace prefix on globals.
# Bootstrap globals are PascalCase and `declare -Agr` (readonly-enforced).
#
# Per-project env spec is a newline-separated string of KEY=value lines.
# Values starting with op:// are resolved by `op run` at exec time;
# all others pass through literally.

declare -Agr ProjectPath=(
  [urma]=/home/ted/projects/urma
)

# ProjectAccount accepts anything OP_ACCOUNT accepts: shorthand, sign-in
# address, or UUID. SSO/desktop-attached accounts have no shorthand --
# `op account` exposes no command to set one and `op account add` is
# rejected for SSO accounts (open 1Password community feature request).
# Use the sign-in address directly for those.
declare -Agr ProjectAccount=(
  [urma]=digi.1password.com
)

declare -Agr ProjectVault=(
  [urma]=urma-atlassian
)

# urma: Bitbucket Server (stash.digi.com) via _PERSONAL_TOKEN, plus
# Confluence Cloud and Jira Cloud (both onedigi.atlassian.net) via Cloud
# API token. Consumed by mcp-atlassian-with-bitbucket.
#
# 1Password item/field names (API Credential item type, default 'credential' field):
#   urma-atlassian/bitbucket   field: credential
#   urma-atlassian/confluence  field: credential
#   urma-atlassian/jira        field: credential
# Adjust the op:// references if the vault uses different names.

declare -Agr ProjectEnvSpec=(
  [urma]="BITBUCKET_URL=https://stash.digi.com
BITBUCKET_USERNAME=tlilley
BITBUCKET_PERSONAL_TOKEN=op://urma-atlassian/bitbucket/credential
CONFLUENCE_URL=https://onedigi.atlassian.net/wiki
CONFLUENCE_USERNAME=tlilley@digi.com
CONFLUENCE_PERSONAL_TOKEN=op://urma-atlassian/confluence/credential
JIRA_URL=https://onedigi.atlassian.net
JIRA_USERNAME=tlilley@digi.com
JIRA_API_TOKEN=op://urma-atlassian/jira/credential"
)
