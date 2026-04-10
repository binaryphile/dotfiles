#!/usr/bin/env bash

# Tests for scripts/probe-lib.bash. Currently focused on combine(),
# the pure-function heart of the widget state machine. Network
# probes (sshHost, pingHost, vendor APIs) are intentionally not
# tested here — they would require either real network access or a
# mocking layer that adds more complexity than the probes themselves.
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
