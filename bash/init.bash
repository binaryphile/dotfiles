# init.bash - single entry point for all shell modes

Root=$(cd "$(dirname "$BASH_SOURCE")"; cd -P "$(dirname "$(readlink "$BASH_SOURCE" || echo .)")"; pwd)
[[ $1 == reload ]] && Reload=1 || Reload=0

Vars=( Reload Root )

source "$Root"/lib/initutil.bash

SplitSpace off
Globbing off

# Login environment: nix session vars (fallback for portability)
{ ShellIsLogin || (( Reload )); } && {
  if IsFile "$HOME/.nix-profile/etc/profile.d/hm-session-vars.sh"; then
    source "$HOME/.nix-profile/etc/profile.d/hm-session-vars.sh"
  elif IsFile "/etc/profiles/per-user/$USER/etc/profile.d/hm-session-vars.sh"; then
    source "/etc/profiles/per-user/$USER/etc/profile.d/hm-session-vars.sh"
  fi
}

TestAndSource $Root/context/init.bash

# Hooks: explicit order (order-sensitive)
# Hooks expect normal IFS and globbing
SplitSpace on
Globbing on

ShellIsInteractive && {
  command -v liquidprompt >/dev/null && {
    source "$(command -v liquidprompt)"
    # Theme must be sourced after liquidprompt -- 2.2.1's lp_activate
    # applies the default theme, overriding any variables set before it.
    [[ -r $Root/../liquidprompt/liquid.theme ]] && source "$Root/../liquidprompt/liquid.theme"
  }
  TestAndSource $Root/apps/direnv/init.bash

  # 1Password SSH agent kick. In a graphical session, push display env into
  # user-systemd and ensure 1password.service is running so op-ssh-sign can
  # talk to its agent. Recovery path for hosts where user-systemd starts
  # before any graphical shell exists (e.g. cold-boot Crostini): import-env
  # makes display vars visible to the manager; reset-failed clears any
  # start-limit-hit state from too-early WantedBy fires; start finishes the
  # job. Idempotent on hosts where the unit already came up via WantedBy.
  if [[ -n ${DISPLAY:-} || -n ${WAYLAND_DISPLAY:-} ]]; then
    {
      systemctl --user import-environment DISPLAY WAYLAND_DISPLAY DBUS_SESSION_BUS_ADDRESS XDG_RUNTIME_DIR
      systemctl --user reset-failed 1password.service
      systemctl --user start 1password.service
    } 2>/dev/null
  fi
}

SplitSpace off
Globbing off

source $Root/settings/base.bash
source $Root/settings/cmds.bash

# Commands: auto-discover (order-independent)
ShellIsInteractive && {
  Globbing on
  shopt -q nullglob; _had_nullglob=$?
  shopt -s nullglob
  for _app_cmds in "$Root"/apps/*/cmds.bash; do
    source "$_app_cmds"
  done
  (( _had_nullglob == 0 )) || shopt -u nullglob
  Globbing off
  unset -v _app_cmds _had_nullglob
}

ShellIsInteractive && source $Root/settings/interactive.bash
{ ShellIsInteractiveAndLogin || (( Reload )); } && source $Root/settings/login.bash

(( Reload )) && echo reloaded

export ENV_SET=1

SplitSpace on
Globbing on
unset -f "${Functions[@]}"
unset -v "${Vars[@]}"
