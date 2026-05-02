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

## hasGroup -- Q1: pure predicate, domain-significant (gates deployment phases)

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

test_platformTaskGroups() {
  local -A case1=(
    [name]='crostini gets all groups'
    [platform]=crostini
    [wantGroups]='apt hostname gpoc nix hm credential'
  )
  local -A case2=(
    [name]='debian gets apt nix hm'
    [platform]=debian
    [wantGroups]='apt nix hm'
  )
  local -A case3=(
    [name]='linux gets nix only'
    [platform]=linux
    [wantGroups]=nix
  )
  local -A case4=(
    [name]='macos gets nix only'
    [platform]=macos
    [wantGroups]=nix
  )
  local -A case5=(
    [name]='nixos gets nothing'
    [platform]=nixos
    [wantGroups]=''
  )

  subtest() {
    local casename=$1
    eval "$(tesht.Inherit "$casename")"
    local got_
    got_=$(platformTaskGroups $platform)
    # normalize newlines to spaces for comparison
    got_=$(echo "$got_" | tr '\n' ' ')
    got_=${got_% }
    [[ $got_ == "$wantGroups" ]] || { echo "got='$got_', want='$wantGroups'"; return 1; }
  }

  tesht.Run ${!case@}
}

## loosely -- Q1: shell option preservation, domain-significant (broken = no error handling)

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

test_loosely_preservesIfs() {
  local before_=$IFS
  loosely true
  [[ $IFS == "$before_" ]] || { echo "IFS changed"; return 1; }
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
