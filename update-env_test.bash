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
    [wantGroupList]=$'apt\nhostname\ngpoc\npangp\nnix\nhm\ncredential'
  )
  local -A case2=(
    [name]='debian gets apt nix hm'
    [platform]=debian
    [wantGroupList]=$'apt\nnix\nhm'
  )
  local -A case3=(
    [name]='desktop gets pangp nix (no hm: NixOS handles home-manager elsewhere)'
    [platform]=desktop
    [wantGroupList]=$'pangp\nnix'
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

## preflightCheckCommands -- guard against home-manager activation walking
## into a missing system command at runtime. The anchor is the pangp
## systemctl-absence failure (dotfiles commit 0a888eb); these tests pin
## the warn-vs-strict surface and the anchor reference shape.

test_preflightCheckCommands_silentWhenAllPresent() {
  ## act
  local got rc
  got=$(preflightCheckCommands 0 2>&1) && rc=$? || rc=$?

  ## assert
  (( rc == 0 )) || { echo "rc=$rc, want 0"; return 1; }
  [[ -z $got ]] || { echo "got non-empty output, want empty: $got"; return 1; }
}

test_preflightCheckCommands_warnsOnMissingNonStrict() {
  ## arrange -- empty PATH so no commands resolve
  local PATH=/nonexistent

  ## act
  local got rc
  got=$(preflightCheckCommands 0 2>&1) && rc=$? || rc=$?

  ## assert -- warn-only does NOT fail rc
  (( rc == 0 )) || { echo "rc=$rc, want 0 (warn-only)"; return 1; }
  [[ $got == *systemctl* ]]  || { echo "missing 'systemctl' in output: $got"; return 1; }
  [[ $got == *sudo* ]]       || { echo "missing 'sudo' in output: $got"; return 1; }
  [[ $got == *0a888eb* ]]    || { echo "missing anchor commit ref: $got"; return 1; }
  [[ $got == *pkgs.*bin* ]]  || { echo "missing nix-managed binary recommendation: $got"; return 1; }
}

test_preflightCheckCommands_failsInStrictMode() {
  ## arrange -- empty PATH so no commands resolve
  local PATH=/nonexistent

  ## act -- strict mode (exit 1 inside the $(...) subshell propagates as rc)
  local got rc
  got=$(preflightCheckCommands 1 2>&1) && rc=$? || rc=$?

  ## assert
  (( rc != 0 )) || { echo "rc=$rc, want non-zero (strict)"; return 1; }
  [[ $got == *fatal* ]] || { echo "missing 'fatal' marker: $got"; return 1; }
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
  # Default-case path for an unknown host: opAccount falls back to
  # "my.1password.com", opVault to "$1" (= "testhost"), opAuthKeyItem to
  # "$1 SSH Key", opSigningKeyItem to "$1 signing SSH Key". Auth key is
  # listed before signing key for ssh-agent negotiation order (per the
  # agentTomlContent header comment).
  local want_='[[ssh-keys]]
account = "my.1password.com"
vault = "testhost"
item = "testhost SSH Key"

[[ssh-keys]]
account = "my.1password.com"
vault = "testhost"
item = "testhost signing SSH Key"'
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

# Phase A migrated-host coverage: calumny's per-machine vault is in the Digi work
# account. The helpers' calumny case branches must produce an agent.toml that
# references vault=calumny, account=digi.1password.com, and the per-host item names.
test_agentTomlTask_calumny() {
  local dir; tesht.MktempDir dir || return 128
  trap "rm -rf $dir" RETURN

  local agentToml_hostname=calumny
  local agentToml_path=$dir/agent.toml
  agentTomlTask >/dev/null 2>&1

  local rc=0
  [[ -f $dir/agent.toml ]] || { echo "target not created"; rc=1; }
  grep -q '"calumny"' $dir/agent.toml          || { echo "calumny vault missing";              rc=1; }
  grep -q '"calumny SSH Key"' $dir/agent.toml  || { echo "calumny auth item missing";         rc=1; }
  grep -q '"calumny signing SSH Key"' $dir/agent.toml || { echo "calumny signing item missing"; rc=1; }
  grep -q '"digi.1password.com"' $dir/agent.toml || { echo "digi account missing";            rc=1; }

  return $rc
}

# Phase A legacy-host coverage: calliope/calderon are on the personal account and
# still use the shared `calliope signing SSH Key` identity until their per-host
# migration. The case branches must produce agent.toml entries that reference
# vault=Private, account=my.1password.com, and the legacy shared signing item.
test_agentTomlTask_calliopeLegacy() {
  local dir; tesht.MktempDir dir || return 128
  trap "rm -rf $dir" RETURN

  local agentToml_hostname=calliope
  local agentToml_path=$dir/agent.toml
  agentTomlTask >/dev/null 2>&1

  local rc=0
  [[ -f $dir/agent.toml ]] || { echo "target not created"; rc=1; }
  grep -q '"Private"' $dir/agent.toml                  || { echo "Private vault missing";       rc=1; }
  grep -q '"calliope SSH Key"' $dir/agent.toml         || { echo "calliope auth item missing";  rc=1; }
  grep -q '"calliope signing SSH Key"' $dir/agent.toml || { echo "legacy shared signing missing"; rc=1; }
  grep -q '"my.1password.com"' $dir/agent.toml         || { echo "personal account missing";    rc=1; }

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

# Phase A hostname-keyed sidecar lookup: when signingPub_src is not injected,
# deploySigningPub should prefer ~/dotfiles/ssh/id_ed25519_signing_<hostname>.pub
# (per-host) over the unscoped ~/dotfiles/ssh/id_ed25519_signing.pub (legacy).
test_deploySigningPub_prefersHostnameKeyedSidecar() {
  local dir; tesht.MktempDir dir || return 128
  trap "rm -rf $dir" RETURN

  # arrange: fake ~/dotfiles/ssh/ with both unscoped (legacy) and hostname-keyed
  mkdir -p $dir/dotfiles/ssh $dir/.ssh
  echo 'ssh-ed25519 AAAA legacy-shared' >$dir/dotfiles/ssh/id_ed25519_signing.pub
  echo 'ssh-ed25519 AAAA calumny-specific' >$dir/dotfiles/ssh/id_ed25519_signing_calumny.pub

  # override $HOME and lib.MachineHostname so deploySigningPub's default-path
  # logic resolves into our tmpdir. tesht subshells confine the overrides.
  local HOME=$dir
  lib.MachineHostname() { echo calumny; }

  # act: no signingPub_src -- exercise the default-path hostname lookup
  local signingPub_dst=$dir/.ssh/id_ed25519_signing.pub
  deploySigningPub >/dev/null 2>&1

  # assert: hostname-keyed sidecar was selected, not the legacy unscoped one
  local rc=0
  diff -q $dir/dotfiles/ssh/id_ed25519_signing_calumny.pub $signingPub_dst >/dev/null 2>&1 || { echo "did not pick hostname-keyed sidecar"; rc=1; }
  ! diff -q $dir/dotfiles/ssh/id_ed25519_signing.pub $signingPub_dst >/dev/null 2>&1 || { echo "legacy sidecar was used despite hostname-keyed available"; rc=1; }

  return $rc
}

# Fallback to legacy unscoped sidecar when no hostname-keyed sidecar exists.
test_deploySigningPub_fallsBackToUnscoped() {
  local dir; tesht.MktempDir dir || return 128
  trap "rm -rf $dir" RETURN

  # arrange: only unscoped sidecar present (legacy host pre-migration)
  mkdir -p $dir/dotfiles/ssh $dir/.ssh
  echo 'ssh-ed25519 AAAA legacy-shared' >$dir/dotfiles/ssh/id_ed25519_signing.pub

  local HOME=$dir
  lib.MachineHostname() { echo calliope; }

  local signingPub_dst=$dir/.ssh/id_ed25519_signing.pub
  deploySigningPub >/dev/null 2>&1

  local rc=0
  diff -q $dir/dotfiles/ssh/id_ed25519_signing.pub $signingPub_dst >/dev/null 2>&1 || { echo "did not fall back to unscoped sidecar"; rc=1; }

  return $rc
}

test_claudeEraConfigTask_converges() {
  local dir; tesht.MktempDir dir || return 128
  trap "rm -rf $dir" RETURN

  # arrange: base and era source files
  echo '# base content' >$dir/base.md
  echo 'Do not use the Claude Code auto-memory system' >$dir/era.md

  # act: inject paths, run append
  local claudeEra_base=$dir/base.md
  local claudeEra_src=$dir/era.md
  claudeEraConfigTask >/dev/null 2>&1

  # assert: convergence (era appended)
  local rc=0
  grep -qF 'Do not use the Claude Code auto-memory system' $dir/base.md || { echo "era not appended"; rc=1; }

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

  echo 'Do not use the Claude Code auto-memory system' >$dir/era.md
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

## claudeMemoryRedirectsTask -- Q3 integration: per-project MEMORY.md deployment

test_claudeMemoryRedirectsTask_converges() {
  local dir; tesht.MktempDir dir || return 128

  # arrange: redirect source + injectable memBase
  local src=$dir/era-memory-redirect.md
  echo 'DO NOT STORE ANYTHING IN THIS FILE' >"$src"
  local claudeRedirects_src="$src"
  local claudeRedirects_memBase="$dir/mem"

  claudeMemoryRedirectsTask >/dev/null 2>&1

  # memoryProjectDirs returns real paths; pick one we know exists
  local encoded; encoded=$HOME/.claude/projects
  # check that at least one MEMORY.md was installed under memBase
  local count
  count=$(find "$dir/mem" -name "MEMORY.md" 2>/dev/null | wc -l)
  local rc=0
  (( count > 0 )) || { echo "no MEMORY.md files installed under memBase"; rc=1; }

  # spot-check: jeeves should be in the list
  local jeevesMd="$dir/mem/-home-ted-projects-jeeves/memory/MEMORY.md"
  diff -q "$src" "$jeevesMd" >/dev/null 2>&1 || { echo "jeeves MEMORY.md missing or wrong content"; rc=1; }

  # idempotence: second run is a no-op
  local mtBefore mtAfter
  mtBefore=$(stat -c %Y "$jeevesMd")
  claudeMemoryRedirectsTask >/dev/null 2>&1
  mtAfter=$(stat -c %Y "$jeevesMd")
  (( mtBefore == mtAfter )) || { echo "MEMORY.md re-installed on second run"; rc=1; }

  return $rc
}

test_claudeMemoryRedirectsTask_skipsWhenSrcMissing() {
  local dir; tesht.MktempDir dir || return 128

  local claudeRedirects_src="$dir/nonexistent.md"
  local claudeRedirects_memBase="$dir/mem"
  claudeMemoryRedirectsTask >/dev/null 2>&1

  [[ ! -d "$dir/mem" ]] || { echo "install should not run when source missing"; return 1; }
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

# extractGlobalprotectDebToOptTask tests use a REAL ELF fixture (copying
# /bin/true via coreutils' dispatcher) so patchelf --print-interpreter
# returns a real nix-store path. Shell-script stand-ins would always
# error out on patchelf and force re-stage on every test run.

test_extractGlobalprotectDebToOptTask_copies_from_marker_fresh() {
  local dir; tesht.MktempDir dir || return 128
  trap "rm -rf $dir" RETURN

  # arrange: fake $HOME with markers; pangp-source with REAL ELF binaries
  # + libwa symlink chain for the cp -a preservation assertion; empty
  # pangpDest to exercise the fresh-deploy branch.
  mkdir -p $dir/home/.local/share/pangp
  local fakeStore=$dir/pangp-store/opt/paloaltonetworks/globalprotect
  mkdir -p $fakeStore
  echo $fakeStore >$dir/home/.local/share/pangp/source
  local fakeDest=$dir/opt-target/paloaltonetworks/globalprotect
  echo $fakeDest >$dir/home/.local/share/pangp/dest

  # real ELF fixture: copy /bin/true. patchelf --print-interpreter on
  # this returns a real nix-store ld-linux path that satisfies the
  # patched-prefix idempotence check.
  cp "$(command -v patchelf)" $fakeStore/PanGPS
  cp "$(command -v patchelf)" $fakeStore/PanGPA

  # libwa symlink chain -- assert cp -a preserves it
  echo 'fake libwaheap content' >$fakeStore/libwaheap.so.4.3.3608.0
  ( cd $fakeStore && ln -s libwaheap.so.4.3.3608.0 libwaheap.so.4 )
  ( cd $fakeStore && ln -s libwaheap.so.4 libwaheap.so )

  # act: inject HOME + function-redef sudo as no-op for filesystem ops
  local HOME=$dir/home
  sudo() { "$@"; }  # tesht subshell confines
  extractGlobalprotectDebToOptTask >/dev/null 2>&1
  local rc=$?

  # assert: convergence + symlink preservation + idempotence-check truth
  local err=0
  (( rc == 0 )) || { echo "task returned $rc"; err=1; }
  [[ -f $fakeDest/PanGPS ]] || { echo "PanGPS not staged"; err=1; }
  [[ -f $fakeDest/PanGPA ]] || { echo "PanGPA not staged"; err=1; }
  [[ -L $fakeDest/libwaheap.so ]] || { echo "libwaheap.so symlink lost (cp -a regression)"; err=1; }
  [[ -L $fakeDest/libwaheap.so.4 ]] || { echo "libwaheap.so.4 symlink lost"; err=1; }

  local interp
  interp=$(patchelf --print-interpreter $fakeDest/PanGPS 2>&1)
  [[ $interp == /nix/store/* ]] || { echo "interpreter not nix-store: $interp"; err=1; }

  return $err
}

test_extractGlobalprotectDebToOptTask_idempotent_when_already_patched() {
  local dir; tesht.MktempDir dir || return 128
  trap "rm -rf $dir" RETURN

  # arrange: source AND dest already populated with real ELF binaries.
  # Idempotence: task should detect already-patched dest and no-op.
  mkdir -p $dir/home/.local/share/pangp
  local fakeStore=$dir/pangp-store/opt/paloaltonetworks/globalprotect
  local fakeDest=$dir/opt-target/paloaltonetworks/globalprotect
  mkdir -p $fakeStore $fakeDest
  echo $fakeStore >$dir/home/.local/share/pangp/source
  echo $fakeDest >$dir/home/.local/share/pangp/dest
  cp "$(command -v patchelf)" $fakeStore/PanGPS
  cp "$(command -v patchelf)" $fakeStore/PanGPA
  cp $fakeStore/PanGPS $fakeDest/PanGPS
  cp $fakeStore/PanGPA $fakeDest/PanGPA

  local HOME=$dir/home
  sudo() { "$@"; }

  # capture pre-state mtime; if task no-ops, mtime stays the same
  local mtimeBefore mtimeAfter
  mtimeBefore=$(stat -c '%Y' $fakeDest/PanGPS)
  sleep 1
  extractGlobalprotectDebToOptTask >/dev/null 2>&1
  mtimeAfter=$(stat -c '%Y' $fakeDest/PanGPS)

  (( mtimeBefore == mtimeAfter )) || { echo "task re-staged despite already-patched dest"; return 1; }
  return 0
}

test_extractGlobalprotectDebToOptTask_fails_without_marker() {
  local dir; tesht.MktempDir dir || return 128
  trap "rm -rf $dir" RETURN

  # arrange: $HOME without marker files
  mkdir -p $dir/home/.local/share/pangp
  local HOME=$dir/home

  # act
  local stderr
  stderr=$(extractGlobalprotectDebToOptTask 2>&1)
  local rc=$?

  # assert: non-zero return; informative stderr
  (( rc != 0 )) || { echo "expected non-zero rc with absent markers"; return 1; }
  [[ $stderr == *"marker"* ]] || { echo "stderr missing 'marker' guidance: $stderr"; return 1; }
  return 0
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

# Predicate-level test: flakeLocksPinned correctly detects a rev mismatch.
# Scope: ok-check only. Mocks cmd() so flakeLocksPin doesn't run and silently
# repair the mismatch before the assertion. The companion test
# test_flakeLockPinTask_repairsMismatch covers the full task path (no mock).
test_flakeLocksPinned_detectsMismatch() {
  local dir; tesht.MktempDir dir || return 128
  trap "rm -rf $dir" RETURN

  # arrange: canonical with one rev, project with a different rev.
  # foo must be a git repo with flake.nix tracked, because flakeManagedDirs
  # uses `git ls-files --error-unmatch flake.nix` to skip untracked flakes
  # (the same check nix uses).
  mkdir -p $dir/projects/era $dir/projects/foo
  cat >$dir/projects/era/flake.lock <<'JSON'
{"nodes":{"nixpkgs":{"locked":{"rev":"aaaa"}},"root":{"inputs":{"nixpkgs":"nixpkgs"}}}}
JSON
  cat >$dir/projects/foo/flake.lock <<'JSON'
{"nodes":{"nixpkgs":{"locked":{"rev":"bbbb"}},"root":{"inputs":{"nixpkgs":"nixpkgs"}}}}
JSON
  echo '{}' >$dir/projects/foo/flake.nix
  git -C $dir/projects/foo init -q
  git -C $dir/projects/foo add flake.nix

  # Mock cmd to no-op: we want the inner functions defined but no fix to run.
  cmd() { :; }
  local HOME=$dir
  flakeLockPinTask >/dev/null 2>&1
  flakeLocksPinned && { echo "should have detected mismatch"; return 1; }
  return 0
}

# Full-task test: flakeLockPinTask actually repairs a detected mismatch.
# Scope: end-to-end. No mocks; runs flakeLocksPin's jq rewrite for real and
# asserts foo's flake.lock got pinned to canonical rev.
test_flakeLockPinTask_repairsMismatch() {
  local dir; tesht.MktempDir dir || return 128
  trap "rm -rf $dir" RETURN

  mkdir -p $dir/projects/era $dir/projects/foo
  cat >$dir/projects/era/flake.lock <<'JSON'
{"nodes":{"nixpkgs":{"locked":{"rev":"aaaa"}},"root":{"inputs":{"nixpkgs":"nixpkgs"}}}}
JSON
  cat >$dir/projects/foo/flake.lock <<'JSON'
{"nodes":{"nixpkgs":{"locked":{"rev":"bbbb"}},"root":{"inputs":{"nixpkgs":"nixpkgs"}}}}
JSON
  echo '{}' >$dir/projects/foo/flake.nix
  git -C $dir/projects/foo init -q
  git -C $dir/projects/foo add flake.nix

  local HOME=$dir
  flakeLockPinTask >/dev/null 2>&1

  # assert: foo's flake.lock now has the canonical rev
  local fooRev
  fooRev=$(jq -r '.nodes.nixpkgs.locked.rev' "$dir/projects/foo/flake.lock")
  [[ $fooRev == "aaaa" ]] || { echo "foo's rev not repaired (got '$fooRev', expected 'aaaa')"; return 1; }

  # assert: ok-check now passes (idempotent on re-run)
  flakeLocksPinned || { echo "ok-check should pass after repair"; return 1; }
  return 0
}

test_flakeLockPinTask_passesWhenAligned() {
  local dir; tesht.MktempDir dir || return 128
  trap "rm -rf $dir" RETURN

  # arrange: same rev everywhere. foo must be git-tracked (see _detectsMismatch).
  mkdir -p $dir/projects/era $dir/projects/foo
  cat >$dir/projects/era/flake.lock <<'JSON'
{"nodes":{"nixpkgs":{"locked":{"rev":"aaaa"}},"root":{"inputs":{"nixpkgs":"nixpkgs"}}}}
JSON
  cat >$dir/projects/foo/flake.lock <<'JSON'
{"nodes":{"nixpkgs":{"locked":{"rev":"aaaa"}},"root":{"inputs":{"nixpkgs":"nixpkgs"}}}}
JSON
  echo '{}' >$dir/projects/foo/flake.nix
  git -C $dir/projects/foo init -q
  git -C $dir/projects/foo add flake.nix

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

## obsidianSnippetsTask -- Q3 integration: CSS snippet deploy to .obsidian/snippets/

test_obsidianSnippetsTask_converges() {
  local dir; tesht.MktempDir dir || return 128
  trap "rm -rf $dir" RETURN

  mkdir -p $dir/dotfiles/obsidian/snippets
  echo '.md { max-width: 1100px; }' >$dir/dotfiles/obsidian/snippets/custom-width.css

  local HOME=$dir
  obsidianSnippetsTask $dir/target/.obsidian/snippets >/dev/null 2>&1

  local rc=0
  [[ -f $dir/target/.obsidian/snippets/custom-width.css ]] || { echo "file not deployed"; rc=1; }
  diff -q $dir/dotfiles/obsidian/snippets/custom-width.css \
          $dir/target/.obsidian/snippets/custom-width.css >/dev/null 2>&1 || { echo "content mismatch"; rc=1; }

  local hashBefore hashAfter
  hashBefore=$(sha256sum $dir/target/.obsidian/snippets/custom-width.css | awk '{print $1}')
  obsidianSnippetsTask $dir/target/.obsidian/snippets >/dev/null 2>&1
  hashAfter=$(sha256sum $dir/target/.obsidian/snippets/custom-width.css | awk '{print $1}')
  [[ $hashBefore == $hashAfter ]] || { echo "not idempotent"; rc=1; }

  return $rc
}

test_obsidianSnippetsTask_noopWhenSrcEmpty() {
  local dir; tesht.MktempDir dir || return 128
  trap "rm -rf $dir" RETURN

  mkdir -p $dir/dotfiles/obsidian/snippets

  local HOME=$dir
  obsidianSnippetsTask $dir/target/.obsidian/snippets >/dev/null 2>&1

  [[ ! -d $dir/target ]] || { echo "target dir created despite empty source"; return 1; }
}

# gitUpdate's autostash-cleanup must not exit non-zero when there is no
# autostash entry to drop (the common case). Previous form used
# `[[ -n $stashRef ]] && cmd`, which returns 1 with an empty stashRef and
# terminates the script under set -e.
test_gitUpdate_handlesEmptyAutostash() {
  local dir; tesht.MktempDir dir || return 128
  trap "rm -rf $dir" RETURN

  # arrange: bare origin + clean local clone, both pointing at the same
  # commit (so task.GitUpdate's rebase is a no-op), no autostash present
  git init --bare $dir/origin.git >/dev/null 2>&1
  git -c init.defaultBranch=main init $dir/local >/dev/null 2>&1
  git -C $dir/local -c user.email=t@e -c user.name=t commit --allow-empty -m init >/dev/null 2>&1
  git -C $dir/local remote add origin $dir/origin.git
  git -C $dir/local push -u origin main >/dev/null 2>&1

  # act
  gitUpdate $dir/local >/dev/null 2>&1
  local rc=$?

  # assert: returned 0 (the bug case)
  (( rc == 0 )) || { echo "gitUpdate returned $rc (expected 0); empty-stashRef path failed"; return 1; }

  # assert: no spurious stash entries
  local stashCount
  stashCount=$(git -C $dir/local stash list 2>/dev/null | wc -l)
  (( stashCount == 0 )) || { echo "$stashCount unexpected stash entries"; return 1; }
  return 0
}

# test_isNotReadme tests that isNotReadme rejects README.md basenames
# and accepts other filenames (regardless of directory depth or case).
test_isNotReadme() {
  local -A case1=([name]='accept regular slash-command file' [path]='/home/ted/projects/era/commands/imprint.md' [wantRc]=0)
  local -A case2=([name]='reject literal README.md at top'   [path]='README.md' [wantRc]=1)
  local -A case3=([name]='reject README.md in deep dir'      [path]='/home/ted/projects/tandem-protocol/commands/README.md' [wantRc]=1)
  local -A case4=([name]='accept lowercase readme.md'        [path]='/some/where/readme.md' [wantRc]=0)
  local -A case5=([name]='accept README-addendum.md'         [path]='/some/where/README-addendum.md' [wantRc]=0)

  subtest() {
    local casename=$1
    eval "$(tesht.Inherit "$casename")"
    isNotReadme "$path"; local got=$?
    tesht.AssertRC "$got" "$wantRc"
  }

  tesht.Run ${!case@}
}
