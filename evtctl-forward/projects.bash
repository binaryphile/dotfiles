# shellcheck shell=bash
# evtctl-forward/projects.bash -- per-project Teams webhook registry
#
# Sourced by `evtctl forward` at bridge startup to derive the op://
# reference for each project's Workflow URL.
#
# Naming Policy: standalone-script style, no namespace prefix on globals.
# Bootstrap globals are PascalCase and `declare -Agr` (readonly-enforced).
#
# Editing this file = enabling/disabling a project's bridge. After
# editing, restart the affected bridge unit:
#   systemctl --user reload evtctl-forward@<project>.service

# Vault name in the 1Password account named by ProjectAccount[$proj].
declare -Agr ProjectVault=(
  # [urma]=teams-webhooks
  # [era]=teams-webhooks
  # [jeeves]=teams-webhooks
)

# 1Password account shorthand or sign-in address. SSO/desktop-attached
# accounts have no shorthand -- use the sign-in address directly.
declare -Agr ProjectAccount=(
  # [urma]=digi.1password.com
  # [era]=digi.1password.com
  # [jeeves]=digi.1password.com
)

# 1Password item name within the project's vault. By convention this is
# the project name itself, but can differ if the operator prefers
# `Teams Webhook - <project>` or similar.
declare -Agr ProjectWebhookItem=(
  # [urma]=urma
  # [era]=era
  # [jeeves]=jeeves
)

# Field name within the 1Password item containing the Workflow URL. By
# convention "webhook" — Password-type items name the field "password" by
# default; this layout uses "webhook" for explicitness.
declare -Agr ProjectWebhookField=(
  # [urma]=webhook
  # [era]=webhook
  # [jeeves]=webhook
)

# Per-project op:// references resolved at runtime as:
#   op://${ProjectVault[$proj]}/${ProjectWebhookItem[$proj]}/${ProjectWebhookField[$proj]}
# against the account ${ProjectAccount[$proj]}.
