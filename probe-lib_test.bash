#!/usr/bin/env bash

# Tests for scripts/probe-lib.bash. Covers combine() (the pure-
# function heart of the widget state machine), pingHost's load-bearing
# side effect of invalidating the cached SSH success on failure, and
# sshHost's interpretation of SSH exit codes. External commands
# (timeout, ssh) are injected via probe-lib's global command variables.
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
# isolated) and inject a mock `$Timeout` command via the global to
# deterministically simulate a successful or failing TCP/443 probe
# without touching the network.

mockTimeoutFail() { return 1; }
mockTimeoutOk()   { return 0; }

# sshHost mock helpers. Each simulates a different ssh exit scenario.
# The mock receives all the args that $Ssh would (e.g. -T -o ... git@host)
# but ignores them — the test controls behavior via which mock is injected.
mockSshRc0()              { return 0; }
mockSshRc1()              { echo "Hi there! You've successfully authenticated" >&2; return 1; }
mockSshShellRequestFailed() { echo "shell request failed on channel 0" >&2; return 128; }
mockSshTimeout()          { return 255; }

test_pingHostInvalidatesSshOnFailure() {
  ## arrange
  local stateDir
  tesht.MktempDir stateDir || return 128
  State=$stateDir

  # Pre-seed the SSH cache as if a recent successful probe ran.
  echo ok > "$State/widgetT-ssh"

  # Inject failing timeout → simulates ping failure.
  local Timeout=mockTimeoutFail

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

  # Inject succeeding timeout → simulates ping success.
  local Timeout=mockTimeoutOk

  ## act
  local got
  got=$(pingHost widgetT example.invalid)

  ## assert
  tesht.Softly <<'  END'
    tesht.AssertGot "$got" "ok"
    tesht.AssertGot "$(cat "$State/widgetT-ssh")" "ok"
  END
}

# sshHost returns ok when SSH indicates the server is reachable (rc 0,
# rc 1, or "shell request failed" — all mean the SSH layer responded)
# and fail otherwise (e.g. connection timeout rc 255).
test_sshHost() {
  local -A case1=([name]='rc 0 → ok'                    [mock]=mockSshRc0              [want]=ok)
  local -A case2=([name]='rc 1 → ok (git rejection)'    [mock]=mockSshRc1              [want]=ok)
  local -A case3=([name]='shell request failed → ok'     [mock]=mockSshShellRequestFailed [want]=ok)
  local -A case4=([name]='rc 255 (timeout) → fail'       [mock]=mockSshTimeout          [want]=fail)

  subtest() {
    local casename=$1
    eval "$(tesht.Inherit "$casename")"

    local Ssh=$mock
    local got
    got=$(sshHost example.invalid)

    tesht.AssertGot "$got" "$want"
  }

  tesht.Run "${!case@}"
}
