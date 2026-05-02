source ./update-env   # defines NL=$'\n'

## functions

# test_each tests that each applies functions to arguments.
# Subtests are run with tesht.Run.
test_each() {
  local -A case1=(
    [name]='capitalize a list of words'

    [command]="each '_() { echo \${1^}; }; _'"
    [inputs]='(foo bar baz)'
    [wants]="(Foo Bar Baz)"
  )

  # subtest runs each subtest.
  # casename is expected to be the name of an associative array holding at least the key "name".
  subtest() {
    local casename=$1

    ## arrange

    # create variables from the keys/values of the test map
    eval "$(tesht.Inherit "$casename")"

    ## act

    # run the command and capture the output and result code
    local got rc
    got=$(stream "${inputs[@]}" | eval "$command" 2>&1) && rc=$? || rc=$?

    ## assert

    # assert no error
    (( rc == 0 )) || {
      echo "${NL}each: error = $rc, want: 0$NL$got"
      return 1
    }

    # assert that we got the wanted output
    local want=$(stream "${wants[@]}")
    tesht.AssertGot "$got" "$want"
  }

  tesht.Run ${!case@}
}

# It creates temporary directories with test files to control the environment.
test_glob() {
  local -A case1=(
    [name]='match files with a splat'

    [args]='(*.txt)'
    [files]="(file1.txt file2.txt file3.log)"
    [wants]="(file1.txt file2.txt)"
  )

  local -A case2=(
    [name]='return no files if none match'

    [args]='(nonexistent-*)'
    [files]="(file1.txt)"
    [wants]="()"
  )

  local -A case3=(
    [name]='match files with question mark'

    [args]='(file?.txt)'
    [files]="(file1.txt file10.txt)"
    [wants]="(file1.txt)"
  )

  local -A case4=(
    [name]='match multiple patterns'

    [args]='(*.txt *.log)'
    [files]="(file.txt file.log)"
    [wants]="(file.txt file.log)"
  )

  # subtest runs each subtest.
  # casename is expected to be the name of an associative array holding at least the key "name".
  subtest() {
    local casename=$1

    ## arrange

    # temporary directory
    local dir=$(tesht.MktempDir) || return 128  # fatal if can't make dir
    trap "rm -rf $dir" EXIT                     # always clean up
    cd $dir

    # create variables from the keys/values of the test map
    eval "$(tesht.Inherit $casename)"

    # Create test files
    stream "${files[@]}" | each touch

    ## act

    # run the command and capture the output and result code
    local got rc
    got=$(lib.Glob "${args[@]}") && rc=$? || rc=$?

    ## assert
    # assert that we got the wanted output
    local want=$(stream "${wants[@]}")
    tesht.AssertGot "$got" "$want"
  }

  local failed=0 casename
  for casename in ${!case@}; do
    tesht.Run $casename || {
      (( $? == 128 )) && return 128   # fatal
      failed=1
    }
  done

  return $failed
}
# test_keepIf tests that keepIf filters lines by a pattern.
# Subtests are run with tesht.Run.
test_keepIf() {
  local -A case1=(
    [name]='keep only lines that match the pattern'

    [command]="keepIf '_() { [[ \$1 == a* ]]; }; _'"
    [inputs]='(apple banana apricot)'
    [wants]='(apple apricot)'
  )

  local -A case2=(
    [name]='keep only exact matches'

    [command]="keepIf '_() { [[ \$1 == cat ]]; }; _'"
    [inputs]='(cat catalog bobcat)'
    [wants]='(cat)'
  )

  # subtest runs each subtest.
  # casename is expected to be the name of an associative array holding at least the key "name".
  subtest() {
    local casename=$1

    ## arrange

    # create variables from the keys/values of the test map
    eval "$(tesht.Inherit "$casename")"

    ## act

    # run the command and capture the output and result code
    local got rc
    got=$(stream "${inputs[@]}" | eval "$command" 2>&1) && rc=$? || rc=$?

    ## assert

    # assert no error
    (( rc == 0 )) || {
      echo "${NL}keepIf: error = $rc, want: 0$NL$got"
      return 1
    }

    # assert that we got the wanted output
    local want=$(stream "${wants[@]}")
    tesht.AssertGot "$got" "$want"
  }

  tesht.Run "${!case@}"
}

# test_map tests that map applies a command to each line.
# Subtests are run with tesht.Run.
test_map() {
  local -A case1=(
    [name]='prefix each line with a label'

    [command]="map line 'line: \$line'"
    [inputs]='(alpha beta)'
    [wants]="('line: alpha' 'line: beta')"
  )

  local -A case2=(
    [name]='double each numeric line'

    [command]="map line '\$(( line * 2 ))'"
    [inputs]='(1 2 3)'
    [wants]='(2 4 6)'
  )


  # subtest runs each subtest.
  # casename is expected to be the name of an associative array holding at least the key "name".
  subtest() {
    local casename=$1

    ## arrange

    # create variables from the keys/values of the test map
    eval "$(tesht.Inherit "$casename")"

    ## act

    # run the command and capture the output and result code
    local got rc
    got=$(stream "${inputs[@]}" | eval "$command" 2>&1) && rc=$? || rc=$?

    ## assert

    # assert no error
    (( rc == 0 )) || {
      echo "${NL}map: error = $rc, want: 0$NL$got"
      return 1
    }

    # assert that we got the wanted output
    local want=$(stream "${wants[@]}")
    tesht.AssertGot "$got" "$want"
  }

  tesht.Run "${!case@}"
}


# test_stream tests that stream splits space-separated input into separate lines
# Subtests are run with tesht.Run.
test_stream() {
  local -A case1=(
    [name]='split arguments into separate lines'

    [command]='stream foo bar baz'
    [want]=$'foo\nbar\nbaz'
  )

  # subtest runs each subtest.
  # casename is expected to be the name of an associative array holding at least the key "name".
  subtest() {
    local casename=$1

    ## arrange

    # create variables from the keys/values of the test map
    eval "$(tesht.Inherit "$casename")"

    ## act

    # run the command and capture the output and result code
    local got rc
    got=$(eval "$command" 2>&1) && rc=$? || rc=$?

    ## assert

    # assert no error
    (( rc == 0 )) || {
      echo "${NL}stream: error = $rc, want: 0$NL$got"
      return 1
    }

    # assert that we got the wanted output
    tesht.AssertGot "$got" "$want"
  }

  tesht.Run "${!case@}"
}

## hasGroup + platformTaskGroups -- Q1: domain-significant (gates deployment phases)
## Tests cover the real data flow: platformTaskGroups output -> hasGroup input

test_hasGroup() {
  local -A case1=(
    [name]='exact match in middle'
    [groupList]=$'apt\nhostname\nhm\ncredential'
    [group]=hm
    [wantRc]=0
  )
  local -A case2=(
    [name]='match at start'
    [groupList]=$'apt\nhostname'
    [group]=apt
    [wantRc]=0
  )
  local -A case3=(
    [name]='match at end'
    [groupList]=$'apt\ncredential'
    [group]=credential
    [wantRc]=0
  )
  local -A case4=(
    [name]='substring rejected'
    [groupList]=$'apt\nhostname\nhm'
    [group]=h
    [wantRc]=1
  )
  local -A case5=(
    [name]='superstring rejected'
    [groupList]=$'apt\nhm'
    [group]=hm2
    [wantRc]=1
  )
  local -A case6=(
    [name]='not present'
    [groupList]=$'apt\nhostname'
    [group]=nix
    [wantRc]=1
  )
  local -A case7=(
    [name]='empty list'
    [groupList]=''
    [group]=apt
    [wantRc]=1
  )

  subtest() {
    local casename=$1
    eval "$(tesht.Inherit "$casename")"
    local rc
    hasGroup "$groupList" $group && rc=0 || rc=$?
    (( rc == wantRc )) || { echo "rc=$rc, want $wantRc"; return 1; }
  }

  tesht.Run ${!case@}
}

## platformTaskGroups -- Q1: pure decision function, domain-significant
## Output is newline-separated (IFS=$'\n' + ${array[*]}). Tests verify
## exact newline structure, not normalized spaces.

test_platformTaskGroups() {
  local -A case1=(
    [name]='crostini gets all groups'
    [platform]=crostini
    [wantGroupList]=$'apt\nhostname\ngpoc\nnix\nhm\ncredential'
  )
  local -A case2=(
    [name]='debian gets apt nix hm'
    [platform]=debian
    [wantGroupList]=$'apt\nnix\nhm'
  )
  local -A case3=(
    [name]='desktop gets nix only'
    [platform]=desktop
    [wantGroupList]=nix
  )
  local -A case4=(
    [name]='macos gets nix only'
    [platform]=macos
    [wantGroupList]=nix
  )
  local -A case5=(
    [name]='nixos gets nothing'
    [platform]=nixos
    [wantGroupList]=''
  )

  subtest() {
    local casename=$1
    eval "$(tesht.Inherit "$casename")"
    local gotGroupList
    gotGroupList=$(platformTaskGroups $platform)
    [[ $gotGroupList == "$wantGroupList" ]] || {
      echo "got=$(printf '%q' "$gotGroupList")"
      echo "want=$(printf '%q' "$wantGroupList")"
      return 1
    }
  }

  tesht.Run ${!case@}
}

## Real data flow: platformTaskGroups -> hasGroup
## This is the actual production path. Verifies newline-separated output
## from platformTaskGroups works correctly with hasGroup when quoted.

test_hasGroupWithPlatformTaskGroups() {
  local -A case1=(
    [name]='crostini has hm'
    [platform]=crostini
    [group]=hm
    [wantRc]=0
  )
  local -A case2=(
    [name]='crostini has credential'
    [platform]=crostini
    [group]=credential
    [wantRc]=0
  )
  local -A case3=(
    [name]='debian does not have credential'
    [platform]=debian
    [group]=credential
    [wantRc]=1
  )
  local -A case4=(
    [name]='nixos has nothing'
    [platform]=nixos
    [group]=nix
    [wantRc]=1
  )

  subtest() {
    local casename=$1
    eval "$(tesht.Inherit "$casename")"
    local groupList
    groupList=$(platformTaskGroups $platform)
    local rc
    hasGroup "$groupList" $group && rc=0 || rc=$?
    (( rc == wantRc )) || { echo "rc=$rc, want $wantRc"; return 1; }
  }

  tesht.Run ${!case@}
}

## loosely -- state management, domain-critical (broken = no error handling)
## Tests verify flag restoration survives the exact failure mode that
## occurred: $(set +o) in a subshell loses errexit. Also tests nested
## calls and failure inside the loosely block.

test_loosely_preservesFlags() {
  local -A case1=( [name]='preserves errexit'  [flag]=e )
  local -A case2=( [name]='preserves nounset'  [flag]=u )
  local -A case3=( [name]='preserves noglob'   [flag]=f )

  subtest() {
    local casename=$1
    eval "$(tesht.Inherit "$casename")"
    set -$flag
    loosely true
    [[ $- == *$flag* ]] || { echo "flag -$flag lost after loosely"; return 1; }
  }

  tesht.Run ${!case@}
}

test_loosely_preservesPipefail() {
  set -o pipefail
  loosely true
  shopt -qo pipefail || { echo "pipefail lost"; return 1; }
}

test_loosely_restoresIfs() {
  local before_=$IFS
  loosely true
  [[ $IFS == "$before_" ]] || { echo "IFS changed"; return 1; }
}

test_loosely_nestedCalls() {
  set -eufo pipefail
  loosely loosely true
  [[ $- == *e* ]] || { echo "errexit lost after nested loosely"; return 1; }
  [[ $- == *f* ]] || { echo "noglob lost after nested loosely"; return 1; }
  shopt -qo pipefail || { echo "pipefail lost after nested loosely"; return 1; }
}

test_loosely_failureInsidePreservesFlags() {
  set -eufo pipefail
  loosely false  # command fails, but loosely should still restore
  [[ $- == *e* ]] || { echo "errexit lost after failed command"; return 1; }
  shopt -qo pipefail || { echo "pipefail lost after failed command"; return 1; }
}

# Regression guard: the original bug was $(set +o) capturing errexit as OFF
# inside a command substitution subshell. This test verifies that after
# calling loosely, a subsequent failing command actually triggers errexit.
test_loosely_errexitActuallyWorks() {
  local rc
  rc=$(bash -c '
    source ./update-env 2>/dev/null
    set -eufo pipefail
    loosely true
    false
    echo "SHOULD NOT REACH"
  ' 2>&1) && rc=0 || rc=$?
  [[ $rc -ne 0 ]] || { echo "errexit did not trigger after loosely: output=$rc"; return 1; }
  [[ $rc != *"SHOULD NOT REACH"* ]] || { echo "script continued past false"; return 1; }
}

## agentTomlContent -- Q1: pure output, security-significant (controls agent key exposure)

test_agentTomlContent() {
  local got_
  got_=$(agentTomlContent testhost)
  local want_='[[ssh-keys]]
vault = "Private"
item = "testhost signing SSH Key"

[[ssh-keys]]
vault = "Private"
item = "testhost SSH Key"'
  [[ $got_ == "$want_" ]] || {
    echo "got:"
    echo "$got_"
    echo "want:"
    echo "$want_"
    return 1
  }
}

## Q3 integration tests -- real filesystem, direct task calls.
## Pattern: backup -> remove target -> re-run -> verify restored -> verify
## idempotent (second run = no change) -> restore backup.
## Trap guarantees teardown even on test failure.
## Task output suppressed (>/dev/null 2>&1) to keep test output clean.

test_claudeBaseCopyTask_converges() {
  local target=$HOME/.claude/CLAUDE.md
  local backup=$(mktemp)
  trap "cp $backup $target; rm -f $backup" RETURN

  claudeBaseCopyTask >/dev/null 2>&1
  cp $target $backup

  # convergence: remove -> re-run -> restored
  rm $target
  claudeBaseCopyTask >/dev/null 2>&1
  local rc=0
  [[ -f $target ]] || { echo "target not restored"; rc=1; }
  diff -q $target $HOME/dotfiles/claude/CLAUDE.md >/dev/null 2>&1 || { echo "content doesn't match source"; rc=1; }

  # idempotence: second run = no change
  local hashBefore hashAfter
  hashBefore=$(sha256sum $target | awk '{print $1}')
  claudeBaseCopyTask >/dev/null 2>&1
  hashAfter=$(sha256sum $target | awk '{print $1}')
  [[ $hashBefore == $hashAfter ]] || { echo "not idempotent"; rc=1; }

  return $rc
}

test_agentTomlTask_converges() {
  local target=$HOME/.config/1Password/ssh/agent.toml
  local backup=$(mktemp)
  trap "cp $backup $target; rm -f $backup" RETURN

  agentTomlTask >/dev/null 2>&1
  cp $target $backup

  # convergence
  rm $target
  agentTomlTask >/dev/null 2>&1
  local rc=0
  [[ -f $target ]] || { echo "target not restored"; rc=1; }
  # verify content uses the actual hostname, not hardcoded
  local hostname
  hostname=$(lib.MachineHostname)
  grep -q "$(opAuthKeyItem $hostname)" $target || { echo "auth key item not in content"; rc=1; }
  grep -q "$(opSigningKeyItem $hostname)" $target || { echo "signing key item not in content"; rc=1; }

  # idempotence
  local hashBefore hashAfter
  hashBefore=$(sha256sum $target | awk '{print $1}')
  agentTomlTask >/dev/null 2>&1
  hashAfter=$(sha256sum $target | awk '{print $1}')
  [[ $hashBefore == $hashAfter ]] || { echo "not idempotent"; rc=1; }

  return $rc
}

test_deploySigningPub_converges() {
  local target=$HOME/.ssh/id_ed25519_signing.pub
  local backup=$(mktemp)
  trap "cp $backup $target; rm -f $backup" RETURN

  deploySigningPub >/dev/null 2>&1
  cp $target $backup

  # convergence
  rm $target
  deploySigningPub >/dev/null 2>&1
  local rc=0
  [[ -f $target ]] || { echo "target not restored"; rc=1; }

  # idempotence
  local hashBefore hashAfter
  hashBefore=$(sha256sum $target | awk '{print $1}')
  deploySigningPub >/dev/null 2>&1
  hashAfter=$(sha256sum $target | awk '{print $1}')
  [[ $hashBefore == $hashAfter ]] || { echo "not idempotent"; rc=1; }

  return $rc
}

test_claudeEraConfigTask_appendsOnlyOnce() {
  local target=$HOME/.claude/CLAUDE.md
  local backup=$(mktemp)
  trap "cp $backup $target; rm -f $backup" RETURN

  claudeBaseCopyTask >/dev/null 2>&1
  cp $target $backup

  # write base-only content (strip era if present)
  cp $HOME/dotfiles/claude/CLAUDE.md $target

  # convergence: append runs
  claudeEraConfigTask >/dev/null 2>&1
  local rc=0
  grep -qF 'Era is your persistent memory' $target || { echo "era config not appended"; rc=1; }

  # idempotence: second append = no change
  local sizeBefore sizeAfter
  sizeBefore=$(wc -c < $target)
  claudeEraConfigTask >/dev/null 2>&1
  sizeAfter=$(wc -c < $target)
  (( sizeBefore == sizeAfter )) || { echo "appended twice: $sizeBefore -> $sizeAfter"; rc=1; }

  return $rc
}
