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
    local dir
    tesht.MktempDir dir || return 128
    cd "$dir"

    # create variables from the keys/values of the test map
    eval "$(tesht.Inherit $casename)"

    # Create test files
    stream "${files[@]}" | each touch

    ## act

    # run the command and capture the output and result code
    local got rc
    got=$(glob "${args[@]}") && rc=$? || rc=$?

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

## credential bootstrap helpers

# test_validateHostname tests hostname validation rules.
test_validateHostname() {
  local -A case1=(
    [name]='accept simple hostname'
    [input]='calumny'
    [wantRc]=0
  )
  local -A case2=(
    [name]='accept hostname with hyphen'
    [input]='my-host'
    [wantRc]=0
  )
  local -A case3=(
    [name]='reject penguin'
    [input]='penguin'
    [wantRc]=1
  )
  local -A case4=(
    [name]='reject uppercase'
    [input]='MyHost'
    [wantRc]=1
  )
  local -A case5=(
    [name]='reject special characters'
    [input]='host/name'
    [wantRc]=1
  )
  local -A case6=(
    [name]='reject leading hyphen'
    [input]='-badhost'
    [wantRc]=1
  )

  subtest() {
    local casename=$1
    eval "$(tesht.Inherit "$casename")"
    local rc
    validateHostname "$input" >/dev/null 2>&1 && rc=$? || rc=$?
    (( rc == wantRc )) || {
      echo "${NL}validateHostname ${input@Q}: rc=$rc, want=$wantRc"
      return 1
    }
  }

  tesht.Run ${!case@}
}

# test_pubFingerprint tests fingerprint extraction from .pub files.
test_pubFingerprint() {
  local -A case1=(
    [name]='extract fingerprint from valid pub file'
    [wantNonEmpty]=1
  )
  local -A case2=(
    [name]='return empty for missing file'
    [wantNonEmpty]=0
  )
  local -A case3=(
    [name]='return empty for empty file'
    [wantNonEmpty]=0
  )
  local -A case4=(
    [name]='return empty for malformed file'
    [wantNonEmpty]=0
  )

  subtest() {
    local casename=$1
    eval "$(tesht.Inherit "$casename")"
    local dir got
    tesht.MktempDir dir || return 128
    case $casename in
      case1)
        ssh-keygen -t ed25519 -f "$dir/key" -N "" -q
        got=$(pubFingerprint "$dir/key.pub")
        ;;
      case2)
        got=$(pubFingerprint "$dir/nonexistent.pub")
        ;;
      case3)
        touch "$dir/empty.pub"
        got=$(pubFingerprint "$dir/empty.pub")
        ;;
      case4)
        echo "not a key" > "$dir/bad.pub"
        got=$(pubFingerprint "$dir/bad.pub")
        ;;
    esac
    if (( wantNonEmpty )); then
      [[ -n "$got" ]] || { echo "${NL}pubFingerprint: got empty, want non-empty"; return 1; }
    else
      [[ -z "$got" ]] || { echo "${NL}pubFingerprint: got=$got, want empty"; return 1; }
    fi
  }

  tesht.Run ${!case@}
}

# test_installKey tests atomic key pair installation.
test_installKey() {
  local -A case1=([name]='install private key and pub')
  local -A case2=([name]='install private key without pub')
  local -A case3=([name]='fail on missing source')

  subtest() {
    local casename=$1
    eval "$(tesht.Inherit "$casename")"
    local dir rc
    tesht.MktempDir dir || return 128
    case $casename in
      case1)
        ssh-keygen -t ed25519 -f "$dir/src" -N "" -q
        installKey "$dir/src" "$dir/dst" && rc=$? || rc=$?
        (( rc == 0 ))          || { echo "${NL}installKey failed: rc=$rc"; return 1; }
        [[ -f "$dir/dst" ]]     || { echo "${NL}dst missing"; return 1; }
        [[ -f "$dir/dst.pub" ]] || { echo "${NL}dst.pub missing"; return 1; }
        local privPerms pubPerms
        privPerms=$(stat -c %a "$dir/dst")
        pubPerms=$(stat -c %a "$dir/dst.pub")
        [[ $privPerms == 600 ]] || { echo "${NL}dst perms=$privPerms, want=600"; return 1; }
        [[ $pubPerms == 644 ]]  || { echo "${NL}dst.pub perms=$pubPerms, want=644"; return 1; }
        ;;
      case2)
        ssh-keygen -t ed25519 -f "$dir/src" -N "" -q
        rm -f "$dir/src.pub"
        installKey "$dir/src" "$dir/dst" && rc=$? || rc=$?
        (( rc == 0 ))             || { echo "${NL}installKey failed: rc=$rc"; return 1; }
        [[ -f "$dir/dst" ]]       || { echo "${NL}dst missing"; return 1; }
        [[ ! -f "$dir/dst.pub" ]] || { echo "${NL}dst.pub should not exist"; return 1; }
        ;;
      case3)
        installKey "$dir/nonexistent" "$dir/dst" && rc=$? || rc=$?
        (( rc != 0 ))            || { echo "${NL}should fail for missing src"; return 1; }
        [[ ! -f "$dir/dst" ]]    || { echo "${NL}dst should not exist"; return 1; }
        ;;
    esac
  }

  tesht.Run ${!case@}
}

# test_sshKeyAction tests the pure decision function for SSH key restore.
# Each test builds a state associative array and asserts the returned action.
# No I/O, no filesystem — pure decision logic in Khorikov's "valuable" quadrant.
test_sshKeyAction() {
  # Helper: build state array from test case, call sshKeyAction
  # Test cases use lowercase keys matching the state array contract.
  local -A case1=(
    [name]='local key matches repo — present'
    [repoHasAge]=1 [repoHasPub]=1 [repoFp]='SHA256:abc'
    [localExists]=1 [localFp]='SHA256:abc'
    [cacheExists]=0 [cacheFp]='' [hasTty]=1 [hasAge]=1
    [want]='present'
  )
  local -A case2=(
    [name]='local key mismatches repo — collision'
    [repoHasAge]=1 [repoHasPub]=1 [repoFp]='SHA256:abc'
    [localExists]=1 [localFp]='SHA256:xyz'
    [cacheExists]=0 [cacheFp]='' [hasTty]=1 [hasAge]=1
    [want]='collision'
  )
  local -A case3=(
    [name]='unverifiable local + cache available — backup then cache'
    [repoHasAge]=1 [repoHasPub]=1 [repoFp]='SHA256:abc'
    [localExists]=1 [localFp]=''
    [cacheExists]=1 [cacheFp]='SHA256:abc' [hasTty]=1 [hasAge]=1
    [want]='backup_then_cache'
  )
  local -A case4=(
    [name]='unverifiable local + no cache, has age — backup then age'
    [repoHasAge]=1 [repoHasPub]=1 [repoFp]='SHA256:abc'
    [localExists]=1 [localFp]=''
    [cacheExists]=0 [cacheFp]='' [hasTty]=1 [hasAge]=1
    [want]='backup_then_age'
  )
  local -A case5=(
    [name]='unverifiable local + no cache, no age — backup then fail'
    [repoHasAge]=0 [repoHasPub]=1 [repoFp]='SHA256:abc'
    [localExists]=1 [localFp]=''
    [cacheExists]=0 [cacheFp]='' [hasTty]=1 [hasAge]=1
    [want]='error_pub_without_age'
  )
  local -A case6=(
    [name]='local key exists, no repo pair — capture'
    [repoHasAge]=0 [repoHasPub]=0 [repoFp]=''
    [localExists]=1 [localFp]='SHA256:abc'
    [cacheExists]=0 [cacheFp]='' [hasTty]=1 [hasAge]=1
    [want]='capture_to_repo'
  )
  local -A case7=(
    [name]='no local, cache matches repo — restore from cache'
    [repoHasAge]=1 [repoHasPub]=1 [repoFp]='SHA256:abc'
    [localExists]=0 [localFp]=''
    [cacheExists]=1 [cacheFp]='SHA256:abc' [hasTty]=1 [hasAge]=1
    [want]='restore_from_cache'
  )
  local -A case8=(
    [name]='no local, stale cache — restore from age'
    [repoHasAge]=1 [repoHasPub]=1 [repoFp]='SHA256:abc'
    [localExists]=0 [localFp]=''
    [cacheExists]=1 [cacheFp]='SHA256:old' [hasTty]=1 [hasAge]=1
    [want]='restore_from_age'
  )
  local -A case9=(
    [name]='no local, no cache, has age — restore from age'
    [repoHasAge]=1 [repoHasPub]=1 [repoFp]='SHA256:abc'
    [localExists]=0 [localFp]=''
    [cacheExists]=0 [cacheFp]='' [hasTty]=1 [hasAge]=1
    [want]='restore_from_age'
  )
  local -A case10=(
    [name]='nothing anywhere, has tty — generate'
    [repoHasAge]=0 [repoHasPub]=0 [repoFp]=''
    [localExists]=0 [localFp]=''
    [cacheExists]=0 [cacheFp]='' [hasTty]=1 [hasAge]=1
    [want]='generate'
  )
  local -A case11=(
    [name]='nothing anywhere, no tty — missing noninteractive'
    [repoHasAge]=0 [repoHasPub]=0 [repoFp]=''
    [localExists]=0 [localFp]=''
    [cacheExists]=0 [cacheFp]='' [hasTty]=0 [hasAge]=1
    [want]='missing_noninteractive'
  )
  local -A case12=(
    [name]='age without pub — error'
    [repoHasAge]=1 [repoHasPub]=0 [repoFp]=''
    [localExists]=0 [localFp]=''
    [cacheExists]=0 [cacheFp]='' [hasTty]=1 [hasAge]=1
    [want]='error_age_without_pub'
  )
  local -A case13=(
    [name]='pub without age — error'
    [repoHasAge]=0 [repoHasPub]=1 [repoFp]='SHA256:abc'
    [localExists]=0 [localFp]=''
    [cacheExists]=0 [cacheFp]='' [hasTty]=1 [hasAge]=1
    [want]='error_pub_without_age'
  )
  local -A case14=(
    [name]='malformed repo pub — error'
    [repoHasAge]=1 [repoHasPub]=1 [repoFp]=''
    [localExists]=0 [localFp]=''
    [cacheExists]=0 [cacheFp]='' [hasTty]=1 [hasAge]=1
    [want]='error_malformed_pub'
  )
  local -A case15=(
    [name]='repo has age, no tty — missing noninteractive'
    [repoHasAge]=1 [repoHasPub]=1 [repoFp]='SHA256:abc'
    [localExists]=0 [localFp]=''
    [cacheExists]=0 [cacheFp]='' [hasTty]=0 [hasAge]=1
    [want]='missing_noninteractive'
  )
  local -A case16=(
    [name]='repo has age, no age command — error'
    [repoHasAge]=1 [repoHasPub]=1 [repoFp]='SHA256:abc'
    [localExists]=0 [localFp]=''
    [cacheExists]=0 [cacheFp]='' [hasTty]=1 [hasAge]=0
    [want]='error_age_not_found'
  )
  local -A case17=(
    [name]='cache valid, no repo — restore from cache'
    [repoHasAge]=0 [repoHasPub]=0 [repoFp]=''
    [localExists]=0 [localFp]=''
    [cacheExists]=1 [cacheFp]='SHA256:abc' [hasTty]=1 [hasAge]=1
    [want]='restore_from_cache'
  )
  # Boundary: cache exists but fingerprint empty — should not use cache
  local -A case18=(
    [name]='cache exists but empty fingerprint — fall through to age'
    [repoHasAge]=1 [repoHasPub]=1 [repoFp]='SHA256:abc'
    [localExists]=0 [localFp]=''
    [cacheExists]=1 [cacheFp]='' [hasTty]=1 [hasAge]=1
    [want]='restore_from_age'
  )
  # Boundary: unverifiable local, stale cache, has age — backup then age
  local -A case19=(
    [name]='unverifiable local + stale cache — backup then age'
    [repoHasAge]=1 [repoHasPub]=1 [repoFp]='SHA256:abc'
    [localExists]=1 [localFp]=''
    [cacheExists]=1 [cacheFp]='SHA256:old' [hasTty]=1 [hasAge]=1
    [want]='backup_then_age'
  )
  # Boundary: unverifiable local, no tty — missing noninteractive
  local -A case20=(
    [name]='unverifiable local + no tty — missing noninteractive'
    [repoHasAge]=1 [repoHasPub]=1 [repoFp]='SHA256:abc'
    [localExists]=1 [localFp]=''
    [cacheExists]=0 [cacheFp]='' [hasTty]=0 [hasAge]=1
    [want]='missing_noninteractive'
  )

  subtest() {
    local casename=$1

    local got
    got=$(sshKeyAction "$casename")

    eval "$(tesht.Inherit "$casename")"
    tesht.AssertGot "$got" "$want"
  }

  tesht.Run ${!case@}
}

# test_machineHostname tests hostname resolution returns a valid hostname.
test_machineHostname() {
  local got
  got=$(machineHostname)
  [[ -n "$got" ]] || { echo "machineHostname returned empty"; return 1; }
}
