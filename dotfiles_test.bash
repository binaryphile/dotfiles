#!/usr/bin/env bash

Root=$PWD

# --- Pre-flight: config structure is valid ---

test_nix_parse() {
  local -A case1=([name]='shared'   [file]="$Root/shared.nix")
  local -A case2=([name]='crostini' [file]="$Root/contexts/crostini/home.nix")
  local -A case3=([name]='desktop'  [file]="$Root/contexts/desktop/home.nix")
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

# --- Encoding ---

test_ascii_only() {
  # All tracked text files must be ASCII-only, except specific scripts
  # that use Unicode for user-facing rendered output (sparklines, notifications).
  local -a allowlist=(
    scripts/load-sparkline
    scripts/panel
    scripts/khal-notify
  )
  local allow_pattern
  allow_pattern=$(printf '%s\n' "${allowlist[@]}" | paste -sd'|')

  local violations
  # LC_ALL=C: grep treats bytes > 0x7F as non-[:print:]. Portable to BSD grep.
  # -I: skip binary files. Works on GNU and BSD grep.
  violations=$(export LC_ALL=C; git ls-files -z \
    | xargs -0 grep -rlI '[^[:print:][:space:]]' -- 2>/dev/null \
    | grep -Ev "^(${allow_pattern})$" || true)

  if [[ -n $violations ]]; then
    echo "Non-ASCII content in tracked files:"
    echo "$violations" | while read -r f; do
      LC_ALL=C grep -n '[^[:print:][:space:]]' "$f" | head -3
    done
    return 1
  fi
}

# --- Behavioral tests ---
# One shell spawn collects all facts. Grouped assertions verify by concern.
# Tests validate observable outcomes, not implementation mechanism.

_run_login_shell() {
  local err
  err=$(mktemp)
  local out
  out=$(env -i HOME="$HOME" USER="$USER" TERM=xterm-256color \
    bash --login -i -c "$1" 2>"$err") || true
  rm -f "$err"
  echo "$out"
}

# Collect all runtime facts in one shell, cached to file.
# tesht evals the source inside subshells -- variables set in one subshell
# don't propagate to others. A file persists across them.
RuntimeFactsFile=/tmp/dotfiles-test-facts
[[ -s $RuntimeFactsFile ]] || _run_login_shell '
    cd '"$Root"'

    # Environment
    command -v "$EDITOR" >/dev/null 2>&1 && echo "EDITOR_EXEC=yes" || echo "EDITOR_EXEC=no"
    command -v "$PAGER" >/dev/null 2>&1 && echo "PAGER_EXEC=yes" || echo "PAGER_EXEC=no"
    [[ -d $CFGDIR ]] && echo "CFGDIR_DIR=yes" || echo "CFGDIR_DIR=no"
    [[ -d $SECRETS ]] && echo "SECRETS_DIR=yes" || echo "SECRETS_DIR=no"
    echo "$PATH" | tr ":" "\n" | grep -q "/.local/bin$" && echo "PATH_LOCAL=yes" || echo "PATH_LOCAL=no"
    [[ -n ${TASK_BASH_LIB:-} && -r $TASK_BASH_LIB ]] && echo "TASK_BASH_LIB=yes" || echo "TASK_BASH_LIB=no"
    [[ -n ${MK_BASH_LIB:-} && -r $MK_BASH_LIB ]] && echo "MK_BASH_LIB=yes" || echo "MK_BASH_LIB=no"
    echo "UMASK=$(umask)"
    bind -V 2>/dev/null | grep -q "editing-mode is set to.*vi" && echo "VI=yes" || echo "VI=no"

    # Git workflow
    gss_out=$(gss 2>&1)
    echo "GSS_RC=${PIPESTATUS[0]}"
    git config user.name >/dev/null 2>&1 && echo "GIT_NAME=yes" || echo "GIT_NAME=no"
    git config user.email >/dev/null 2>&1 && echo "GIT_EMAIL=yes" || echo "GIT_EMAIL=no"

    # Reveal
    gss_stderr=$({ gss 1>/dev/null; } 2>&1)
    [[ $gss_stderr == *"git status"* ]] && echo "REVEAL=yes" || echo "REVEAL=no"

    # Prompt (regression guard: _lp_load_color is IFS-sensitive)
    # Valid return codes: 0 = load above threshold, 1 = below, 2 = disabled.
    # IFS corruption produces stderr noise or unexpected exit codes.
    if declare -F _lp_load_color >/dev/null; then
      lp_err=$(_lp_load_color 2>&1 >/dev/null); rc=$?
      if (( rc <= 2 )) && [[ -z $lp_err ]]; then
        echo "LP_LOAD=ok"
      else
        echo "LP_LOAD=error"
      fi
    else
      echo "LP_LOAD=missing"
    fi
    pc="$PROMPT_COMMAND"
    lp=$(echo "$pc" | grep -bo "_lp_set_prompt" | head -1 | cut -d: -f1)
    dv=$(echo "$pc" | grep -bo "_direnv_hook" | head -1 | cut -d: -f1)
    [[ -n $lp ]] && echo "LP_PRESENT=yes" || echo "LP_PRESENT=no"
    [[ -n $dv ]] && echo "DV_PRESENT=yes" || echo "DV_PRESENT=no"
    [[ -n $lp && -n $dv && $lp -lt $dv ]] && echo "HOOK_ORDER=correct" || echo "HOOK_ORDER=wrong"

    # SSH agent
    ssh-add -l >/dev/null 2>&1 && echo "AGENT=yes" || echo "AGENT=no"

    # Direnv activation
    tmpdir=$(mktemp -d)
    echo "export DIRENV_TEST_VAR=behavioral_test" > "$tmpdir/.envrc"
    direnv allow "$tmpdir" >/dev/null 2>&1
    pushd "$tmpdir" >/dev/null
    eval "$(direnv export bash 2>/dev/null)"
    [[ $DIRENV_TEST_VAR == behavioral_test ]] && echo "DIRENV_ACTIVATE=yes" || echo "DIRENV_ACTIVATE=no"
    popd >/dev/null
    rm -rf "$tmpdir"
  ' > "$RuntimeFactsFile"

test_shell_environment() {
  local -A case1=(
    [name]='EDITOR executable'
    [fact]='EDITOR_EXEC=yes'
  )
  local -A case2=(
    [name]='PAGER executable'
    [fact]='PAGER_EXEC=yes'
  )
  local -A case3=(
    [name]='.local/bin in PATH'
    [fact]='PATH_LOCAL=yes'
  )
  local -A case4=(
    [name]='umask 0022'
    [fact]='UMASK=0022'
  )
  local -A case5=(
    [name]='vi mode active'
    [fact]='VI=yes'
  )
  local -A case6=(
    [name]='TASK_BASH_LIB set and readable'
    [fact]='TASK_BASH_LIB=yes'
  )
  local -A case7=(
    [name]='MK_BASH_LIB set and readable'
    [fact]='MK_BASH_LIB=yes'
  )

  subtest() {
    local casename=$1
    eval "$(tesht.Inherit $casename)"
    local got
    got=$(< "$RuntimeFactsFile")
    [[ $got == *"$fact"* ]] || { echo "error: $name"; return 1; }
  }

  tesht.Run ${!case@}
}

test_git_workflow() {
  local -A case1=(
    [name]='gss (git status -s) works'
    [fact]='GSS_RC=0'
  )
  local -A case2=(
    [name]='git user.name configured'
    [fact]='GIT_NAME=yes'
  )
  local -A case3=(
    [name]='git user.email configured'
    [fact]='GIT_EMAIL=yes'
  )
  local -A case4=(
    [name]='reveal shows underlying command'
    [fact]='REVEAL=yes'
  )

  subtest() {
    local casename=$1
    eval "$(tesht.Inherit $casename)"
    local got
    got=$(< "$RuntimeFactsFile")
    [[ $got == *"$fact"* ]] || { echo "error: $name"; return 1; }
  }

  tesht.Run ${!case@}
}

# Regression guards for known integration issues.
# _lp_load_color and hook ordering are internal, but they guard
# against the IFS/sourcing-order class of bugs that behavioral
# tests alone cannot catch in a non-TTY environment.
test_prompt_integration() {
  local -A case1=(
    [name]='liquidprompt _lp_load_color works (IFS-sensitive)'
    [fact]='LP_LOAD=ok'
  )
  local -A case2=(
    [name]='liquidprompt in PROMPT_COMMAND'
    [fact]='LP_PRESENT=yes'
  )
  local -A case3=(
    [name]='direnv in PROMPT_COMMAND'
    [fact]='DV_PRESENT=yes'
  )
  local -A case4=(
    [name]='liquidprompt before direnv in hook order'
    [fact]='HOOK_ORDER=correct'
  )

  subtest() {
    local casename=$1
    eval "$(tesht.Inherit $casename)"
    local got
    got=$(< "$RuntimeFactsFile")
    [[ $got == *"$fact"* ]] || { echo "error: $name"; return 1; }
  }

  tesht.Run ${!case@}
}

# VPN handler registration: guard against regression where the
# globalprotectcallback URL scheme handler is accidentally dropped from the
# shared config layer (as happened in commit 28beecf -- see docs/vpn.md).
test_vpn_handler_config() {
  local -A case1=(
    [name]='linux-base has globalprotectcallback mimeApps entry'
    [file]="$Root/contexts/linux-base.nix"
    [want]='x-scheme-handler/globalprotectcallback'
  )
  local -A case2=(
    [name]='crostini has gpgui desktopEntries declaration'
    [file]="$Root/contexts/crostini/home.nix"
    [want]='xdg.desktopEntries'
  )

  subtest() {
    local casename=$1
    eval "$(tesht.Inherit $casename)"

    local got
    got=$(< "$file")

    [[ $got == *"$want"* ]] || {
      echo "error: '$file' missing required string '$want'"
      return 1
    }
  }

  tesht.Run ${!case@}
}

# Guard against garcon symlink regression (commit 28beecf): a home.file entry
# pointing to .nix-profile/share/applications/ becomes a broken symlink when
# the nix gpoc package is removed. xdg.desktopEntries already deploys to the
# garcon discovery path; the redundant symlink wins the conflict and silently
# drops URL dispatch. Strip Nix line comments before checking to avoid false
# positives from comment text that mentions the removed path.
test_vpn_no_garcon_symlink() {
  local got
  got=$(grep -v '^\s*#' "$Root/contexts/crostini/home.nix" | sed 's/\s*#.*//')

  [[ $got != *'nix-profile/share/applications/gpgui.desktop'* ]] || {
    echo "error: crostini/home.nix must not reference the nix-profile garcon symlink for gpgui.desktop"
    return 1
  }
}

# Deployment-state tests: verify update-env stage 2 outcomes.
# These test orchestration results, not config correctness.
# They fail on machines where stage 2 hasn't run -- that's expected.

test_deployment() {
  local got rc=0
  got=$(< "$RuntimeFactsFile")

  [[ $got == *"CFGDIR_DIR=yes"* ]]  || { echo "error: CFGDIR directory does not exist"; rc=1; }
  [[ $got == *"SECRETS_DIR=yes"* ]] || { echo "error: SECRETS directory does not exist"; rc=1; }
  [[ $got == *"AGENT=yes"* ]]       || { echo "error: SSH agent not running or no keys loaded"; rc=1; }
  return $rc
}

test_direnv_activation() {
  local got
  got=$(< "$RuntimeFactsFile")

  [[ $got == *"DIRENV_ACTIVATE=yes"* ]] || { echo "error: direnv did not activate .envrc"; return 1; }
}

# Reload needs its own shell (re-sources init.bash).
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
