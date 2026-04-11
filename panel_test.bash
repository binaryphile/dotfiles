#!/usr/bin/env bash

# Tests for scripts/panel batModule.
#
# Covers:
#   batModule -- battery widget: sysfs detection, capacity threshold,
#                charge/energy fallback, negative/zero guards.
#
# Uses mock sysfs directories in /tmp via the BatSysfs injectable.

State=/tmp
source "$PWD/scripts/probe-lib.bash" || exit 1
source "$PWD/scripts/panel" || exit 1

# mkBatDir creates a mock sysfs battery directory with the given files.
# Usage: mkBatDir <parentDir> <name> <status> <capacity> [file=value ...]
mkBatDir() {
  local parent=$1 name=$2 status=$3 capacity=$4
  shift 4
  local dir=$parent/$name
  mkdir -p "$dir"
  echo "$status"  > "$dir/status"
  echo "$capacity" > "$dir/capacity"
  local kv
  for kv in "$@"; do
    echo "${kv#*=}" > "$dir/${kv%%=*}"
  done
}

# stripFmt removes tmux format codes from output for clean assertions.
stripFmt() { sed 's/#\[[^]]*\]//g'; }


## batModule

test_batModule() {
  local -A case1=(
    [name]='warning: charge_counter/current_now shows time bat'
    [bat]=battery
    [status]=Discharging
    [capacity]=8
    [files]='current_now=1000000 charge_counter=2000000'
    [want]='2:00'
  )

  local -A case2=(
    [name]='warning: energy_now/power_now shows time bat'
    [bat]=BAT0
    [status]=Discharging
    [capacity]=7
    [files]='power_now=1000000 energy_now=3000000'
    [want]='3:00'
  )

  local -A case3=(
    [name]='negative charge returns nothing'
    [bat]=battery
    [status]=Discharging
    [capacity]=8
    [files]='current_now=1000000 charge_counter=-500'
    [want]=''
  )

  local -A case4=(
    [name]='zero current returns nothing'
    [bat]=battery
    [status]=Discharging
    [capacity]=8
    [files]='current_now=0 charge_counter=2000000'
    [want]=''
  )

  local -A case5=(
    [name]='warning: no compatible files shows nothing'
    [bat]=battery
    [status]=Discharging
    [capacity]=8
    [files]=''
    [want]=''
  )

  local -A case6=(
    [name]='critical: capacity at 5 shows percentage'
    [bat]=battery
    [status]=Discharging
    [capacity]=5
    [files]=''
    [want]='5%% bat'
  )

  local -A case7=(
    [name]='above 10 pct hides widget'
    [bat]=battery
    [status]=Discharging
    [capacity]=11
    [files]='current_now=1000000 charge_counter=2000000'
    [want]=''
  )

  local -A case8=(
    [name]='charging hides widget'
    [bat]=battery
    [status]=Charging
    [capacity]=8
    [files]='current_now=1000000 charge_counter=2000000'
    [want]=''
  )

  local -A case9=(
    [name]='no sysfs dir returns nothing'
    [bat]=MISSING
    [status]=Discharging
    [capacity]=8
    [files]=''
    [want]=''

  )

  local -A case10=(
    [name]='exactly 10 pct shows time bat'
    [bat]=battery
    [status]=Discharging
    [capacity]=10
    [files]='current_now=1000000 charge_counter=500000'
    [want]='0:30'
  )

  subtest() {
    local casename=$1
    eval "$(tesht.Inherit "$casename")"

    local sysfsDir
    tesht.MktempDir sysfsDir || return 128
    local BatSysfs=$sysfsDir

    if [[ $bat != MISSING ]]; then
      local fileArgs
      IFS=' ' read -ra fileArgs <<< "$files"
      mkBatDir "$sysfsDir" "$bat" "$status" "$capacity" "${fileArgs[@]}"
    fi

    local got
    got=$(batModule | stripFmt)

    tesht.AssertGot "${got# }" "$want"
  }

  tesht.Run "${!case@}"
}
