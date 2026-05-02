source ./update-env   # sources scripts/lib.bash, provides NL, each, stream

## functions

# test_glob tests lib.Glob with temporary directories to control the environment.
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

  subtest() {
    local casename=$1

    ## arrange

    local dir
    tesht.MktempDir dir || return 128
    cd "$dir" || return 128

    eval "$(tesht.Inherit $casename)"

    stream "${files[@]}" | each touch

    ## act

    local got rc
    got=$(lib.Glob "${args[@]}") && rc=$? || rc=$?

    ## assert
    local want
    want=$(stream "${wants[@]}")
    tesht.AssertGot "$got" "$want"
  }

  local failed=0 casename
  for casename in ${!case@}; do
    tesht.Run $casename || {
      (( $? == 128 )) && return 128
      failed=1
    }
  done

  return $failed
}

# test_lib.ValidateHostname tests hostname validation rules.
test_lib.ValidateHostname() {
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
    lib.ValidateHostname "$input" >/dev/null 2>&1 && rc=$? || rc=$?
    (( rc == wantRc )) || {
      echo "${NL}lib.ValidateHostname ${input@Q}: rc=$rc, want=$wantRc"
      return 1
    }
  }

  tesht.Run ${!case@}
}

# test_lib.ValidSecretName tests the shared filename policy used by both
# encrypt-secrets (producer) and restoreSecrets (consumer).
test_lib.ValidSecretName() {
  local -A case1=([name]='accept simple name' [input]='stash.key' [wantRc]=0)
  local -A case2=([name]='accept underscores' [input]='api_token' [wantRc]=0)
  local -A case3=([name]='accept hyphens' [input]='my-token' [wantRc]=0)
  local -A case4=([name]='accept dots' [input]='key.pem' [wantRc]=0)
  local -A case5=([name]='reject dotfile' [input]='.secret' [wantRc]=1)
  local -A case6=([name]='reject leading dash' [input]='-rf' [wantRc]=1)
  local -A case7=([name]='reject path separator' [input]='foo/bar' [wantRc]=1)
  local -A case8=([name]='reject spaces' [input]='my key' [wantRc]=1)
  local -A case9=([name]='reject empty' [input]='' [wantRc]=1)
  local -A case10=([name]='reject path traversal' [input]='../etc' [wantRc]=1)

  subtest() {
    local casename=$1
    eval "$(tesht.Inherit "$casename")"
    local rc
    lib.ValidSecretName "$input" && rc=$? || rc=$?
    (( rc == wantRc )) || {
      echo "lib.ValidSecretName ${input@Q}: rc=$rc, want=$wantRc"
      return 1
    }
  }

  tesht.Run ${!case@}
}

# test_lib.MachineHostname tests hostname resolution returns a valid hostname.
test_lib.MachineHostname() {
  local got
  got=$(lib.MachineHostname)
  [[ -n $got ]] || { echo "lib.MachineHostname returned empty"; return 1; }
}
