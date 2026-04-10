#!/usr/bin/env bash

# Tests for scripts/probe-lib.bash. Covers combine() (the pure-
# function heart of the widget state machine) and pingHost's
# load-bearing side effect of invalidating the cached SSH success
# on failure. sshHost, the vendor API probes, and probeReachability
# are not tested here — they require real network access or a
# heavier mocking layer.
#
# Style follows tesht's table-driven pattern. State must be set
# before sourcing probe-lib because probe-lib enforces it. combine()
# is pure and doesn't touch the directory, so any existing path works.

State=/tmp
source "$PWD/scripts/probe-lib.bash" || exit 1

# combine() rules (from probe-lib.bash):
#   1. api in {down, off}            → off
#   2. api in {degraded, partial}    → partial
#   3. ping == fail                  → off
#   4. ssh == ok && ping == ok       → on
#   5. ping == ok                    → partial
#   6. otherwise                     → unknown
test_combine() {
  local -A case1=([name]='ssh ok, ping ok, api on → on'                       [ssh]=ok      [ping]=ok      [api]=on       [want]=on)
  local -A case2=([name]='ssh ok, ping ok, api degraded → partial (api wins)' [ssh]=ok      [ping]=ok      [api]=degraded [want]=partial)
  local -A case3=([name]='ssh ok, ping ok, api partial → partial (api wins)'  [ssh]=ok      [ping]=ok      [api]=partial  [want]=partial)
  local -A case4=([name]='ssh ok, ping ok, api off → off (api wins)'          [ssh]=ok      [ping]=ok      [api]=off      [want]=off)
  local -A case5=([name]='ssh ok, ping ok, api down → off (api wins)'         [ssh]=ok      [ping]=ok      [api]=down     [want]=off)
  local -A case6=([name]='ssh fail, ping ok, api on → partial'                [ssh]=fail    [ping]=ok      [api]=on       [want]=partial)
  local -A case7=([name]='ssh unknown, ping ok, api on → partial'             [ssh]=unknown [ping]=ok      [api]=on       [want]=partial)
  local -A case8=([name]='ssh ok, ping fail, api on → off (ping fail wins)'   [ssh]=ok      [ping]=fail    [api]=on       [want]=off)
  local -A case9=([name]='ssh fail, ping fail, api on → off'                  [ssh]=fail    [ping]=fail    [api]=on       [want]=off)
  local -A case10=([name]='ssh ok, ping unknown, api on → unknown'            [ssh]=ok      [ping]=unknown [api]=on       [want]=unknown)
  local -A case11=([name]='ssh unknown, ping unknown, api on → unknown'       [ssh]=unknown [ping]=unknown [api]=on       [want]=unknown)

  subtest() {
    local casename=$1
    eval "$(tesht.Inherit "$casename")"

    local got
    got=$(combine "$ssh" "$ping" "$api")

    tesht.AssertGot "$got" "$want"
  }

  tesht.Run "${!case@}"
}

# pingHost has a load-bearing side effect: on failure it must
# invalidate the cached SSH success for the widget so the state can
# only return to "active" via a fresh successful SSH probe. Without
# this, a partial recovery from a network blip would prematurely
# upgrade a widget back to "on" the next time ping succeeded.
#
# These tests use a private $State per case (so file writes are
# isolated) and mock `timeout` to deterministically simulate a
# successful or failing TCP/443 probe without touching the network.
test_pingHostInvalidatesSshOnFailure() {
  ## arrange
  local stateDir
  tesht.MktempDir stateDir || return 128
  State=$stateDir

  # Pre-seed the SSH cache as if a recent successful probe ran.
  echo ok > "$State/widgetT-ssh"

  # Mock `timeout` to fail unconditionally → simulates ping failure.
  timeout() { return 1; }

  ## act
  local got
  got=$(pingHost widgetT example.invalid)

  ## assert
  tesht.Softly <<'  END'
    tesht.AssertGot "$got" "fail"
    tesht.AssertGot "$(cat "$State/widgetT-ssh")" "fail"
  END
}

test_pingHostLeavesSshCacheOnSuccess() {
  ## arrange
  local stateDir
  tesht.MktempDir stateDir || return 128
  State=$stateDir

  # Pre-seed the SSH cache as if a recent successful probe ran.
  echo ok > "$State/widgetT-ssh"

  # Mock `timeout` to succeed → simulates ping success.
  timeout() { return 0; }

  ## act
  local got
  got=$(pingHost widgetT example.invalid)

  ## assert
  tesht.Softly <<'  END'
    tesht.AssertGot "$got" "ok"
    tesht.AssertGot "$(cat "$State/widgetT-ssh")" "ok"
  END
}
