#!/usr/bin/env bash

# Tests for scripts/probe-lib.bash.
#
# Covers:
#   combine     -- pure state machine at the heart of widget rendering
#   pingHost    -- side effect: invalidates SSH cache on failure
#   sshHost     -- maps SSH exit codes to ok/fail
#   bitbucketApiProbe -- maps Atlassian status JSON to on/partial/off
#   codebergApiProbe  -- maps Codeberg heartbeat JSON to on/off
#
# External commands (timeout, ssh, curl) are injected via probe-lib's
# global command variables and overridden in case declarations.

State=/tmp
source "$PWD/scripts/probe-lib.bash" || exit 1

# Parameterized mocks.  Behavior is controlled by locals that appear
# as keys in the case tables -- tesht.Inherit brings them into scope.
mockTimeout() { return "$mockRc"; }
mockSsh()     { [[ -n ${mockStderr:-} ]] && echo "$mockStderr" >&2; return "$mockRc"; }
mockCurl()    { [[ -n ${mockOutput:-} ]] && echo "$mockOutput"; return "${mockRc:-0}"; }


## combine

test_combine() {
  local -A case1=(
    [name]='all ok'
    [ssh]=ok      [ping]=ok      [api]=on
    [want]=on
  )

  local -A case2=(
    [name]='api degraded wins over ok ssh+ping'
    [ssh]=ok      [ping]=ok      [api]=degraded
    [want]=partial
  )

  local -A case3=(
    [name]='api partial wins over ok ssh+ping'
    [ssh]=ok      [ping]=ok      [api]=partial
    [want]=partial
  )

  local -A case4=(
    [name]='api off wins over ok ssh+ping'
    [ssh]=ok      [ping]=ok      [api]=off
    [want]=off
  )

  local -A case5=(
    [name]='api down wins over ok ssh+ping'
    [ssh]=ok      [ping]=ok      [api]=down
    [want]=off
  )

  local -A case6=(
    [name]='ssh fail degrades to partial'
    [ssh]=fail    [ping]=ok      [api]=on
    [want]=partial
  )

  local -A case7=(
    [name]='ssh unknown degrades to partial'
    [ssh]=unknown [ping]=ok      [api]=on
    [want]=partial
  )

  local -A case8=(
    [name]='ping fail wins over ok ssh'
    [ssh]=ok      [ping]=fail    [api]=on
    [want]=off
  )

  local -A case9=(
    [name]='both fail'
    [ssh]=fail    [ping]=fail    [api]=on
    [want]=off
  )

  local -A case10=(
    [name]='ping unknown yields unknown'
    [ssh]=ok      [ping]=unknown [api]=on
    [want]=unknown
  )

  local -A case11=(
    [name]='all unknown'
    [ssh]=unknown [ping]=unknown [api]=on
    [want]=unknown
  )

  local -A case12=(
    [name]='ssh skip with ping ok yields on'
    [ssh]=skip    [ping]=ok      [api]=on
    [want]=on
  )

  local -A case13=(
    [name]='ssh skip with api degraded yields partial'
    [ssh]=skip    [ping]=ok      [api]=degraded
    [want]=partial
  )

  subtest() {
    local casename=$1
    eval "$(tesht.Inherit "$casename")"

    local got
    got=$(combine "$ssh" "$ping" "$api")

    tesht.AssertGot "$got" "$want"
  }

  tesht.Run "${!case@}"
}


## pingHost -- side effect: invalidates SSH cache on failure

test_pingHostInvalidatesSshOnFailure() {
  ## arrange
  local stateDir
  tesht.MktempDir stateDir || return 128
  State=$stateDir
  echo ok > "$State/widgetT-ssh"
  local timeout=mockTimeout mockRc=1

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
  echo ok > "$State/widgetT-ssh"
  local timeout=mockTimeout mockRc=0

  ## act
  local got
  got=$(pingHost widgetT example.invalid)

  ## assert
  tesht.Softly <<'  END'
    tesht.AssertGot "$got" "ok"
    tesht.AssertGot "$(cat "$State/widgetT-ssh")" "ok"
  END
}


## sshHost -- maps exit codes to ok/fail

test_sshHost() {
  local -A case1=(
    [name]='rc 0 means ok'
    [ssh]=mockSsh
    [mockRc]=0
    [mockStderr]=''
    [want]=ok
  )

  local -A case2=(
    [name]='rc 1 means ok (git rejection)'
    [ssh]=mockSsh
    [mockRc]=1
    [mockStderr]='successfully authenticated'
    [want]=ok
  )

  local -A case3=(
    [name]='shell request failed means ok'
    [ssh]=mockSsh
    [mockRc]=128
    [mockStderr]='shell request failed on channel 0'
    [want]=ok
  )

  local -A case4=(
    [name]='rc 255 means fail (timeout)'
    [ssh]=mockSsh
    [mockRc]=255
    [mockStderr]=''
    [want]=fail
  )

  subtest() {
    local casename=$1
    eval "$(tesht.Inherit "$casename")"

    local got
    got=$(sshHost example.invalid)

    tesht.AssertGot "$got" "$want"
  }

  tesht.Run "${!case@}"
}


## bitbucketApiProbe -- real jq validates the filter expression

test_bitbucketApiProbe() {
  local -A case1=(
    [name]='operational means on'
    [curl]=mockCurl
    [mockOutput]='{"components":[{"id":"qmh4tj8h5kbn","status":"operational"}]}'
    [want]=on
  )

  local -A case2=(
    [name]='degraded_performance means partial'
    [curl]=mockCurl
    [mockOutput]='{"components":[{"id":"qmh4tj8h5kbn","status":"degraded_performance"}]}'
    [want]=partial
  )

  local -A case3=(
    [name]='partial_outage means partial'
    [curl]=mockCurl
    [mockOutput]='{"components":[{"id":"qmh4tj8h5kbn","status":"partial_outage"}]}'
    [want]=partial
  )

  local -A case4=(
    [name]='major_outage means off'
    [curl]=mockCurl
    [mockOutput]='{"components":[{"id":"qmh4tj8h5kbn","status":"major_outage"}]}'
    [want]=off
  )

  local -A case5=(
    [name]='curl failure means off'
    [curl]=mockCurl
    [mockOutput]=''
    [mockRc]=1
    [want]=off
  )

  subtest() {
    local casename=$1
    eval "$(tesht.Inherit "$casename")"

    local got
    got=$(bitbucketApiProbe)

    tesht.AssertGot "$got" "$want"
  }

  tesht.Run "${!case@}"
}


## digiApiProbe -- worst-of across all Digi status page components

test_digiApiProbe() {
  local -A case1=(
    [name]='all operational means on'
    [curl]=mockCurl
    [mockOutput]='{"components":[{"status":"operational"},{"status":"operational"}]}'
    [want]=on
  )

  local -A case2=(
    [name]='one degraded means partial'
    [curl]=mockCurl
    [mockOutput]='{"components":[{"status":"operational"},{"status":"degraded_performance"}]}'
    [want]=partial
  )

  local -A case3=(
    [name]='one major outage means off'
    [curl]=mockCurl
    [mockOutput]='{"components":[{"status":"operational"},{"status":"major_outage"}]}'
    [want]=off
  )

  local -A case4=(
    [name]='curl failure means off'
    [curl]=mockCurl
    [mockOutput]=''
    [mockRc]=1
    [want]=off
  )

  subtest() {
    local casename=$1
    eval "$(tesht.Inherit "$casename")"

    local got
    got=$(digiApiProbe)

    tesht.AssertGot "$got" "$want"
  }

  tesht.Run "${!case@}"
}


## codebergApiProbe

test_codebergApiProbe() {
  local -A case1=(
    [name]='heartbeat status 1 means on'
    [curl]=mockCurl
    [mockOutput]='{"heartbeatList":{"7":[{"status":1}]}}'
    [want]=on
  )

  local -A case2=(
    [name]='heartbeat status 0 means off'
    [curl]=mockCurl
    [mockOutput]='{"heartbeatList":{"7":[{"status":0}]}}'
    [want]=off
  )

  local -A case3=(
    [name]='curl failure means off'
    [curl]=mockCurl
    [mockOutput]=''
    [mockRc]=1
    [want]=off
  )

  subtest() {
    local casename=$1
    eval "$(tesht.Inherit "$casename")"

    local got
    got=$(codebergApiProbe)

    tesht.AssertGot "$got" "$want"
  }

  tesht.Run "${!case@}"
}
