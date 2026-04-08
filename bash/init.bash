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
{ ShellIsLogin || (( Reload )); } && {
  TestAndSource $Root/apps/keychain/init.bash
}
ShellIsInteractive && {
  [[ -r $Root/../liquidprompt/liquidprompt ]] && source $Root/../liquidprompt/liquidprompt
  TestAndSource $Root/apps/direnv/init.bash
}

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
