#!/usr/bin/env bash

Root=$PWD

# --- Pre-flight checks: config structure is valid ---

test_nix_parse() {
  local -A case1=([name]='shared'   [file]="$Root/shared.nix")
  local -A case2=([name]='crostini' [file]="$Root/contexts/crostini/home.nix")
  local -A case3=([name]='linux'    [file]="$Root/contexts/linux/home.nix")
  local -A case4=([name]='macos'    [file]="$Root/contexts/macos/home.nix")

  subtest() {
    local casename=$1
    eval "$(tesht.Inherit $casename)"

    local got rc
    got=$(nix-instantiate --parse "$file" 2>&1 >/dev/null) && rc=$? || rc=$?

    tesht.AssertRC $rc 0
  }

  tesht.Run ${!case@}
}

test_symlinks() {
  local -A case1=([name]='context exists'             [link]="$Root/context"       [want]='contexts/')
  local -A case2=([name]='home.nix through context'   [link]="$Root/home.nix"      [want]='context/home.nix')
  local -A case3=([name]='gitconfig through context'  [link]="$Root/gitconfig"     [want]='context/gitconfig')
  local -A case4=([name]='tmux.conf through context'  [link]="$Root/tmux.conf"     [want]='context/tmux.conf')
  local -A case5=([name]='bashrc to init.bash'        [link]="$HOME/.bashrc"       [want]='bash/init.bash')
  local -A case6=([name]='bash_profile to init.bash'  [link]="$HOME/.bash_profile" [want]='bash/init.bash')

  subtest() {
    local casename=$1
    eval "$(tesht.Inherit $casename)"

    local got
    got=$(readlink "$link")

    [[ $got == *"$want"* ]] || {
      echo "error: readlink '$link' = '$got', want pattern '*$want*'"
      return 1
    }
  }

  tesht.Run ${!case@}
}

# --- Behavioral tests: what can the user do after shell startup? ---
# These test the contract, not the mechanism. They should not break
# when the init system's implementation changes.

_run_login_shell() {
  local err
  err=$(mktemp)
  local out
  out=$(env -i HOME="$HOME" USER="$USER" TERM=xterm-256color \
    bash --login -i -c "$1" 2>"$err") || true
  rm -f "$err"
  echo "$out"
}

# Single shell invocation for all behavioral checks.
# Batched to avoid ~550ms keychain overhead per spawn.
# Reload test needs its own shell (it re-sources init.bash).
test_behavior() {
  local got
  got=$(_run_login_shell '
    cd '"$Root"'

    # --- Environment ---
    command -v "$EDITOR" >/dev/null 2>&1 && echo "EDITOR_EXEC=yes" || echo "EDITOR_EXEC=no"
    command -v "$PAGER" >/dev/null 2>&1 && echo "PAGER_EXEC=yes" || echo "PAGER_EXEC=no"
    [[ -d $CFGDIR ]] && echo "CFGDIR_DIR=yes" || echo "CFGDIR_DIR=no"
    [[ -d $SECRETS ]] && echo "SECRETS_DIR=yes" || echo "SECRETS_DIR=no"
    echo "$PATH" | tr ":" "\n" | grep -q "/.local/bin$" && echo "PATH_LOCAL=yes" || echo "PATH_LOCAL=no"
    echo "UMASK=$(umask)"
    bind -V 2>/dev/null | grep -q "editing-mode is set to.*vi" && echo "VI=yes" || echo "VI=no"

    # --- Git workflow ---
    gss 2>&1 | head -1
    echo "GSS_RC=$?"
    git config user.name >/dev/null 2>&1 && echo "GIT_NAME=yes" || echo "GIT_NAME=no"
    git config user.email >/dev/null 2>&1 && echo "GIT_EMAIL=yes" || echo "GIT_EMAIL=no"

    # --- Prompt ---
    if declare -F _lp_load_color >/dev/null; then
      _lp_load_color >/dev/null 2>&1 && echo "LP_LOAD=ok" || echo "LP_LOAD=error"
    else
      echo "LP_LOAD=missing"
    fi
    pc="$PROMPT_COMMAND"
    lp=$(echo "$pc" | grep -bo "_lp_set_prompt" | head -1 | cut -d: -f1)
    dv=$(echo "$pc" | grep -bo "_direnv_hook" | head -1 | cut -d: -f1)
    [[ -n $lp ]] && echo "LP_PRESENT=yes" || echo "LP_PRESENT=no"
    [[ -n $dv ]] && echo "DV_PRESENT=yes" || echo "DV_PRESENT=no"
    [[ -n $lp && -n $dv && $lp -lt $dv ]] && echo "HOOK_ORDER=correct" || echo "HOOK_ORDER=wrong"

    # --- Reveal ---
    gss_stderr=$({ gss 1>/dev/null; } 2>&1)
    [[ $gss_stderr == *"git status"* ]] && echo "REVEAL=yes" || echo "REVEAL=no"

    # --- SSH agent ---
    ssh-add -l >/dev/null 2>&1 && echo "AGENT=yes" || echo "AGENT=no"
  ')

  local rc=0

  # Environment
  [[ $got == *"EDITOR_EXEC=yes"* ]]  || { echo "error: EDITOR is not executable"; rc=1; }
  [[ $got == *"PAGER_EXEC=yes"* ]]   || { echo "error: PAGER is not executable"; rc=1; }
  [[ $got == *"CFGDIR_DIR=yes"* ]]   || { echo "error: CFGDIR directory does not exist"; rc=1; }
  [[ $got == *"SECRETS_DIR=yes"* ]]   || { echo "error: SECRETS directory does not exist"; rc=1; }
  [[ $got == *"PATH_LOCAL=yes"* ]]    || { echo "error: .local/bin not in PATH"; rc=1; }
  [[ $got == *"UMASK=0022"* ]]        || { echo "error: umask not 0022"; rc=1; }
  [[ $got == *"VI=yes"* ]]            || { echo "error: vi mode not active"; rc=1; }

  # Git workflow
  [[ $got == *"GSS_RC=0"* ]]          || { echo "error: gss (git status -s) failed"; rc=1; }
  [[ $got == *"GIT_NAME=yes"* ]]      || { echo "error: git user.name not configured"; rc=1; }
  [[ $got == *"GIT_EMAIL=yes"* ]]     || { echo "error: git user.email not configured"; rc=1; }

  # Prompt
  [[ $got == *"LP_LOAD=ok"* ]]        || { echo "error: liquidprompt _lp_load_color failed (IFS issue?)"; rc=1; }
  [[ $got == *"LP_PRESENT=yes"* ]]    || { echo "error: liquidprompt not in PROMPT_COMMAND"; rc=1; }
  [[ $got == *"DV_PRESENT=yes"* ]]    || { echo "error: direnv not in PROMPT_COMMAND"; rc=1; }
  [[ $got == *"HOOK_ORDER=correct"* ]]|| { echo "error: liquidprompt must appear before direnv"; rc=1; }

  # Reveal
  [[ $got == *"REVEAL=yes"* ]]        || { echo "error: reveal did not show underlying command"; rc=1; }

  # SSH agent
  [[ $got == *"AGENT=yes"* ]]         || { echo "error: SSH agent not running or no keys loaded"; rc=1; }

  return $rc
}

test_reload() {
  local got
  got=$(_run_login_shell '
    output=$(source ~/.bashrc reload 2>&1)
    [[ $output == *"reloaded"* ]] && echo "RELOAD=yes" || echo "RELOAD=no"
    alias ga. >/dev/null 2>&1 && echo "ALIAS_AFTER=yes" || echo "ALIAS_AFTER=no"
  ')

  local rc=0
  [[ $got == *"RELOAD=yes"* ]]      || { echo "error: reload did not print 'reloaded'"; rc=1; }
  [[ $got == *"ALIAS_AFTER=yes"* ]] || { echo "error: aliases broken after reload"; rc=1; }
  return $rc
}
