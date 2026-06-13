#!/usr/bin/env bash

# Tests for scripts/vpn.
#
# Covers:
#   sourceGuard -- file-foot guard prevents main from running on source
#   cmdDown     -- idempotent dual-down across gpoc (tmux) + pangp
#                  (globalprotect disconnect), predicate-free, stdout
#                  summary reflects which paths fired
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
