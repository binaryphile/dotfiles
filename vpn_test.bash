#!/usr/bin/env bash

# Tests for scripts/vpn.
#
# Covers:
#   sourceGuard -- file-foot guard prevents main from running on source
#   cmdDown     -- idempotent dual-down across gpoc (tmux) + pangp
#                  (globalprotect disconnect), predicate-free, stdout
#                  summary reflects which paths fired
#   cmdUp       -- mode-dispatched (#32959) across gpoc (tmux-wrap of
#                  vpn-connect) + pangp (control-plane predicate via
#                  globalprotect show --status, fall-through to vpn-connect)
#   cmdStatus   -- control-plane status (#51793) — pangp branch via
#                  globalprotect show --status with two-check predicate
#                  excluding Not-Connected false-match; gpoc branch via
#                  tmux + pgrep; stdout 'up' or 'down'
#
# Sourcing pattern: override `main` to a no-op BEFORE sourcing so the
# bottom `main "$@"` (when present unguarded) is harmless for tests
# that need the function definitions. The dedicated sourceGuard test
# invokes a fresh subshell to test the raw source behavior.

main() { :; }  # neutralize before sourcing
source "$PWD/scripts/vpn" || exit 1
unset -f main


## sourceGuard — #27694

test_sourceGuard_isolated() {
  local -A case1=(
    [name]='sourcing does not invoke main (no usage / cmdUp marker on stdout/stderr)'
    [check]=no-marker
  )
  local -A case2=(
    [name]='sourcing succeeds under set -uo pipefail (rc=0)'
    [check]=rc-zero
  )

  subtest() {
    local casename=$1
    eval "$(tesht.Inherit "$casename")"

    local script=$PWD/scripts/vpn
    local out rc

    case $check in
      no-marker)
        # main's reachable behaviors when called with no args: cmdUp's
        # "vpn started" / "vpn session already running" lines, or usage
        # via the default-case error path. Sourcing without args should
        # emit none of these — the guard skips main entirely.
        out=$(bash -c "source '$script'" 2>&1)
        if grep -qE 'usage: vpn|vpn started|vpn session already running' <<<"$out"; then
          tesht.AssertGot "main was invoked on source: $out" ''
        else
          tesht.AssertGot '' ''
        fi
        ;;
      rc-zero)
        bash -c "set -uo pipefail; source '$script'" >/dev/null 2>&1
        rc=$?
        tesht.AssertGot "$rc" 0
        ;;
    esac
  }

  tesht.Run "${!case@}"
}


## cmdDown — #27694 idempotent dual-down

test_cmdDown() {
  local -A case1=(
    [name]='gpoc tmux session present, globalprotect absent → tmux kill only'
    [hasSession]=0
    [gpRc]=127
    [want]='vpn (gpoc) tmux session stopped'
  )

  local -A case2=(
    [name]='pangp connected, no tmux session → globalprotect disconnect only'
    [hasSession]=1
    [gpRc]=0
    [want]='vpn (pangp) disconnect requested'
  )

  local -A case3=(
    [name]='both present → both paths fire, stdout has both lines'
    [hasSession]=0
    [gpRc]=0
    [want]=$'vpn (gpoc) tmux session stopped\nvpn (pangp) disconnect requested'
  )

  local -A case4=(
    [name]='neither present → already-down message'
    [hasSession]=1
    [gpRc]=127
    [want]='vpn was already down'
  )

  subtest() {
    local casename=$1
    eval "$(tesht.Inherit "$casename")"

    tmux() {
      case ${1:-} in
        has-session)  return "$hasSession" ;;
        kill-session) return 0 ;;
        *)            return 0 ;;
      esac
    }
    globalprotect() { return "$gpRc"; }
    export -f tmux globalprotect
    export hasSession gpRc

    local got
    got=$(cmdDown)

    tesht.AssertGot "$got" "$want"
  }

  tesht.Run "${!case@}"
}


## cmdUp — #32959 mode-dispatched up

test_cmdUp() {
  # Cases mirror the dispatch table: 3 pangp cases + 2 gpoc cases + 1 unknown.
  # showStatus is what `globalprotect show --status` prints; showRc is its rc.
  # hasSession is the tmux has-session return code (0=present, 1=absent —
  # matches the convention test_cmdDown uses). For the unknown-mode case the
  # predicate inputs don't matter (the case fails before reaching them).

  local -A case1=(
    [name]='pangp + already-connected: echo already-connected, no vpn-connect'
    [mode]=pangp
    [showRc]=0
    [showStatus]='GlobalProtect Status: Connected'
    [hasSession]=1
    [wantStdout]='vpn (pangp) already connected'
    [wantRc]=0
  )

  local -A case2=(
    [name]='pangp + not-connected: fall through to vpn-connect'
    [mode]=pangp
    [showRc]=0
    [showStatus]='GlobalProtect Status: Not Connected'
    [hasSession]=1
    [wantStdout]='vpn-connect invoked'
    [wantRc]=0
  )

  local -A case3=(
    [name]='pangp + globalprotect CLI missing (rc=127): fall through to vpn-connect'
    [mode]=pangp
    [showRc]=127
    [showStatus]=''
    [hasSession]=1
    [wantStdout]='vpn-connect invoked'
    [wantRc]=0
  )

  local -A case4=(
    [name]='gpoc + tmux session exists: echo already-running, no new-session'
    [mode]=gpoc
    [showRc]=0
    [showStatus]=''
    [hasSession]=0
    [wantStdout]='vpn (gpoc) session already running; attach with: vpn attach'
    [wantRc]=0
  )

  local -A case5=(
    [name]='gpoc + no session: tmux new-session called + stdout summary'
    [mode]=gpoc
    [showRc]=0
    [showStatus]=''
    [hasSession]=1
    [wantStdout]=$'tmux new-session called\nvpn (gpoc) started in tmux session \'vpn\'\n  attach: vpn attach\n  stop:   vpn down'
    [wantRc]=0
  )

  local -A case6=(
    [name]='unknown vpn-mode: stderr error + rc=1'
    [mode]=unknown
    [showRc]=0
    [showStatus]=''
    [hasSession]=1
    [wantStdout]="vpn-mode returned unknown state; run 'vpn-mode pangp' or 'vpn-mode gpoc' first"
    [wantRc]=1
  )

  subtest() {
    local casename=$1
    eval "$(tesht.Inherit "$casename")"

    vpn-mode() { echo "$mode"; }
    globalprotect() {
      case ${1:-} in
        show) [[ -n $showStatus ]] && printf '%s\n' "$showStatus"; return "$showRc" ;;
        *)    return 0 ;;
      esac
    }
    tmux() {
      case ${1:-} in
        has-session) return "$hasSession" ;;
        new-session) echo "tmux new-session called"; return 0 ;;
        *)           return 0 ;;
      esac
    }
    vpn-connect() { echo "vpn-connect invoked"; }
    export -f vpn-mode globalprotect tmux vpn-connect
    export mode showRc showStatus hasSession

    # Capture stdout+stderr combined; rc from cmdUp.
    local got rc
    got=$(cmdUp 2>&1); rc=$?

    tesht.AssertGot "$got" "$wantStdout"
    tesht.AssertRC "$rc" "$wantRc"
  }

  tesht.Run "${!case@}"
}


## cmdStatus — #51793 control-plane status

test_cmdStatus() {
  # cmdStatus checks pangp first (globalprotect show --status), then gpoc
  # (tmux has-session + pgrep -f 'gpclient connect'). Returns 'up' if
  # either path indicates connected; 'down' otherwise. NOT mode-dispatched
  # (unlike cmdUp) — both probes can be evaluated in sequence.
  #
  # Mocks: globalprotect (stdout + rc), tmux has-session (rc),
  # pgrep -f (rc only).

  local -A case1=(
    [name]='pangp Connected: echo up (gpoc state irrelevant)'
    [showRc]=0
    [showStatus]='GlobalProtect Status: Connected'
    [hasSession]=1
    [pgrepRc]=1
    [want]='up'
  )

  local -A case2=(
    [name]='pangp Not-Connected, no gpoc: fall through to down (the #51793 bug fix case)'
    [showRc]=0
    [showStatus]='GlobalProtect Status: Not Connected'
    [hasSession]=1
    [pgrepRc]=1
    [want]='down'
  )

  local -A case3=(
    [name]='pangp Disconnected, no gpoc: fall through to down'
    [showRc]=0
    [showStatus]='GlobalProtect Status: Disconnected'
    [hasSession]=1
    [pgrepRc]=1
    [want]='down'
  )

  local -A case4=(
    [name]='pangp CLI missing (rc=127 empty), no gpoc: fall through to down'
    [showRc]=127
    [showStatus]=''
    [hasSession]=1
    [pgrepRc]=1
    [want]='down'
  )

  local -A case5=(
    [name]='pangp absent, gpoc tmux+pgrep both present: echo up via gpoc'
    [showRc]=0
    [showStatus]=''
    [hasSession]=0
    [pgrepRc]=0
    [want]='up'
  )

  local -A case6=(
    [name]='pangp absent, gpoc tmux yes but no gpclient process: down'
    [showRc]=0
    [showStatus]=''
    [hasSession]=0
    [pgrepRc]=1
    [want]='down'
  )

  local -A case7=(
    [name]='pangp absent, gpoc no tmux session: down (pgrep not consulted)'
    [showRc]=0
    [showStatus]=''
    [hasSession]=1
    [pgrepRc]=0
    [want]='down'
  )

  local -A case8=(
    [name]='neither pangp nor gpoc indicates up: down'
    [showRc]=127
    [showStatus]=''
    [hasSession]=1
    [pgrepRc]=1
    [want]='down'
  )

  subtest() {
    local casename=$1
    eval "$(tesht.Inherit "$casename")"

    globalprotect() {
      case ${1:-} in
        show) [[ -n $showStatus ]] && printf '%s\n' "$showStatus"; return "$showRc" ;;
        *)    return 0 ;;
      esac
    }
    tmux() {
      case ${1:-} in
        has-session) return "$hasSession" ;;
        *)           return 0 ;;
      esac
    }
    pgrep() { return "$pgrepRc"; }
    export -f globalprotect tmux pgrep
    export showRc showStatus hasSession pgrepRc

    local got
    got=$(cmdStatus)

    tesht.AssertGot "$got" "$want"
  }

  tesht.Run "${!case@}"
}
