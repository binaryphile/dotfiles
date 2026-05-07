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
    local want
    want=$(stream "${wants[@]}")
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
    local dir; tesht.MktempDir dir || return 128  # fatal if can't make dir
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
    local want
    want=$(stream "${wants[@]}")
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
    local want
    want=$(stream "${wants[@]}")
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
    local want
    want=$(stream "${wants[@]}")
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
    [name]='desktop gets nix hm'
    [platform]=desktop
    [wantGroupList]=$'nix\nhm'
  )
  local -A case4=(
    [name]='macos gets nix hm'
    [platform]=macos
    [wantGroupList]=$'nix\nhm'
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
item = "calliope signing SSH Key"

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

## Q3 integration tests -- real filesystem in tmp, direct task calls.
## Each test creates isolated temp dirs, injects paths via lowercase globals,
## and cleans up via trap. No interaction with live $HOME config.

test_claudeBaseCopyTask_converges() {
  local dir; tesht.MktempDir dir || return 128
  trap "rm -rf $dir" RETURN

  # arrange: source file in tmp
  mkdir -p $dir/src $dir/dst
  echo '# test base content' >$dir/src/CLAUDE.md

  # act: inject paths and run
  local claudeBase_src=$dir/src/CLAUDE.md
  local claudeBase_dst=$dir/dst/CLAUDE.md
  local claudeBase_hash=$dir/dst/CLAUDE.md.base-src-hash
  claudeBaseCopyTask >/dev/null 2>&1

  # assert: convergence (file + hash sentinel)
  local rc=0
  [[ -f $dir/dst/CLAUDE.md ]]                  || { echo "target not created"; rc=1; }
  [[ -f $dir/dst/CLAUDE.md.base-src-hash ]]    || { echo "hash sentinel not created"; rc=1; }
  diff -q $dir/src/CLAUDE.md $dir/dst/CLAUDE.md >/dev/null 2>&1 || { echo "content mismatch"; rc=1; }

  # assert: idempotence
  local hashBefore hashAfter
  hashBefore=$(sha256sum $dir/dst/CLAUDE.md | awk '{print $1}')
  claudeBaseCopyTask >/dev/null 2>&1
  hashAfter=$(sha256sum $dir/dst/CLAUDE.md | awk '{print $1}')
  [[ $hashBefore == $hashAfter ]] || { echo "not idempotent"; rc=1; }

  return $rc
}

# Source change must trigger redeploy (the whole reason the task became
# content-aware). Without this property, a fixed source path doesn't propagate.
test_claudeBaseCopyTask_redeploysOnSourceChange() {
  local dir; tesht.MktempDir dir || return 128
  trap "rm -rf $dir" RETURN

  mkdir -p $dir/src $dir/dst
  echo '# v1 content' >$dir/src/CLAUDE.md

  local claudeBase_src=$dir/src/CLAUDE.md
  local claudeBase_dst=$dir/dst/CLAUDE.md
  local claudeBase_hash=$dir/dst/CLAUDE.md.base-src-hash

  # arrange: initial deploy
  claudeBaseCopyTask >/dev/null 2>&1

  # act: change source content, re-run
  echo '# v2 content -- source changed' >$dir/src/CLAUDE.md
  claudeBaseCopyTask >/dev/null 2>&1

  # assert: dst now matches the new source
  local rc=0
  diff -q $dir/src/CLAUDE.md $dir/dst/CLAUDE.md >/dev/null 2>&1 \
    || { echo "dst not updated after source change"; rc=1; }
  return $rc
}

# Missing hash sentinel (legacy installs that pre-date the content-aware
# behavior) must trigger redeploy so the sentinel gets written, restoring
# content-awareness on the next run.
test_claudeBaseCopyTask_redeploysWhenSentinelMissing() {
  local dir; tesht.MktempDir dir || return 128
  trap "rm -rf $dir" RETURN

  mkdir -p $dir/src $dir/dst
  echo '# legacy deploy' >$dir/src/CLAUDE.md
  # simulate legacy install: dst exists, no sentinel.
  cp $dir/src/CLAUDE.md $dir/dst/CLAUDE.md

  local claudeBase_src=$dir/src/CLAUDE.md
  local claudeBase_dst=$dir/dst/CLAUDE.md
  local claudeBase_hash=$dir/dst/CLAUDE.md.base-src-hash

  # act: run; should deploy and create sentinel even though dst content matches.
  claudeBaseCopyTask >/dev/null 2>&1

  local rc=0
  [[ -f $claudeBase_hash ]] || { echo "sentinel not created on legacy redeploy"; rc=1; }
  return $rc
}

# Matching hash sentinel + matching source = no-op. Verify the dst's mtime
# does NOT advance when the task is a no-op, proving the content-aware
# fast-path actually short-circuits the cp.
test_claudeBaseCopyTask_noopWhenHashMatches() {
  local dir; tesht.MktempDir dir || return 128
  trap "rm -rf $dir" RETURN

  mkdir -p $dir/src $dir/dst
  echo '# stable content' >$dir/src/CLAUDE.md

  local claudeBase_src=$dir/src/CLAUDE.md
  local claudeBase_dst=$dir/dst/CLAUDE.md
  local claudeBase_hash=$dir/dst/CLAUDE.md.base-src-hash

  claudeBaseCopyTask >/dev/null 2>&1

  local mtimeBefore mtimeAfter
  mtimeBefore=$(stat -c '%Y' $dir/dst/CLAUDE.md)
  sleep 1  # make any rewrite observable in a 1s mtime resolution
  claudeBaseCopyTask >/dev/null 2>&1
  mtimeAfter=$(stat -c '%Y' $dir/dst/CLAUDE.md)

  local rc=0
  [[ $mtimeBefore == $mtimeAfter ]] || { echo "dst rewritten despite hash match (mtime $mtimeBefore -> $mtimeAfter)"; rc=1; }
  return $rc
}

test_agentTomlTask_converges() {
  local dir; tesht.MktempDir dir || return 128
  trap "rm -rf $dir" RETURN

  # act: inject paths
  local agentToml_hostname=testhost
  local agentToml_path=$dir/agent.toml
  agentTomlTask >/dev/null 2>&1

  # assert: convergence
  local rc=0
  [[ -f $dir/agent.toml ]] || { echo "target not created"; rc=1; }
  grep -q "$(opAuthKeyItem testhost)" $dir/agent.toml || { echo "auth key missing"; rc=1; }
  grep -q "$(opSigningKeyItem testhost)" $dir/agent.toml || { echo "signing key missing"; rc=1; }

  # assert: idempotence
  local hashBefore hashAfter
  hashBefore=$(sha256sum $dir/agent.toml | awk '{print $1}')
  agentTomlTask >/dev/null 2>&1
  hashAfter=$(sha256sum $dir/agent.toml | awk '{print $1}')
  [[ $hashBefore == $hashAfter ]] || { echo "not idempotent"; rc=1; }

  return $rc
}

test_deploySigningPub_converges() {
  local dir; tesht.MktempDir dir || return 128
  trap "rm -rf $dir" RETURN

  # arrange: fake .pub sidecar in tmp
  mkdir -p $dir/src $dir/dst
  echo 'ssh-ed25519 AAAA test@testhost' >$dir/src/id_ed25519_signing_testhost.pub

  # act: inject paths
  local signingPub_hostname=testhost
  local signingPub_src=$dir/src/id_ed25519_signing_testhost.pub
  local signingPub_dst=$dir/dst/id_ed25519_signing.pub
  deploySigningPub >/dev/null 2>&1

  # assert: convergence
  local rc=0
  [[ -f $dir/dst/id_ed25519_signing.pub ]] || { echo "target not created"; rc=1; }
  diff -q $dir/src/id_ed25519_signing_testhost.pub $dir/dst/id_ed25519_signing.pub >/dev/null 2>&1 || { echo "content mismatch"; rc=1; }

  # assert: idempotence
  local hashBefore hashAfter
  hashBefore=$(sha256sum $dir/dst/id_ed25519_signing.pub | awk '{print $1}')
  deploySigningPub >/dev/null 2>&1
  hashAfter=$(sha256sum $dir/dst/id_ed25519_signing.pub | awk '{print $1}')
  [[ $hashBefore == $hashAfter ]] || { echo "not idempotent"; rc=1; }

  return $rc
}

test_claudeEraConfigTask_converges() {
  local dir; tesht.MktempDir dir || return 128
  trap "rm -rf $dir" RETURN

  # arrange: base and era source files
  echo '# base content' >$dir/base.md
  echo 'Era is your persistent memory' >$dir/era.md

  # act: inject paths, run append
  local claudeEra_base=$dir/base.md
  local claudeEra_src=$dir/era.md
  claudeEraConfigTask >/dev/null 2>&1

  # assert: convergence (era appended)
  local rc=0
  grep -qF 'Era is your persistent memory' $dir/base.md || { echo "era not appended"; rc=1; }

  # assert: idempotence (second run = no change)
  local sizeBefore sizeAfter
  sizeBefore=$(wc -c < $dir/base.md)
  claudeEraConfigTask >/dev/null 2>&1
  sizeAfter=$(wc -c < $dir/base.md)
  (( sizeBefore == sizeAfter )) || { echo "appended twice: $sizeBefore -> $sizeAfter"; rc=1; }

  return $rc
}

test_claudeEraConfigTask_skipsWhenBaseMissing() {
  local dir; tesht.MktempDir dir || return 128
  trap "rm -rf $dir" RETURN

  echo 'Era is your persistent memory' >$dir/era.md
  local claudeEra_base=$dir/base.md
  local claudeEra_src=$dir/era.md
  claudeEraConfigTask >/dev/null 2>&1

  [[ ! -f $dir/base.md ]] || { echo "base should not be created by era task"; return 1; }
}

test_claudeEraConfigTask_skipsWhenEraMissing() {
  local dir; tesht.MktempDir dir || return 128
  trap "rm -rf $dir" RETURN

  echo '# base only' >$dir/base.md
  local claudeEra_base=$dir/base.md
  local claudeEra_src=$dir/nonexistent.md
  claudeEraConfigTask >/dev/null 2>&1

  # base should be unchanged (check guard skips when era source missing)
  [[ $(cat $dir/base.md) == '# base only' ]] || { echo "base was modified despite missing era source"; return 1; }
}

test_deploySigningPub_skipsWhenSidecarMissing() {
  local dir; tesht.MktempDir dir || return 128
  trap "rm -rf $dir" RETURN

  local signingPub_hostname=testhost
  local signingPub_src=$dir/nonexistent.pub
  local signingPub_dst=$dir/dst/signing.pub
  deploySigningPub >/dev/null 2>&1

  [[ ! -f $dir/dst/signing.pub ]] || { echo "dst created despite missing sidecar"; return 1; }
}

test_platformTaskGroups_unknownPlatformGetsNothing() {
  local got
  got=$(platformTaskGroups unknownplatform)
  [[ -z $got ]] || { echo "unknown platform got groups: $(printf '%q' "$got")"; return 1; }
}

## detectPlatform -- Q1: pure detection, domain-significant

test_detectPlatform_returnsKnownPlatform() {
  local got
  got=$(detectPlatform)
  case $got in
    macos|crostini|desktop|debian|nixos) ;;
    # host-specific NixOS platform (e.g., calumny) is also valid
    *) [[ -d ~/dotfiles/contexts/$got ]] || { echo "unknown platform: $got"; return 1; };;
  esac
}

test_detectPlatform_neverReturnsLinux() {
  local got
  got=$(detectPlatform)
  [[ $got != linux ]] || { echo "detectPlatform returned 'linux' -- should be 'desktop'"; return 1; }
}

## shellcheckrcTask -- Q3 integration: neutral path + symlink deployment

test_shellcheckrcTask_converges() {
  local dir; tesht.MktempDir dir || return 128
  trap "rm -rf $dir" RETURN

  # arrange: source shellcheckrc and one work project
  mkdir -p $dir/dotfiles $dir/.config $dir/projects/urma
  echo 'disable=SC2086' >$dir/dotfiles/.shellcheckrc

  # act: inject paths and run
  local shellcheckrc_src=$dir/dotfiles/.shellcheckrc
  local shellcheckrc_neutral=$dir/.config/shellcheck/shellcheckrc
  local HOME=$dir
  shellcheckrcTask >/dev/null 2>&1

  # assert: neutral path deployed with correct content
  local rc=0
  [[ -f $dir/.config/shellcheck/shellcheckrc ]] || { echo "neutral path not created"; rc=1; }
  diff -q $dir/dotfiles/.shellcheckrc $dir/.config/shellcheck/shellcheckrc >/dev/null 2>&1 || { echo "neutral content mismatch"; rc=1; }

  # assert: work project has symlink to neutral path
  [[ -L $dir/projects/urma/.shellcheckrc ]] || { echo "symlink not created"; rc=1; }
  local target
  target=$(readlink $dir/projects/urma/.shellcheckrc)
  [[ $target == $dir/.config/shellcheck/shellcheckrc ]] || { echo "symlink target wrong: $target"; rc=1; }

  # assert: idempotent
  local hashBefore hashAfter
  hashBefore=$(sha256sum $dir/.config/shellcheck/shellcheckrc | awk '{print $1}')
  shellcheckrcTask >/dev/null 2>&1
  hashAfter=$(sha256sum $dir/.config/shellcheck/shellcheckrc | awk '{print $1}')
  [[ $hashBefore == $hashAfter ]] || { echo "not idempotent"; rc=1; }

  return $rc
}

## flakeLockPinTask -- Q3 integration: nixpkgs rev pinning across flakes
## The cmd calls `nix flake lock` (requires nix + network), so we test the
## ok-check logic only. Invoke flakeLockPinTask to define inner functions,
## then test flakeLocksPinned directly.

test_flakeLockPinTask_detectsMismatch() {
  local dir; tesht.MktempDir dir || return 128
  trap "rm -rf $dir" RETURN

  # arrange: canonical with one rev, project with a different rev
  mkdir -p $dir/projects/era $dir/projects/foo
  cat >$dir/projects/era/flake.lock <<'JSON'
{"nodes":{"nixpkgs":{"locked":{"rev":"aaaa"}},"root":{"inputs":{"nixpkgs":"nixpkgs"}}}}
JSON
  cat >$dir/projects/foo/flake.lock <<'JSON'
{"nodes":{"nixpkgs":{"locked":{"rev":"bbbb"}},"root":{"inputs":{"nixpkgs":"nixpkgs"}}}}
JSON
  echo '{}' >$dir/projects/foo/flake.nix

  # act: run task to define inner functions, then test ok-check
  local HOME=$dir
  flakeLockPinTask >/dev/null 2>&1  # will attempt cmd (nix not available = fails gracefully)
  flakeLocksPinned && { echo "should have detected mismatch"; return 1; }
  return 0
}

test_flakeLockPinTask_passesWhenAligned() {
  local dir; tesht.MktempDir dir || return 128
  trap "rm -rf $dir" RETURN

  # arrange: same rev everywhere
  mkdir -p $dir/projects/era $dir/projects/foo
  cat >$dir/projects/era/flake.lock <<'JSON'
{"nodes":{"nixpkgs":{"locked":{"rev":"aaaa"}},"root":{"inputs":{"nixpkgs":"nixpkgs"}}}}
JSON
  cat >$dir/projects/foo/flake.lock <<'JSON'
{"nodes":{"nixpkgs":{"locked":{"rev":"aaaa"}},"root":{"inputs":{"nixpkgs":"nixpkgs"}}}}
JSON
  echo '{}' >$dir/projects/foo/flake.nix

  # act
  local HOME=$dir
  flakeLockPinTask >/dev/null 2>&1
  flakeLocksPinned || { echo "should have passed"; return 1; }
  return 0
}

test_flakeLockPinTask_skipsWhenCanonicalMissing() {
  local dir; tesht.MktempDir dir || return 128
  trap "rm -rf $dir" RETURN

  mkdir -p $dir/projects/foo
  echo '{}' >$dir/projects/foo/flake.nix
  cat >$dir/projects/foo/flake.lock <<'JSON'
{"nodes":{"nixpkgs":{"locked":{"rev":"aaaa"}},"root":{"inputs":{"nixpkgs":"nixpkgs"}}}}
JSON

  local HOME=$dir
  flakeLockPinTask >/dev/null 2>&1
  flakeLocksPinned && { echo "should fail when canonical missing"; return 1; }
  return 0
}

test_shellcheckrcTask_skipsUncreatedProjects() {
  local dir; tesht.MktempDir dir || return 128
  trap "rm -rf $dir" RETURN

  # arrange: source exists but no project dirs
  mkdir -p $dir/dotfiles
  echo 'disable=SC2086' >$dir/dotfiles/.shellcheckrc

  local shellcheckrc_src=$dir/dotfiles/.shellcheckrc
  local shellcheckrc_neutral=$dir/.config/shellcheck/shellcheckrc
  local HOME=$dir
  shellcheckrcTask >/dev/null 2>&1

  # assert: neutral path created but no project symlinks
  [[ -f $dir/.config/shellcheck/shellcheckrc ]] || { echo "neutral path not created"; return 1; }
  [[ ! -e $dir/projects ]] || { echo "projects dir should not exist"; return 1; }
}
